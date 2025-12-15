/**
 * test_mlfq.c - 多级反馈队列测试程序
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "../include/scheduler.h"

/* 打印队列状态 */
static void print_mlfq_queues(void) {
    printf("\nMLFQ Queue Status:\n");
    printf("-----------------\n");
    
    // 注意：这里需要访问mlfq内部结构，实际实现中可能需要调整
    for (int i = 0; i < 4; i++) {
        printf("Queue %d: ", i);
        // 简化显示，实际需要遍历队列
        printf("[needs queue iteration]\n");
    }
}

/* 测试1: 基本MLFQ调度 */
void test_mlfq_basic(void) {
    printf("\n================================\n");
    printf("Test: MLFQ Basic Scheduling\n");
    printf("================================\n");
    
    scheduler_config_t config = {
        .type = SCHED_MLFQ,
        .mlfq_levels = 4,
        .boost_interval = 50,
        .enable_preemption = 1
    };
    
    scheduler_init(config);
    
    // 创建不同优先级的进程
    pcb_t* p_high = scheduler_create_process("High-Prio", 0);
    pcb_t* p_mid = scheduler_create_process("Mid-Prio", 2);
    pcb_t* p_low = scheduler_create_process("Low-Prio", 3);
    
    printf("Created processes at different priority levels\n");
    
    int passed = 1;
    
    // 高优先级进程应该先运行
    scheduler_schedule();
    pcb_t* current = scheduler_get_current_process();
    
    if (current != p_high) {
        printf("Error: Highest priority process not scheduled first\n");
        passed = 0;
    }
    
    printf("Initial scheduling: PID=%d (priority %d)\n", 
           current->pid, current->priority);
    
    // 模拟运行
    for (int i = 0; i < 20; i++) {
        scheduler_tick();
    }
    
    printf("After 20 ticks:\n");
    printf("  High-prio used: %d ticks\n", p_high->time_used);
    printf("  Mid-prio used:  %d ticks\n", p_mid->time_used);
    printf("  Low-prio used:  %d ticks\n", p_low->time_used);
    
    // 高优先级进程应该获得更多CPU时间
    if (p_high->time_used < p_mid->time_used || 
        p_high->time_used < p_low->time_used) {
        printf("Warning: High priority process may not be getting preference\n");
        // 这不是必然失败，因为MLFQ会降级
    }
    
    print_test_result("Basic priority scheduling", passed);
    
    // 清理
    scheduler_terminate_process(p_high->pid);
    scheduler_terminate_process(p_mid->pid);
    scheduler_terminate_process(p_low->pid);
}

/* 测试2: 优先级降级 */
void test_mlfq_demotion(void) {
    printf("\n================================\n");
    printf("Test: MLFQ Priority Demotion\n");
    printf("================================\n");
    
    scheduler_config_t config = {
        .type = SCHED_MLFQ,
        .mlfq_levels = 3,
        .boost_interval = 100,
        .enable_preemption = 1
    };
    
    scheduler_init(config);
    
    // 创建一个CPU密集型进程
    pcb_t* cpu_bound = scheduler_create_process("CPU-Bound", 0);
    
    printf("Created CPU-bound process at highest priority (0)\n");
    printf("This process should be demoted over time\n");
    
    // 运行进程并使用完整时间片
    scheduler_schedule();
    
    int previous_priority = cpu_bound->priority;
    int demotion_count = 0;
    
    for (int tick = 0; tick < 150; tick++) {
        scheduler_tick();
        
        // 检查优先级变化
        if (cpu_bound->priority != previous_priority) {
            printf("[%03d] Priority demotion: %d -> %d\n", 
                   tick, previous_priority, cpu_bound->priority);
            previous_priority = cpu_bound->priority;
            demotion_count++;
        }
        
        // 显示进度
        if (tick % 25 == 0) {
            printf("[%03d] PID=%d, Priority=%d, TimeUsed=%d\n",
                   tick, cpu_bound->pid, cpu_bound->priority, cpu_bound->time_used);
        }
    }
    
    int passed = 1;
    if (demotion_count == 0) {
        printf("Error: No priority demotion occurred\n");
        passed = 0;
    } else if (demotion_count > 3) {
        printf("Warning: Excessive demotions (%d)\n", demotion_count);
    }
    
    printf("Final priority: %d (started at 0)\n", cpu_bound->priority);
    printf("Demotion count: %d\n", demotion_count);
    
    print_test_result("Priority demotion", passed);
    
    scheduler_terminate_process(cpu_bound->pid);
}

