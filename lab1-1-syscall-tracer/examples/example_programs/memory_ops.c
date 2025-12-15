/**
 * memory_ops.c - 内存操作示例程序
 * 
 * 用于演示内存管理相关的系统调用模式
 * 可以通过strace观察内存分配、映射等系统调用
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <errno.h>

#define PAGE_SIZE 4096
#define SMALL_ALLOC_SIZE 1024
#define LARGE_ALLOC_SIZE (1024 * 1024)  // 1MB
#define HUGE_ALLOC_SIZE (10 * 1024 * 1024) // 10MB

// 显示系统调用错误
void show_error(const char *operation) {
    fprintf(stderr, "错误: %s - %s\n", operation, strerror(errno));
}

// 显示内存信息
void show_memory_info(const char *description) {
    printf("=== %s ===\n", description);
    
    // 获取程序断点位置
    void *current_brk = sbrk(0);
    printf("当前程序断点: %p\n", current_brk);
    
    // 获取内存使用统计
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage) == 0) {
        printf("最大常驻集大小: %ld KB\n", usage.ru_maxrss);
        printf("次要页错误: %ld\n", usage.ru_minflt);
        printf("主要页错误: %ld\n", usage.ru_majflt);
    }
    printf("\n");
}

// 1. 基础内存分配（brk/sbrk）
void test_brk_operations() {
    printf("=== 测试brk/sbrk内存分配 ===\n");
    
    void *initial_brk = sbrk(0);
    printf("初始程序断点: %p\n", initial_brk);
    
    // 使用sbrk分配内存
    int increment = PAGE_SIZE * 4;  // 分配4页
    void *new_brk = sbrk(increment);
    if (new_brk == (void *)-1) {
        show_error("sbrk");
        return;
    }
    printf("sbrk分配后断点: %p (增加 %d 字节)\n", new_brk, increment);
    
    // 在分配的内存中写入数据
    char *memory = (char *)initial_brk;
    strcpy(memory, "测试sbrk分配的内存");
    printf("写入数据: %s\n", memory);
    
    // 使用brk释放内存
    if (brk(initial_brk) == -1) {
        show_error("brk");
        return;
    }
    printf("brk释放内存后断点: %p\n", sbrk(0));
    
    printf("brk操作测试完成\n\n");
}

// 2. malloc/free 操作（底层使用brk/mmap）
void test_malloc_operations() {
    printf("=== 测试malloc/free操作 ===\n");
    
    // 小内存分配（通常使用brk）
    char *small_mem = malloc(SMALL_ALLOC_SIZE);
    if (!small_mem) {
        show_error("malloc small");
        return;
    }
    printf("小内存分配: %p (%d 字节)\n", small_mem, SMALL_ALLOC_SIZE);
    strcpy(small_mem, "小内存测试数据");
    printf("小内存内容: %s\n", small_mem);
    
    // 大内存分配（通常使用mmap）
    char *large_mem = malloc(LARGE_ALLOC_SIZE);
    if (!large_mem) {
        show_error("malloc large");
        free(small_mem);
        return;
    }
    printf("大内存分配: %p (%d 字节)\n", large_mem, LARGE_ALLOC_SIZE);
    
    // 在大内存中写入模式数据
    for (int i = 0; i < LARGE_ALLOC_SIZE; i++) {
        large_mem[i] = (char)(i % 256);
    }
    printf("大内存初始化完成\n");
    
    // 重新分配内存
    char *realloc_mem = realloc(small_mem, SMALL_ALLOC_SIZE * 2);
    if (!realloc_mem) {
        show_error("realloc");
        free(small_mem);
        free(large_mem);
        return;
    }
    printf("内存重新分配: %p -> %p (新大小: %d 字节)\n", 
           small_mem, realloc_mem, SMALL_ALLOC_SIZE * 2);
    
    // 释放所有内存
    free(realloc_mem);
    free(large_mem);
    printf("内存释放完成\n\n");
}

// 3. 内存映射操作
void test_mmap_operations() {
    printf("=== 测试mmap/munmap操作 ===\n");
    
    // 使用mmap分配匿名内存
    size_t map_size = PAGE_SIZE * 10;  // 10页
    void *mapped_mem = mmap(NULL, map_size, 
                           PROT_READ | PROT_WRITE,
                           MAP_PRIVATE | MAP_ANONYMOUS, 
                           -1, 0);
    
    if (mapped_mem == MAP_FAILED) {
        show_error("mmap");
        return;
    }
    printf("mmap分配内存: %p (%zu 字节)\n", mapped_mem, map_size);
    
    // 在映射内存中操作
    char *data = (char *)mapped_mem;
    strcpy(data, "这是mmap分配的内存");
    printf("映射内存内容: %s\n", data);
    
    // 测试内存保护
    if (mprotect(mapped_mem, PAGE_SIZE, PROT_READ) == -1) {
        show_error("mprotect");
    } else {
        printf("内存保护设置: 只读模式\n");
        
        // 尝试写入只读内存（应该失败）
        printf("尝试写入只读内存...\n");
        // data[0] = 'X';  // 这会导致段错误
    }
    
    // 恢复读写权限
    mprotect(mapped_mem, PAGE_SIZE, PROT_READ | PROT_WRITE);
    
    // 取消内存映射
    if (munmap(mapped_mem, map_size) == -1) {
        show_error("munmap");
        return;
    }
    printf("内存映射已取消\n\n");
}

// 4. 文件内存映射
void test_file_mmap() {
    printf("=== 测试文件内存映射 ===\n");
    
    const char *filename = "mmap_test_file.dat";
    
    // 创建测试文件
    FILE *file = fopen(filename, "w+");
    if (!file) {
        show_error("fopen");
        return;
    }
    
    // 写入测试数据
    const char *file_data = "这是文件内存映射测试数据\n第二行数据\n第三行数据";
    size_t data_size = strlen(file_data);
    fwrite(file_data, 1, data_size, file);
    fflush(file);
    
    // 获取文件描述符
    int fd = fileno(file);
    
    // 内存映射文件
    void *file_mapping = mmap(NULL, data_size,
                             PROT_READ | PROT_WRITE,
                             MAP_SHARED,
                             fd, 0);
    
    if (file_mapping == MAP_FAILED) {
        show_error("mmap file");
        fclose(file);
        return;
    }
    printf("文件内存映射: %p (%zu 字节)\n", file_mapping, data_size);
    
    // 通过内存映射读取文件内容
    printf("映射文件内容:\n%s\n", (char *)file_mapping);
    
    // 通过内存映射修改文件内容
    char *mapped_data = (char *)file_mapping;
    strcpy(mapped_data + 10, "[修改的数据]");
    printf("修改后文件内容:\n%s\n", mapped_data);
    
    // 同步到磁盘
    if (msync(file_mapping, data_size, MS_SYNC) == -1) {
        show_error("msync");
    } else {
        printf("数据已同步到磁盘\n");
    }
    
    // 清理
    munmap(file_mapping, data_size);
    fclose(file);
    unlink(filename);
    
    printf("文件内存映射测试完成\n\n");
}

// 5. 内存分配压力测试
void test_memory_stress() {
    printf("=== 内存分配压力测试 ===\n");
    
    const int num_allocations = 100;
    void *allocations[num_allocations];
    size_t total_allocated = 0;
    
    // 分配大量小内存块
    for (int i = 0; i < num_allocations; i++) {
        size_t size = 64 + (i % 256);  // 不同大小的分配
        allocations[i] = malloc(size);
        if (allocations[i]) {
            total_allocated += size;
            // 初始化内存
            memset(allocations[i], i % 256, size);
        }
    }
    printf("分配 %d 个内存块，总计约 %zu 字节\n", num_allocations, total_allocated);
    
    // 随机释放一些内存块
    int freed_count = 0;
    for (int i = 0; i < num_allocations; i += 3) {
        if (allocations[i]) {
            free(allocations[i]);
            allocations[i] = NULL;
            freed_count++;
        }
    }
    printf("释放了 %d 个内存块\n", freed_count);
    
    // 重新分配一些内存
    int realloc_count = 0;
    for (int i = 1; i < num_allocations; i += 4) {
        if (allocations[i]) {
            void *new_ptr = realloc(allocations[i], 512);
            if (new_ptr) {
                allocations[i] = new_ptr;
                realloc_count++;
            }
        }
    }
    printf("重新分配了 %d 个内存块\n", realloc_count);
    
    // 释放所有剩余内存
    for (int i = 0; i < num_allocations; i++) {
        if (allocations[i]) {
            free(allocations[i]);
        }
    }
    printf("所有内存已释放\n\n");
}

// 6. 堆内存碎片化测试
void test_heap_fragmentation() {
    printf("=== 堆内存碎片化测试 ===\n");
    
    void *small_blocks[50];
    void *large_blocks[10];
    
    // 分配大量小内存块
    for (int i = 0; i < 50; i++) {
        small_blocks[i] = malloc(128);
        if (small_blocks[i]) {
            memset(small_blocks[i], 0xAA, 128);
        }
    }
    printf("分配了 50 个小内存块 (128 字节 each)\n");
    
    // 间隔释放一些小内存块，制造碎片
    for (int i = 0; i < 50; i += 3) {
        free(small_blocks[i]);
        small_blocks[i] = NULL;
    }
    printf("间隔释放了部分小内存块，制造碎片\n");
    
    // 尝试分配大内存块
    for (int i = 0; i < 10; i++) {
        large_blocks[i] = malloc(2048);
        if (large_blocks[i]) {
            printf("大内存块 %d 分配成功: %p\n", i, large_blocks[i]);
        } else {
            printf("大内存块 %d 分配失败\n", i);
        }
    }
    
    // 清理
    for (int i = 0; i < 50; i++) {
        if (small_blocks[i]) {
            free(small_blocks[i]);
        }
    }
    for (int i = 0; i < 10; i++) {
        if (large_blocks[i]) {
            free(large_blocks[i]);
        }
    }
    printf("堆碎片测试完成\n\n");
}

// 7. 内存限制测试
void test_memory_limits() {
    printf("=== 内存限制测试 ===\n");
    
    struct rlimit limit;
    
    // 获取当前内存限制
    if (getrlimit(RLIMIT_AS, &limit) == 0) {
        printf("虚拟内存限制: 软限制=%ld, 硬限制=%ld\n", 
               limit.rlim_cur, limit.rlim_max);
    }
    
    if (getrlimit(RLIMIT_DATA, &limit) == 0) {
        printf("数据段限制: 软限制=%ld, 硬限制=%ld\n", 
               limit.rlim_cur, limit.rlim_max);
    }
    
    // 尝试分配大量内存（可能失败）
    printf("尝试分配大量内存...\n");
    void *huge_memory = malloc(HUGE_ALLOC_SIZE);
    if (huge_memory) {
        printf("大内存分配成功: %p\n", huge_memory);
        memset(huge_memory, 0, HUGE_ALLOC_SIZE);
        free(huge_memory);
    } else {
        printf("大内存分配失败: %s\n", strerror(errno));
    }
    
    printf("内存限制测试完成\n\n");
}

// 8. 内存对齐分配
void test_aligned_allocations() {
    printf("=== 内存对齐分配测试 ===\n");
    
    // 使用posix_memalign进行对齐分配
    void *aligned_mem;
    size_t alignment = 64;  // 64字节对齐
    
    if (posix_memalign(&aligned_mem, alignment, 1024) == 0) {
        printf("对齐内存分配成功: %p\n", aligned_mem);
        printf("地址对齐检查: %s\n", 
               ((uintptr_t)aligned_mem % alignment == 0) ? "正确" : "错误");
        
        // 使用对齐的内存
        memset(aligned_mem, 0xCC, 1024);
        free(aligned_mem);
    } else {
        show_error("posix_memalign");
    }
    
    // 使用valloc（页对齐）
    void *page_aligned = valloc(4096);
    if (page_aligned) {
        printf("页对齐内存分配成功: %p\n", page_aligned);
        printf("页对齐检查: %s\n",
               ((uintptr_t)page_aligned % PAGE_SIZE == 0) ? "正确" : "错误");
        free(page_aligned);
    } else {
        show_error("valloc");
    }
    
    printf("内存对齐分配测试完成\n\n");
}

// 9. 内存操作性能测试
void test_memory_performance() {
    printf("=== 内存操作性能测试 ===\n");
    
    const size_t test_size = 1024 * 1024;  // 1MB
    char *buffer = malloc(test_size);
    
    if (!buffer) {
        show_error("malloc for performance test");
        return;
    }
    
    // 测试memset性能
    clock_t start = clock();
    memset(buffer, 0x55, test_size);
    clock_t end = clock();
    printf("memset 1MB 时间: %.3f 毫秒\n", 
           (double)(end - start) * 1000 / CLOCKS_PER_SEC);
    
    // 测试memcpy性能
    char *buffer2 = malloc(test_size);
    if (buffer2) {
        start = clock();
        memcpy(buffer2, buffer, test_size);
        end = clock();
        printf("memcpy 1MB 时间: %.3f 毫秒\n", 
               (double)(end - start) * 1000 / CLOCKS_PER_SEC);
        free(buffer2);
    }
    
    // 测试内存访问模式
    start = clock();
    volatile int sum = 0;
    for (size_t i = 0; i < test_size; i++) {
        sum += buffer[i];
    }
    end = clock();
    printf("顺序访问 1MB 时间: %.3f 毫秒\n", 
           (double)(end - start) * 1000 / CLOCKS_PER_SEC);
    
    free(buffer);
    printf("内存性能测试完成\n\n");
}

// 清理函数
void cleanup() {
    printf("=== 内存测试清理 ===\n");
    
    // 这里可以添加任何必要的清理代码
    // 大多数内存已经在测试函数中释放
    
    printf("内存测试清理完成\n");
}

// 显示使用说明
void show_usage(const char *program_name) {
    printf("用法: %s [选项]\n", program_name);
    printf("选项:\n");
    printf("  all       运行所有测试（默认）\n");
    printf("  brk       只运行brk操作测试\n");
    printf("  malloc    只运行malloc操作测试\n");
    printf("  mmap      只运行mmap操作测试\n");
    printf("  filemap   只运行文件映射测试\n");
    printf("  stress    只运行内存压力测试\n");
    printf("  fragment  只运行堆碎片测试\n");
    printf("  limits    只运行内存限制测试\n");
    printf("  aligned   只运行对齐分配测试\n");
    printf("  perf      只运行性能测试\n");
    printf("  info      显示内存信息\n");
    printf("  clean     清理测试文件\n");
    printf("\n示例:\n");
    printf("  %s all              # 运行所有测试\n", program_name);
    printf("  %s malloc mmap      # 运行malloc和mmap测试\n", program_name);
    printf("  %s info             # 显示内存信息\n", program_name);
}

int main(int argc, char *argv[]) {
    printf("内存操作示例程序 - 系统调用追踪演示\n");
    printf("====================================\n\n");
    
    // 显示初始内存信息
    show_memory_info("初始内存状态");
    
    // 如果没有参数，运行所有测试
    if (argc == 1) {
        test_brk_operations();
        test_malloc_operations();
        test_mmap_operations();
        test_file_mmap();
        test_memory_stress();
        test_heap_fragmentation();
        test_memory_limits();
        test_aligned_allocations();
        test_memory_performance();
    } else {
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "all") == 0) {
                test_brk_operations();
                test_malloc_operations();
                test_mmap_operations();
                test_file_mmap();
                test_memory_stress();
                test_heap_fragmentation();
                test_memory_limits();
                test_aligned_allocations();
                test_memory_performance();
            } else if (strcmp(argv[i], "brk") == 0) {
                test_brk_operations();
            } else if (strcmp(argv[i], "malloc") == 0) {
                test_malloc_operations();
            } else if (strcmp(argv[i], "mmap") == 0) {
                test_mmap_operations();
            } else if (strcmp(argv[i], "filemap") == 0) {
                test_file_mmap();
            } else if (strcmp(argv[i], "stress") == 0) {
                test_memory_stress();
            } else if (strcmp(argv[i], "fragment") == 0) {
                test_heap_fragmentation();
            } else if (strcmp(argv[i], "limits") == 0) {
                test_memory_limits();
            } else if (strcmp(argv[i], "aligned") == 0) {
                test_aligned_allocations();
            } else if (strcmp(argv[i], "perf") == 0) {
                test_memory_performance();
            } else if (strcmp(argv[i], "info") == 0) {
                show_memory_info("当前内存状态");
            } else if (strcmp(argv[i], "clean") == 0) {
                cleanup();
                return 0;
            } else if (strcmp(argv[i], "help") == 0 || strcmp(argv[i], "-h") == 0) {
                show_usage(argv[0]);
                return 0;
            } else {
                printf("未知选项: %s\n", argv[i]);
                show_usage(argv[0]);
                return 1;
            }
        }
    }
    
    // 显示最终内存信息
    show_memory_info("最终内存状态");
    
    printf("所有内存操作测试完成！\n");
    printf("可以使用以下命令观察系统调用:\n");
    printf("  strace -o memory_ops_trace.log ./memory_ops\n");
    printf("  python3 ../src/syscall_tracer.py -f memory_ops_trace.log --visualize\n");
    
    return 0;
}