#ifndef _OS_TYPES_H
#define _OS_TYPES_H

// 标准整数类型
typedef unsigned char       uint8_t;
typedef unsigned short      uint16_t;
typedef unsigned int        uint32_t;
typedef unsigned long       uint64_t;

typedef signed char         int8_t;
typedef signed short        int16_t;
typedef signed int          int32_t;
typedef signed long         int64_t;

// 大小类型
typedef uint64_t            size_t;
typedef int64_t             ssize_t;

// 布尔类型
typedef uint8_t             bool;
#define true                1
#define false               0

// 指针类型
typedef uint64_t            uintptr_t;
typedef int64_t             intptr_t;

// NULL 定义
#define NULL                ((void *)0)

// 常用常量
#define KB                  1024
#define MB                  (1024 * KB)
#define GB                  (1024 * MB)

// 位操作宏
#define BIT(n)              (1UL << (n))
#define MASK(n)             (BIT(n) - 1)
#define SET_BIT(reg, bit)   ((reg) |= BIT(bit))
#define CLEAR_BIT(reg, bit) ((reg) &= ~BIT(bit))
#define TEST_BIT(reg, bit)  ((reg) & BIT(bit))

// 内存屏障
#define barrier()           asm volatile("" ::: "memory")
#define cpu_relax()         asm volatile("pause" ::: "memory")

#endif // _OS_TYPES_H