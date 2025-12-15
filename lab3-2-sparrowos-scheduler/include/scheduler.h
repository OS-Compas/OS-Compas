/**
 * scheduler.h - SparrowOS调度器接口定义
 */

#ifndef _SPARROW_SCHEDULER_H
#define _SPARROW_SCHEDULER_H

#include "pcb.h"

/* 调度器类型枚举 */
typedef enum {
    SCHED_FIFO,     // 先来先服务
    SCHED_RR,       // 时间片轮转
    SCHED_MLFQ,     // 多级反馈队列
    SCHED_CFS       // 完全公平调度
} scheduler_type_t;

/* 调度器配置 */
typedef struct {
    scheduler_type_t type;
    uint32_t time_quantum;      // 时间片长度
    uint8_t enable_preemption;  // 是否启用抢占
    uint8_t mlfq_levels;        // MLFQ队列级数
    uint32_t boost_interval;    // 优先级提升间隔
} scheduler_config_t;

/* 调度器接口函数 */
void scheduler_init(scheduler_config_t config);
pcb_t* scheduler_create_process(const char* name, uint8_t priority);
void scheduler_terminate_process(uint32_t pid);
void scheduler_yield(void);
pcb_t* scheduler_get_current_process(void);
void scheduler_tick(void);
void scheduler_schedule(void);

/* 算法特定接口 */
void scheduler_fifo_init(void);
pcb_t* scheduler_fifo_schedule(void);

void scheduler_rr_init(uint32_t time_quantum);
pcb_t* scheduler_rr_schedule(void);

void scheduler_mlfq_init(uint8_t levels, uint32_t boost_interval);
pcb_t* scheduler_mlfq_schedule(void);
void scheduler_mlfq_boost_priority(void);

/* 统计函数 */
scheduler_stats_t scheduler_get_stats(void);
void scheduler_print_stats(void);
void scheduler_reset_stats(void);

/* 调试函数 */
void scheduler_print_ready_queue(void);
void scheduler_print_process_info(pcb_t* pcb);
void scheduler_dump_all_processes(void);

#endif /* _SPARROW_SCHEDULER_H */