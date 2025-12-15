/**
 * CPU密集型测试程序
 * 用于测试进程监视器的CPU监控功能
 * 
 * 编译: gcc -o cpu_intensive cpu_intensive.c -lm
 * 运行: ./cpu_intensive [运行时间(秒)] [线程数]
 * 
 * 实验1.2：进程资源监视器 - 测试程序
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <time.h>
#include <pthread.h>
#include <signal.h>
#include <string.h>

// 全局变量，用于控制程序运行
volatile int running = 1;
volatile int active_threads = 0;
pthread_mutex_t count_mutex = PTHREAD_MUTEX_INITIALIZER;

// 信号处理函数
void handle_signal(int sig) {
    printf("\n接收到信号 %d，正在停止程序...\n", sig);
    running = 0;
}

// CPU密集型计算函数 - 计算素数
int is_prime(long long n) {
    if (n <= 1) return 0;
    if (n <= 3) return 1;
    if (n % 2 == 0 || n % 3 == 0) return 0;
    
    for (long long i = 5; i * i <= n; i += 6) {
        if (n % i == 0 || n % (i + 2) == 0)
            return 0;
    }
    return 1;
}

// CPU密集型计算函数 - 计算斐波那契数列
long long fibonacci(int n) {
    if (n <= 1) return n;
    
    long long a = 0, b = 1, c;
    for (int i = 2; i <= n; i++) {
        c = a + b;
        a = b;
        b = c;
    }
    return b;
}

// CPU密集型计算函数 - 矩阵乘法
void matrix_multiply(double **a, double **b, double **result, int size) {
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            result[i][j] = 0;
            for (int k = 0; k < size; k++) {
                result[i][j] += a[i][k] * b[k][j];
            }
        }
    }
}

// CPU密集型计算函数 - 数值积分
double numerical_integral(double start, double end, int steps) {
    double step_size = (end - start) / steps;
    double sum = 0.0;
    
    for (int i = 0; i < steps; i++) {
        double x = start + (i + 0.5) * step_size;
        // 计算复杂函数：sin(x) * cos(x) * exp(sin(x))
        sum += sin(x) * cos(x) * exp(sin(x));
    }
    
    return sum * step_size;
}

// 工作线程函数
void* cpu_worker(void* arg) {
    int thread_id = *(int*)arg;
    long long iteration = 0;
    double cpu_result = 0.0;
    
    printf("线程 %d 启动\n", thread_id);
    
    // 增加活跃线程计数
    pthread_mutex_lock(&count_mutex);
    active_threads++;
    pthread_mutex_unlock(&count_mutex);
    
    while (running) {
        // 交替执行不同的CPU密集型任务
        switch (iteration % 4) {
            case 0:
                // 计算大数的素数判断
                for (long long i = 1000000 + iteration; i < 1000000 + iteration + 100; i++) {
                    if (is_prime(i)) {
                        cpu_result += i;
                    }
                }
                break;
                
            case 1:
                // 计算斐波那契数列
                for (int i = 40; i < 45; i++) {
                    cpu_result += fibonacci(i);
                }
                break;
                
            case 2:
                // 数值积分计算
                for (int i = 0; i < 10; i++) {
                    cpu_result += numerical_integral(0, M_PI, 100000);
                }
                break;
                
            case 3:
                // 小规模矩阵乘法
                {
                    int size = 50;
                    double **a = (double**)malloc(size * sizeof(double*));
                    double **b = (double**)malloc(size * sizeof(double*));
                    double **result = (double**)malloc(size * sizeof(double*));
                    
                    for (int i = 0; i < size; i++) {
                        a[i] = (double*)malloc(size * sizeof(double));
                        b[i] = (double*)malloc(size * sizeof(double));
                        result[i] = (double*)malloc(size * sizeof(double));
                        
                        for (int j = 0; j < size; j++) {
                            a[i][j] = (double)rand() / RAND_MAX;
                            b[i][j] = (double)rand() / RAND_MAX;
                        }
                    }
                    
                    matrix_multiply(a, b, result, size);
                    
                    // 累加结果
                    for (int i = 0; i < size; i++) {
                        for (int j = 0; j < size; j++) {
                            cpu_result += result[i][j];
                        }
                    }
                    
                    // 释放内存
                    for (int i = 0; i < size; i++) {
                        free(a[i]);
                        free(b[i]);
                        free(result[i]);
                    }
                    free(a);
                    free(b);
                    free(result);
                }
                break;
        }
        
        iteration++;
        
        // 每10000次迭代输出一次进度（仅主线程）
        if (thread_id == 0 && iteration % 10000 == 0) {
            printf("主线程已完成 %lld 次迭代，当前结果: %f\n", iteration, cpu_result);
        }
    }
    
    // 减少活跃线程计数
    pthread_mutex_lock(&count_mutex);
    active_threads--;
    pthread_mutex_unlock(&count_mutex);
    
    printf("线程 %d 结束，总迭代次数: %lld，最终结果: %f\n", 
           thread_id, iteration, cpu_result);
    
    free(arg);
    return NULL;
}

// 显示使用说明
void show_usage(const char* program_name) {
    printf("CPU密集型测试程序\n");
    printf("用法: %s [运行时间(秒)] [线程数]\n", program_name);
    printf("参数:\n");
    printf("  运行时间: 程序运行的时间（默认: 30秒）\n");
    printf("  线程数:   CPU工作线程数量（默认: 2）\n");
    printf("\n示例:\n");
    printf("  %s          # 运行30秒，2个线程\n", program_name);
    printf("  %s 60       # 运行60秒，2个线程\n", program_name);
    printf("  %s 30 4     # 运行30秒，4个线程\n", program_name);
    printf("\n说明:\n");
    printf("  该程序会创建多个线程执行CPU密集型计算，用于测试进程监视器的CPU监控功能。\n");
    printf("  可以通过Ctrl+C发送SIGINT信号来提前终止程序。\n");
}

int main(int argc, char* argv[]) {
    int run_time = 30;      // 默认运行30秒
    int num_threads = 2;    // 默认2个线程
    pthread_t* threads;
    int* thread_ids;
    
    // 解析命令行参数
    if (argc > 1) {
        if (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0) {
            show_usage(argv[0]);
            return 0;
        }
        run_time = atoi(argv[1]);
    }
    
    if (argc > 2) {
        num_threads = atoi(argv[2]);
    }
    
    // 验证参数
    if (run_time <= 0) {
        run_time = 30;
        printf("警告: 运行时间无效，使用默认值: 30秒\n");
    }
    
    if (num_threads <= 0 || num_threads > 64) {
        num_threads = 2;
        printf("警告: 线程数无效，使用默认值: 2\n");
    }
    
    // 显示启动信息
    printf("==========================================\n");
    printf("CPU密集型测试程序启动\n");
    printf("PID: %d\n", getpid());
    printf("运行时间: %d 秒\n", run_time);
    printf("工作线程: %d 个\n", num_threads);
    printf("开始时间: %ld\n", (long)time(NULL));
    printf("==========================================\n");
    
    // 设置信号处理
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    
    // 初始化随机数种子
    srand(time(NULL));
    
    // 创建线程数组
    threads = (pthread_t*)malloc(num_threads * sizeof(pthread_t));
    thread_ids = (int*)malloc(num_threads * sizeof(int));
    
    if (!threads || !thread_ids) {
        fprintf(stderr, "错误: 内存分配失败\n");
        return 1;
    }
    
    // 创建工作线程
    for (int i = 0; i < num_threads; i++) {
        thread_ids[i] = i;
        int* arg = (int*)malloc(sizeof(int));
        *arg = i;
        
        if (pthread_create(&threads[i], NULL, cpu_worker, arg) != 0) {
            fprintf(stderr, "错误: 无法创建线程 %d\n", i);
            free(arg);
            // 继续创建其他线程
        }
    }
    
    printf("所有线程已启动，开始CPU密集型计算...\n");
    
    // 主线程等待指定时间
    int elapsed = 0;
    while (running && elapsed < run_time) {
        sleep(1);
        elapsed++;
        
        // 每5秒输出一次状态
        if (elapsed % 5 == 0) {
            printf("已运行: %d/%d 秒，活跃线程: %d\n", 
                   elapsed, run_time, active_threads);
        }
    }
    
    // 设置停止标志
    running = 0;
    printf("停止标志已设置，等待线程结束...\n");
    
    // 等待所有线程结束
    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }
    
    // 清理资源
    free(threads);
    free(thread_ids);
    pthread_mutex_destroy(&count_mutex);
    
    printf("==========================================\n");
    printf("CPU密集型测试程序正常结束\n");
    printf("总运行时间: %d 秒\n", elapsed);
    printf("结束时间: %ld\n", (long)time(NULL));
    printf("==========================================\n");
    
    return 0;
}