/**
 * scheduler.c - SparrowOS内核调度器核心实现
 * 位于: kernel/core/scheduler.c
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#include "kernel/include/pcb.h"
#include "kernel/include/scheduler.h"
#include "kernel/include/interrupt.h"
#include "kernel/include/spinlock.h"

/* 全局调度器状态 */
typedef struct {
    scheduler_config_t config;          // 调度器配置
    process_table_t process_table;      // 进程表
    mlfq_t mlfq;                        // 多级反馈队列
    ready_queue_t ready_queue;          // 通用就绪队列
    wait_queue_t wait_queue;            // 等待队列
    wait_queue_t sleep_queue;           // 睡眠队列
    
    pcb_t *current_process;             // 当前运行进程
    pcb_t *idle_process;                // 空闲进程
    pcb_t *init_process;                // init进程
    
    scheduler_stats_t stats;            // 调度统计
    uint32_t system_ticks;              // 系统时钟滴答
    uint32_t last_schedule_time;        // 上次调度时间
    
    spinlock_t scheduler_lock;          // 调度器自旋锁
    bool scheduler_running;             // 调度器运行标志
    bool need_reschedule;               // 需要重新调度标志
} scheduler_state_t;

static scheduler_state_t scheduler_state;

/* 调度器内部函数声明 */
static pcb_t* find_free_pcb(void);
static void add_to_ready_queue_internal(pcb_t *pcb);
static void remove_from_ready_queue_internal(pcb_t *pcb);
static pcb_t* get_next_process(void);
static void update_process_times(void);
static void check_sleeping_processes(void);
static void update_scheduler_stats(void);
static void load_balance(void);
static void scheduler_tick_handler(void);

/* 空闲进程函数 */
static void idle_process_entry(void) {
    while (1) {
        // HLT指令让CPU进入低功耗状态，等待中断
        __asm__ volatile("hlt");
    }
}

/* 初始化调度器 */
void scheduler_init(scheduler_config_t *config) {
    printf("SparrowOS Scheduler Initializing...\n");
    
    // 初始化调度器状态
    memset(&scheduler_state, 0, sizeof(scheduler_state_t));
    
    // 保存配置
    if (config) {
        scheduler_state.config = *config;
    } else {
        // 默认配置
        scheduler_state.config.scheduler_type = SCHEDULER_MLFQ;
        scheduler_state.config.time_quantum = TIME_SLICE_BASE;
        scheduler_state.config.enable_preemption = true;
        scheduler_state.config.enable_multicore = false;
        scheduler_state.config.num_priority_levels = MAX_PRIORITY_LEVELS;
        scheduler_state.config.boost_interval = 1000;
        scheduler_state.config.load_balance_interval = 500;
    }
    
    // 初始化进程表
    process_table_init(&scheduler_state.process_table);
    
    // 初始化就绪队列
    ready_queue_init(&scheduler_state.ready_queue, 
                    MAX_PROCESSES, 
                    scheduler_state.config.time_quantum);
    
    // 初始化等待队列
    wait_queue_init(&scheduler_state.wait_queue, WAIT_REASON_UNKNOWN);
    wait_queue_init(&scheduler_state.sleep_queue, WAIT_REASON_SLEEP);
    
    // 初始化MLFQ（如果使用）
    if (scheduler_state.config.scheduler_type == SCHEDULER_MLFQ) {
        mlfq_init(&scheduler_state.mlfq, 
                 scheduler_state.config.num_priority_levels,
                 scheduler_state.config.boost_interval);
    }
    
    // 初始化自旋锁
    spinlock_init(&scheduler_state.scheduler_lock);
    
    // 创建空闲进程
    scheduler_state.idle_process = scheduler_create_process(
        "idle", 
        PROCESS_TYPE_SYSTEM, 
        MAX_PRIORITY_LEVELS - 1,  // 最低优先级
        PROCESS_FLAG_CPU_BOUND
    );
    
    if (!scheduler_state.idle_process) {
        printf("ERROR: Failed to create idle process\n");
        return;
    }
    
    // 设置空闲进程的入口点
    scheduler_state.idle_process->context.eip = (uint32_t)idle_process_entry;
    
    // 设置当前进程为空闲进程
    scheduler_state.current_process = scheduler_state.idle_process;
    scheduler_state.current_process->state = PROCESS_RUNNING;
    
    // 初始化系统时钟
    scheduler_state.system_ticks = 0;
    scheduler_state.last_schedule_time = 0;
    
    // 设置调度器运行标志
    scheduler_state.scheduler_running = true;
    scheduler_state.need_reschedule = false;
    
    // 注册定时器中断处理函数
    interrupt_register_handler(IRQ_TIMER, scheduler_tick_handler);
    
    printf("Scheduler initialized successfully\n");
    printf("  Type: %s\n", 
           scheduler_state.config.scheduler_type == SCHEDULER_MLFQ ? "MLFQ" :
           scheduler_state.config.scheduler_type == SCHEDULER_RR ? "RR" : "FIFO");
    printf("  Time quantum: %d\n", scheduler_state.config.time_quantum);
    printf("  Preemption: %s\n", scheduler_state.config.enable_preemption ? "enabled" : "disabled");
}

