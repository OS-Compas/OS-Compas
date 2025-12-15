/* SparrowOS 链接脚本 - RISC-V 64位 */
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY {
    RAM (rwx) : ORIGIN = 0x80020000, LENGTH = 128M - 0x20000
}

SECTIONS {
    /* 内核入口点 */
    . = 0x80020000;
    
    .text : {
        *(.text.init)     /* 启动代码 */
        *(.text .text.*)  /* 所有代码段 */
    } > RAM
    
    .rodata : {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
    } > RAM
    
    .data : {
        *(.data .data.*)
        *(.sdata .sdata.*)
        
        /* 全局构造函数指针 */
        __global_pointer$ = . + 0x800;
        
        /* 内核堆起始 */
        _heap_start = .;
    } > RAM
    
    .bss : {
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        
        /* 内核堆结束（预留64KB堆空间） */
        . = ALIGN(16);
        _heap_end = . + 0x10000;  /* 64KB 堆 */
    } > RAM
    
    /* 栈空间 */
    .stack : {
        . = ALIGN(16);
        _stack_start = .;
        . += 0x4000;  /* 16KB 启动栈 */
        _stack_end = .;
    } > RAM
    
    /* 内存管理统计 */
    . = ALIGN(8);
    _memory_end = .;
    
    /* 丢弃其他段 */
    /DISCARD/ : {
        *(.comment)
        *(.note*)
    }
    
    /* 符号定义供C代码使用 */
    PROVIDE(_memory_start = ORIGIN(RAM));
    PROVIDE(_memory_size = LENGTH(RAM));
}