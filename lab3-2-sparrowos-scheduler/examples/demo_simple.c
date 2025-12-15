/**
 * demo_simple.c - 简单调度演示程序
 * 展示基本调度器功能
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "../include/scheduler.h"

/* 演示1: FIFO调度器 */
void demo_fifo(void) {
    printf("\n=== FIFO Scheduler Demo ===\n");
    
    scheduler_config_t config = {
        .type = SCHED_FIFO,
        .enable_preemption = 0
    };
    
    scheduler_init(config);
    
    // 创建5个进程
    printf("Creating 5 processes...\n");
    pcb_t* processes[5];
    for (int i = 0; i < 5; i++) {
        char name[32];
        snprintf(name, sizeof(name), "Task-%c", 'A' + i);
        processes[i] = scheduler_create_process(name, 0);
    }
    
    printf("\nFIFO调度过程:\n");
    printf("---------------\n");
    
    // 模拟调度和执行
    int tick = 0;
    while (1) {
        // 检查是否所有进程都已完成
        int all_done = 1;
        for (int i = 0; i < 5; i++) {
            if (processes[i]->state != PROCESS_TERMINATED) {
                all_done = 0;
                break;
            }
        }
        if (all_done) break;
        
        // 执行调度
        scheduler_schedule();
        pcb_t* current = scheduler_get_current_process();
        
        if (current) {
            printf("[%03d] Running: %s (PID: %d)\n", 
                   tick, current->name, current->pid);
            
            // 模拟进程执行
            for (int i = 0; i < 5; i++) {
                scheduler_tick();
                tick++;
            }
            
            // 终止当前进程
            printf("    -> Completing %s\n", current->name);
            scheduler_terminate_process(current->pid);
        } else {
            printf("[%03d] No processes to run\n", tick);
            break;
        }
    }
    
    printf("\nFIFO调度完成!\n");
    scheduler_print_stats();
}

/* 演示2: Round-Robin调度器 */
void demo_round_robin(void) {
    printf("\n=== Round-Robin Scheduler Demo ===\n");
    
    scheduler_config_t config = {
        .type = SCHED_RR,
        .time_quantum = 4,
        .enable_preemption = 1
    };
    
    scheduler_init(config);
    
    printf("创建3个进程，时间片=%d\n", config.time_quantum);
    
    pcb_t* processes[3];
    for (int i = 0; i < 3; i++) {
        char name[32];
        snprintf(name, sizeof(name), "RR-%c", 'X' + i);
        processes[i] = scheduler_create_process(name, 0);
    }
    
    printf("\nRR调度过程 (显示时间片轮转):\n");
    printf("---------------------------\n");
    
    // 运行足够长时间观察轮转
    for (int tick = 0; tick < 60; tick++) {
        scheduler_tick();
        
        // 每4个tick显示状态
        if (tick % 4 == 0) {
            pcb_t* current = scheduler_get_current_process();
            if (current) {
                printf("[%02d] %s running (slice: %d/%d)\n",
                       tick, current->name,
                       current->time_slice_used,
                       current->time_slice);
                
                // 时间片用完时显示
                if (current->time_slice_used >= current->time_slice) {
                    printf("    *** Time slice expired! ***\n");
                }
            }
        }
        
        // 在特定时间点终止进程，展示动态变化
        if (tick == 20) {
            printf("\n[%02d] Terminating %s\n", tick, processes[0]->name);
            scheduler_terminate_process(processes[0]->pid);
        }
        
        if (tick == 40) {
            printf("\n[%02d] Adding new process 'Late-Comer'\n", tick);
            pcb_t* new_proc = scheduler_create_process("Late-Comer", 0);
            (void)new_proc; // 避免未使用变量警告
        }
    }
    
    // 终止剩余进程
    for (int i = 1; i < 3; i++) {
        if (processes[i]->state != PROCESS_TERMINATED) {
            scheduler_terminate_process(processes[i]->pid);
        }
    }
    
    printf("\nRR调度演示完成!\n");
    scheduler_print_stats();
}

