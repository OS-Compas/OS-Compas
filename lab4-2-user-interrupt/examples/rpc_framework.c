/**
 * rpc_framework.c - 基于UINTR的简单RPC框架
 * 
 * 展示如何将UINTR集成到RPC框架中
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/mman.h>
#include <sys/syscall.h>

/* RPC框架定义 */
#define MAX_RPC_METHODS 10
#define SHARED_BUFFER_SIZE 4096

typedef struct {
    int method_id;
    int param1;
    int param2;
    int result;
    volatile int ready;
    volatile int processed;
} rpc_request_t;

typedef struct {
    rpc_request_t *requests;
    int request_count;
    pthread_mutex_t lock;
    volatile int interrupt_pending;
} rpc_server_t;

typedef int (*rpc_handler_t)(int, int);

/* 简化的UINTR支持 */
#ifdef UINTR_SUPPORT
#include "uintr_common.h"
static int uipi_index = -1;
#endif

/* RPC方法实现 */
static int add(int a, int b) { return a + b; }
static int sub(int a, int b) { return a - b; }
static int mul(int a, int b) { return a * b; }
static int div_safe(int a, int b) { return b != 0 ? a / b : 0; }

static rpc_handler_t rpc_methods[] = {
    add,        // method_id = 0
    sub,        // method_id = 1
    mul,        // method_id = 2
    div_safe,   // method_id = 3
    NULL
};

/* UINTR中断处理函数 */
#ifdef UINTR_SUPPORT
static void __attribute__((interrupt)) rpc_interrupt_handler(void)
{
    // 在实际实现中，这里会处理RPC请求队列
    printf("[RPC] Interrupt received for RPC processing\n");
}
#endif

/* RPC服务器线程 */
static void *rpc_server_thread(void *arg)
{
    rpc_server_t *server = (rpc_server_t *)arg;
    
#ifdef UINTR_SUPPORT
    // 注册UINTR处理函数
    if (uintr_register_handler((unsigned long)rpc_interrupt_handler, 0) < 0) {
        printf("[RPC Server] UINTR not available, using polling\n");
    }
#endif
    
    printf("[RPC Server] Started (PID: %d)\n", getpid());
    
    while (1) {
        for (int i = 0; i < server->request_count; i++) {
            rpc_request_t *req = &server->requests[i];
            
            if (req->ready && !req->processed) {
                pthread_mutex_lock(&server->lock);
                
                // 处理RPC请求
                if (req->method_id >= 0 && req->method_id < 4) {
                    req->result = rpc_methods[req->method_id](req->param1, req->param2);
                    printf("[RPC Server] Processed request %d: %d %c %d = %d\n",
                           i, req->param1, 
                           req->method_id == 0 ? '+' : 
                           req->method_id == 1 ? '-' : 
                           req->method_id == 2 ? '*' : '/',
                           req->param2, req->result);
                }
                
                req->processed = 1;
                pthread_mutex_unlock(&server->lock);
                
#ifdef UINTR_SUPPORT
                // 如果有中断挂起，清除标志
                if (server->interrupt_pending) {
                    server->interrupt_pending = 0;
                }
#endif
            }
        }
        
        usleep(1000); // 避免忙等待
    }
    
    return NULL;
}

/* RPC客户端函数 */
static int rpc_call(rpc_request_t *req, int method_id, int param1, int param2)
{
    req->method_id = method_id;
    req->param1 = param1;
    req->param2 = param2;
    req->result = 0;
    req->processed = 0;
    req->ready = 1;
    
#ifdef UINTR_SUPPORT
    // 发送UINTR通知服务器
    if (uipi_index >= 0) {
        senduipi(uipi_index);
    }
#endif
    
    // 等待响应
    while (!req->processed) {
        usleep(10);
    }
    
    req->ready = 0;
    return req->result;
}

int main(void)
{
    printf("=== Simple RPC Framework with UINTR ===\n");
    
    // 创建共享内存
    rpc_request_t *shared_reqs = mmap(NULL, sizeof(rpc_request_t) * 10,
                                     PROT_READ | PROT_WRITE,
                                     MAP_SHARED | MAP_ANONYMOUS, -1, 0);
    
    if (shared_reqs == MAP_FAILED) {
        perror("mmap failed");
        return 1;
    }
    
    memset(shared_reqs, 0, sizeof(rpc_request_t) * 10);
    
    rpc_server_t server = {
        .requests = shared_reqs,
        .request_count = 10,
        .interrupt_pending = 0
    };
    pthread_mutex_init(&server.lock, NULL);
    
    // 创建服务器线程
    pthread_t server_thread;
    if (pthread_create(&server_thread, NULL, rpc_server_thread, &server) != 0) {
        perror("pthread_create failed");
        return 1;
    }
    
    sleep(1); // 给服务器时间初始化
    
    // 客户端测试
    printf("\n=== RPC Client Tests ===\n");
    
    // 测试1: 加法
    int result = rpc_call(&shared_reqs[0], 0, 10, 5);
    printf("Test 1: 10 + 5 = %d\n", result);
    
    // 测试2: 减法
    result = rpc_call(&shared_reqs[1], 1, 20, 7);
    printf("Test 2: 20 - 7 = %d\n", result);
    
    // 测试3: 乘法
    result = rpc_call(&shared_reqs[2], 2, 6, 8);
    printf("Test 3: 6 * 8 = %d\n", result);
    
    // 测试4: 除法
    result = rpc_call(&shared_reqs[3], 3, 100, 4);
    printf("Test 4: 100 / 4 = %d\n", result);
    
    // 性能测试
    printf("\n=== Performance Test ===\n");
    
    struct timeval start, end;
    gettimeofday(&start, NULL);
    
    int iterations = 100;
    for (int i = 0; i < iterations; i++) {
        rpc_call(&shared_reqs[i % 10], i % 4, i, i + 1);
    }
    
    gettimeofday(&end, NULL);
    
    long long elapsed = (end.tv_sec - start.tv_sec) * 1000000LL + 
                       (end.tv_usec - start.tv_usec);
    
    printf("Completed %d RPC calls in %lld us\n", iterations, elapsed);
    printf("Average latency: %.2f us per call\n", (double)elapsed / iterations);
    
    // 清理
    pthread_cancel(server_thread);
    pthread_join(server_thread, NULL);
    pthread_mutex_destroy(&server.lock);
    munmap(shared_reqs, sizeof(rpc_request_t) * 10);
    
    printf("\n=== RPC Framework Example Completed ===\n");
    return 0;
}