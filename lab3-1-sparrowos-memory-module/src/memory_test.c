/**
 * memory_test.c - SparrowOS 内存管理测试
 */

#include <os/memory.h>
#include <os/print.h>
#include <string.h>

// 测试宏定义
#define TEST_START(name) \
    printk("\n=== [TEST] %s ===\n", name)

#define TEST_ASSERT(condition, message) \
    do { \
        if (!(condition)) { \
            printk("[TEST] FAILED: %s\n", message); \
            return -1; \
        } \
    } while(0)

#define TEST_PASS() \
    do { \
        printk("[TEST] PASSED\n"); \
        return 0; \
    } while(0)

/**
 * 测试1: 基础分配和释放
 */
int test_basic_allocation(void)
{
    TEST_START("Basic Allocation");
    
    void *ptr1 = kmalloc(64);
    TEST_ASSERT(ptr1 != NULL, "kmalloc(64) failed");
    
    void *ptr2 = kmalloc(128);
    TEST_ASSERT(ptr2 != NULL, "kmalloc(128) failed");
    
    void *ptr3 = kmalloc(256);
    TEST_ASSERT(ptr3 != NULL, "kmalloc(256) failed");
    
    // 写入数据
    memset(ptr1, 0xAA, 64);
    memset(ptr2, 0xBB, 128);
    memset(ptr3, 0xCC, 256);
    
    // 验证数据
    for (int i = 0; i < 64; i++) {
        TEST_ASSERT(((char *)ptr1)[i] == 0xAA, "ptr1 data corruption");
    }
    
    for (int i = 0; i < 128; i++) {
        TEST_ASSERT(((char *)ptr2)[i] == 0xBB, "ptr2 data corruption");
    }
    
    // 释放内存
    kfree(ptr1);
    kfree(ptr2);
    kfree(ptr3);
    
    TEST_PASS();
}

/**
 * 测试2: 边界情况
 */
int test_edge_cases(void)
{
    TEST_START("Edge Cases");
    
    // 测试分配0字节
    void *ptr = kmalloc(0);
    TEST_ASSERT(ptr == NULL, "kmalloc(0) should return NULL");
    
    // 测试释放NULL指针
    kfree(NULL);  // 不应崩溃
    
    // 测试分配大内存
    void *large = kmalloc(8192);  // 8KB
    TEST_ASSERT(large != NULL, "Large allocation failed");
    
    // 测试kcalloc清零
    int *array = (int *)kcalloc(10, sizeof(int));
    TEST_ASSERT(array != NULL, "kcalloc failed");
    
    for (int i = 0; i < 10; i++) {
        TEST_ASSERT(array[i] == 0, "kcalloc didn't zero memory");
    }
    
    // 测试krealloc
    char *str = (char *)kmalloc(10);
    TEST_ASSERT(str != NULL, "Initial allocation failed");
    
    strcpy(str, "Hello");
    
    char *new_str = (char *)krealloc(str, 20);
    TEST_ASSERT(new_str != NULL, "krealloc failed");
    TEST_ASSERT(strcmp(new_str, "Hello") == 0, "Data lost after realloc");
    
    strcpy(new_str + 5, " World");
    TEST_ASSERT(strcmp(new_str, "Hello World") == 0, "Data corrupted");
    
    kfree(large);
    kfree(array);
    kfree(new_str);
    
    TEST_PASS();
}

/**
 * 测试3: 碎片化测试
 */
int test_fragmentation(void)
{
    TEST_START("Fragmentation Test");
    
    // 分配多个不同大小的块
    void *blocks[20];
    size_t sizes[20];
    
    // 创建碎片化模式
    for (int i = 0; i < 20; i++) {
        sizes[i] = 16 + (i * 8);  // 16, 24, 32, ..., 168
        blocks[i] = kmalloc(sizes[i]);
        TEST_ASSERT(blocks[i] != NULL, "Allocation failed");
        
        // 写入模式数据
        memset(blocks[i], 0xA0 + i, sizes[i]);
    }
    
    // 每隔一个释放，创建碎片
    for (int i = 0; i < 20; i += 2) {
        kfree(blocks[i]);
        blocks[i] = NULL;
    }
    
    // 现在尝试分配一些更大的块
    void *large1 = kmalloc(256);
    TEST_ASSERT(large1 != NULL, "Failed to allocate large block in fragmented heap");
    
    void *large2 = kmalloc(512);
    TEST_ASSERT(large2 != NULL, "Failed to allocate second large block");
    
    // 清理剩余块
    for (int i = 0; i < 20; i++) {
        if (blocks[i] != NULL) {
            kfree(blocks[i]);
        }
    }
    
    kfree(large1);
    kfree(large2);
    
    printk("[TEST] Memory stats after fragmentation test:\n");
    memory_stats();
    
    TEST_PASS();
}

