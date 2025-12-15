/**
 * interrupt.c - 定时器中断处理程序
 * 实现SparrowOS的时间片中断
 */

#include <stdio.h>
#include <stdint.h>
#include "interrupt.h"
#include "scheduler.h"

/* 全局变量 */
static uint32_t timer_ticks = 0;
static uint32_t timer_frequency = TIMER_FREQUENCY;
static interrupt_handler_t interrupt_handlers[256];
static idt_entry_t idt[256];

/* 初始化8254可编程间隔定时器 */
void timer_init(uint32_t frequency) {
    timer_frequency = frequency;
    
    /* 计算定时器除数 */
    uint32_t divisor = 1193180 / frequency;
    
    /* 发送初始化命令字节到命令端口 */
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)0x36), "d"((uint16_t)TIMER_CMD_PORT));
    
    /* 发送除数低位字节 */
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)(divisor & 0xFF)), "d"((uint16_t)TIMER_DATA_PORT));
    
    /* 发送除数高位字节 */
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)((divisor >> 8) & 0xFF)), "d"((uint16_t)TIMER_DATA_PORT));
    
    printf("Timer initialized: frequency=%dHz, divisor=%d\n", frequency, divisor);
}

/* 定时器中断处理程序 */
void timer_handler(interrupt_context_t* context) {
    timer_ticks++;
    
    /* 调用调度器的tick处理 */
    scheduler_tick();
    
    /* 发送中断结束命令 */
    pic_send_eoi(TIMER_IRQ);
}

/* 设置定时器频率 */
void timer_set_frequency(uint32_t frequency) {
    if (frequency < 20 || frequency > 10000) {
        printf("Warning: Frequency %d out of range (20-10000Hz)\n", frequency);
        return;
    }
    
    timer_frequency = frequency;
    uint32_t divisor = 1193180 / frequency;
    
    __asm__ volatile("cli");
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)0x36), "d"((uint16_t)TIMER_CMD_PORT));
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)(divisor & 0xFF)), "d"((uint16_t)TIMER_DATA_PORT));
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)((divisor >> 8) & 0xFF)), "d"((uint16_t)TIMER_DATA_PORT));
    __asm__ volatile("sti");
    
    printf("Timer frequency changed to %dHz\n", frequency);
}

/* 获取当前tick数 */
uint32_t timer_get_ticks(void) {
    return timer_ticks;
}

/* 睡眠指定毫秒数 */
void timer_sleep(uint32_t ms) {
    uint32_t end_ticks = timer_ticks + (ms * timer_frequency / 1000);
    while (timer_ticks < end_ticks) {
        __asm__ volatile("hlt");  // 休眠直到下一个中断
    }
}

/* 初始化中断系统 */
void interrupt_init(void) {
    /* 清零中断处理程序数组 */
    for (int i = 0; i < 256; i++) {
        interrupt_handlers[i] = NULL;
    }
    
    /* 设置定时器中断处理程序 */
    interrupt_set_handler(INTERRUPT_VECTOR_TIMER, (interrupt_handler_t)timer_handler);
    
    /* 初始化中断描述符表（简化版） */
    printf("Interrupt system initialized\n");
}

/* 设置中断处理程序 */
void interrupt_set_handler(uint8_t vector, interrupt_handler_t handler) {
    if (vector < 256) {
        interrupt_handlers[vector] = handler;
        
        /* 设置IDT条目（简化实现） */
        idt[vector].offset_low = (uint16_t)((uint32_t)handler & 0xFFFF);
        idt[vector].selector = 0x08;  // 内核代码段选择子
        idt[vector].zero = 0;
        idt[vector].type_attr = 0x8E; // 32位中断门，DPL=0
        idt[vector].offset_high = (uint16_t)(((uint32_t)handler >> 16) & 0xFFFF);
        
        printf("Interrupt handler set: vector=0x%02x\n", vector);
    }
}

/* 启用中断 */
void interrupt_enable(void) {
    __asm__ volatile("sti");
}

/* 禁用中断 */
void interrupt_disable(void) {
    __asm__ volatile("cli");
}

/* 初始化8259A可编程中断控制器 */
void pic_init(void) {
    /* 初始化主8259A */
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)0x11), "d"((uint16_t)0x20)); // ICW1
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)0x20), "d"((uint16_t)0x21)); // ICW2: 中断向量基址
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)0x04), "d"((uint16_t)0x21)); // ICW3
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)0x01), "d"((uint16_t)0x21)); // ICW4
    
    /* 初始化从8259A */
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)0x11), "d"((uint16_t)0xA0)); // ICW1
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)0x28), "d"((uint16_t)0xA1)); // ICW2
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)0x02), "d"((uint16_t)0xA1)); // ICW3
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)0x01), "d"((uint16_t)0xA1)); // ICW4
    
    /* 启用所有中断 */
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)0x00), "d"((uint16_t)0x21)); // 主PIC
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)0x00), "d"((uint16_t)0xA1)); // 从PIC
    
    printf("PIC initialized\n");
}

/* 发送中断结束命令 */
void pic_send_eoi(uint8_t irq) {
    if (irq >= 8) {
        __asm__ volatile("outb %%al, %%dx" 
            : : "a"((uint8_t)0x20), "d"((uint16_t)0xA0)); // 从PIC EOI
    }
    __asm__ volatile("outb %%al, %%dx" 
        : : "a"((uint8_t)0x20), "d"((uint16_t)0x20)); // 主PIC EOI
}