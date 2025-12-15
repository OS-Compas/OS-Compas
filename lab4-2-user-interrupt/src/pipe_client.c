/**
 * pipe_client.c - 传统管道客户端
 * 
 * 用于与UINTR进行性能对比
 */

#include "uintr_common.h"
#include <sys/types.h>
#include <sys/stat.h>

int main(int argc, char *argv[])
{
    int read_fd, write_fd;
    char pipe_name_read[64];
    char pipe_name_write[64];
    int server_pid;
    int iterations = 10;
    benchmark_t bench;
    
    if (argc < 2) {
        printf("Usage: %s <server_pid> [iterations]\n", argv[0]);
        return 1;
    }
    
    server_pid = atoi(argv[1]);
    if (argc >= 3) {
        iterations = atoi(argv[2]);
    }
    
    printf("=== Pipe Client Process ===\n");
    printf("Server PID: %d\n", server_pid);
    printf("Iterations: %d\n", iterations);
    
    // 构建管道名称
    snprintf(pipe_name_read, sizeof(pipe_name_read), "/tmp/pipe_server_read_%d", server_pid);
    snprintf(pipe_name_write, sizeof(pipe_name_write), "/tmp/pipe_server_write_%d", server_pid);
    
    // 打开管道（注意：客户端打开的顺序与服务器相反）
    printf("[Pipe Client] Connecting to server...\n");
    
    write_fd = open(pipe_name_write, O_WRONLY);
    if (write_fd < 0) {
        perror("open write pipe failed");
        return 1;
    }
    
    read_fd = open(pipe_name_read, O_RDONLY);
    if (read_fd < 0) {
        perror("open read pipe failed");
        close(write_fd);
        return 1;
    }
    
    printf("[Pipe Client] Connected to server\n");
    
    // 性能测试
    bench.total_latency = 0;
    bench.iterations = 0;
    
    printf("\n[Pipe Client] Starting Pipe latency test...\n");
    printf("========================================\n");
    
    for (int i = 1; i <= iterations; i++) {
        int request = i;
        int response;
        
        // 测量往返延迟
        start_timing(&bench);
        
        // 发送请求
        ssize_t bytes = write(write_fd, &request, sizeof(request));
        if (bytes != sizeof(request)) {
            printf("[Pipe Client] Write error\n");
            break;
        }
        
        // 接收响应
        bytes = read(read_fd, &response, sizeof(response));
        if (bytes != sizeof(response)) {
            printf("[Pipe Client] Read error\n");
            break;
        }
        
        stop_timing(&bench);
        
        long long latency = get_latency_us(&bench);
        bench.total_latency += latency;
        bench.iterations++;
        
        printf("[Pipe Client] Request %d: %d -> %d, Latency: %lld us\n",
               i, request, response, latency);
        
        usleep(50000); // 50ms间隔
    }
    
    // 输出统计信息
    printf("\n========================================\n");
    printf("[Pipe Client] Pipe Test Results:\n");
    printf("  Total iterations: %d\n", bench.iterations);
    printf("  Total latency: %lld us\n", bench.total_latency);
    printf("  Average latency: %.2f us\n", get_average_latency_us(&bench));
    printf("  Average RTT latency: %.2f us\n", 
           (double)bench.total_latency / bench.iterations);
    
    // 清理
    close(read_fd);
    close(write_fd);
    
    printf("[Pipe Client] Test completed\n");
    return 0;
}