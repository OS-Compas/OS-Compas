/**
 * pcb.h - 进程控制块定义
 * SparrowOS 进程调度器核心数据结构
 */

#ifndef _SPARROW_PCB_H
#define _SPARROW_PCB_H

#include <stdint.h>
#include <stdbool.h>

#define MAX_PROCESSES       64
#define MAX_PRIORITY_LEVELS 4
#define TIME_SLICE_BASE     10      // 基本时间片（时间单位）
#define MAX_RUNTIME         1000    // 最大运行时间
#define STACK_SIZE          4096    // 进程栈大小
#define PROCESS_NAME_LEN    32

/* 进程状态枚举 */
typedef enum {
    PROCESS_NEW,        // 新建
    PROCESS_READY,      // 就绪
    PROCESS_RUNNING,    // 运行
    PROCESS_BLOCKED,    // 阻塞
    PROCESS_SLEEPING,   // 睡眠
    PROCESS_ZOMBIE,     // 僵尸（已终止但资源未回收）
    PROCESS_TERMINATED  // 终止
} process_state_t;

/* 进程类型 */
typedef enum {
    PROCESS_TYPE_SYSTEM,    // 系统进程
    PROCESS_TYPE_USER,      // 用户进程
    PROCESS_TYPE_DAEMON,    // 守护进程
    PROCESS_TYPE_THREAD     // 线程
} process_type_t;

/* 进程标志位 */
typedef enum {
    PROCESS_FLAG_NONE       = 0x00,
    PROCESS_FLAG_CPU_BOUND  = 0x01,  // CPU密集型
    PROCESS_FLAG_IO_BOUND   = 0x02,  // IO密集型
    PROCESS_FLAG_INTERACTIVE = 0x04, // 交互式
    PROCESS_FLAG_REALTIME   = 0x08,  // 实时进程
    PROCESS_FLAG_KERNEL     = 0x10,  // 内核进程
    PROCESS_FLAG_SCHED_MLFQ = 0x20,  // MLFQ调度
    PROCESS_FLAG_SCHED_RR   = 0x40,  // RR调度
    PROCESS_FLAG_SCHED_FIFO = 0x80   // FIFO调度
} process_flags_t;

/* CPU上下文结构（用于上下文切换） */
typedef struct {
    /* 通用寄存器 */
    uint32_t eax;
    uint32_t ebx;
    uint32_t ecx;
    uint32_t edx;
    uint32_t esi;
    uint32_t edi;
    uint32_t ebp;
    
    /* 栈指针和指令指针 */
    uint32_t esp;
    uint32_t eip;
    
    /* 段寄存器 */
    uint32_t cs;
    uint32_t ds;
    uint32_t es;
    uint32_t fs;
    uint32_t gs;
    uint32_t ss;
    
    /* 控制寄存器 */
    uint32_t eflags;
    uint32_t cr3;   // 页目录基址寄存器
    
    /* 浮点寄存器上下文（可选） */
    uint8_t fpu_state[512];
} cpu_context_t;

/* 进程统计信息 */
typedef struct {
    uint32_t user_time;      // 用户态运行时间
    uint32_t kernel_time;    // 内核态运行时间
    uint32_t sleep_time;     // 睡眠时间
    uint32_t wait_time;      // 等待时间
    uint32_t context_switches; // 上下文切换次数
    uint32_t page_faults;    // 缺页次数
    uint32_t io_operations;  // IO操作次数
} process_stats_t;

/* 资源使用统计 */
typedef struct {
    uint32_t memory_used;    // 已使用内存
    uint32_t memory_peak;    // 峰值内存使用
    uint32_t open_files;     // 打开文件数
    uint32_t child_processes; // 子进程数
} resource_usage_t;

