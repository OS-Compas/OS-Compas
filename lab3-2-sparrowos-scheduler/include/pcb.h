/**
 * pcb.h - 进程控制块定义
 * SparrowOS 进程调度器核心数据结构
 */

#ifndef _SPARROW_PCB_H
#define _SPARROW_PCB_H

#include <stdint.h>

#define MAX_PROCESSES       64
#define MAX_PRIORITY_LEVELS 4
#define TIME_SLICE_BASE     10      // 基本时间片（时间单位）
#define MAX_RUNTIME         1000    // 最大运行时间

/* 进程状态枚举 */
typedef enum {
    PROCESS_NEW,        // 新建
    PROCESS_READY,      // 就绪
    PROCESS_RUNNING,    // 运行
    PROCESS_BLOCKED,    // 阻塞
    PROCESS_TERMINATED  // 终止
} process_state_t;

/* 进程控制块（PCB）结构体 */
typedef struct process_control_block {
    uint32_t pid;               // 进程ID
    char name[32];             // 进程名称
    
    /* 进程状态 */
    process_state_t state;
    uint8_t priority;           // 当前优先级（0最高，3最低）
    uint32_t priority_original; // 原始优先级
    
    /* 时间统计 */
    uint32_t time_created;      // 创建时间
    uint32_t time_started;      // 开始运行时间
    uint32_t time_used;         // 已使用CPU时间
    uint32_t time_slice;        // 当前时间片长度
    uint32_t time_slice_used;   // 当前时间片已使用时间
    uint32_t vruntime;          // 虚拟运行时间（用于CFS）
    
    /* CPU上下文 */
    uint32_t reg_esp;           // 栈指针
    uint32_t reg_eip;           // 指令指针
    uint32_t reg_eax;           // 通用寄存器
    uint32_t reg_ebx;
    uint32_t reg_ecx;
    uint32_t reg_edx;
    uint32_t reg_esi;
    uint32_t reg_edi;
    uint32_t reg_ebp;
    
    /* 内存信息 */
    uint32_t stack_base;        // 栈基址
    uint32_t stack_size;        // 栈大小
    
    /* 链表指针 */
    struct process_control_block *next;
    struct process_control_block *prev;
    
    /* MLFQ特定字段 */
    uint32_t time_in_queue;     // 在当前队列中的时间
    uint8_t demotions;          // 降级次数
    uint8_t promotions;         // 升级次数
} pcb_t;

/* 就绪队列结构 */
typedef struct {
    pcb_t *head;
    pcb_t *tail;
    uint32_t count;
    uint32_t time_slice;        // 该队列的时间片长度
} ready_queue_t;

/* 多级反馈队列 */
typedef struct {
    ready_queue_t queues[MAX_PRIORITY_LEVELS];
    uint32_t time_slices[MAX_PRIORITY_LEVELS]; // 各优先级时间片
    uint32_t boost_interval;    // 优先级提升间隔
    uint32_t last_boost_time;   // 上次提升时间
} mlfq_t;

/* 调度统计 */
typedef struct {
    uint32_t context_switches;
    uint32_t processes_completed;
    uint32_t total_runtime;
    uint32_t avg_response_time;
    uint32_t avg_turnaround_time;
} scheduler_stats_t;

#endif /* _SPARROW_PCB_H */