/* 创建新进程 */
pcb_t* scheduler_create_process(const char *name, 
                               process_type_t type,
                               uint8_t priority,
                               process_flags_t flags) {
    spinlock_lock(&scheduler_state.scheduler_lock);
    
    // 分配PCB
    pcb_t *pcb = pcb_alloc();
    if (!pcb) {
        printf("ERROR: No free PCB available\n");
        spinlock_unlock(&scheduler_state.scheduler_lock);
        return NULL;
    }
    
    // 初始化PCB
    uint32_t pid = scheduler_state.process_table.next_pid++;
    pcb_init(pcb, pid, name, type, priority);
    
    // 设置进程标志
    pcb->flags = flags;
    
    // 设置父进程（如果有当前进程）
    if (scheduler_state.current_process && 
        scheduler_state.current_process != scheduler_state.idle_process) {
        pcb->ppid = scheduler_state.current_process->pid;
        pcb->parent = scheduler_state.current_process;
        pcb_add_child(scheduler_state.current_process, pcb);
    } else {
        pcb->ppid = 0;  // 孤儿进程
        pcb->parent = NULL;
    }
    
    // 设置时间信息
    pcb->time_created = scheduler_state.system_ticks;
    pcb->time_slice = calculate_time_slice(priority, scheduler_state.config.time_quantum);
    
    // 分配栈空间（模拟）
    pcb->stack_base = 0x1000000 + (pid * STACK_SIZE);
    pcb->stack_size = STACK_SIZE;
    
    // 设置初始CPU上下文
    pcb->context.esp = pcb->stack_base + STACK_SIZE - sizeof(uint32_t);
    pcb->context.eflags = 0x00000202;  // 中断使能，IOPL=0
    
    // 根据调度器类型设置标志
    switch (scheduler_state.config.scheduler_type) {
        case SCHEDULER_MLFQ:
            PCB_SET_FLAG(pcb, PROCESS_FLAG_SCHED_MLFQ);
            pcb->queue_level = priority;  // 初始队列级别
            break;
        case SCHEDULER_RR:
            PCB_SET_FLAG(pcb, PROCESS_FLAG_SCHED_RR);
            break;
        case SCHEDULER_FIFO:
            PCB_SET_FLAG(pcb, PROCESS_FLAG_SCHED_FIFO);
            break;
    }
    
    // 加入就绪队列
    pcb_set_state(pcb, PROCESS_READY);
    add_to_ready_queue_internal(pcb);
    
    // 更新统计
    scheduler_state.stats.processes_created++;
    
    spinlock_unlock(&scheduler_state.scheduler_lock);
    
    printf("Process created: PID=%d, Name=%s, Priority=%d\n", 
           pcb->pid, pcb->name, pcb->priority);
    
    return pcb;
}