/* 进程控制块（PCB）结构体 */
typedef struct process_control_block {
    /* === 标识信息 === */
    uint32_t pid;                   // 进程ID
    uint32_t ppid;                  // 父进程ID
    uint32_t uid;                   // 用户ID
    uint32_t gid;                   // 组ID
    char name[PROCESS_NAME_LEN];   // 进程名称
    
    /* === 状态信息 === */
    process_state_t state;          // 进程状态
    process_type_t type;            // 进程类型
    process_flags_t flags;          // 进程标志
    uint8_t priority;               // 当前优先级（0最高，MAX_PRIORITY_LEVELS-1最低）
    uint32_t priority_original;     // 原始优先级
    int exit_code;                  // 退出代码
    
    /* === 时间统计 === */
    uint32_t time_created;          // 创建时间戳
    uint32_t time_started;          // 开始运行时间
    uint32_t time_terminated;       // 终止时间
    uint32_t time_used;             // 已使用CPU时间
    uint32_t time_slice;            // 当前时间片长度
    uint32_t time_slice_used;       // 当前时间片已使用时间
    uint32_t vruntime;              // 虚拟运行时间（用于CFS）
    uint32_t deadline;              // 截止时间（用于实时调度）
    
    /* === CPU上下文 === */
    cpu_context_t context;          // CPU寄存器上下文
    
    /* === 内存管理 === */
    uint32_t stack_base;            // 栈基址
    uint32_t stack_size;            // 栈大小
    uint32_t heap_base;             // 堆基址
    uint32_t heap_size;             // 堆大小
    uint32_t page_dir;              // 页目录地址
    
    /* === 调度信息 === */
    struct process_control_block *next;      // 链表指针
    struct process_control_block *prev;      // 链表指针
    struct process_control_block *parent;    // 父进程指针
    struct process_control_block *children;  // 子进程链表头
    struct process_control_block *sibling;   // 兄弟进程指针
    
    /* === MLFQ特定字段 === */
    uint32_t time_in_queue;         // 在当前队列中的时间
    uint8_t demotions;              // 降级次数
    uint8_t promotions;             // 升级次数
    uint8_t queue_level;            // 当前队列级别
    
    /* === 统计信息 === */
    process_stats_t stats;          // 运行统计
    resource_usage_t resources;     // 资源使用
    
    /* === 信号处理 === */
    uint32_t signal_mask;           // 信号掩码
    uint32_t pending_signals;       // 待处理信号
    void (*signal_handlers[32])(int); // 信号处理函数
    
    /* === 文件系统 === */
    int working_dir;                // 工作目录文件描述符
    int *open_files;                // 打开文件表
    uint32_t num_open_files;        // 打开文件数量
    
    /* === 通信和同步 === */
    uint32_t message_queue;         // 消息队列ID
    uint32_t semaphores[8];         // 信号量数组
    uint32_t shared_memory[4];      // 共享内存段
    
    /* === 安全信息 === */
    uint32_t capabilities;          // 能力集
    uint32_t security_label;        // 安全标签
    
    /* === 扩展字段 === */
    void *private_data;             // 进程私有数据
    uint32_t magic_number;          // 魔数，用于验证PCB完整性
} pcb_t;

/* 就绪队列节点 */
typedef struct ready_queue_node {
    pcb_t *pcb;
    struct ready_queue_node *next;
    struct ready_queue_node *prev;
    uint32_t enqueue_time;          // 入队时间
} ready_queue_node_t;

/* 就绪队列结构 */
typedef struct {
    ready_queue_node_t *head;
    ready_queue_node_t *tail;
    uint32_t count;
    uint32_t time_slice;            // 该队列的时间片长度
    uint32_t max_count;             // 队列最大容量
} ready_queue_t;

/* 等待队列（用于阻塞状态） */
typedef struct wait_queue {
    pcb_t *head;
    pcb_t *tail;
    uint32_t count;
    uint32_t wait_reason;           // 等待原因
} wait_queue_t;

