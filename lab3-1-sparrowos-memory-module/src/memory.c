/**
 * memory.c - SparrowOS 内存管理模块
 * 
 * 实现基于空闲链表的物理内存分配器
 * 支持 kmalloc/kfree 接口
 * RISC-V Sv39 兼容
 */

#include <os/memory.h>
#include <os/print.h>
#include <string.h>

// 内存管理器状态
static struct {
    free_block_t *free_list;        // 空闲链表头
    uint64_t total_memory;          // 总内存字节数
    uint64_t free_memory;           // 空闲内存字节数
    uint64_t used_memory;           // 已用内存字节数
    uint64_t alloc_count;           // 分配次数
    uint64_t free_count;            // 释放次数
    uint64_t heap_start;            // 堆起始地址
    uint64_t heap_end;              // 堆结束地址
    uint8_t initialized;            // 初始化标志
} mem_manager = {0};

// 内部辅助函数声明
static void split_block(free_block_t *block, size_t size);
static void coalesce_blocks(void);
static free_block_t *find_best_fit(size_t size);
static void add_to_free_list(free_block_t *block);
static void remove_from_free_list(free_block_t *block);
static void check_block_integrity(free_block_t *block);

// 内存对齐宏
#define MIN_BLOCK_SIZE      (sizeof(free_block_t) + 8)
#define HEADER_SIZE         sizeof(block_header_t)
#define BLOCK_FROM_PTR(ptr) ((free_block_t *)((char *)(ptr) - HEADER_SIZE))
#define PTR_FROM_BLOCK(blk) ((void *)((char *)(blk) + HEADER_SIZE))

/**
 * 初始化内存管理器
 */
void memory_init(uint64_t mem_start, uint64_t mem_end)
{
    if (mem_manager.initialized) {
        printk("[MEM] Memory manager already initialized\n");
        return;
    }
    
    printk("[MEM] Initializing memory manager...\n");
    
    // 对齐起始和结束地址
    mem_start = ALIGN_UP(mem_start, MEM_ALIGNMENT);
    mem_end = ALIGN_DOWN(mem_end, MEM_ALIGNMENT);
    
    // 设置堆区域
    mem_manager.heap_start = mem_start;
    mem_manager.heap_end = mem_end;
    mem_manager.total_memory = mem_end - mem_start;
    
    // 创建初始空闲块
    free_block_t *first_block = (free_block_t *)mem_start;
    first_block->size = mem_manager.total_memory - sizeof(free_block_t);
    first_block->next = NULL;
    first_block->magic = BLOCK_MAGIC;
    
    mem_manager.free_list = first_block;
    mem_manager.free_memory = first_block->size;
    mem_manager.used_memory = 0;
    mem_manager.alloc_count = 0;
    mem_manager.free_count = 0;
    mem_manager.initialized = 1;
    
    printk("[MEM] Heap region: 0x%llx - 0x%llx (%llu bytes)\n",
           mem_manager.heap_start, mem_manager.heap_end, mem_manager.total_memory);
    printk("[MEM] First free block: size=%llu\n", first_block->size);
    printk("[MEM] Memory manager initialized successfully\n");
}

/**
 * 分割内存块
 */
static void split_block(free_block_t *block, size_t size)
{
    // 计算剩余空间是否足够创建一个新块
    size_t remaining = block->size - size - sizeof(free_block_t);
    
    if (remaining < MIN_BLOCK_SIZE) {
        return;  // 剩余空间太小，不分割
    }
    
    // 创建新空闲块
    free_block_t *new_block = (free_block_t *)((char *)block + sizeof(free_block_t) + size);
    new_block->size = remaining;
    new_block->magic = BLOCK_MAGIC;
    new_block->next = block->next;
    
    // 更新原块大小
    block->size = size;
    block->next = new_block;
    
    // 更新空闲内存统计
    mem_manager.free_memory -= sizeof(free_block_t);
}

/**
 * 合并相邻空闲块
 */
static void coalesce_blocks(void)
{
    free_block_t *curr = mem_manager.free_list;
    free_block_t *prev = NULL;
    
    while (curr) {
        // 检查块完整性
        check_block_integrity(curr);
        
        free_block_t *next = curr->next;
        
        // 如果下一个块与当前块相邻且都是空闲的
        if (next && 
            (char *)curr + sizeof(free_block_t) + curr->size == (char *)next) {
            
            // 合并块
            curr->size += sizeof(free_block_t) + next->size;
            curr->next = next->next;
            
            // 更新空闲内存（减去一个块头）
            mem_manager.free_memory += sizeof(free_block_t);
            
            // 继续检查，可能还有更多相邻块
            continue;
        }
        
        prev = curr;
        curr = curr->next;
    }
}

