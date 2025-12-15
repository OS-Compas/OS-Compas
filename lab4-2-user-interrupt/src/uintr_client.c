/**
 * uintr_client.c - UINTR客户端进程
 * 
 * 演示如何获取UINTR向量并发送用户态中断
 */

#include "uintr_common.h"
#include <sys/ipc.h>
#include <sys/shm.h>

int main(int argc, char *argv[])
{
    int server_pid = 0;
    int iterations = 10;
    benchmark_t bench;
    shared_data_t *shared_mem = NULL;
    int shm_id = -1;
    
    printf("=== UINTR Client Process ===\n");
    
    if (argc < 2) {
        printf("Usage: %s <server_pid> [iterations]\n", argv[0]);
        return 1;
    }
    
    server_pid = atoi(argv[1]);
    if (argc >= 3) {
        iterations = atoi(argv[2]);
    }
    
    printf("Server PID: %d\n", server_pid);
    printf("Iterations: %d\n", iterations);
    
    // 连接到共享内存
    key_t key = ftok("/tmp", 'U');
    shm_id = shmget(key, sizeof(shared_data_t), 0666);
    if (shm_id < 0) {
        perror("shmget failed");
        return 1;
    }
    
    shared_mem = (shared_data_t *)shmat(shm_id, NULL, 0);
    if (shared_mem == (void *)-1) {
        perror("shmat failed");
        return 1;
    }
    
    // 等待服务器准备好
    printf("[Client] Waiting for server to initialize...\n");
    while (shared_mem->vector == 0) {
        usleep(100000); // 100ms
    }
    
    int uipi_index = shared_mem->vector;
    printf("[Client] Got UINTR vector: %d\n", uipi_index);
    
    // 性能测试
    bench.total_latency = 0;
    bench.iterations = 0;
    
    printf("\n[Client] Starting UINTR latency test...\n");
    printf("========================================\n");
    
    for (int i = 1; i <= iterations; i++) {
        // 准备消息
        snprintf(shared_mem->message, sizeof(shared_mem->message), 
                "Request #%d from client %d", i, getpid());
        shared_mem->response = 0;
        
        // 设置就绪标志
        shared_mem->ready = 1;
        
        // 测量发送延迟
        start_timing(&bench);
        
        // 发送用户态中断
        int ret = senduipi(uipi_index);
        if (ret < 0) {
            perror("senduipi failed");
            break;
        }
        
        // 等待响应
        while (shared_mem->response == 0) {
            usleep(10); // 微秒级等待
        }
        
        stop_timing(&bench);
        
        long long latency = get_latency_us(&bench);
        bench.total_latency += latency;
        bench.iterations++;
        
        printf("[Client] Request %d sent. Response: %d, Latency: %lld us\n",
               i, shared_mem->response, latency);
        
        // 清除就绪标志
        shared_mem->ready = 0;
        
        usleep(50000); // 50ms间隔
    }
    
    // 输出统计信息
    printf("\n========================================\n");
    printf("[Client] UINTR Test Results:\n");
    printf("  Total iterations: %d\n", bench.iterations);
    printf("  Total latency: %lld us\n", bench.total_latency);
    printf("  Average latency: %.2f us\n", get_average_latency_us(&bench));
    printf("  Average latency per iteration: %.2f us\n", 
           (double)bench.total_latency / bench.iterations);
    
    // 清理
    if (shared_mem) {
        shmdt(shared_mem);
    }
    
    printf("[Client] Test completed\n");
    return 0;
}