#ifndef _RISCV_H
#define _RISCV_H

#include <os/types.h>

// CSR寄存器地址
#define CSR_SSTATUS     0x100
#define CSR_SIE         0x104
#define CSR_STVEC       0x105
#define CSR_SCOUNTEREN  0x106
#define CSR_SSCRATCH    0x140
#define CSR_SEPC        0x141
#define CSR_SCAUSE      0x142
#define CSR_STVAL       0x143
#define CSR_SIP         0x144
#define CSR_SATP        0x180

#define CSR_MSTATUS     0x300
#define CSR_MISA        0x301
#define CSR_MEDELEG     0x302
#define CSR_MIDELEG     0x303
#define CSR_MIE         0x304
#define CSR_MTVEC       0x305
#define CSR_MCOUNTEREN  0x306
#define CSR_MSCRATCH    0x340
#define CSR_MEPC        0x341
#define CSR_MCAUSE      0x342
#define CSR_MTVAL       0x343
#define CSR_MIP         0x344

#define CSR_CYCLE       0xc00
#define CSR_TIME        0xc01
#define CSR_INSTRET     0xc02
#define CSR_CYCLEH      0xc80
#define CSR_TIMEH       0xc81
#define CSR_INSTRETH    0xc82

// 特权级别
#define PRIV_MODE_M     0x3
#define PRIV_MODE_S     0x1
#define PRIV_MODE_U     0x0

// SSTATUS 标志位
#define SSTATUS_SPP     BIT(8)   // 之前的特权模式
#define SSTATUS_SPIE    BIT(5)   // 之前的 SIE
#define SSTATUS_UPIE    BIT(4)   // U-mode 之前的中断使能
#define SSTATUS_SIE     BIT(1)   // Supervisor 中断使能
#define SSTATUS_UIE     BIT(0)   // User 中断使能

// MSTATUS 标志位
#define MSTATUS_MPP     (0x3 << 11)
#define MSTATUS_MPIE    BIT(7)
#define MSTATUS_MIE     BIT(3)

// 中断原因
#define CAUSE_MISALIGNED_FETCH    0x0
#define CAUSE_FAULT_FETCH         0x1
#define CAUSE_ILLEGAL_INSTRUCTION 0x2
#define CAUSE_BREAKPOINT          0x3
#define CAUSE_MISALIGNED_LOAD     0x4
#define CAUSE_FAULT_LOAD          0x5
#define CAUSE_MISALIGNED_STORE    0x6
#define CAUSE_FAULT_STORE         0x7
#define CAUSE_ECALL_U_MODE        0x8
#define CAUSE_ECALL_S_MODE        0x9
#define CAUSE_ECALL_M_MODE        0xb
#define CAUSE_INSTRUCTION_PAGE    0xc
#define CAUSE_LOAD_PAGE           0xd
#define CAUSE_STORE_PAGE          0xf

// 中断掩码
#define MIP_SSIP        BIT(1)   // Supervisor 软件中断待处理
#define MIP_MSIP        BIT(3)   // Machine 软件中断待处理
#define MIP_STIP        BIT(5)   // Supervisor 定时器中断待处理
#define MIP_MTIP        BIT(7)   // Machine 定时器中断待处理
#define MIP_SEIP        BIT(9)   // Supervisor 外部中断待处理
#define MIP_MEIP        BIT(11)  // Machine 外部中断待处理

// CSR 读写函数
static inline uint64_t csr_read(uint64_t csr)
{
    uint64_t value;
    asm volatile("csrr %0, %1" : "=r"(value) : "i"(csr));
    return value;
}

static inline void csr_write(uint64_t csr, uint64_t value)
{
    asm volatile("csrw %0, %1" :: "i"(csr), "r"(value));
}

static inline void csr_set(uint64_t csr, uint64_t value)
{
    asm volatile("csrs %0, %1" :: "i"(csr), "r"(value));
}

static inline void csr_clear(uint64_t csr, uint64_t value)
{
    asm volatile("csrc %0, %1" :: "i"(csr), "r"(value));
}

// 内存屏障
static inline void fence_i(void)
{
    asm volatile("fence.i" ::: "memory");
}

static inline void fence(void)
{
    asm volatile("fence" ::: "memory");
}

// 原子操作
static inline uint64_t atomic_swap(uint64_t *ptr, uint64_t new_val)
{
    uint64_t old_val;
    asm volatile("amoswap.d %0, %1, (%2)"
                 : "=r"(old_val)
                 : "r"(new_val), "r"(ptr)
                 : "memory");
    return old_val;
}

static inline uint64_t atomic_add(uint64_t *ptr, uint64_t delta)
{
    uint64_t old_val;
    asm volatile("amoadd.d %0, %1, (%2)"
                 : "=r"(old_val)
                 : "r"(delta), "r"(ptr)
                 : "memory");
    return old_val;
}

// 核休眠
static inline void wfi(void)
{
    asm volatile("wfi");
}

#endif // _RISCV_H