/**
 * 寻找最佳适配块
 */
static free_block_t *find_best_fit(size_t size)
{
    free_block_t *curr = mem_manager.free_list;
    free_block_t *best = NULL;
    size_t best_size = SIZE_MAX;
    
    while (curr) {
        check_block_integrity(curr);
        
        if (curr->size >= size && curr->size < best_size) {
            best = curr;
            best_size = curr->size;
            
            // 如果找到完全匹配的块，直接返回
            if (curr->size == size) {
                break;
            }
        }
        curr = curr->next;
    }
    
    return best;
}

/**
 * 添加到空闲链表
 */
static void add_to_free_list(free_block_t *block)
{
    block->magic = BLOCK_MAGIC;
    block->next = mem_manager.free_list;
    mem_manager.free_list = block;
}

/**
 * 从空闲链表移除
 */
static void remove_from_free_list(free_block_t *block)
{
    if (mem_manager.free_list == block) {
        mem_manager.free_list = block->next;
        return;
    }
    
    free_block_t *curr = mem_manager.free_list;
    while (curr && curr->next != block) {
        curr = curr->next;
    }
    
    if (curr) {
        curr->next = block->next;
    }
}

/**
 * 检查块完整性
 */
static void check_block_integrity(free_block_t *block)
{
    if (block->magic != BLOCK_MAGIC) {
        printk("[MEM] ERROR: Block at 0x%llx has corrupt magic number: 0x%02x\n",
               (uint64_t)block, block->magic);
        // 在真实系统中，这里应该触发内核恐慌
    }
}

/**
 * 分配内存
 */
void *kmalloc(size_t size)
{
    if (!mem_manager.initialized || size == 0) {
        return NULL;
    }
    
    // 对齐大小
    size = ALIGN_UP(size, MEM_ALIGNMENT);
    
    // 查找最佳适配块
    free_block_t *block = find_best_fit(size);
    
    if (!block) {
        // 尝试合并碎片后重新查找
        coalesce_blocks();
        block = find_best_fit(size);
        
        if (!block) {
            printk("[MEM] WARNING: kmalloc(%zu) failed - out of memory\n", size);
            printk("[MEM] Free memory: %llu bytes\n", mem_manager.free_memory);
            return NULL;
        }
    }
    
    // 分割块（如果需要）
    split_block(block, size);
    
    // 从空闲链表移除
    remove_from_free_list(block);
    
    // 创建块头
    block_header_t *header = (block_header_t *)block;
    header->size = size;
    header->magic = BLOCK_MAGIC;
    header->used = 1;
    
    // 更新统计信息
    mem_manager.used_memory += size + HEADER_SIZE;
    mem_manager.free_memory -= size + HEADER_SIZE;
    mem_manager.alloc_count++;
    
    // 返回可用内存地址
    void *ptr = PTR_FROM_BLOCK(block);
    
    return ptr;
}

/**
 * 释放内存
 */
void kfree(void *ptr)
{
    if (!ptr || !mem_manager.initialized) {
        return;
    }
    
    // 获取块头
    free_block_t *block = BLOCK_FROM_PTR(ptr);
    
    // 边界检查
    if ((uint64_t)block < mem_manager.heap_start || 
        (uint64_t)block >= mem_manager.heap_end) {
        printk("[MEM] ERROR: kfree(0x%llx) - pointer outside heap\n", (uint64_t)ptr);
        return;
    }
    
    // 检查块头
    block_header_t *header = (block_header_t *)block;
    if (header->magic != BLOCK_MAGIC) {
        printk("[MEM] ERROR: kfree(0x%llx) - corrupt block header\n", (uint64_t)ptr);
        return;
    }
    
    if (!header->used) {
        printk("[MEM] ERROR: kfree(0x%llx) - double free detected\n", (uint64_t)ptr);
        return;
    }
    
    // 标记为空闲
    header->used = 0;
    
    // 添加到空闲链表
    add_to_free_list(block);
    
    // 更新统计信息
    mem_manager.used_memory -= header->size + HEADER_SIZE;
    mem_manager.free_memory += header->size + HEADER_SIZE;
    mem_manager.free_count++;
    
    // 尝试合并相邻空闲块
    coalesce_blocks();
}

/**
 * 分配并清零内存
 */
void *kcalloc(size_t num, size_t size)
{
    size_t total = num * size;
    void *ptr = kmalloc(total);
    
    if (ptr) {
        memset(ptr, 0, total);
    }
    
    return ptr;
}

