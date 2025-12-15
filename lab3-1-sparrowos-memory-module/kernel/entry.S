/* SparrowOS 内核入口 - RISC-V 64位汇编 */

.section .text.init
.global _start
_start:
    /* 关闭所有中断 */
    csrw sie, zero
    csrw sip, zero
    
    /* 设置栈指针 */
    la sp, _stack_end
    
    /* 清零BSS段 */
    la t0, _bss_start
    la t1, _bss_end
    bgeu t0, t1, 2f
1:
    sd zero, (t0)
    addi t0, t0, 8
    bltu t0, t1, 1b
2:
    
    /* 调用内核主函数 */
    call main
    
    /* 如果main返回，则进入无限循环 */
1:
    wfi
    j 1b

/* 陷阱处理入口 */
.section .text.trap
.global trap_vector
trap_vector:
    /* 保存所有寄存器 */
    addi sp, sp, -256
    
    /* 保存通用寄存器 */
    sd x1, 0(sp)
    sd x2, 8(sp)
    sd x3, 16(sp)
    sd x4, 24(sp)
    sd x5, 32(sp)
    sd x6, 40(sp)
    sd x7, 48(sp)
    sd x8, 56(sp)
    sd x9, 64(sp)
    sd x10, 72(sp)
    sd x11, 80(sp)
    sd x12, 88(sp)
    sd x13, 96(sp)
    sd x14, 104(sp)
    sd x15, 112(sp)
    sd x16, 120(sp)
    sd x17, 128(sp)
    sd x18, 136(sp)
    sd x19, 144(sp)
    sd x20, 152(sp)
    sd x21, 160(sp)
    sd x22, 168(sp)
    sd x23, 176(sp)
    sd x24, 184(sp)
    sd x25, 192(sp)
    sd x26, 200(sp)
    sd x27, 208(sp)
    sd x28, 216(sp)
    sd x29, 224(sp)
    sd x30, 232(sp)
    sd x31, 240(sp)
    
    /* 调用C语言陷阱处理函数 */
    mv a0, sp
    call trap_handler
    
    /* 恢复所有寄存器 */
    ld x1, 0(sp)
    ld x2, 8(sp)
    ld x3, 16(sp)
    ld x4, 24(sp)
    ld x5, 32(sp)
    ld x6, 40(sp)
    ld x7, 48(sp)
    ld x8, 56(sp)
    ld x9, 64(sp)
    ld x10, 72(sp)
    ld x11, 80(sp)
    ld x12, 88(sp)
    ld x13, 96(sp)
    ld x14, 104(sp)
    ld x15, 112(sp)
    ld x16, 120(sp)
    ld x17, 128(sp)
    ld x18, 136(sp)
    ld x19, 144(sp)
    ld x20, 152(sp)
    ld x21, 160(sp)
    ld x22, 168(sp)
    ld x23, 176(sp)
    ld x24, 184(sp)
    ld x25, 192(sp)
    ld x26, 200(sp)
    ld x27, 208(sp)
    ld x28, 216(sp)
    ld x29, 224(sp)
    ld x30, 232(sp)
    ld x31, 240(sp)
    
    addi sp, sp, 256
    
    /* 返回 */
    sret

/* 数据内存屏障 */
.global data_memory_barrier
data_memory_barrier:
    fence
    ret

/* 指令内存屏障 */
.global instruction_memory_barrier
instruction_memory_barrier:
    fence.i
    ret

/* 原子交换 */
.global atomic_swap
atomic_swap:
    amoswap.d a0, a1, (a0)
    ret

/* 原子加法 */
.global atomic_add
atomic_add:
    amoadd.d a0, a1, (a0)
    ret