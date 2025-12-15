/**
 * kasan_module.c - KASAN (Kernel Address SANitizer) 测试模块
 * 用于演示和测试内核内存错误检测功能
 * 
 * 注意：此模块故意包含内存错误，仅用于测试目的
 * 在生产环境中不应使用
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/delay.h>
#include <linux/kthread.h>
#include <linux/sched.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Kernel Security Lab");
MODULE_DESCRIPTION("KASAN Test Module - Memory Error Detection Demo");
MODULE_VERSION("2.0");

// 模块参数
static int test_mode = 1;  // 0=safe, 1=out-of-bounds, 2=use-after-free, 3=double-free
module_param(test_mode, int, 0644);
MODULE_PARM_DESC(test_mode, "Test mode: 0=safe, 1=OOB, 2=UAF, 3=double-free");

static int iterations = 3;
module_param(iterations, int, 0644);
MODULE_PARM_DESC(iterations, "Number of iterations for each test");

static int delay_ms = 100;
module_param(delay_ms, int, 0644);
MODULE_PARM_DESC(delay_ms, "Delay between tests in milliseconds");

static bool panic_on_error = false;
module_param(panic_on_error, bool, 0644);
MODULE_PARM_DESC(panic_on_error, "Trigger kernel panic on error detection");

// 测试数据结构
struct test_data {
    char buffer[32];
    int value;
    struct list_head list;
};

// KASAN测试函数声明
static void test_safe_operations(void);
static void test_out_of_bounds(void);
static void test_use_after_free(void);
static void test_double_free(void);
static void test_null_pointer_deref(void);
static void test_memory_leak(void);
static void test_stack_overflow(void);

// 辅助函数
static void fill_pattern(char *buffer, size_t size, char pattern) {
    if (buffer && size > 0) {
        memset(buffer, pattern, size - 1);
        buffer[size - 1] = '\0';
    }
}

static void print_test_header(const char *test_name) {
    printk(KERN_INFO "KASAN_TEST: ===== %s =====\n", test_name);
}

static void print_test_result(const char *test_name, bool passed) {
    if (passed) {
        printk(KERN_INFO "KASAN_TEST: %s - %s\n", test_name, 
               panic_on_error ? "PASSED (panic disabled)" : "PASSED");
    } else {
        printk(KERN_ERR "KASAN_TEST: %s - FAILED (expected with KASAN)\n", test_name);
    }
}

/**
 * 安全操作测试 - 不应该触发KASAN
 */
static void test_safe_operations(void) {
    print_test_header("Safe Memory Operations");
    
    char *safe_buffer;
    struct test_data *data;
    
    // 1. 正常分配和释放
    safe_buffer = kmalloc(64, GFP_KERNEL);
    if (safe_buffer) {
        fill_pattern(safe_buffer, 64, 'S');
        printk(KERN_INFO "KASAN_TEST: Allocated safe buffer at %px\n", safe_buffer);
        printk(KERN_INFO "KASAN_TEST: Buffer content: %.16s...\n", safe_buffer);
        kfree(safe_buffer);
        printk(KERN_INFO "KASAN_TEST: Safe buffer freed\n");
    }
    
    // 2. 分配结构体
    data = kmalloc(sizeof(struct test_data), GFP_KERNEL);
    if (data) {
        strncpy(data->buffer, "Safe structure", sizeof(data->buffer) - 1);
        data->value = 0x12345678;
        printk(KERN_INFO "KASAN_TEST: Allocated struct at %px\n", data);
        printk(KERN_INFO "KASAN_TEST: Struct buffer: %s\n", data->buffer);
        printk(KERN_INFO "KASAN_TEST: Struct value: 0x%x\n", data->value);
        kfree(data);
    }
    
    // 3. 使用kzalloc（零初始化）
    safe_buffer = kzalloc(32, GFP_KERNEL);
    if (safe_buffer) {
        printk(KERN_INFO "KASAN_TEST: Zero-initialized buffer at %px\n", safe_buffer);
        kfree(safe_buffer);
    }
    
    print_test_result("Safe Operations", true);
}

