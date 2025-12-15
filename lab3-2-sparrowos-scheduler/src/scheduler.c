/**
 * scheduler.c - SparrowOS调度器核心实现
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "scheduler.h"

/* 全局变量 */
static pcb_t process_table[MAX_PROCESSES];
static pcb_t* current_process = NULL;
static ready_queue_t ready_queue;
static mlfq_t mlfq;
static scheduler_config_t scheduler_config;
static scheduler_stats_t scheduler_stats;
static uint32_t next_pid = 1;
static uint32_t system_ticks = 0;

/* 辅助函数声明 */
static pcb_t* find_free_pcb(void);
static void add_to_ready_queue(pcb_t* pcb);
static void remove_from_ready_queue(pcb_t* pcb);
static void promote_process(pcb_t* pcb);
static void demote_process(pcb_t* pcb);

/* 初始化调度器 */
void scheduler_init(scheduler_config_t config) {
    memset(&process_table, 0, sizeof(process_table));
    memset(&ready_queue, 0, sizeof(ready_queue));
    memset(&mlfq, 0, sizeof(mlfq));
    memset(&scheduler_stats, 0, sizeof(scheduler_stats));
    
    scheduler_config = config;
    next_pid = 1;
    system_ticks = 0;
    current_process = NULL;
    
    /* 根据调度类型初始化 */
    switch (config.type) {
        case SCHED_FIFO:
            scheduler_fifo_init();
            break;
        case SCHED_RR:
            scheduler_rr_init(config.time_quantum);
            break;
        case SCHED_MLFQ:
            scheduler_mlfq_init(config.mlfq_levels, config.boost_interval);
            break;
        case SCHED_CFS:
            // CFS初始化（简化版）
            break;
    }
    
    printf("Scheduler initialized with type: %d\n", config.type);
}

/* 创建新进程 */
pcb_t* scheduler_create_process(const char* name, uint8_t priority) {
    pcb_t* pcb = find_free_pcb();
    if (!pcb) {
        printf("Error: No free PCB available\n");
        return NULL;
    }
    
    /* 初始化PCB */
    pcb->pid = next_pid++;
    strncpy(pcb->name, name, sizeof(pcb->name) - 1);
    pcb->name[sizeof(pcb->name) - 1] = '\0';
    
    pcb->state = PROCESS_NEW;
    pcb->priority = priority;
    pcb->priority_original = priority;
    
    pcb->time_created = system_ticks;
    pcb->time_started = 0;
    pcb->time_used = 0;
    pcb->time_slice = TIME_SLICE_BASE * (MAX_PRIORITY_LEVELS - priority);
    pcb->time_slice_used = 0;
    pcb->vruntime = 0;
    
    /* 初始化寄存器（模拟值） */
    pcb->reg_esp = 0x1000 + (pcb->pid * 0x1000);
    pcb->reg_eip = 0x400000;
    
    /* 加入就绪队列 */
    pcb->state = PROCESS_READY;
    add_to_ready_queue(pcb);
    
    printf("Process created: PID=%d, Name=%s, Priority=%d\n", 
           pcb->pid, pcb->name, pcb->priority);
    
    return pcb;
}

/* 终止进程 */
void scheduler_terminate_process(uint32_t pid) {
    for (int i = 0; i < MAX_PROCESSES; i++) {
        if (process_table[i].pid == pid && 
            process_table[i].state != PROCESS_TERMINATED) {
            
            process_table[i].state = PROCESS_TERMINATED;
            remove_from_ready_queue(&process_table[i]);
            
            scheduler_stats.processes_completed++;
            scheduler_stats.total_runtime += process_table[i].time_used;
            
            printf("Process terminated: PID=%d, TotalTime=%d\n", 
                   pid, process_table[i].time_used);
            
            /* 如果终止的是当前进程，触发调度 */
            if (current_process && current_process->pid == pid) {
                current_process = NULL;
                scheduler_schedule();
            }
            return;
        }
    }
    printf("Error: Process %d not found\n", pid);
}

/* 主动让出CPU */
void scheduler_yield(void) {
    if (current_process) {
        current_process->state = PROCESS_READY;
        add_to_ready_queue(current_process);
    }
    scheduler_schedule();
}

/* 获取当前运行进程 */
pcb_t* scheduler_get_current_process(void) {
    return current_process;
}

/* 定时器滴答处理 */
void scheduler_tick(void) {
    system_ticks++;
    
    if (current_process) {
        current_process->time_used++;
        current_process->time_slice_used++;
        current_process->vruntime++;
        
        /* 检查时间片是否用完 */
        if (scheduler_config.enable_preemption && 
            current_process->time_slice_used >= current_process->time_slice) {
            printf("Time slice expired for process %d\n", current_process->pid);
            scheduler_yield();
        }
        
        /* MLFQ特定处理 */
        if (scheduler_config.type == SCHED_MLFQ) {
            current_process->time_in_queue++;
            
            /* 检查是否需要优先级提升 */
            if (system_ticks - mlfq.last_boost_time >= mlfq.boost_interval) {
                scheduler_mlfq_boost_priority();
                mlfq.last_boost_time = system_ticks;
            }
        }
    }
}