/* 多级反馈队列 */
typedef struct {
    ready_queue_t queues[MAX_PRIORITY_LEVELS];
    uint32_t time_slices[MAX_PRIORITY_LEVELS]; // 各优先级时间片
    uint32_t boost_interval;        // 优先级提升间隔
    uint32_t last_boost_time;       // 上次提升时间
    uint32_t demotion_threshold;    // 降级阈值
    uint32_t promotion_threshold;   // 升级阈值
    uint32_t total_processes;       // 总进程数
} mlfq_t;

/* 调度统计 */
typedef struct {
    uint32_t context_switches;
    uint32_t processes_created;
    uint32_t processes_completed;
    uint32_t processes_terminated;
    uint32_t total_runtime;
    uint32_t total_wait_time;
    uint32_t avg_response_time;
    uint32_t avg_turnaround_time;
    uint32_t throughput;            // 吞吐量（进程/时间单位）
    uint32_t cpu_utilization;       // CPU利用率百分比
} scheduler_stats_t;

/* 调度器配置 */
typedef struct {
    uint32_t scheduler_type;        // 调度器类型
    uint32_t time_quantum;          // 基础时间片
    bool enable_preemption;         // 是否启用抢占
    bool enable_multicore;          // 是否支持多核
    uint32_t num_priority_levels;   // 优先级级别数
    uint32_t boost_interval;        // 优先级提升间隔
    uint32_t load_balance_interval; // 负载均衡间隔
} scheduler_config_t;

/* 进程表 */
typedef struct {
    pcb_t processes[MAX_PROCESSES]; // 进程数组
    uint32_t bitmap[MAX_PROCESSES / 32]; // 位图，用于快速查找空闲PCB
    uint32_t count;                 // 当前进程数
    uint32_t next_pid;              // 下一个可用的PID
    pcb_t *idle_process;            // 空闲进程
} process_table_t;

/* 进程组信息 */
typedef struct {
    uint32_t pgid;                  // 进程组ID
    pcb_t *leader;                  // 进程组领导进程
    uint32_t member_count;          // 成员数量
    pcb_t *members[MAX_PROCESSES];  // 成员列表
} process_group_t;

/* 会话信息 */
typedef struct {
    uint32_t sid;                   // 会话ID
    pcb_t *leader;                  // 会话领导进程
    process_group_t *foreground_pg; // 前台进程组
    process_group_t *background_pg; // 后台进程组
} session_t;

/* 函数声明 */

// PCB管理
pcb_t* pcb_alloc(void);
void pcb_free(pcb_t *pcb);
void pcb_init(pcb_t *pcb, uint32_t pid, const char *name, 
              process_type_t type, uint8_t priority);
void pcb_reset(pcb_t *pcb);
bool pcb_validate(const pcb_t *pcb);

// 上下文管理
void pcb_save_context(pcb_t *pcb, cpu_context_t *context);
void pcb_restore_context(pcb_t *pcb, cpu_context_t *context);
void pcb_clone_context(pcb_t *dest, const pcb_t *src);

// 进程状态
void pcb_set_state(pcb_t *pcb, process_state_t new_state);
bool pcb_is_runnable(const pcb_t *pcb);
bool pcb_is_zombie(const pcb_t *pcb);
bool pcb_is_terminated(const pcb_t *pcb);

// 优先级管理
void pcb_set_priority(pcb_t *pcb, uint8_t priority);
void pcb_promote(pcb_t *pcb);
void pcb_demote(pcb_t *pcb);
uint8_t pcb_get_effective_priority(const pcb_t *pcb);

// 统计信息
void pcb_update_stats(pcb_t *pcb, uint32_t runtime);
void pcb_reset_stats(pcb_t *pcb);
void pcb_print_stats(const pcb_t *pcb);

// 资源管理
void pcb_add_memory_usage(pcb_t *pcb, uint32_t size);
void pcb_remove_memory_usage(pcb_t *pcb, uint32_t size);
void pcb_add_open_file(pcb_t *pcb, int fd);
void pcb_remove_open_file(pcb_t *pcb, int fd);

