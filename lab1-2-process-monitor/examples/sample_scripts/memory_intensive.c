/**
 * 内存密集型测试程序
 * 用于测试进程监视器的内存监控功能
 * 
 * 编译: gcc -o memory_intensive memory_intensive.c -lm -lpthread
 * 运行: ./memory_intensive [运行时间(秒)] [内存大小(MB)] [模式]
 * 
 * 实验1.2：进程资源监视器 - 内存测试程序
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <pthread.h>
#include <signal.h>
#include <math.h>
#include <sys/mman.h>

// 内存块结构
typedef struct {
    void* address;
    size_t size;
    int id;
} memory_block_t;

// 全局变量
volatile int running = 1;
volatile int memory_allocated = 0;
memory_block_t** memory_blocks = NULL;
int block_count = 0;
pthread_mutex_t memory_mutex = PTHREAD_MUTEX_INITIALIZER;

// 内存访问模式
typedef enum {
    MODE_SEQUENTIAL = 0,    // 顺序访问
    MODE_RANDOM = 1,        // 随机访问  
    MODE_PAGE_FAULT = 2,    // 页面错误密集型
    MODE_MEMORY_LEAK = 3    // 内存泄漏模拟
} access_mode_t;

// 信号处理函数
void handle_signal(int sig) {
    printf("\n接收到信号 %d，正在清理内存并停止程序...\n", sig);
    running = 0;
}

// 显示内存使用信息
void show_memory_info() {
    printf("进程PID: %d\n", getpid());
    
    // 读取/proc/self/status中的内存信息
    FILE* status_file = fopen("/proc/self/status", "r");
    if (status_file) {
        char line[256];
        while (fgets(line, sizeof(line), status_file)) {
            if (strstr(line, "VmSize") || strstr(line, "VmRSS") || 
                strstr(line, "VmPeak") || strstr(line, "VmHWM")) {
                printf("%s", line);
            }
        }
        fclose(status_file);
    }
}

// 分配内存块
memory_block_t* allocate_memory_block(size_t size, int id) {
    memory_block_t* block = (memory_block_t*)malloc(sizeof(memory_block_t));
    if (!block) {
        return NULL;
    }
    
    // 使用calloc分配并初始化为非零值，确保实际占用物理内存
    block->address = calloc(1, size);
    if (!block->address) {
        free(block);
        return NULL;
    }
    
    block->size = size;
    block->id = id;
    
    pthread_mutex_lock(&memory_mutex);
    memory_allocated += size;
    pthread_mutex_unlock(&memory_mutex);
    
    return block;
}

// 释放内存块
void free_memory_block(memory_block_t* block) {
    if (block && block->address) {
        pthread_mutex_lock(&memory_mutex);
        memory_allocated -= block->size;
        pthread_mutex_unlock(&memory_mutex);
        
        free(block->address);
        free(block);
    }
}

// 顺序访问模式 - 线性访问内存
void* sequential_access(void* arg) {
    memory_block_t* block = (memory_block_t*)arg;
    char* data = (char*)block->address;
    size_t size = block->size;
    
    printf("线程 %d: 顺序访问 %zu MB 内存\n", block->id, size / (1024 * 1024));
    
    while (running) {
        // 顺序写入
        for (size_t i = 0; i < size && running; i += 4096) { // 按页大小访问
            data[i] = (char)(i % 256);
        }
        
        // 顺序读取并计算校验和
        volatile char checksum = 0;
        for (size_t i = 0; i < size && running; i += 4096) {
            checksum += data[i];
        }
        
        // 防止编译器优化掉checksum计算
        if (checksum == 0) {
            // 极不可能的情况，只是为了使用checksum
        }
        
        usleep(100000); // 每100ms一次循环
    }
    
    return NULL;
}

// 随机访问模式 - 随机位置访问内存
void* random_access(void* arg) {
    memory_block_t* block = (memory_block_t*)arg;
    char* data = (char*)block->address;
    size_t size = block->size;
    
    printf("线程 %d: 随机访问 %zu MB 内存\n", block->id, size / (1024 * 1024));
    
    srand(time(NULL) + block->id);
    
    while (running) {
        // 随机位置写入
        for (int i = 0; i < 1000 && running; i++) {
            size_t pos = rand() % (size - 1);
            data[pos] = (char)(rand() % 256);
        }
        
        // 随机位置读取
        volatile char checksum = 0;
        for (int i = 0; i < 1000 && running; i++) {
            size_t pos = rand() % (size - 1);
            checksum += data[pos];
        }
        
        // 防止编译器优化
        if (checksum == 0) {
            // 极不可能的情况
        }
        
        usleep(50000); // 每50ms一次循环
    }
    
    return NULL;
}

// 页面错误密集型模式 - 使用mmap和mprotect制造页面错误
void* page_fault_intensive(void* arg) {
    size_t size = 256 * 1024 * 1024; // 256MB
    int page_size = getpagesize();
    int page_count = size / page_size;
    
    printf("页面错误密集型模式: 分配 %d 个内存页\n", page_count);
    
    // 使用mmap分配内存，但不立即提交
    char* memory = mmap(NULL, size, PROT_NONE, 
                       MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    
    if (memory == MAP_FAILED) {
        perror("mmap失败");
        return NULL;
    }
    
    int fault_count = 0;
    
    while (running && fault_count < 10000) { // 限制页面错误次数
        // 随机选择一个页面并提交
        int page_index = rand() % page_count;
        if (mprotect(memory + page_index * page_size, page_size, PROT_READ | PROT_WRITE) == 0) {
            // 写入数据以实际触发页面分配
            memory[page_index * page_size] = (char)page_index;
            fault_count++;
        }
        
        // 偶尔取消一些页面的保护
        if (fault_count % 100 == 0 && fault_count > 0) {
            int unprotect_page = rand() % page_count;
            mprotect(memory + unprotect_page * page_size, page_size, PROT_NONE);
        }
        
        usleep(1000); // 1ms延迟
    }
    
    // 清理
    munmap(memory, size);
    printf("页面错误密集型模式: 产生了 %d 个页面错误\n", fault_count);
    
    return NULL;
}

// 内存泄漏模拟模式
void* memory_leak_simulation(void* arg) {
    int leak_count = 0;
    const size_t leak_size = 1024 * 1024; // 每次泄漏1MB
    
    printf("内存泄漏模拟模式: 每2秒泄漏1MB内存\n");
    
    while (running && leak_count < 50) { // 最多泄漏50MB
        // 分配内存但不释放
        void* leaked_memory = malloc(leak_size);
        if (leaked_memory) {
            // 写入数据确保实际占用物理内存
            memset(leaked_memory, 0xAA, leak_size);
            leak_count++;
            printf("已泄漏: %d MB\n", leak_count);
        }
        
        sleep(2); // 每2秒泄漏一次
    }
    
    printf("内存泄漏模拟完成，共泄漏 %d MB\n", leak_count);
    
    return NULL;
}

// 内存压缩测试 - 频繁分配和释放不同大小的内存块
void* memory_fragmentation_test(void* arg) {
    printf("内存碎片化测试模式\n");
    
    void* blocks[100] = {0};
    int block_sizes[100];
    int active_blocks = 0;
    
    srand(time(NULL));
    
    while (running) {
        // 随机决定是分配还是释放
        if (active_blocks < 50 && rand() % 100 < 70) { // 70%概率分配
            // 分配随机大小的内存块 (1KB - 10MB)
            size_t size = (rand() % 10 + 1) * 1024 * 1024 / (rand() % 10 + 1);
            blocks[active_blocks] = malloc(size);
            if (blocks[active_blocks]) {
                // 写入数据
                memset(blocks[active_blocks], rand() % 256, size);
                block_sizes[active_blocks] = size;
                active_blocks++;
            }
        } else if (active_blocks > 0) { // 释放一个内存块
            int index = rand() % active_blocks;
            free(blocks[index]);
            // 移动数组元素
            for (int i = index; i < active_blocks - 1; i++) {
                blocks[i] = blocks[i + 1];
                block_sizes[i] = block_sizes[i + 1];
            }
            active_blocks--;
        }
        
        usleep(100000); // 100ms
    }
    
    // 清理剩余的内存块
    for (int i = 0; i < active_blocks; i++) {
        free(blocks[i]);
    }
    
    return NULL;
}

// 显示使用说明
void show_usage(const char* program_name) {
    printf("内存密集型测试程序\n");
    printf("用法: %s [运行时间(秒)] [内存大小(MB)] [模式]\n", program_name);
    printf("参数:\n");
    printf("  运行时间:  程序运行时间（默认: 30秒）\n");
    printf("  内存大小:  每个线程分配的内存大小（默认: 100 MB）\n");
    printf("  模式:      内存访问模式（默认: 0）\n");
    printf("             0 - 顺序访问\n");
    printf("             1 - 随机访问\n");
    printf("             2 - 页面错误密集型\n");
    printf("             3 - 内存泄漏模拟\n");
    printf("             4 - 内存碎片化测试\n");
    printf("\n示例:\n");
    printf("  %s                    # 运行30秒，100MB，顺序访问\n", program_name);
    printf("  %s 60 200 1          # 运行60秒，200MB，随机访问\n", program_name);
    printf("  %s 30 0 3            # 运行30秒，内存泄漏模拟\n", program_name);
    printf("\n说明:\n");
    printf("  该程序模拟各种内存使用模式，用于测试进程监视器的内存监控功能。\n");
    printf("  请谨慎使用大内存参数，避免系统内存耗尽。\n");
}

int main(int argc, char* argv[]) {
    int run_time = 30;          // 默认运行30秒
    int memory_mb = 100;        // 默认100MB
    access_mode_t mode = MODE_SEQUENTIAL; // 默认顺序访问
    int num_threads = 2;        // 默认2个线程
    
    // 解析命令行参数
    if (argc > 1) {
        if (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0) {
            show_usage(argv[0]);
            return 0;
        }
        run_time = atoi(argv[1]);
    }
    
    if (argc > 2) {
        memory_mb = atoi(argv[2]);
    }
    
    if (argc > 3) {
        mode = (access_mode_t)atoi(argv[3]);
    }
    
    // 验证参数
    if (run_time <= 0) run_time = 30;
    if (memory_mb < 0) memory_mb = 100;
    if (mode < 0 || mode > 4) mode = MODE_SEQUENTIAL;
    
    // 对于特殊模式，调整参数
    if (mode == MODE_PAGE_FAULT || mode == MODE_MEMORY_LEAK) {
        memory_mb = 0; // 这些模式有自己的内存管理
        num_threads = 1;
    }
    
    // 显示启动信息
    printf("==========================================\n");
    printf("内存密集型测试程序启动\n");
    printf("PID: %d\n", getpid());
    printf("运行时间: %d 秒\n", run_time);
    printf("内存大小: %d MB\n", memory_mb);
    printf("访问模式: %d\n", mode);
    printf("工作线程: %d 个\n", num_threads);
    printf("开始时间: %ld\n", (long)time(NULL));
    printf("==========================================\n");
    
    // 显示初始内存信息
    printf("初始内存状态:\n");
    show_memory_info();
    printf("------------------------------------------\n");
    
    // 设置信号处理
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    
    pthread_t* threads = NULL;
    memory_blocks = (memory_block_t**)malloc(num_threads * sizeof(memory_block_t*));
    
    if (!memory_blocks) {
        fprintf(stderr, "错误: 内存分配失败\n");
        return 1;
    }
    
    // 根据模式执行不同的测试
    switch (mode) {
        case MODE_SEQUENTIAL:
        case MODE_RANDOM: {
            // 分配内存块
            size_t block_size = (size_t)memory_mb * 1024 * 1024 / num_threads;
            
            threads = (pthread_t*)malloc(num_threads * sizeof(pthread_t));
            if (!threads) {
                fprintf(stderr, "错误: 线程数组分配失败\n");
                goto cleanup;
            }
            
            for (int i = 0; i < num_threads; i++) {
                memory_blocks[i] = allocate_memory_block(block_size, i);
                if (!memory_blocks[i]) {
                    fprintf(stderr, "错误: 无法分配内存块 %d\n", i);
                    goto cleanup;
                }
                
                // 创建线程
                if (mode == MODE_SEQUENTIAL) {
                    pthread_create(&threads[i], NULL, sequential_access, memory_blocks[i]);
                } else {
                    pthread_create(&threads[i], NULL, random_access, memory_blocks[i]);
                }
            }
            break;
        }
        
        case MODE_PAGE_FAULT: {
            threads = (pthread_t*)malloc(sizeof(pthread_t));
            pthread_create(threads, NULL, page_fault_intensive, NULL);
            num_threads = 1;
            break;
        }
        
        case MODE_MEMORY_LEAK: {
            threads = (pthread_t*)malloc(sizeof(pthread_t));
            pthread_create(threads, NULL, memory_leak_simulation, NULL);
            num_threads = 1;
            break;
        }
        
        case MODE_MEMORY_LEAK + 1: { // 模式4：内存碎片化测试
            threads = (pthread_t*)malloc(sizeof(pthread_t));
            pthread_create(threads, NULL, memory_fragmentation_test, NULL);
            num_threads = 1;
            break;
        }
    }
    
    printf("测试已启动，运行 %d 秒...\n", run_time);
    
    // 主线程等待指定时间，定期显示内存状态
    int elapsed = 0;
    while (running && elapsed < run_time) {
        sleep(5);
        elapsed += 5;
        
        printf("\n运行 %d/%d 秒 - 内存状态:\n", elapsed, run_time);
        show_memory_info();
        printf("已分配内存: %.2f MB\n", memory_allocated / (1024.0 * 1024.0));
    }
    
    // 设置停止标志
    running = 0;
    printf("\n停止标志已设置，等待线程结束...\n");
    
    // 等待所有线程结束
    if (threads) {
        for (int i = 0; i < num_threads; i++) {
            pthread_join(threads[i], NULL);
        }
        free(threads);
    }
    
cleanup:
    // 释放所有内存块
    if (memory_blocks) {
        for (int i = 0; i < num_threads; i++) {
            if (memory_blocks[i]) {
                free_memory_block(memory_blocks[i]);
            }
        }
        free(memory_blocks);
    }
    
    // 显示最终内存状态
    printf("\n最终内存状态:\n");
    show_memory_info();
    
    printf("==========================================\n");
    printf("内存密集型测试程序正常结束\n");
    printf("总运行时间: %d 秒\n", elapsed);
    printf("结束时间: %ld\n", (long)time(NULL));
    printf("==========================================\n");
    
    pthread_mutex_destroy(&memory_mutex);
    return 0;
}