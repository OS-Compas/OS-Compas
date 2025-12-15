/**
 * pipe_server.c - 传统管道服务器
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
    char buffer[256];
    int iterations = 10;
    benchmark_t bench;
    
    printf("=== Pipe Server Process ===\n");
    printf("Process ID: %d\n", getpid());
    
    if (argc >= 2) {
        iterations = atoi(argv[1]);
    }
    
    // 创建命名管道
    snprintf(pipe_name_read, sizeof(pipe_name_read), "/tmp/pipe_server_read_%d", getpid());
    snprintf(pipe_name_write, sizeof(pipe_name_write), "/tmp/pipe_server_write_%d", getpid());
    
    // 删除可能存在的旧管道
    unlink(pipe_name_read);
    unlink(pipe_name_write);
    
    // 创建管道
    if (mkfifo(pipe_name_read, 0666) < 0) {
        perror("mkfifo read failed");
        return 1;
    }
    
    if (mkfifo(pipe_name_write, 0666) < 0) {
        perror("mkfifo write failed");
        unlink(pipe_name_read);
        return 1;
    }
    
    printf("[Pipe Server] Named pipes created:\n");
    printf("  Read pipe: %s\n", pipe_name_read);
    printf("  Write pipe: %s\n", pipe_name_write);
    
    // 打开管道
    printf("[Pipe Server] Waiting for client to connect...\n");
    read_fd = open(pipe_name_read, O_RDONLY);
    if (read_fd < 0) {
        perror("open read pipe failed");
        unlink(pipe_name_read);
        unlink(pipe_name_write);
        return 1;
    }
    
    write_fd = open(pipe_name_write, O_WRONLY);
    if (write_fd < 0) {
        perror("open write pipe failed");
        close(read_fd);
        unlink(pipe_name_read);
        unlink(pipe_name_write);
        return 1;
    }
    
    printf("[Pipe Server] Client connected\n");
    
    // 性能测试
    bench.total_latency = 0;
    bench.iterations = 0;
    
    for (int i = 1; i <= iterations; i++) {
        int request, response;
        
        // 测量处理延迟
        start_timing(&bench);
        
        // 读取请求
        ssize_t bytes = read(read_fd, &request, sizeof(request));
        if (bytes != sizeof(request)) {
            printf("[Pipe Server] Read error\n");
            break;
        }
        
        // 处理请求
        response = request * 100;
        
        // 发送响应
        bytes = write(write_fd, &response, sizeof(response));
        if (bytes != sizeof(response)) {
            printf("[Pipe Server] Write error\n");
            break;
        }
        
        stop_timing(&bench);
        
        long long latency = get_latency_us(&bench);
        bench.total_latency += latency;
        bench.iterations++;
        
        printf("[Pipe Server] Request %d: %d -> %d, Latency: %lld us\n",
               i, request, response, latency);
    }
    
    // 输出统计信息
    printf("\n[Pipe Server] Pipe Test Results:\n");
    printf("  Total iterations: %d\n", bench.iterations);
    printf("  Total latency: %lld us\n", bench.total_latency);
    printf("  Average latency: %.2f us\n", get_average_latency_us(&bench));
    
    // 清理
    close(read_fd);
    close(write_fd);
    unlink(pipe_name_read);
    unlink(pipe_name_write);
    
    printf("[Pipe Server] Exiting\n");
    return 0;
}