/* 演示3: 进程状态转换 */
void demo_state_transitions(void) {
    printf("\n=== Process State Transitions Demo ===\n");
    
    scheduler_config_t config = {
        .type = SCHED_FIFO,
        .enable_preemption = 0
    };
    
    scheduler_init(config);
    
    printf("演示进程状态转换:\n");
    printf("NEW -> READY -> RUNNING -> TERMINATED\n\n");
    
    pcb_t* proc = scheduler_create_process("DemoProc", 0);
    
    printf("1. 创建后状态: ");
    switch (proc->state) {
        case PROCESS_NEW: printf("NEW\n"); break;
        case PROCESS_READY: printf("READY (已加入就绪队列)\n"); break;
        default: printf("%d\n", proc->state);
    }
    
    // 调度进程
    scheduler_schedule();
    
    printf("2. 调度后状态: ");
    switch (proc->state) {
        case PROCESS_RUNNING: printf("RUNNING\n"); break;
        default: printf("%d\n", proc->state);
    }
    
    // 模拟执行
    printf("3. 执行10个时间单位...\n");
    for (int i = 0; i < 10; i++) {
        scheduler_tick();
        printf("   Tick %d: Used time = %d\n", i, proc->time_used);
    }
    
    // 终止进程
    printf("4. 终止进程...\n");
    scheduler_terminate_process(proc->pid);
    
    printf("5. 终止后状态: ");
    switch (proc->state) {
        case PROCESS_TERMINATED: printf("TERMINATED\n"); break;
        default: printf("%d\n", proc->state);
    }
    
    printf("\n状态转换演示完成!\n");
}

/* 演示4: 优先级演示 */
void demo_priority(void) {
    printf("\n=== Priority Scheduling Demo ===\n");
    
    scheduler_config_t config = {
        .type = SCHED_FIFO,  // 使用FIFO展示优先级
        .enable_preemption = 0
    };
    
    scheduler_init(config);
    
    printf("创建不同优先级的进程 (0=最高, 3=最低):\n\n");
    
    // 创建不同优先级的进程
    struct {
        char* name;
        int priority;
    } proc_specs[] = {
        {"High-Prio", 0},
        {"Medium-Prio", 2},
        {"Low-Prio", 3},
        {"Urgent", 0},  // 另一个高优先级
    };
    
    pcb_t* processes[4];
    
    for (int i = 0; i < 4; i++) {
        processes[i] = scheduler_create_process(proc_specs[i].name, 
                                               proc_specs[i].priority);
        printf("%d. %-12s Priority: %d\n", 
               i+1, proc_specs[i].name, proc_specs[i].priority);
    }
    
    printf("\n执行顺序 (高优先级先执行):\n");
    printf("--------------------------\n");
    
    int completed = 0;
    int tick = 0;
    
    while (completed < 4) {
        scheduler_schedule();
        pcb_t* current = scheduler_get_current_process();
        
        if (current) {
            printf("[%02d] Running: %s (Priority: %d)\n",
                   tick, current->name, current->priority);
            
            // 模拟执行
            for (int i = 0; i < 3; i++) {
                scheduler_tick();
                tick++;
            }
            
            scheduler_terminate_process(current->pid);
            completed++;
        }
    }
    
    printf("\n优先级调度演示完成!\n");
}

/* 主函数 */
int main(void) {
    printf("SparrowOS调度器演示程序\n");
    printf("=======================\n");
    
    int choice;
    
    do {
        printf("\n选择演示项目:\n");
        printf("1. FIFO调度器演示\n");
        printf("2. 时间片轮转(RR)演示\n");
        printf("3. 进程状态转换演示\n");
        printf("4. 优先级调度演示\n");
        printf("5. 退出\n");
        printf("请输入选择 (1-5): ");
        
        if (scanf("%d", &choice) != 1) {
            printf("输入错误!\n");
            while (getchar() != '\n'); // 清空输入缓冲区
            continue;
        }
        
        switch (choice) {
            case 1:
                demo_fifo();
                break;
            case 2:
                demo_round_robin();
                break;
            case 3:
                demo_state_transitions();
                break;
            case 4:
                demo_priority();
                break;
            case 5:
                printf("退出演示程序。\n");
                break;
            default:
                printf("无效选择，请重试。\n");
        }
        
        printf("\n按Enter键继续...");
        while (getchar() != '\n'); // 清空输入缓冲区
        getchar(); // 等待用户按Enter
        
    } while (choice != 5);
    
    return 0;
}