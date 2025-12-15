#ifndef _SPARROW_MEMORY_H
#define _SPARROW_MEMORY_H

#include <os/types.h>

// 内存管理常量
#define PAGE_SIZE               4096
#define PAGE_SHIFT              12
#define KERNEL_BASE             0x80000000
#define MEM_ALIGNMENT           8

// 内存分配标志
#define MEM_NORMAL              0x0000
#define MEM_ZEROED              0x0001
#define MEM_ALIGN16             0x0002

// 内存区域类型
typedef enum {
    MEM_FREE = 1,
    MEM_RESERVED,
    MEM_KERNEL,
    MEM_DEVICE,
} mem_type_t;

// 内存区域描述符
typedef struct {
    uint64_t start;
    uint64_t end;
    mem_type_t type;
    const char *name;
} mem_region_t;

// 空闲内存块
typedef struct free_block {
    struct free_block *next;
    size_t size;
    uint8_t magic;          // 魔术字，用于检测内存损坏
} free_block_t;

#define BLOCK_MAGIC 0xAB

// 已分配块头部
typedef struct {
    size_t size;
    uint8_t magic;
    uint8_t used;
} block_header_t;

// 内存管理初始化
void memory_init(uint64_t mem_start, uint64_t mem_end);
uint64_t get_total_memory(void);
uint64_t get_free_memory(void);
uint64_t get_used_memory(void);

// 核心分配函数
void *kmalloc(size_t size);
void *kcalloc(size_t num, size_t size);
void *krealloc(void *ptr, size_t size);
void kfree(void *ptr);

// 调试和统计
void memory_dump(void);
void memory_stats(void);
void memory_integrity_check(void);

#endif // _SPARROW_MEMORY_H