// 进程关系
void pcb_add_child(pcb_t *parent, pcb_t *child);
void pcb_remove_child(pcb_t *parent, pcb_t *child);
void pcb_orphan_children(pcb_t *parent);

// 队列操作
void ready_queue_init(ready_queue_t *queue, uint32_t max_count, 
                      uint32_t time_slice);
void ready_queue_enqueue(ready_queue_t *queue, pcb_t *pcb);
pcb_t* ready_queue_dequeue(ready_queue_t *queue);
pcb_t* ready_queue_peek(const ready_queue_t *queue);
void ready_queue_remove(ready_queue_t *queue, pcb_t *pcb);
bool ready_queue_is_empty(const ready_queue_t *queue);
bool ready_queue_is_full(const ready_queue_t *queue);
void ready_queue_clear(ready_queue_t *queue);

// 等待队列操作
void wait_queue_init(wait_queue_t *queue, uint32_t wait_reason);
void wait_queue_enqueue(wait_queue_t *queue, pcb_t *pcb);
pcb_t* wait_queue_dequeue(wait_queue_t *queue);
void wait_queue_wake_all(wait_queue_t *queue);
void wait_queue_wake_one(wait_queue_t *queue);

// MLFQ管理
void mlfq_init(mlfq_t *mlfq, uint32_t levels, uint32_t boost_interval);
void mlfq_enqueue(mlfq_t *mlfq, pcb_t *pcb, uint8_t priority_level);
pcb_t* mlfq_dequeue(mlfq_t *mlfq);
void mlfq_adjust_priority(mlfq_t *mlfq, pcb_t *pcb, bool used_full_slice);
void mlfq_boost_priorities(mlfq_t *mlfq, uint32_t current_time);

// 进程表管理
void process_table_init(process_table_t *table);
pcb_t* process_table_find(process_table_t *table, uint32_t pid);
pcb_t* process_table_find_by_name(process_table_t *table, const char *name);
pcb_t** process_table_get_all(process_table_t *table, uint32_t *count);
uint32_t process_table_get_count(const process_table_t *table);
void process_table_dump(const process_table_t *table);

// 验证和调试
bool pcb_check_integrity(const pcb_t *pcb);
void pcb_dump(const pcb_t *pcb);
void pcb_dump_brief(const pcb_t *pcb);
void pcb_trace(const pcb_t *pcb);

// 工具函数
uint32_t calculate_time_slice(uint8_t priority, uint32_t base_slice);
uint32_t calculate_vruntime(uint32_t realtime, uint8_t priority, 
                           uint32_t weight);
bool should_preempt(const pcb_t *current, const pcb_t *next);
uint32_t get_scheduler_flags(const pcb_t *pcb);

// 宏定义
#define PCB_MAGIC 0x53504152  // "SPAR" in ASCII

#define PCB_SET_FLAG(pcb, flag) ((pcb)->flags |= (flag))
#define PCB_CLEAR_FLAG(pcb, flag) ((pcb)->flags &= ~(flag))
#define PCB_HAS_FLAG(pcb, flag) (((pcb)->flags & (flag)) != 0)

#define PCB_IS_CPU_BOUND(pcb) PCB_HAS_FLAG(pcb, PROCESS_FLAG_CPU_BOUND)
#define PCB_IS_IO_BOUND(pcb) PCB_HAS_FLAG(pcb, PROCESS_FLAG_IO_BOUND)
#define PCB_IS_INTERACTIVE(pcb) PCB_HAS_FLAG(pcb, PROCESS_FLAG_INTERACTIVE)
#define PCB_IS_REALTIME(pcb) PCB_HAS_FLAG(pcb, PROCESS_FLAG_REALTIME)

#define PCB_LIFETIME(pcb) ((pcb)->time_terminated - (pcb)->time_created)
#define PCB_RESPONSE_TIME(pcb) ((pcb)->time_started - (pcb)->time_created)
#define PCB_TURNAROUND_TIME(pcb) ((pcb)->time_terminated - (pcb)->time_created)

#endif /* _SPARROW_PCB_H */