/* 调度决策 */
void scheduler_schedule(void) {
    pcb_t* next_process = NULL;
    
    switch (scheduler_config.type) {
        case SCHED_FIFO:
            next_process = scheduler_fifo_schedule();
            break;
        case SCHED_RR:
            next_process = scheduler_rr_schedule();
            break;
        case SCHFQ_MLFQ:
            next_process = scheduler_mlfq_schedule();
            break;
        default:
            next_process = scheduler_fifo_schedule();
            break;
    }
    
    /* 执行上下文切换 */
    if (next_process && next_process != current_process) {
        if (current_process) {
            current_process->state = PROCESS_READY;
            if (current_process->state != PROCESS_BLOCKED) {
                add_to_ready_queue(current_process);
            }
        }
        
        current_process = next_process;
        current_process->state = PROCESS_RUNNING;
        current_process->time_started = system_ticks;
        current_process->time_slice_used = 0;
        remove_from_ready_queue(current_process);
        
        scheduler_stats.context_switches++;
        
        printf("Context switch: PID %d -> %d\n", 
               current_process ? current_process->pid : 0, 
               next_process->pid);
    }
}

/* FIFO调度算法实现 */
void scheduler_fifo_init(void) {
    ready_queue.head = NULL;
    ready_queue.tail = NULL;
    ready_queue.count = 0;
}

pcb_t* scheduler_fifo_schedule(void) {
    if (ready_queue.count == 0) {
        return NULL;
    }
    
    pcb_t* next = ready_queue.head;
    if (ready_queue.head == ready_queue.tail) {
        ready_queue.head = ready_queue.tail = NULL;
    } else {
        ready_queue.head = ready_queue.head->next;
        if (ready_queue.head) {
            ready_queue.head->prev = NULL;
        }
    }
    ready_queue.count--;
    
    return next;
}

/* RR调度算法实现 */
void scheduler_rr_init(uint32_t time_quantum) {
    scheduler_fifo_init();
    for (int i = 0; i < MAX_PROCESSES; i++) {
        process_table[i].time_slice = time_quantum;
    }
}

pcb_t* scheduler_rr_schedule(void) {
    pcb_t* next = scheduler_fifo_schedule();
    if (next && current_process && current_process->state == PROCESS_READY) {
        /* 将当前进程移到队列尾部 */
        add_to_ready_queue(current_process);
    }
    return next;
}

/* MLFQ调度算法实现 */
void scheduler_mlfq_init(uint8_t levels, uint32_t boost_interval) {
    if (levels > MAX_PRIORITY_LEVELS) {
        levels = MAX_PRIORITY_LEVELS;
    }
    
    for (int i = 0; i < levels; i++) {
        mlfq.queues[i].head = NULL;
        mlfq.queues[i].tail = NULL;
        mlfq.queues[i].count = 0;
        mlfq.time_slices[i] = TIME_SLICE_BASE * (1 << i); // 指数增长
    }
    
    mlfq.boost_interval = boost_interval;
    mlfq.last_boost_time = 0;
}

pcb_t* scheduler_mlfq_schedule(void) {
    /* 从高优先级到低优先级查找就绪进程 */
    for (int i = 0; i < MAX_PRIORITY_LEVELS; i++) {
        if (mlfq.queues[i].count > 0) {
            pcb_t* next = mlfq.queues[i].head;
            
            /* 从队列头部移除 */
            if (mlfq.queues[i].head == mlfq.queues[i].tail) {
                mlfq.queues[i].head = mlfq.queues[i].tail = NULL;
            } else {
                mlfq.queues[i].head = mlfq.queues[i].head->next;
                if (mlfq.queues[i].head) {
                    mlfq.queues[i].head->prev = NULL;
                }
            }
            mlfq.queues[i].count--;
            
            next->time_slice = mlfq.time_slices[i];
            next->time_in_queue = 0;
            
            return next;
        }
    }
    return NULL;
}

void scheduler_mlfq_boost_priority(void) {
    printf("MLFQ: Boosting priority of all processes\n");
    
    /* 将所有低优先级进程提升到最高优先级 */
    for (int i = 1; i < MAX_PRIORITY_LEVELS; i++) {
        while (mlfq.queues[i].count > 0) {
            pcb_t* pcb = mlfq.queues[i].head;
            
            /* 从当前队列移除 */
            if (mlfq.queues[i].head == mlfq.queues[i].tail) {
                mlfq.queues[i].head = mlfq.queues[i].tail = NULL;
            } else {
                mlfq.queues[i].head = mlfq.queues[i].head->next;
                if (mlfq.queues[i].head) {
                    mlfq.queues[i].head->prev = NULL;
                }
            }
            mlfq.queues[i].count--;
            
            /* 提升到最高优先级队列 */
            pcb->priority = 0;
            pcb->time_in_queue = 0;
            pcb->promotions++;
            
            /* 添加到最高优先级队列尾部 */
            if (!mlfq.queues[0].head) {
                mlfq.queues[0].head = mlfq.queues[0].tail = pcb;
            } else {
                mlfq.queues[0].tail->next = pcb;
                pcb->prev = mlfq.queues[0].tail;
                mlfq.queues[0].tail = pcb;
            }
            mlfq.queues[0].count++;
            
            printf("  Boosted PID=%d to priority 0\n", pcb->pid);
        }
    }
}