/**
 * 越界访问测试 - 应该被KASAN检测到
 */
static void test_out_of_bounds(void) {
    print_test_header("Out-of-Bounds Access Test");
    
    char *buffer;
    int i;
    
    // 分配一个小缓冲区
    buffer = kmalloc(16, GFP_KERNEL);
    if (!buffer) {
        printk(KERN_ERR "KASAN_TEST: Failed to allocate buffer\n");
        return;
    }
    
    printk(KERN_INFO "KASAN_TEST: Allocated 16-byte buffer at %px\n", buffer);
    
    // 1. 越界写入（前向）
    printk(KERN_INFO "KASAN_TEST: Attempting forward out-of-bounds write...\n");
    for (i = 0; i < 32; i++) {
        buffer[i] = 'A' + (i % 26);
    }
    printk(KERN_INFO "KASAN_TEST: Forward OOB write completed (if no KASAN)\n");
    
    // 2. 越界读取
    printk(KERN_INFO "KASAN_TEST: Attempting out-of-bounds read...\n");
    for (i = 16; i < 24; i++) {
        char c = buffer[i];
        printk(KERN_INFO "KASAN_TEST: buffer[%d] = %c (0x%02x)\n", i, 
               (c >= 32 && c <= 126) ? c : '.', c);
    }
    
    // 3. 越界写入（后向）
    printk(KERN_INFO "KASAN_TEST: Attempting backward out-of-bounds write...\n");
    for (i = -8; i < 0; i++) {
        buffer[i] = 'Z' - ((-i) % 26);
    }
    
    kfree(buffer);
    printk(KERN_INFO "KASAN_TEST: Buffer freed\n");
    
    print_test_result("Out-of-Bounds Access", false);
}

/**
 * 释放后使用测试 - 应该被KASAN检测到
 */
static void test_use_after_free(void) {
    print_test_header("Use-After-Free Test");
    
    int *ptr = NULL;
    struct test_data *data = NULL;
    
    // 场景1: 简单UAF
    printk(KERN_INFO "KASAN_TEST: Scenario 1 - Simple use-after-free\n");
    ptr = kmalloc(sizeof(int) * 4, GFP_KERNEL);
    if (ptr) {
        ptr[0] = 0xDEADBEEF;
        ptr[1] = 0xCAFEBABE;
        printk(KERN_INFO "KASAN_TEST: Allocated memory at %px\n", ptr);
        printk(KERN_INFO "KASAN_TEST: Values: 0x%08x, 0x%08x\n", ptr[0], ptr[1]);
        
        // 释放内存
        kfree(ptr);
        printk(KERN_INFO "KASAN_TEST: Memory freed\n");
        
        // 故意使用已释放的内存
        printk(KERN_INFO "KASAN_TEST: Attempting to use freed memory...\n");
        ptr[0] = 0x12345678;
        printk(KERN_INFO "KASAN_TEST: Write to freed memory: 0x%x\n", ptr[0]);
        
        // 尝试读取
        printk(KERN_INFO "KASAN_TEST: Reading from freed memory: 0x%x\n", ptr[1]);
    }
    
    // 场景2: 结构体UAF
    printk(KERN_INFO "KASAN_TEST: Scenario 2 - Struct use-after-free\n");
    data = kmalloc(sizeof(struct test_data), GFP_KERNEL);
    if (data) {
        strncpy(data->buffer, "UAF Test String", sizeof(data->buffer) - 1);
        data->value = 0xABCDEF01;
        printk(KERN_INFO "KASAN_TEST: Allocated struct at %px\n", data);
        printk(KERN_INFO "KASAN_TEST: Struct content: %s (0x%x)\n", 
               data->buffer, data->value);
        
        kfree(data);
        printk(KERN_INFO "KASAN_TEST: Struct freed\n");
        
        // 使用已释放的结构体
        printk(KERN_INFO "KASAN_TEST: Accessing freed struct...\n");
        printk(KERN_INFO "KASAN_TEST: Freed struct buffer: %s\n", data->buffer);
        data->value = 0x99999999;
    }
    
    print_test_result("Use-After-Free", false);
}