/**
 * 重新分配内存
 */
void *krealloc(void *ptr, size_t size)
{
    if (!ptr) {
        return kmalloc(size);
    }
    
    if (size == 0) {
        kfree(ptr);
        return NULL;
    }
    
    // 获取原块信息
    block_header_t *header = (block_header_t *)BLOCK_FROM_PTR(ptr);
    
    // 如果当前块已经足够大
    if (header->size >= size) {
        return ptr;
    }
    
    // 分配新块
    void *new_ptr = kmalloc(size);
    if (!new_ptr) {
        return NULL;
    }
    
    // 复制数据（不超过原大小）
    size_t copy_size = header->size < size ? header->size : size;
    memcpy(new_ptr, ptr, copy_size);
    
    // 释放原块
    kfree(ptr);
    
    return new_ptr;
}

/**
 * 获取总内存大小
 */
uint64_t get_total_memory(void)
{
    return mem_manager.total_memory;
}

/**
 * 获取空闲内存大小
 */
uint64_t get_free_memory(void)
{
    return mem_manager.free_memory;
}

/**
 * 获取已用内存大小
 */
uint64_t get_used_memory(void)
{
    return mem_manager.used_memory;
}

/**
 * 内存完整性检查
 */
void memory_integrity_check(void)
{
    printk("[MEM] Running integrity check...\n");
    
    uint64_t calculated_free = 0;
    free_block_t *curr = mem_manager.free_list;
    uint32_t free_count = 0;
    
    while (curr) {
        check_block_integrity(curr);
        calculated_free += curr->size + sizeof(free_block_t);
        free_count++;
        curr = curr->next;
    }
    
    // 验证统计信息一致性
    uint64_t expected_free = mem_manager.total_memory - mem_manager.used_memory;
    
    if (calculated_free != mem_manager.free_memory) {
        printk("[MEM] ERROR: Free memory mismatch! Calculated=%llu, Recorded=%llu\n",
               calculated_free, mem_manager.free_memory);
    }
    
    if (mem_manager.used_memory + mem_manager.free_memory != mem_manager.total_memory) {
        printk("[MEM] ERROR: Memory accounting inconsistent!\n");
    }
    
    printk("[MEM] Integrity check: %u free blocks, %llu free bytes\n",
           free_count, calculated_free);
}

/**
 * 打印内存统计信息
 */
void memory_stats(void)
{
    printk("\n=== Memory Statistics ===\n");
    printk("Total Memory:    %llu bytes (%llu KB)\n",
           mem_manager.total_memory, mem_manager.total_memory / 1024);
    printk("Used Memory:     %llu bytes (%llu KB)\n",
           mem_manager.used_memory, mem_manager.used_memory / 1024);
    printk("Free Memory:     %llu bytes (%llu KB)\n",
           mem_manager.free_memory, mem_manager.free_memory / 1024);
    printk("Allocations:     %llu\n", mem_manager.alloc_count);
    printk("Frees:           %llu\n", mem_manager.free_count);
    printk("Fragmentation:   %.2f%%\n",
           (mem_manager.total_memory - mem_manager.free_memory) * 100.0 / 
           mem_manager.total_memory);
    
    // 显示空闲链表信息
    printk("\nFree list blocks:\n");
    free_block_t *curr = mem_manager.free_list;
    uint32_t count = 0;
    while (curr && count < 10) {  // 限制显示前10个块
        printk("  [%u] 0x%llx size=%llu\n", 
               count, (uint64_t)curr, curr->size);
        curr = curr->next;
        count++;
    }
    if (curr) {
        printk("  ... and %u more blocks\n", count);
    }
}

/**
 * 打印内存布局
 */
void memory_dump(void)
{
    printk("\n=== Memory Dump ===\n");
    printk("Heap region: 0x%llx - 0x%llx\n",
           mem_manager.heap_start, mem_manager.heap_end);
    
    // 扫描整个堆区域
    uint64_t addr = mem_manager.heap_start;
    uint32_t block_num = 0;
    
    while (addr < mem_manager.heap_end) {
        block_header_t *header = (block_header_t *)addr;
        
        // 检查魔术字
        if (header->magic != BLOCK_MAGIC) {
            // 未初始化的内存区域
            addr += 8;  // 跳过检查
            continue;
        }
        
        printk("Block %u: 0x%llx size=%zu %s\n",
               block_num++,
               addr + HEADER_SIZE,
               header->size,
               header->used ? "[USED]" : "[FREE]");
        
        // 移动到下一个块
        addr += HEADER_SIZE + header->size;
    }
}