/**
 * main.c - SparrowOS调度器测试程序
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "scheduler.h"
#include "interrupt.h"

/* 模拟进程函数 */
void process_function_a(void) {
    printf("Process A is running\n");
    for (int i = 0; i < 5; i++) {
        printf("  A: Task %d\n", i);
        scheduler_yield();  // 主动让出CPU
    }
    printf("Process A finished\n");
}

void process_function_b(void) {
    printf("Process B is running\n");
    for (int i = 0; i < 3; i++) {
        printf("  B: Computation %d\n", i);
        // 模拟长时间计算
        for (int j = 0; j < 1000000; j++) {}
        scheduler_yield();
    }
    printf("Process B finished\n");
}

void process_function_c(void) {
    printf("Process C is running\n");
    for (int i = 0; i < 4; i++) {
        printf("  C: IO Operation %d\n", i);
        // 模拟IO等待
        usleep(100000);
        scheduler_yield();
    }
    printf("Process C finished\n");
}

/* 测试FIFO调度器 */
void test_fifo_scheduler(void) {
    printf("\n=== Testing FIFO Scheduler ===\n");
    
    scheduler_config_t config = {
        .type = SCHED_FIFO,
        .time_quantum = 10,
        .enable_preemption = 0,
        .mlfq_levels = 4,
        .boost_interval = 100
    };
    
    scheduler_init(config);
    
    // 创建进程
    pcb_t* p1 = scheduler_create_process("ProcessA", 0);
    pcb_t* p2 = scheduler_create_process("ProcessB", 0);
    pcb_t* p3 = scheduler_create_process("ProcessC", 0);
    
    // 手动模拟调度
    for (int i = 0; i < 15; i++) {
        scheduler_tick();
        if (i % 5 == 0) {
            scheduler_schedule();
        }
    }
    
    // 终止进程
    scheduler_terminate_process(p1->pid);
    scheduler_terminate_process(p2->pid);
    scheduler_terminate_process(p3->pid);
    
    scheduler_print_stats();
}

/* 测试RR调度器 */
void test_rr_scheduler(void) {
    printf("\n=== Testing Round-Robin Scheduler ===\n");
    
    scheduler_config_t config = {
        .type = SCHED_RR,
        .time_quantum = 3,  // 短时间片
        .enable_preemption = 1,
        .mlfq_levels = 4,
        .boost_interval = 100
    };
    
    scheduler_init(config);
    
    pcb_t* p1 = scheduler_create_process("RR-Process1", 0);
    pcb_t* p2 = scheduler_create_process("RR-Process2", 0);
    pcb_t* p3 = scheduler_create_process("RR-Process3", 0);
    
    // 模拟时间片轮转
    for (int tick = 0; tick < 30; tick++) {
        scheduler_tick();
        if (tick % 2 == 0) {
            printf("Tick %d: ", tick);
            pcb_t* current = scheduler_get_current_process();
            if (current) {
                printf("Running PID=%d, TimeUsed=%d/%d\n", 
                       current->pid, 
                       current->time_slice_used,
                       current->time_slice);
            }
        }
    }
    
    scheduler_terminate_process(p1->pid);
    scheduler_terminate_process(p2->pid);
    scheduler_terminate_process(p3->pid);
    
    scheduler_print_stats();
    scheduler_dump_all_processes();
}