/* 终止进程 */
int scheduler_terminate_process(uint32_t pid, int exit_code) {
    spinlock_lock(&scheduler_state.scheduler_lock);
    
    pcb_t *pcb = process_table_find(&scheduler_state.process_table, pid);
    if (!pcb) {
        printf("ERROR: Process %d not found\n", pid);
        spinlock_unlock(&scheduler_state.scheduler_lock);
        return -1;
    }
    
    // 检查进程状态
    if (pcb->state == PROCESS_TERMINATED || pcb->state == PROCESS_ZOMBIE) {
        printf("ERROR: Process %d already terminated\n", pid);
        spinlock_unlock(&scheduler_state.scheduler_lock);
        return -1;
    }
    
    // 保存退出代码
    pcb->exit_code = exit_code;
    
    // 处理子进程
    if (pcb->children) {
        pcb_orphan_children(pcb);
    }
    
    // 从调度队列中移除
    remove_from_ready_queue_internal(pcb);
    
    // 更新状态
    pcb->time_terminated = scheduler_state.system_ticks;
    pcb_set_state(pcb, PROCESS_ZOMBIE);  // 先变为僵尸状态
    
    // 如果终止的是当前进程，触发调度
    if (pcb == scheduler_state.current_process) {
        scheduler_state.current_process = NULL;
        scheduler_state.need_reschedule = true;
    }
    
    // 更新统计
    scheduler_state.stats.processes_terminated++;
    
    spinlock_unlock(&scheduler_state.scheduler_lock);
    
    printf("Process terminated: PID=%d, ExitCode=%d\n", pid, exit_code);
    
    return 0;
}

/* 真正回收进程资源 */
int scheduler_reap_process(uint32_t pid) {
    spinlock_lock(&scheduler_state.scheduler_lock);
    
    pcb_t *pcb = process_table_find(&scheduler_state.process_table, pid);
    if (!pcb) {
        spinlock_unlock(&scheduler_state.scheduler_lock);
        return -1;
    }
    
    if (pcb->state != PROCESS_ZOMBIE) {
        printf("ERROR: Process %d is not a zombie\n", pid);
        spinlock_unlock(&scheduler_state.scheduler_lock);
        return -1;
    }
    
    // 更新统计
    uint32_t lifetime = PCB_LIFETIME(pcb);
    uint32_t turnaround_time = PCB_TURNAROUND_TIME(pcb);
    
    scheduler_state.stats.processes_completed++;
    scheduler_state.stats.total_runtime += pcb->time_used;
    scheduler_state.stats.total_wait_time += (lifetime - pcb->time_used);
    
    // 计算平均时间
    if (scheduler_state.stats.processes_completed > 0) {
        scheduler_state.stats.avg_turnaround_time = 
            scheduler_state.stats.total_runtime / 
            scheduler_state.stats.processes_completed;
    }
    
    // 释放PCB
    pcb_set_state(pcb, PROCESS_TERMINATED);
    pcb_free(pcb);
    
    spinlock_unlock(&scheduler_state.scheduler_lock);
    
    return 0;
}

