#ifndef _OS_MEMORY_H
#define _OS_MEMORY_H

#include <os/types.h>

/**
 * @file memory.h
 * @brief SparrowOS 内存管理接口
 * 
 * 提供内核内存分配和管理的核心API
 */

#ifdef __cplusplus
extern "C" {
#endif

/* ==================== 内存常量定义 ==================== */

/**
 * @brief 内存页大小 (4KB)
 */
#define PAGE_SIZE               4096UL

/**
 * @brief 页大小位偏移
 */
#define PAGE_SHIFT              12

/**
 * @brief 页掩码
 */
#define PAGE_MASK               (~(PAGE_SIZE - 1))

/**
 * @brief 内核基地址
 */
#define KERNEL_BASE             0x80000000UL

/**
 * @brief 默认内存对齐边界 (8字节)
 */
#define MEM_ALIGNMENT           8

/**
 * @brief 缓存行大小 (64字节)
 */
#define CACHE_LINE_SIZE         64

/* ==================== 内存类型定义 ==================== */

/**
 * @brief 内存区域类型
 */
typedef enum {
    MEM_TYPE_FREE = 1,      /**< 可用内存 */
    MEM_TYPE_RESERVED,      /**< 保留内存（如内核代码） */
    MEM_TYPE_ACPI,          /**< ACPI表内存 */
    MEM_TYPE_NVS,           /**< ACPI NVS内存 */
    MEM_TYPE_DEVICE,        /**< 设备内存（MMIO） */
    MEM_TYPE_DISABLED,      /**< 不可用内存 */
} mem_type_t;

/**
 * @brief 内存分配标志
 */
typedef enum {
    MEM_NORMAL     = 0x0000, /**< 普通分配 */
    MEM_ZEROED     = 0x0001, /**< 分配并清零 */
    MEM_ALIGNED    = 0x0002, /**< 对齐分配 */
    MEM_ATOMIC     = 0x0004, /**< 原子分配（不可中断） */
    MEM_DMA        = 0x0008, /**< DMA可访问内存 */
    MEM_NOCACHE    = 0x0010, /**< 非缓存内存 */
} mem_flags_t;

/**
 * @brief 内存统计信息结构
 */
typedef struct {
    uint64_t total_memory;      /**< 总内存字节数 */
    uint64_t free_memory;       /**< 空闲内存字节数 */
    uint64_t used_memory;       /**< 已用内存字节数 */
    uint64_t kernel_memory;     /**< 内核使用内存 */
    uint64_t alloc_count;       /**< 分配次数 */
    uint64_t free_count;        /**< 释放次数 */
    uint64_t failed_count;      /**< 分配失败次数 */
    uint64_t largest_free_block;/**< 最大空闲块大小 */
} mem_stats_t;

/**
 * @brief 内存区域描述符
 */
typedef struct {
    uint64_t start;             /**< 起始地址 */
    uint64_t end;               /**< 结束地址 */
    mem_type_t type;            /**< 内存类型 */
    const char *name;           /**< 区域名称 */
    uint8_t reserved[4];        /**< 保留字段 */
} mem_region_t;

/**
 * @brief 内存分配信息（用于调试）
 */
typedef struct {
    void *address;              /**< 分配地址 */
    size_t size;                /**< 分配大小 */
    const char *file;           /**< 源文件名 */
    int line;                   /**< 行号 */
    uint64_t timestamp;         /**< 时间戳 */
    uint32_t magic;             /**< 魔术字 */
} alloc_info_t;

/* ==================== 对齐宏定义 ==================== */

/**
 * @brief 向上对齐到指定边界
 * @param x 要对齐的值
 * @param align 对齐边界（必须是2的幂）
 * @return 对齐后的值
 */
#define ALIGN_UP(x, align)      (((x) + ((align) - 1)) & ~((align) - 1))

/**
 * @brief 向下对齐到指定边界
 * @param x 要对齐的值
 * @param align 对齐边界（必须是2的幂）
 * @return 对齐后的值
 */
#define ALIGN_DOWN(x, align)    ((x) & ~((align) - 1))

/**
 * @brief 检查是否对齐
 * @param x 要检查的值
 * @param align 对齐边界
 * @return 1如果对齐，0否则
 */
#define IS_ALIGNED(x, align)    (((x) & ((align) - 1)) == 0)

/**
 * @brief 向上对齐到页边界
 */
#define PAGE_ALIGN_UP(x)        ALIGN_UP(x, PAGE_SIZE)

/**
 * @brief 向下对齐到页边界
 */
#define PAGE_ALIGN_DOWN(x)      ALIGN_DOWN(x, PAGE_SIZE)

/* ==================== 内存操作宏 ==================== */

/**
 * @brief 安全的内存设置（防止优化）
 * @param ptr 目标地址
 * @param value 要设置的值
 * @param size 大小
 */
#define memset_secure(ptr, value, size) \
    do { \
        volatile uint8_t *_ptr = (volatile uint8_t *)(ptr); \
        size_t _size = (size); \
        uint8_t _value = (value); \
        while (_size--) { \
            *_ptr++ = _value; \
        } \
    } while (0)

/**
 * @brief 检查指针是否在堆范围内
 * @param ptr 要检查的指针
 * @return 1如果在堆内，0否则
 */
#define IS_IN_HEAP(ptr) \
    (((uintptr_t)(ptr) >= _heap_start) && ((uintptr_t)(ptr) < _heap_end))

/* ==================== 内存调试宏 ==================== */

#ifdef MEMORY_DEBUG

/**
 * @brief 调试分配宏（记录文件和行号）
 */
#define kmalloc_debug(size, file, line) \
    _kmalloc_debug(size, file, line)

/**
 * @brief 调试释放宏
 */
#define kfree_debug(ptr, file, line) \
    _kfree_debug(ptr, file, line)

/**
 * @brief 调试分配（带标志）
 */
#define kmalloc_flags_debug(size, flags, file, line) \
    _kmalloc_flags_debug(size, flags, file, line)

#else

/**
 * @brief 非调试版本
 */
#define kmalloc_debug(size, file, line)        kmalloc(size)
#define kfree_debug(ptr, file, line)           kfree(ptr)
#define kmalloc_flags_debug(size, flags, file, line) kmalloc_flags(size, flags)

#endif /* MEMORY_DEBUG */

/**
 * @brief 便捷分配宏
 */
#define KALLOC(size)            kmalloc(size)
#define KCALLOC(num, size)      kcalloc(num, size)
#define KREALLOC(ptr, size)     krealloc(ptr, size)
#define KFREE(ptr)              kfree(ptr)

/* ==================== 函数声明 ==================== */

/**
 * @brief 初始化内存管理器
 * @param mem_start 可用内存起始地址
 * @param mem_end 可用内存结束地址
 * 
 * 必须在任何内存分配之前调用
 */
void memory_init(uint64_t mem_start, uint64_t mem_end);

/**
 * @brief 获取总内存大小
 * @return 总内存字节数
 */
uint64_t get_total_memory(void);

/**
 * @brief 获取空闲内存大小
 * @return 空闲内存字节数
 */
uint64_t get_free_memory(void);

/**
 * @brief 获取已用内存大小
 * @return 已用内存字节数
 */
uint64_t get_used_memory(void);

/**
 * @brief 分配内存
 * @param size 要分配的字节数
 * @return 分配的内存地址，失败返回NULL
 * 
 * 分配的内存至少8字节对齐
 */
void *kmalloc(size_t size);

/**
 * @brief 分配内存（带标志）
 * @param size 要分配的字节数
 * @param flags 分配标志
 * @return 分配的内存地址
 */
void *kmalloc_flags(size_t size, mem_flags_t flags);

/**
 * @brief 分配并清零内存
 * @param num 元素数量
 * @param size 每个元素大小
 * @return 分配的内存地址
 * 
 * 相当于 calloc
 */
void *kcalloc(size_t num, size_t size);

/**
 * @brief 重新分配内存
 * @param ptr 原内存地址
 * @param size 新大小
 * @return 新内存地址
 * 
 * 如果ptr为NULL，相当于kmalloc
 * 如果size为0，相当于kfree
 */
void *krealloc(void *ptr, size_t size);

/**
 * @brief 释放内存
 * @param ptr 要释放的内存地址
 * 
 * 如果ptr为NULL，函数无操作
 */
void kfree(void *ptr);

/**
 * @brief 对齐分配内存
 * @param alignment 对齐边界
 * @param size 分配大小
 * @return 对齐的内存地址
 */
void *kmalloc_aligned(size_t alignment, size_t size);

/**
 * @brief 分配DMA内存
 * @param size 分配大小
 * @return DMA可访问的内存地址
 */
void *kmalloc_dma(size_t size);

/**
 * @brief 分配不可缓存内存
 * @param size 分配大小
 * @return 非缓存内存地址
 */
void *kmalloc_noncache(size_t size);

/**
 * @brief 获取内存统计信息
 * @param stats 输出统计信息
 */
void memory_get_stats(mem_stats_t *stats);

/**
 * @brief 打印内存统计信息
 */
void memory_stats(void);

/**
 * @brief 打印内存布局
 */
void memory_dump(void);

/**
 * @brief 检查内存完整性
 * @return 0表示正常，非0表示错误
 * 
 * 检查堆完整性，包括魔术字、链表等
 */
int memory_integrity_check(void);

/**
 * @brief 检查内存泄漏
 * @return 泄漏的字节数，0表示无泄漏
 */
uint64_t memory_leak_check(void);

/**
 * @brief 内存自检
 * @return 0表示正常，非0表示错误
 * 
 * 运行完整的内存系统自检
 */
int memory_self_test(void);

/**
 * @brief 获取最大连续空闲块大小
 * @return 最大连续空闲字节数
 */
size_t memory_get_largest_free_block(void);

/**
 * @brief 设置内存分配失败回调
 * @param callback 回调函数
 * 
 * 当分配失败时调用回调函数
 */
typedef void (*alloc_fail_callback_t)(size_t size, const char *file, int line);
void memory_set_alloc_fail_callback(alloc_fail_callback_t callback);

/**
 * @brief 启用/禁用内存调试
 * @param enable 1启用，0禁用
 */
void memory_debug_enable(int enable);

/**
 * @brief 转储分配记录
 * @param max_entries 最大记录数（0表示全部）
 */
void memory_dump_allocations(size_t max_entries);

/**
 * @brief 验证指针有效性
 * @param ptr 要验证的指针
 * @param size 期望的大小
 * @return 1如果有效，0如果无效
 */
int memory_validate_pointer(void *ptr, size_t size);

/* ==================== 内存池接口 ==================== */

/**
 * @brief 内存池句柄
 */
typedef void *mem_pool_t;

/**
 * @brief 创建内存池
 * @param name 池名称
 * @param block_size 块大小
 * @param num_blocks 块数量
 * @return 内存池句柄
 */
mem_pool_t mempool_create(const char *name, size_t block_size, size_t num_blocks);

/**
 * @brief 从内存池分配
 * @param pool 内存池
 * @return 分配的内存
 */
void *mempool_alloc(mem_pool_t pool);

/**
 * @brief 释放到内存池
 * @param pool 内存池
 * @param ptr 要释放的内存
 */
void mempool_free(mem_pool_t pool, void *ptr);

/**
 * @brief 销毁内存池
 * @param pool 内存池
 */
void mempool_destroy(mem_pool_t pool);

/**
 * @brief 获取内存池统计
 * @param pool 内存池
 * @param used 输出已用块数
 * @param free 输出空闲块数
 */
void mempool_stats(mem_pool_t pool, size_t *used, size_t *free);

/* ==================== 页面管理接口 ==================== */

/**
 * @brief 分配物理页
 * @param count 页数
 * @return 物理页地址，失败返回0
 */
uint64_t page_alloc(size_t count);

/**
 * @brief 释放物理页
 * @param addr 页地址
 * @param count 页数
 */
void page_free(uint64_t addr, size_t count);

/**
 * @brief 获取系统总页数
 * @return 总页数
 */
size_t page_get_total_count(void);

/**
 * @brief 获取空闲页数
 * @return 空闲页数
 */
size_t page_get_free_count(void);

/* ==================== 调试函数声明 ==================== */

#ifdef MEMORY_DEBUG
void *_kmalloc_debug(size_t size, const char *file, int line);
void _kfree_debug(void *ptr, const char *file, int line);
void *_kmalloc_flags_debug(size_t size, mem_flags_t flags, const char *file, int line);
#endif

/* ==================== 外部符号声明 ==================== */

/**
 * @brief 堆起始地址（由链接器定义）
 */
extern uint8_t _heap_start[];

/**
 * @brief 堆结束地址（由链接器定义）
 */
extern uint8_t _heap_end[];

/**
 * @brief 内存起始地址
 */
extern uint8_t _memory_start[];

/**
 * @brief 内存结束地址
 */
extern uint8_t _memory_end[];

#ifdef __cplusplus
}
#endif

#endif /* _OS_MEMORY_H */