/* 辅助函数实现 */
static pcb_t* find_free_pcb(void) {
    for (int i = 0; i < MAX_PROCESSES; i++) {
        if (process_table[i].state == PROCESS_TERMINATED || 
            process_table[i].pid == 0) {
            return &process_table[i];
        }
    }
    return NULL;
}

static void add_to_ready_queue(pcb_t* pcb) {
    if (!pcb) return;
    
    pcb->next = NULL;
    pcb->prev = NULL;
    
    if (scheduler_config.type == SCHED_MLFQ) {
        /* 添加到对应优先级的MLFQ队列 */
        uint8_t priority = pcb->priority;
        if (priority >= MAX_PRIORITY_LEVELS) {
            priority = MAX_PRIORITY_LEVELS - 1;
        }
        
        if (!mlfq.queues[priority].head) {
            mlfq.queues[priority].head = mlfq.queues[priority].tail = pcb;
        } else {
            mlfq.queues[priority].tail->next = pcb;
            pcb->prev = mlfq.queues[priority].tail;
            mlfq.queues[priority].tail = pcb;
        }
        mlfq.queues[priority].count++;
    } else {
        /* 添加到单一就绪队列 */
        if (!ready_queue.head) {
            ready_queue.head = ready_queue.tail = pcb;
        } else {
            ready_queue.tail->next = pcb;
            pcb->prev = ready_queue.tail;
            ready_queue.tail = pcb;
        }
        ready_queue.count++;
    }
}

static void remove_from_ready_queue(pcb_t* pcb) {
    if (!pcb) return;
    
    if (scheduler_config.type == SCHED_MLFQ) {
        uint8_t priority = pcb->priority;
        if (priority >= MAX_PRIORITY_LEVELS) return;
        
        if (pcb->prev) {
            pcb->prev->next = pcb->next;
        } else {
            mlfq.queues[priority].head = pcb->next;
        }
        
        if (pcb->next) {
            pcb->next->prev = pcb->prev;
        } else {
            mlfq.queues[priority].tail = pcb->prev;
        }
        
        if (mlfq.queues[priority].count > 0) {
            mlfq.queues[priority].count--;
        }
    } else {
        if (pcb->prev) {
            pcb->prev->next = pcb->next;
        } else {
            ready_queue.head = pcb->next;
        }
        
        if (pcb->next) {
            pcb->next->prev = pcb->prev;
        } else {
            ready_queue.tail = pcb->prev;
        }
        
        if (ready_queue.count > 0) {
            ready_queue.count--;
        }
    }
    
    pcb->next = pcb->prev = NULL;
}

/* 统计函数 */
scheduler_stats_t scheduler_get_stats(void) {
    if (scheduler_stats.processes_completed > 0) {
        scheduler_stats.avg_turnaround_time = 
            scheduler_stats.total_runtime / scheduler_stats.processes_completed;
    }
    return scheduler_stats;
}

void scheduler_print_stats(void) {
    scheduler_stats_t stats = scheduler_get_stats();
    
    printf("\n=== Scheduler Statistics ===\n");
    printf("Context switches: %d\n", stats.context_switches);
    printf("Processes completed: %d\n", stats.processes_completed);
    printf("Total runtime: %d ticks\n", stats.total_runtime);
    printf("Average turnaround time: %d ticks\n", stats.avg_turnaround_time);
    printf("System uptime: %d ticks\n", system_ticks);
    printf("============================\n");
}

/* 调试函数 */
void scheduler_print_ready_queue(void) {
    printf("\n=== Ready Queue ===\n");
    
    if (scheduler_config.type == SCHED_MLFQ) {
        for (int i = 0; i < MAX_PRIORITY_LEVELS; i++) {
            printf("Priority %d (%d processes): ", i, mlfq.queues[i].count);
            pcb_t* pcb = mlfq.queues[i].head;
            while (pcb) {
                printf("%s(PID:%d) ", pcb->name, pcb->pid);
                pcb = pcb->next;
            }
            printf("\n");
        }
    } else {
        printf("Total processes: %d\n", ready_queue.count);
        pcb_t* pcb = ready_queue.head;
        while (pcb) {
            printf("  PID:%d, Name:%s, State:%d\n", 
                   pcb->pid, pcb->name, pcb->state);
            pcb = pcb->next;
        }
    }
}

void scheduler_dump_all_processes(void) {
    printf("\n=== All Processes ===\n");
    for (int i = 0; i < MAX_PROCESSES; i++) {
        if (process_table[i].pid != 0 && 
            process_table[i].state != PROCESS_TERMINATED) {
            printf("PID:%d, Name:%s, State:%d, Priority:%d, Used:%d\n",
                   process_table[i].pid,
                   process_table[i].name,
                   process_table[i].state,
                   process_table[i].priority,
                   process_table[i].time_used);
        }
    }
}