/* 进程调度 */
void scheduler_schedule(void) {
    if (!scheduler_state.scheduler_running) {
        return;
    }
    
    spinlock_lock(&scheduler_state.scheduler_lock);
    
    // 获取下一个要运行的进程
    pcb_t *next_process = get_next_process();
    
    // 如果没有就绪进程，运行空闲进程
    if (!next_process) {
        next_process = scheduler_state.idle_process;
    }
    
    // 检查是否需要切换
    pcb_t *current_process = scheduler_state.current_process;
    
    if (current_process != next_process) {
        // 执行上下文切换
        scheduler_state.stats.context_switches++;
        
        // 保存当前进程上下文
        if (current_process && current_process != scheduler_state.idle_process) {
            // 保存CPU寄存器到PCB
            __asm__ volatile(
                "movl %%esp, %0\n"
                "movl %%eip, %1\n"
                : "=r"(current_process->context.esp),
                  "=r"(current_process->context.eip)
                :
                : "memory"
            );
            
            // 更新进程状态
            if (current_process->state == PROCESS_RUNNING) {
                pcb_set_state(current_process, PROCESS_READY);
                add_to_ready_queue_internal(current_process);
            }
        }
        
        // 更新下一个进程状态
        pcb_set_state(next_process, PROCESS_RUNNING);
        next_process->time_started = scheduler_state.system_ticks;
        next_process->time_slice_used = 0;
        remove_from_ready_queue_internal(next_process);
        
        // 更新当前进程指针
        scheduler_state.current_process = next_process;
        scheduler_state.last_schedule_time = scheduler_state.system_ticks;
        
        // 设置需要重新调度标志为false
        scheduler_state.need_reschedule = false;
        
        printf("Context switch: %s(PID:%d) -> %s(PID:%d)\n",
               current_process ? current_process->name : "NULL",
               current_process ? current_process->pid : 0,
               next_process->name, next_process->pid);
        
        // 恢复下一个进程的上下文
        if (next_process != scheduler_state.idle_process) {
            __asm__ volatile(
                "movl %0, %%esp\n"
                "movl %1, %%eip\n"
                :
                : "r"(next_process->context.esp),
                  "r"(next_process->context.eip)
                : "memory"
            );
        }
    }
    
    spinlock_unlock(&scheduler_state.scheduler_lock);
}

/* 定时器中断处理 */
static void scheduler_tick_handler(void) {
    scheduler_state.system_ticks++;
    
    // 更新当前进程的时间统计
    update_process_times();
    
    // 检查睡眠进程
    check_sleeping_processes();
    
    // 更新调度器统计
    update_scheduler_stats();
    
    // 定期负载均衡
    if (scheduler_state.config.enable_multicore &&
        (scheduler_state.system_ticks % scheduler_state.config.load_balance_interval == 0)) {
        load_balance();
    }
    
    // 检查是否需要重新调度
    if (scheduler_state.need_reschedule ||
        (scheduler_state.current_process && 
         scheduler_state.config.enable_preemption &&
         scheduler_state.current_process->time_slice_used >= 
         scheduler_state.current_process->time_slice)) {
        
        scheduler_state.need_reschedule = true;
        scheduler_schedule();
    }
}

/* 进程主动让出CPU */
void scheduler_yield(void) {
    spinlock_lock(&scheduler_state.scheduler_lock);
    
    if (scheduler_state.current_process && 
        scheduler_state.current_process != scheduler_state.idle_process) {
        
        // 对于MLFQ，主动让出CPU的进程保持当前优先级
        if (PCB_HAS_FLAG(scheduler_state.current_process, PROCESS_FLAG_SCHED_MLFQ)) {
            // 重置在当前队列中的时间
            scheduler_state.current_process->time_in_queue = 0;
        }
        
        // 设置需要重新调度
        scheduler_state.need_reschedule = true;
    }
    
    spinlock_unlock(&scheduler_state.scheduler_lock);
    
    // 触发调度
    scheduler_schedule();
}

/* 阻塞当前进程 */
int scheduler_block_process(uint32_t wait_reason) {
    spinlock_lock(&scheduler_state.scheduler_lock);
    
    pcb_t *pcb = scheduler_state.current_process;
    if (!pcb || pcb == scheduler_state.idle_process) {
        spinlock_unlock(&scheduler_state.scheduler_lock);
        return -1;
    }
    
    // 设置阻塞状态
    pcb_set_state(pcb, PROCESS_BLOCKED);
    
    // 加入等待队列
    wait_queue_enqueue(&scheduler_state.wait_queue, pcb);
    
    // 设置需要重新调度
    scheduler_state.need_reschedule = true;
    
    spinlock_unlock(&scheduler_state.scheduler_lock);
    
    // 触发调度
    scheduler_schedule();
    
    return 0;
}