/* 测试MLFQ调度器 */
void test_mlfq_scheduler(void) {
    printf("\n=== Testing Multi-Level Feedback Queue ===\n");
    
    scheduler_config_t config = {
        .type = SCHED_MLFQ,
        .time_quantum = 10,
        .enable_preemption = 1,
        .mlfq_levels = 4,
        .boost_interval = 50  // 频繁提升优先级
    };
    
    scheduler_init(config);
    
    // 创建不同优先级的进程
    pcb_t* p1 = scheduler_create_process("MLFQ-High", 0);   // 高优先级
    pcb_t* p2 = scheduler_create_process("MLFQ-Medium", 2); // 中优先级
    pcb_t* p3 = scheduler_create_process("MLFQ-Low", 3);    // 低优先级
    
    printf("\nInitial queue state:\n");
    scheduler_print_ready_queue();
    
    // 模拟运行
    for (int tick = 0; tick < 100; tick++) {
        scheduler_tick();
        
        // 定期显示状态
        if (tick % 20 == 0) {
            printf("\nTick %d:\n", tick);
            scheduler_print_ready_queue();
            
            pcb_t* current = scheduler_get_current_process();
            if (current) {
                printf("Current: PID=%d, Priority=%d, TimeInQueue=%d\n",
                       current->pid, current->priority, current->time_in_queue);
            }
        }
        
        // 模拟进程行为
        if (tick == 30) {
            printf("\nProcess 2 using full time slice (CPU-bound)...\n");
        }
        
        if (tick == 60) {
            printf("\nPriority boost triggered...\n");
        }
    }
    
    scheduler_terminate_process(p1->pid);
    scheduler_terminate_process(p2->pid);
    scheduler_terminate_process(p3->pid);
    
    scheduler_print_stats();
}

/* 集成测试：模拟真实场景 */
void integrated_test(void) {
    printf("\n=== Integrated Scheduler Test ===\n");
    
    // 使用MLFQ调度器
    scheduler_config_t config = {
        .type = SCHED_MLFQ,
        .time_quantum = 10,
        .enable_preemption = 1,
        .mlfq_levels = 4,
        .boost_interval = 100
    };
    
    scheduler_init(config);
    
    // 模拟不同类型的工作负载
    printf("Creating workload mix:\n");
    printf("1. Interactive process (high priority, short bursts)\n");
    printf("2. Batch process (CPU-intensive)\n");
    printf("3. Background process (low priority)\n");
    
    pcb_t* interactive = scheduler_create_process("Interactive", 0);
    pcb_t* batch = scheduler_create_process("Batch", 2);
    pcb_t* background = scheduler_create_process("Background", 3);
    
    // 运行模拟
    for (int tick = 0; tick < 200; tick++) {
        scheduler_tick();
        
        // 模拟交互式进程的行为（频繁让出CPU）
        if (interactive->state == PROCESS_RUNNING && (tick % 5 == 0)) {
            printf("[%03d] Interactive process yields\n", tick);
            scheduler_yield();
        }
        
        // 模拟批处理进程（长时间运行）
        if (batch->state == PROCESS_RUNNING && tick % 25 == 0) {
            printf("[%03d] Batch process checkpoint\n", tick);
        }
        
        // 每50个tick显示一次统计
        if (tick % 50 == 0) {
            printf("\n--- Progress Report at tick %d ---\n", tick);
            scheduler_print_stats();
        }
    }
    
    // 清理
    scheduler_terminate_process(interactive->pid);
    scheduler_terminate_process(batch->pid);
    scheduler_terminate_process(background->pid);
    
    printf("\n=== Final Statistics ===\n");
    scheduler_print_stats();
}

/* 主函数 */
int main(int argc, char* argv[]) {
    printf("SparrowOS Process Scheduler Test Program\n");
    printf("========================================\n");
    
    // 初始化中断系统（模拟）
    interrupt_init();
    timer_init(TIMER_FREQUENCY);
    
    int choice;
    do {
        printf("\nSelect test to run:\n");
        printf("1. FIFO Scheduler Test\n");
        printf("2. Round-Robin Scheduler Test\n");
        printf("3. MLFQ Scheduler Test\n");
        printf("4. Integrated Test\n");
        printf("5. Exit\n");
        printf("Choice: ");
        
        scanf("%d", &choice);
        
        switch (choice) {
            case 1:
                test_fifo_scheduler();
                break;
            case 2:
                test_rr_scheduler();
                break;
            case 3:
                test_mlfq_scheduler();
                break;
            case 4:
                integrated_test();
                break;
            case 5:
                printf("Exiting...\n");
                break;
            default:
                printf("Invalid choice\n");
        }
    } while (choice != 5);
    
    return 0;
}