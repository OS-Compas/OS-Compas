/**
 * uintr_server.c - UINTR服务器进程
 * 
 * 演示如何注册用户态中断处理函数并响应中断
 */

#include "uintr_common.h"
#include <stdatomic.h>
#include <signal.h>
#include <sys/ipc.h>
#include <sys/shm.h>

/* 全局变量 */
static volatile atomic_int interrupt_count = 0;
static shared_data_t *shared_mem = NULL;
static int shm_id = -1;
static int uipi_fd = -1;
static int uipi_index = -1;

/* 用户态中断处理函数 */
static void __attribute__((interrupt)) uintr_handler(struct __uintr_frame *ui_frame, unsigned long long vector)
{
    interrupt_count++;
    
    if (shared_mem) {
        printf("[Server] UINTR received! Count: %d, Message: %s\n", 
               interrupt_count, shared_mem->message);
        
        // 处理请求并设置响应
        shared_mem->response = interrupt_count * 100;
    }
}

/* 清理函数 */
static void cleanup(void)
{
    printf("[Server] Cleaning up...\n");
    
    if (uipi_index >= 0) {
        uintr_unregister_sender(uipi_index, 0);
    }
    
    if (uipi_fd >= 0) {
        close(uipi_fd);
    }
    
    if (shared_mem) {
        shmdt(shared_mem);
    }
    
    if (shm_id >= 0) {
        shmctl(shm_id, IPC_RMID, NULL);
    }
    
    uintr_unregister_handler((unsigned int)uintr_handler, 0);
}

/* 信号处理函数 */
static void signal_handler(int sig)
{
    printf("\n[Server] Received signal %d, exiting...\n", sig);
    cleanup();
    exit(0);
}

int main(int argc, char *argv[])
{
    int iterations = 10;
    benchmark_t bench;
    
    printf("=== UINTR Server Process ===\n");
    printf("Process ID: %d\n", getpid());
    
    // 设置信号处理
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // 创建共享内存
    key_t key = ftok("/tmp", 'U');
    shm_id = shmget(key, sizeof(shared_data_t), IPC_CREAT | 0666);
    if (shm_id < 0) {
        perror("shmget failed");
        return 1;
    }
    
    shared_mem = (shared_data_t *)shmat(shm_id, NULL, 0);
    if (shared_mem == (void *)-1) {
        perror("shmat failed");
        return 1;
    }
    
    memset(shared_mem, 0, sizeof(shared_data_t));
    
    // 注册UINTR处理函数
    printf("[Server] Registering UINTR handler...\n");
    int ret = uintr_register_handler((unsigned int)uintr_handler, 0);
    if (ret < 0) {
        perror("uintr_register_handler failed");
        cleanup();
        return 1;
    }
    
    // 创建UINTR文件描述符
    uipi_fd = uintr_create_fd();
    if (uipi_fd < 0) {
        perror("uintr_create_fd failed");
        cleanup();
        return 1;
    }
    
    // 注册发送者（自己）
    uipi_index = uintr_register_sender(uipi_fd, 0);
    if (uipi_index < 0) {
        perror("uintr_register_sender failed");
        cleanup();
        return 1;
    }
    
    // 将向量号写入共享内存
    shared_mem->vector = uipi_index;
    printf("[Server] UINTR vector: %d\n", uipi_index);
    
    // 等待客户端连接
    printf("[Server] Waiting for client to connect...\n");
    printf("[Server] Shared memory ID: %d\n", shm_id);
    printf("[Server] Press Ctrl+C to exit\n\n");
    
    // 等待中断
    bench.total_latency = 0;
    bench.iterations = 0;
    
    while (1) {
        // 重置就绪标志
        shared_mem->ready = 0;
        
        // 等待客户端设置消息
        while (shared_mem->ready == 0) {
            usleep(1000); // 短暂休眠避免忙等待
        }
        
        // 测量延迟
        if (interrupt_count > 0 && bench.iterations < iterations) {
            bench.iterations++;
            printf("[Server] Request %d processed. Response: %d\n", 
                   bench.iterations, shared_mem->response);
        }
        
        if (bench.iterations >= iterations) {
            printf("[Server] Completed %d iterations\n", iterations);
            break;
        }
        
        sleep(1); // 给客户端时间发送下一个请求
    }
    
    cleanup();
    printf("[Server] Exiting normally\n");
    return 0;
}