/* 唤醒阻塞进程 */
int scheduler_wakeup_process(uint32_t pid) {
    spinlock_lock(&scheduler_state.scheduler_lock);
    
    // 在等待队列中查找进程
    pcb_t *pcb = NULL;
    wait_queue_node_t *node = scheduler_state.wait_queue.head;
    
    while (node) {
        if (node->pcb->pid == pid) {
            pcb = node->pcb;
            break;
        }
        node = node->next;
    }
    
    if (!pcb) {
        spinlock_unlock(&scheduler_state.scheduler_lock);
        return -1;
    }
    
    // 从等待队列移除
    wait_queue_remove(&scheduler_state.wait_queue, pcb);
    
    // 设置为就绪状态
    pcb_set_state(pcb, PROCESS_READY);
    add_to_ready_queue_internal(pcb);
    
    spinlock_unlock(&scheduler_state.scheduler_lock);
    
    return 0;
}

/* 使进程睡眠 */
int scheduler_sleep_process(uint32_t ticks) {
    spinlock_lock(&scheduler_state.scheduler_lock);
    
    pcb_t *pcb = scheduler_state.current_process;
    if (!pcb || pcb == scheduler_state.idle_process) {
        spinlock_unlock(&scheduler_state.scheduler_lock);
        return -1;
    }
    
    // 设置睡眠状态
    pcb_set_state(pcb, PROCESS_SLEEPING);
    pcb->deadline = scheduler_state.system_ticks + ticks;
    
    // 加入睡眠队列
    wait_queue_enqueue(&scheduler_state.sleep_queue, pcb);
    
    // 设置需要重新调度
    scheduler_state.need_reschedule = true;
    
    spinlock_unlock(&scheduler_state.scheduler_lock);
    
    // 触发调度
    scheduler_schedule();
    
    return 0;
}

/* 设置进程优先级 */
int scheduler_set_priority(uint32_t pid, uint8_t priority) {
    spinlock_lock(&scheduler_state.scheduler_lock);
    
    pcb_t *pcb = process_table_find(&scheduler_state.process_table, pid);
    if (!pcb) {
        spinlock_unlock(&scheduler_state.scheduler_lock);
        return -1;
    }
    
    // 检查优先级范围
    if (priority >= MAX_PRIORITY_LEVELS) {
        priority = MAX_PRIORITY_LEVELS - 1;
    }
    
    // 更新优先级
    uint8_t old_priority = pcb->priority;
    pcb_set_priority(pcb, priority);
    
    // 重新计算时间片
    pcb->time_slice = calculate_time_slice(priority, 
                                          scheduler_state.config.time_quantum);
    
    // 如果进程在就绪队列中，可能需要调整位置
    if (pcb->state == PROCESS_READY) {
        remove_from_ready_queue_internal(pcb);
        add_to_ready_queue_internal(pcb);
    }
    
    printf("Process %d priority changed: %d -> %d\n", 
           pid, old_priority, priority);
    
    spinlock_unlock(&scheduler_state.scheduler_lock);
    
    return 0;
}

/* 获取当前进程 */
pcb_t* scheduler_get_current_process(void) {
    return scheduler_state.current_process;
}

/* 获取进程信息 */
pcb_t* scheduler_get_process(uint32_t pid) {
    spinlock_lock(&scheduler_state.scheduler_lock);
    pcb_t *pcb = process_table_find(&scheduler_state.process_table, pid);
    spinlock_unlock(&scheduler_state.scheduler_lock);
    return pcb;
}