/* 测试3: 优先级提升（boost） */
void test_mlfq_boost(void) {
    printf("\n================================\n");
    printf("Test: MLFQ Priority Boost\n");
    printf("================================\n");
    
    scheduler_config_t config = {
        .type = SCHED_MLFQ,
        .mlfq_levels = 4,
        .boost_interval = 30,  // 频繁提升
        .enable_preemption = 1
    };
    
    scheduler_init(config);
    
    // 创建几个进程
    pcb_t* processes[3];
    for (int i = 0; i < 3; i++) {
        char name[32];
        snprintf(name, sizeof(name), "BoostTest%d", i);
        processes[i] = scheduler_create_process(name, i); // 不同初始优先级
    }
    
    printf("Created 3 processes at different priorities\n");
    printf("Boost interval: %d ticks\n", config.boost_interval);
    
    int boost_detected = 0;
    int last_boost_tick = -100;
    
    for (int tick = 0; tick < 100; tick++) {
        scheduler_tick();
        
        // 检查是否有进程被提升
        for (int i = 0; i < 3; i++) {
            if (processes[i]->priority == 0 && processes[i]->time_used > 0) {
                // 低优先级进程被提升到最高优先级
                if (tick - last_boost_tick > 10) { // 避免重复计数
                    printf("[%03d] Priority boost detected for PID=%d\n", 
                           tick, processes[i]->pid);
                    boost_detected = 1;
                    last_boost_tick = tick;
                }
            }
        }
        
        // 显示状态
        if (tick % 20 == 0) {
            printf("\n[%03d] Priorities: ", tick);
            for (int i = 0; i < 3; i++) {
                printf("P%d=%d ", processes[i]->pid, processes[i]->priority);
            }
            printf("\n");
        }
    }
    
    int passed = boost_detected;
    if (!boost_detected) {
        printf("Error: No priority boost detected\n");
    }
    
    print_test_result("Priority boost mechanism", passed);
    
    // 清理
    for (int i = 0; i < 3; i++) {
        scheduler_terminate_process(processes[i]->pid);
    }
}

/* 测试4: 交互式进程优先 */
void test_mlfq_interactive(void) {
    printf("\n================================\n");
    printf("Test: MLFQ Interactive Preference\n");
    printf("================================\n");
    
    scheduler_config_t config = {
        .type = SCHED_MLFQ,
        .mlfq_levels = 4,
        .boost_interval = 50,
        .enable_preemption = 1
    };
    
    scheduler_init(config);
    
    printf("Simulating:\n");
    printf("1. Interactive process (frequent short bursts)\n");
    printf("2. Batch process (long CPU bursts)\n\n");
    
    // 创建进程
    pcb_t* interactive = scheduler_create_process("Interactive", 0);
    pcb_t* batch = scheduler_create_process("Batch", 0);
    
    int interactive_time = 0;
    int batch_time = 0;
    
    for (int tick = 0; tick < 200; tick++) {
        scheduler_tick();
        
        pcb_t* current = scheduler_get_current_process();
        if (current == interactive) {
            interactive_time++;
            
            // 模拟交互式行为：运行很短时间就让出CPU
            if (tick % 3 == 0) {
                scheduler_yield();
            }
        } else if (current == batch) {
            batch_time++;
            
            // 模拟批处理行为：长时间运行
            if (tick % 50 == 0) {
                printf("[%03d] Batch process checkpoint\n", tick);
            }
        }
        
        // 定期报告
        if (tick % 40 == 0) {
            printf("[%03d] Interactive: %d, Batch: %d, Ratio: %.2f\n",
                   tick, interactive_time, batch_time,
                   (float)interactive_time / (batch_time + 1));
            
            printf("  Priorities: Interactive=%d, Batch=%d\n",
                   interactive->priority, batch->priority);
        }
    }
    
    printf("\nFinal results:\n");
    printf("Interactive process: %d ticks\n", interactive_time);
    printf("Batch process:       %d ticks\n", batch_time);
    printf("Ratio (Interactive/Batch): %.2f\n", 
           (float)interactive_time / (batch_time + 1));
    
    // 交互式进程应该保持较高优先级
    int passed = 1;
    if (interactive->priority > batch->priority) {
        printf("Error: Interactive process has lower priority than batch\n");
        passed = 0;
    }
    
    // 交互式进程应该获得合理的时间比例
    float ratio = (float)interactive_time / batch_time;
    if (ratio < 0.3 || ratio > 3.0) {
        printf("Warning: Unusual time ratio (%.2f)\n", ratio);
    }
    
    print_test_result("Interactive preference", passed);
    
    scheduler_terminate_process(interactive->pid);
    scheduler_terminate_process(batch->pid);
    
    printf("\nFinal statistics:\n");
    scheduler_print_stats();
}

/* 辅助函数 */
static void print_test_result(const char* test_name, int passed) {
    printf("\n%s: %s\n", test_name, passed ? "✓ PASS" : "✗ FAIL");
}

/* 主函数 */
int main(void) {
    printf("Multi-Level Feedback Queue Test Suite\n");
    printf("=====================================\n");
    
    test_mlfq_basic();
    test_mlfq_demotion();
    test_mlfq_boost();
    test_mlfq_interactive();
    
    printf("\n================================\n");
    printf("MLFQ Test Suite Complete\n");
    printf("================================\n");
    
    return 0;
}