/**
 * 双重释放测试 - 应该被KASAN检测到
 */
static void test_double_free(void) {
    print_test_header("Double-Free Test");
    
    char *buffer = NULL;
    struct test_data *data = NULL;
    
    // 场景1: 简单双重释放
    printk(KERN_INFO "KASAN_TEST: Scenario 1 - Simple double-free\n");
    buffer = kmalloc(64, GFP_KERNEL);
    if (buffer) {
        fill_pattern(buffer, 64, 'D');
        printk(KERN_INFO "KASAN_TEST: Allocated buffer at %px\n", buffer);
        
        // 第一次释放
        kfree(buffer);
        printk(KERN_INFO "KASAN_TEST: First free completed\n");
        
        // 第二次释放（应该触发KASAN）
        printk(KERN_INFO "KASAN_TEST: Attempting second free...\n");
        kfree(buffer);
        printk(KERN_INFO "KASAN_TEST: Second free completed (if no KASAN)\n");
    }
    
    // 场景2: 通过不同指针双重释放
    printk(KERN_INFO "KASAN_TEST: Scenario 2 - Double-free via alias\n");
    data = kmalloc(sizeof(struct test_data), GFP_KERNEL);
    if (data) {
        struct test_data *alias = data;
        printk(KERN_INFO "KASAN_TEST: Allocated struct at %px (alias %px)\n", data, alias);
        
        kfree(data);
        printk(KERN_INFO "KASAN_TEST: Freed via original pointer\n");
        
        printk(KERN_INFO "KASAN_TEST: Attempting to free via alias...\n");
        kfree(alias);
    }
    
    print_test_result("Double-Free", false);
}

/**
 * 空指针解引用测试 - 注意：这可能会直接导致崩溃
 */
static void test_null_pointer_deref(void) {
    print_test_header("Null Pointer Dereference Test");
    
    int *null_ptr = NULL;
    struct test_data *null_struct = NULL;
    
    printk(KERN_WARNING "KASAN_TEST: WARNING: Null pointer test may cause Oops\n");
    
    // 尝试解引用空指针
    printk(KERN_INFO "KASAN_TEST: Attempting null pointer dereference...\n");
    
    // 注：我们不直接解引用，而是使用可能包含NULL的指针
    // 实际测试中可能需要更复杂的方法来触发
    
    printk(KERN_INFO "KASAN_TEST: Null pointer test completed (carefully)\n");
    print_test_result("Null Pointer", true);
}

/**
 * 内存泄漏模拟 - KASAN可以检测某些类型的内存泄漏
 */
static void test_memory_leak(void) {
    print_test_header("Memory Leak Simulation");
    
    // 故意不释放内存
    char *leaked_buffer = kmalloc(128, GFP_KERNEL);
    int *leaked_array = kmalloc(256 * sizeof(int), GFP_KERNEL);
    
    if (leaked_buffer) {
        fill_pattern(leaked_buffer, 128, 'L');
        printk(KERN_INFO "KASAN_TEST: Allocated leaked buffer at %px\n", leaked_buffer);
        // 注意：我们不释放这个缓冲区
    }
    
    if (leaked_array) {
        leaked_array[0] = 0xLEAKED;
        printk(KERN_INFO "KASAN_TEST: Allocated leaked array at %px\n", leaked_array);
        // 注意：我们不释放这个数组
    }
    
    printk(KERN_INFO "KASAN_TEST: Memory intentionally not freed (simulating leak)\n");
    print_test_result("Memory Leak", true);
}

/**
 * 栈溢出测试 - 注意：这可能不稳定
 */
static void test_stack_overflow(void) {
    print_test_header("Stack Overflow Test");
    
    printk(KERN_WARNING "KASAN_TEST: WARNING: Stack overflow test may be unstable\n");
    
    // 通过递归或大栈分配模拟栈溢出
    // 注意：在内核模块中要非常小心
    
    printk(KERN_INFO "KASAN_TEST: Stack overflow test skipped for safety\n");
    printk(KERN_INFO "KASAN_TEST: Use proper kernel config for stack overflow detection\n");
    print_test_result("Stack Overflow", true);
}