/* 获取调度器统计 */
scheduler_stats_t scheduler_get_stats(void) {
    spinlock_lock(&scheduler_state.scheduler_lock);
    scheduler_stats_t stats = scheduler_state.stats;
    spinlock_unlock(&scheduler_state.scheduler_lock);
    return stats;
}

/* 打印调度器状态 */
void scheduler_print_status(void) {
    spinlock_lock(&scheduler_state.scheduler_lock);
    
    printf("\n=== SparrowOS Scheduler Status ===\n");
    printf("System ticks: %u\n", scheduler_state.system_ticks);
    printf("Running: %s\n", scheduler_state.scheduler_running ? "yes" : "no");
    
    // 当前进程信息
    if (scheduler_state.current_process) {
        printf("\nCurrent process:\n");
        pcb_dump_brief(scheduler_state.current_process);
    }
    
    // 就绪队列信息
    printf("\nReady queue: %u processes\n", scheduler_state.ready_queue.count);
    
    // 进程表信息
    printf("Process table: %u/%u processes\n", 
           scheduler_state.process_table.count, MAX_PROCESSES);
    
    // 统计信息
    printf("\nStatistics:\n");
    printf("  Context switches: %u\n", scheduler_state.stats.context_switches);
    printf("  Processes created: %u\n", scheduler_state.stats.processes_created);
    printf("  Processes completed: %u\n", scheduler_state.stats.processes_completed);
    printf("  Total runtime: %u\n", scheduler_state.stats.total_runtime);
    printf("  Avg turnaround time: %u\n", scheduler_state.stats.avg_turnaround_time);
    printf("  CPU utilization: %u%%\n", scheduler_state.stats.cpu_utilization);
    
    spinlock_unlock(&scheduler_state.scheduler_lock);
}

/* ========== 内部函数实现 ========== */

/* 获取下一个要运行的进程 */
static pcb_t* get_next_process(void) {
    switch (scheduler_state.config.scheduler_type) {
        case SCHEDULER_MLFQ:
            return mlfq_dequeue(&scheduler_state.mlfq);
            
        case SCHEDULER_RR:
            // RR调度：从就绪队列头部取一个进程
            return ready_queue_dequeue(&scheduler_state.ready_queue);
            
        case SCHEDULER_FIFO:
            // FIFO调度：也是从就绪队列头部取，但没有时间片概念
            return ready_queue_dequeue(&scheduler_state.ready_queue);
            
        default:
            return ready_queue_dequeue(&scheduler_state.ready_queue);
    }
}

/* 添加进程到就绪队列 */
static void add_to_ready_queue_internal(pcb_t *pcb) {
    if (!pcb || pcb->state != PROCESS_READY) {
        return;
    }
    
    switch (scheduler_state.config.scheduler_type) {
        case SCHEDULER_MLFQ:
            // 根据进程的当前队列级别添加到MLFQ
            mlfq_enqueue(&scheduler_state.mlfq, pcb, pcb->queue_level);
            break;
            
        case SCHEDULER_RR:
        case SCHEDULER_FIFO:
            // 添加到通用就绪队列尾部
            ready_queue_enqueue(&scheduler_state.ready_queue, pcb);
            break;
    }
}

/* 从就绪队列移除进程 */
static void remove_from_ready_queue_internal(pcb_t *pcb) {
    if (!pcb) {
        return;
    }
    
    switch (scheduler_state.config.scheduler_type) {
        case SCHEDULER_MLFQ:
            // MLFQ队列移除（简化实现）
            // 在实际实现中，需要遍历队列找到并移除
            break;
            
        case SCHEDULER_RR:
        case SCHEDULER_FIFO:
            // 从通用就绪队列移除
            ready_queue_remove(&scheduler_state.ready_queue, pcb);
            break;
    }
}

