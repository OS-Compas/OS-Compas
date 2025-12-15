/**
 * interrupt.h - 定时器中断处理
 */

#ifndef _SPARROW_INTERRUPT_H
#define _SPARROW_INTERRUPT_H

#include <stdint.h>

/* 定时器配置 */
#define TIMER_FREQUENCY 1000    // 1kHz，1ms精度
#define TIMER_IRQ       0x20    // 8259A IRQ0

/* 定时器寄存器 */
#define TIMER_CMD_PORT  0x43
#define TIMER_DATA_PORT 0x40

/* 中断向量 */
#define INTERRUPT_VECTOR_TIMER 0x20

/* 中断处理函数类型 */
typedef void (*interrupt_handler_t)(void);

/* 中断描述符 */
typedef struct {
    uint16_t offset_low;
    uint16_t selector;
    uint8_t zero;
    uint8_t type_attr;
    uint16_t offset_high;
} __attribute__((packed)) idt_entry_t;

/* 中断寄存器状态 */
typedef struct {
    uint32_t eax, ebx, ecx, edx;
    uint32_t esi, edi, ebp, esp;
    uint32_t eip, eflags;
    uint32_t cs, ds, es, fs, gs, ss;
} interrupt_context_t;

/* 函数声明 */
void timer_init(uint32_t frequency);
void timer_handler(interrupt_context_t* context);
void timer_set_frequency(uint32_t frequency);
uint32_t timer_get_ticks(void);
void timer_sleep(uint32_t ms);

void interrupt_init(void);
void interrupt_enable(void);
void interrupt_disable(void);
void interrupt_set_handler(uint8_t vector, interrupt_handler_t handler);

void pic_init(void);
void pic_send_eoi(uint8_t irq);

#endif /* _SPARROW_INTERRUPT_H */