/**
 * 测试4: 压力测试
 */
int test_stress_allocation(void)
{
    TEST_START("Stress Test");
    
    #define NUM_ALLOCATIONS 100
    #define MAX_SIZE 1024
    
    void *allocations[NUM_ALLOCATIONS];
    size_t sizes[NUM_ALLOCATIONS];
    
    printk("[TEST] Allocating %d random blocks...\n", NUM_ALLOCATIONS);
    
    // 第一阶段：随机分配
    for (int i = 0; i < NUM_ALLOCATIONS; i++) {
        sizes[i] = (rand() % MAX_SIZE) + 1;
        allocations[i] = kmalloc(sizes[i]);
        
        if (!allocations[i]) {
            printk("[TEST] Allocation %d failed (size=%zu), free memory=%llu\n",
                   i, sizes[i], get_free_memory());
            // 继续测试而不是失败
            sizes[i] = 0;
            continue;
        }
        
        // 填充模式数据
        memset(allocations[i], i % 256, sizes[i]);
    }
    
    // 第二阶段：随机释放和重新分配
    printk("[TEST] Random free/realloc cycles...\n");
    for (int cycle = 0; cycle < 50; cycle++) {
        int idx = rand() % NUM_ALLOCATIONS;
        
        if (allocations[idx]) {
            kfree(allocations[idx]);
            allocations[idx] = NULL;
        } else {
            sizes[idx] = (rand() % MAX_SIZE) + 1;
            allocations[idx] = kmalloc(sizes[idx]);
            
            if (allocations[idx]) {
                memset(allocations[idx], cycle % 256, sizes[idx]);
            }
        }
    }
    
    // 清理所有剩余分配
    printk("[TEST] Cleaning up...\n");
    for (int i = 0; i < NUM_ALLOCATIONS; i++) {
        if (allocations[i]) {
            kfree(allocations[i]);
        }
    }
    
    // 验证内存完整性
    memory_integrity_check();
    
    printk("[TEST] Stress test completed\n");
    TEST_PASS();
}

/**
 * 测试5: 对齐测试
 */
int test_alignment(void)
{
    TEST_START("Alignment Test");
    
    // 测试不同对齐要求
    for (int i = 1; i <= 256; i *= 2) {
        void *ptr = kmalloc(i);
        TEST_ASSERT(ptr != NULL, "Allocation failed");
        
        // 检查对齐
        uint64_t addr = (uint64_t)ptr;
        TEST_ASSERT((addr % MEM_ALIGNMENT) == 0, 
                    "Memory not properly aligned");
        
        // 写入并验证
        memset(ptr, 0x55, i);
        
        for (int j = 0; j < i; j++) {
            TEST_ASSERT(((char *)ptr)[j] == 0x55, "Data corruption");
        }
        
        kfree(ptr);
    }
    
    TEST_PASS();
}

/**
 * 运行所有测试
 */
void run_all_tests(void)
{
    printk("\n======= Running Memory Management Tests =======\n");
    
    int passed = 0;
    int total = 0;
    
    // 测试函数数组
    int (*tests[])(void) = {
        test_basic_allocation,
        test_edge_cases,
        test_fragmentation,
        test_alignment,
        test_stress_allocation,
        NULL  // 结束标记
    };
    
    // 运行每个测试
    for (int i = 0; tests[i] != NULL; i++) {
        total++;
        if (tests[i]() == 0) {
            passed++;
        }
    }
    
    printk("\n======= Test Results =======\n");
    printk("Passed: %d/%d tests\n", passed, total);
    
    if (passed == total) {
        printk("All tests PASSED! \\o/\n");
    } else {
        printk("%d tests FAILED!\n", total - passed);
    }
    
    // 显示最终内存状态
    printk("\nFinal memory state:\n");
    memory_stats();
}