/* 更新进程时间统计 */
static void update_process_times(void) {
    if (scheduler_state.current_process && 
        scheduler_state.current_process != scheduler_state.idle_process) {
        
        pcb_t *pcb = scheduler_state.current_process;
        
        // 增加已使用时间
        pcb->time_used++;
        pcb->time_slice_used++;
        pcb->vruntime++;
        
        // 更新进程统计
        pcb_update_stats(pcb, 1);
        
        // 对于MLFQ，增加在当前队列的时间
        if (PCB_HAS_FLAG(pcb, PROCESS_FLAG_SCHED_MLFQ)) {
            pcb->time_in_queue++;
            
            // 检查是否需要调整优先级
            if (pcb->time_in_queue >= scheduler_state.mlfq.demotion_threshold) {
                mlfq_adjust_priority(&scheduler_state.mlfq, pcb, true);
            }
        }
    }
}

/* 检查睡眠进程 */
static void check_sleeping_processes(void) {
    // 检查睡眠队列中的进程是否应该被唤醒
    wait_queue_node_t *node = scheduler_state.sleep_queue.head;
    wait_queue_node_t *prev = NULL;
    
    while (node) {
        pcb_t *pcb = node->pcb;
        
        if (scheduler_state.system_ticks >= pcb->deadline) {
            // 唤醒进程
            wait_queue_node_t *next = node->next;
            
            // 从睡眠队列移除
            if (prev) {
                prev->next = next;
            } else {
                scheduler_state.sleep_queue.head = next;
            }
            
            if (!next) {
                scheduler_state.sleep_queue.tail = prev;
            }
            
            // 设置为就绪状态并加入就绪队列
            pcb_set_state(pcb, PROCESS_READY);
            add_to_ready_queue_internal(pcb);
            
            // 移动到下一个节点
            node = next;
        } else {
            prev = node;
            node = node->next;
        }
    }
}

/* 更新调度器统计 */
static void update_scheduler_stats(void) {
    // 计算CPU利用率
    static uint32_t last_idle_time = 0;
    static uint32_t last_total_time = 0;
    
    uint32_t current_idle_time = scheduler_state.idle_process->time_used;
    uint32_t current_total_time = scheduler_state.system_ticks;
    
    if (current_total_time > last_total_time) {
        uint32_t idle_delta = current_idle_time - last_idle_time;
        uint32_t total_delta = current_total_time - last_total_time;
        
        if (total_delta > 0) {
            scheduler_state.stats.cpu_utilization = 
                100 - (idle_delta * 100 / total_delta);
        }
        
        last_idle_time = current_idle_time;
        last_total_time = current_total_time;
    }
    
    // 计算吞吐量（每秒完成的进程数）
    static uint32_t last_completed = 0;
    static uint32_t last_time = 0;
    
    if (scheduler_state.system_ticks - last_time >= 1000) { // 每秒计算一次
        uint32_t completed_delta = scheduler_state.stats.processes_completed - last_completed;
        uint32_t time_delta = scheduler_state.system_ticks - last_time;
        
        if (time_delta > 0) {
            scheduler_state.stats.throughput = completed_delta * 1000 / time_delta;
        }
        
        last_completed = scheduler_state.stats.processes_completed;
        last_time = scheduler_state.system_ticks;
    }
}

/* 负载均衡（多核支持） */
static void load_balance(void) {
    // 这是一个简化的负载均衡实现
    // 在实际的多核系统中，需要在不同CPU之间迁移进程
    
    if (!scheduler_state.config.enable_multicore) {
        return;
    }
    
    // 检查就绪队列长度
    uint32_t ready_count = scheduler_state.ready_queue.count;
    
    // 如果有太多就绪进程，可以考虑创建更多调度实体
    if (ready_count > MAX_PROCESSES / 2) {
        printf("Load balancing: %u processes in ready queue\n", ready_count);
    }
}

/* 分配空闲PCB */
static pcb_t* find_free_pcb(void) {
    return pcb_alloc();
}