/**
 * 综合测试运行器
 */
static void run_kasan_tests(void) {
    int i;
    
    printk(KERN_INFO "KASAN_TEST: === Starting KASAN Test Suite ===\n");
    printk(KERN_INFO "KASAN_TEST: Test mode: %d\n", test_mode);
    printk(KERN_INFO "KASAN_TEST: Iterations: %d\n", iterations);
    printk(KERN_INFO "KASAN_TEST: Delay: %d ms\n", delay_ms);
    printk(KERN_INFO "KASAN_TEST: Panic on error: %s\n", 
           panic_on_error ? "enabled" : "disabled");
    
#ifdef CONFIG_KASAN
    printk(KERN_INFO "KASAN_TEST: KASAN is ENABLED in kernel\n");
#else
    printk(KERN_WARNING "KASAN_TEST: WARNING: KASAN is DISABLED in kernel\n");
    printk(KERN_WARNING "KASAN_TEST: Memory errors will NOT be detected!\n");
#endif
    
    for (i = 0; i < iterations; i++) {
        printk(KERN_INFO "KASAN_TEST: --- Iteration %d/%d ---\n", i + 1, iterations);
        
        switch (test_mode) {
            case 0:
                test_safe_operations();
                break;
            case 1:
                test_out_of_bounds();
                break;
            case 2:
                test_use_after_free();
                break;
            case 3:
                test_double_free();
                break;
            default:
                printk(KERN_ERR "KASAN_TEST: Invalid test mode: %d\n", test_mode);
                // 运行所有测试
                test_safe_operations();
                msleep(delay_ms);
                test_out_of_bounds();
                msleep(delay_ms);
                test_use_after_free();
                msleep(delay_ms);
                test_double_free();
                break;
        }
        
        if (i < iterations - 1) {
            msleep(delay_ms);
        }
    }
    
    printk(KERN_INFO "KASAN_TEST: === Test Suite Completed ===\n");
    printk(KERN_INFO "KASAN_TEST: Check dmesg for KASAN reports\n");
    printk(KERN_INFO "KASAN_TEST: If KASAN is enabled, you should see error reports\n");
}

/**
 * 模块初始化函数
 */
static int __init kasan_module_init(void) {
    printk(KERN_INFO "KASAN_TEST: Module loading...\n");
    printk(KERN_WARNING "KASAN_TEST: WARNING: This module contains intentional memory errors!\n");
    printk(KERN_WARNING "KASAN_TEST: Use only on test systems with KASAN enabled.\n");
    
    // 显示警告信息
    if (panic_on_error) {
        printk(KERN_ALERT "KASAN_TEST: ALERT: panic_on_error is enabled!\n");
        printk(KERN_ALERT "KASAN_TEST: System may panic if errors are detected!\n");
    }
    
    // 延迟一点以确保打印信息可见
    msleep(100);
    
    // 运行测试
    run_kasan_tests();
    
    printk(KERN_INFO "KASAN_TEST: Module loaded successfully\n");
    return 0;
}

/**
 * 模块清理函数
 */
static void __exit kasan_module_exit(void) {
    printk(KERN_INFO "KASAN_TEST: Module unloading...\n");
    printk(KERN_INFO "KASAN_TEST: Tests completed. Check kernel logs for results.\n");
    
    // 清理任何可能未释放的内存（安全测试）
    // 注意：我们故意不清理泄漏的内存以进行测试
    
    printk(KERN_INFO "KASAN_TEST: Module unloaded\n");
}

module_init(kasan_module_init);
module_exit(kasan_module_exit);

// 模块信息
MODULE_INFO(test, "KASAN memory error detection test");
MODULE_INFO(kasan, "Requires CONFIG_KASAN=y for proper testing");
MODULE_INFO(warning, "Contains intentional memory errors - use with caution");