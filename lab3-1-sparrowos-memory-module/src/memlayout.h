#ifndef _SPARROW_MEMLAYOUT_H
#define _SPARROW_MEMLAYOUT_H

#include <os/types.h>

// SparrowOS 内存布局 (RISC-V 64位，QEMU virt 机器)
#define KERNEL_BASE         0x80000000
#define KERNEL_LOAD_ADDR    0x80020000  // 内核加载地址

// 设备内存映射
#define UART0_BASE          0x10000000  // UART 16550
#define VIRTIO_BASE         0x10001000  // VirtIO
#define CLINT_BASE          0x2000000   // 核心本地中断器
#define PLIC_BASE           0x0c000000  // 平台级中断控制器

// 物理内存限制 (QEMU virt 默认)
#define PHYS_MEM_START      0x80000000
#define PHYS_MEM_END        0x88000000  // 128MB

// 内核内存区域
#define KERNEL_TEXT_START   KERNEL_LOAD_ADDR
#define KERNEL_TEXT_END     (KERNEL_TEXT_START + 0x100000)  // 1MB 代码
#define KERNEL_DATA_START   KERNEL_TEXT_END
#define KERNEL_DATA_END     (KERNEL_DATA_START + 0x200000)  // 2MB 数据
#define KERNEL_HEAP_START   KERNEL_DATA_END
#define KERNEL_HEAP_END     (PHYS_MEM_END - 0x100000)       // 保留1MB

// 栈配置
#define BOOT_STACK_SIZE     0x4000      // 16KB 启动栈
#define KERNEL_STACK_SIZE   0x8000      // 32KB 内核栈

// 分页相关
#define PAGE_SIZE           4096
#define PAGE_TABLE_ENTRIES  512
#define PTE_VALID           (1L << 0)
#define PTE_READ            (1L << 1)
#define PTE_WRITE           (1L << 2)
#define PTE_EXECUTE         (1L << 3)
#define PTE_USER            (1L << 4)
#define PTE_GLOBAL          (1L << 5)
#define PTE_ACCESSED        (1L << 6)
#define PTE_DIRTY           (1L << 7)

// Sv39 虚拟地址布局
#define SATP_SV39           (8L << 60)
#define VA_BITS             39
#define PPN_BITS            44
#define VPN_SHIFT           12
#define LEVEL_BITS          9

// 工具宏
#define ALIGN_UP(x, a)      (((x) + ((a) - 1)) & ~((a) - 1))
#define ALIGN_DOWN(x, a)    ((x) & ~((a) - 1))
#define PAGE_UP(x)          ALIGN_UP(x, PAGE_SIZE)
#define PAGE_DOWN(x)        ALIGN_DOWN(x, PAGE_SIZE)

#endif // _SPARROW_MEMLAYOUT_H