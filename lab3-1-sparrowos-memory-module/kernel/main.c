/**
 * main.c - SparrowOS 内核主函数
 */

#include <os/print.h>
#include <os/memory.h>
#include <os/types.h>
#include <riscv/riscv.h>

// 外部符号定义
extern char _heap_start[];
extern char _heap_end[];
extern char _memory_start[];
extern char _memory_end[];

// 陷阱处理函数
void trap_handler(void *regs)
{
    uint64_t scause = csr_read(CSR_SCAUSE);
    uint64_t stval = csr_read(CSR_STVAL);
    uint64_t sepc = csr_read(CSR_SEPC);
    
    printk("[TRAP] scause=0x%llx stval=0x%llx sepc=0x%llx\n",
           scause, stval, sepc);
    
    // 处理不同类型的中断/异常
    switch (scause) {
        case CAUSE_ILLEGAL_INSTRUCTION:
            printk("[TRAP] Illegal instruction at 0x%llx\n", sepc);
            break;
            
        case CAUSE_BREAKPOINT:
            printk("[TRAP] Breakpoint at 0x%llx\n", sepc);
            break;
            
        case CAUSE_ECALL_S_MODE:
            printk("[TRAP] Supervisor ECALL at 0x%llx\n", sepc);
            // 跳过ECALL指令
            csr_write(CSR_SEPC, sepc + 4);
            break;
            
        default:
            printk("[TRAP] Unknown cause: 0x%llx\n", scause);
            break;
    }
}

/**
 * 内核早期初始化
 */
void early_init(void)
{
    // 初始化串口打印
    print_init();
    
    printk("\n");
    printk("========================================\n");
    printk("      SparrowOS - Memory Manager       \n");
    printk("         RISC-V 64-bit Sv39            \n");
    printk("========================================\n");
    printk("\n");
    
    // 显示系统信息
    uint64_t mstatus = csr_read(CSR_MSTATUS);
    uint64_t misa = csr_read(CSR_MISA);
    
    printk("[INIT] MSTATUS: 0x%llx\n", mstatus);
    printk("[INIT] MISA: 0x%llx\n", misa);
    
    // 显示内存布局
    printk("[INIT] Memory layout:\n");
    printk("  Heap start:   0x%llx\n", (uint64_t)_heap_start);
    printk("  Heap end:     0x%llx\n", (uint64_t)_heap_end);
    printk("  Memory start: 0x%llx\n", (uint64_t)_memory_start);
    printk("  Memory end:   0x%llx\n", (uint64_t)_memory_end);
    
    // 计算可用内存
    uint64_t heap_size = (uint64_t)_heap_end - (uint64_t)_heap_start;
    uint64_t total_memory = (uint64_t)_memory_end - (uint64_t)_memory_start;
    
    printk("[INIT] Heap size: %llu bytes (%llu KB)\n",
           heap_size, heap_size / 1024);
    printk("[INIT] Total memory: %llu bytes (%llu MB)\n",
           total_memory, total_memory / (1024 * 1024));
}

/**
 * 内核主函数
 */
int main(void)
{
    // 早期初始化
    early_init();
    
    // 初始化内存管理器
    printk("\n[INIT] Initializing memory manager...\n");
    memory_init((uint64_t)_heap_start, (uint64_t)_heap_end);
    
    // 显示初始内存状态
    memory_stats();
    
    // 运行内存测试
    printk("\n[INIT] Running memory tests...\n");
    
    // 声明测试函数（在memory_test.c中定义）
    extern void run_all_tests(void);
    run_all_tests();
    
    // 演示内存分配
    printk("\n[DEMO] Memory allocation demonstration:\n");
    
    // 演示1: 基础分配
    printk("1. Basic allocation:\n");
    void *ptr1 = kmalloc(64);
    void *ptr2 = kmalloc(128);
    void *ptr3 = kmalloc(256);
    
    printk("   Allocated: 64@0x%llx, 128@0x%llx, 256@0x%llx\n",
           (uint64_t)ptr1, (uint64_t)ptr2, (uint64_t)ptr3);
    
    memory_stats();
    
    // 演示2: 释放和重新分配
    printk("\n2. Free and reallocate:\n");
    kfree(ptr2);
    
    void *ptr4 = kmalloc(200);  // 应该重用ptr2的空间
    printk("   Freed 128, allocated 200@0x%llx\n", (uint64_t)ptr4);
    
    memory_stats();
    
    // 演示3: 碎片化演示
    printk("\n3. Fragmentation demonstration:\n");
    
    void *small_blocks[10];
    for (int i = 0; i < 10; i++) {
        small_blocks[i] = kmalloc(32);
    }
    
    // 释放奇数索引的块
    for (int i = 1; i < 10; i += 2) {
        kfree(small_blocks[i]);
    }
    
    // 尝试分配一个大块
    void *large = kmalloc(256);
    printk("   Allocated large block (256 bytes) @0x%llx\n", (uint64_t)large);
    
    memory_stats();
    memory_dump();
    
    // 演示4: 完整性检查
    printk("\n4. Integrity check:\n");
    memory_integrity_check();
    
    // 清理
    kfree(ptr1);
    kfree(ptr3);
    kfree(ptr4);
    kfree(large);
    
    for (int i = 0; i < 10; i += 2) {
        kfree(small_blocks[i]);
    }
    
    // 最终状态
    printk("\n[INIT] Final memory state:\n");
    memory_stats();
    
    printk("\n[INIT] SparrowOS memory manager test completed!\n");
    printk("========================================\n");
    
    // 进入空闲循环
    while (1) {
        asm volatile("wfi");
    }
    
    return 0;
}