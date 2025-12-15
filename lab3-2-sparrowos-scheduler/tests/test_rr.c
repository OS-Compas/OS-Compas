/**
 * test_rr.c - 时间片轮转调度器测试程序
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "../include/scheduler.h"

/* 测试辅助函数 */
static void print_rr_status(int tick, pcb_t* current) {
    if (current) {
        printf("[%03d] Running: PID=%d, TimeSlice=%d/%d\n", 
               tick, current->pid, 
               current->time_slice_used, current->time_slice);
    } else {
        printf("[%03d] No process running\n", tick);
    }
}

/* 测试1: 基本时间片轮转 */
void test_rr_basic(void) {
    printf("\n================================\n");
    printf("Test: RR Basic Time Slicing\n");
    printf("================================\n");
    
    scheduler_config_t config = {
        .type = SCHED_RR,
        .time_quantum = 5,
        .enable_preemption = 1
    };
    
    scheduler_init(config);
    
    // 创建3个进程
    pcb_t* processes[3];
    for (int i = 0; i < 3; i++) {
        char name[32];
        snprintf(name, sizeof(name), "RR-Proc%d", i);
        processes[i] = scheduler_create_process(name, 0);
    }
    
    printf("Created 3 processes with time quantum = %d\n", config.time_quantum);
    
    int passed = 1;
    int expected_order[] = {0, 1, 2, 0, 1, 2}; // 预期的轮转顺序
    
    // 模拟时间片轮转
    for (int tick = 0; tick < 30; tick++) {
        scheduler_tick();
        
        // 每5个tick显示一次状态
        if (tick % 5 == 0) {
            print_rr_status(tick, scheduler_get_current_process());
        }
        
        // 检查时间片超时
        pcb_t* current = scheduler_get_current_process();
        if (current && current->time_slice_used >= current->time_slice) {
            printf("  Time slice expired for PID=%d\n", current->pid);
        }
    }
    
    // 检查所有进程都获得了CPU时间
    for (int i = 0; i < 3; i++) {
        if (processes[i]->time_used == 0) {
            printf("Error: Process %d got no CPU time\n", i);
            passed = 0;
        }
    }
    
    printf("Result: %s\n", passed ? "✓ PASS" : "✗ FAIL");
    
    // 清理
    for (int i = 0; i < 3; i++) {
        scheduler_terminate_process(processes[i]->pid);
    }
}

/* 测试2: 抢占式调度 */
void test_rr_preemption(void) {
    printf("\n================================\n");
    printf("Test: RR Preemptive Scheduling\n");
    printf("================================\n");
    
    scheduler_config_t config = {
        .type = SCHED_RR,
        .time_quantum = 10,
        .enable_preemption = 1
    };
    
    scheduler_init(config);
    
    // 创建进程
    pcb_t* p1 = scheduler_create_process("Preempt-Test1", 0);
    pcb_t* p2 = scheduler_create_process("Preempt-Test2", 0);
    
    printf("Testing preemption with time quantum = %d\n", config.time_quantum);
    
    // 开始第一个进程
    scheduler_schedule();
    printf("Started PID=%d\n", p1->pid);
    
    // 运行部分时间片
    for (int i = 0; i < 5; i++) {
        scheduler_tick();
    }
    
    // 创建第二个进程并立即调度
    printf("Created new process PID=%d\n", p2->pid);
    
    // 继续运行第一个进程直到时间片用完
    for (int i = 5; i < 15; i++) {
        scheduler_tick();
        
        if (i == 10) {
            printf("Time slice should expire here\n");
        }
    }
    
    pcb_t* current = scheduler_get_current_process();
    
    int passed = 1;
    if (current != p2) {
        printf("Error: Preemption failed. Current PID=%d, expected PID=%d\n",
               current ? current->pid : -1, p2->pid);
        passed = 0;
    } else {
        printf("Preemption successful: PID=%d preempted PID=%d\n",
               p2->pid, p1->pid);
    }
    
    printf("Result: %s\n", passed ? "✓ PASS" : "✗ FAIL");
    
    // 清理
    scheduler_terminate_process(p1->pid);
    scheduler_terminate_process(p2->pid);
}

/* 测试3: 不同时间片长度 */
void test_rr_varying_timeslices(void) {
    printf("\n================================\n");
    printf("Test: RR Varying Time Slices\n");
    printf("================================\n");
    
    int test_cases[] = {1, 3, 5, 10};
    int passed = 1;
    
    for (int tc = 0; tc < 4; tc++) {
        int quantum = test_cases[tc];
        
        printf("\nTest case: Time quantum = %d\n", quantum);
        
        scheduler_config_t config = {
            .type = SCHED_RR,
            .time_quantum = quantum,
            .enable_preemption = 1
        };
        
        scheduler_init(config);
        
        // 创建两个进程
        pcb_t* p1 = scheduler_create_process("TS-Test1", 0);
        pcb_t* p2 = scheduler_create_process("TS-Test2", 0);
        
        // 运行足够长时间来观察多次上下文切换
        int context_switches_before = scheduler_get_stats().context_switches;
        
        for (int tick = 0; tick < quantum * 10; tick++) {
            scheduler_tick();
        }
        
        int context_switches_after = scheduler_get_stats().context_switches;
        int switches_during_test = context_switches_after - context_switches_before;
        
        printf("  Context switches during test: %d\n", switches_during_test);
        
        // 验证时间片起作用
        if (switches_during_test < 5) {
            printf("  Warning: Fewer context switches than expected\n");
        }
        
        // 检查每个进程的运行时间比例
        float ratio = (float)p1->time_used / p2->time_used;
        printf("  Time ratio P1/P2: %.2f\n", ratio);
        
        if (ratio < 0.5 || ratio > 2.0) {
            printf("  Error: Unbalanced CPU time distribution\n");
            passed = 0;
        }
        
        scheduler_terminate_process(p1->pid);
        scheduler_terminate_process(p2->pid);
    }
    
    printf("\nOverall result: %s\n", passed ? "✓ PASS" : "✗ FAIL");
}

/* 测试4: 混合工作负载 */
void test_rr_mixed_workload(void) {
    printf("\n================================\n");
    printf("Test: RR Mixed Workload\n");
    printf("================================\n");
    
    scheduler_config_t config = {
        .type = SCHED_RR,
        .time_quantum = 4,
        .enable_preemption = 1
    };
    
    scheduler_init(config);
    
    printf("Simulating mixed workload:\n");
    printf("- CPU-bound process (long bursts)\n");
    printf("- IO-bound process (frequent yields)\n");
    printf("- Interactive process (short bursts)\n");
    
    // 创建不同类型的工作负载
    pcb_t* cpu_bound = scheduler_create_process("CPU-Bound", 0);
    pcb_t* io_bound = scheduler_create_process("IO-Bound", 0);
    pcb_t* interactive = scheduler_create_process("Interactive", 0);
    
    // 模拟不同行为
    int cpu_time = 0;
    int io_time = 0;
    int interactive_time = 0;
    
    for (int tick = 0; tick < 100; tick++) {
        scheduler_tick();
        
        pcb_t* current = scheduler_get_current_process();
        if (!current) continue;
        
        // 统计各进程运行时间
        if (current == cpu_bound) cpu_time++;
        else if (current == io_bound) io_time++;
        else if (current == interactive) interactive_time++;
        
        // 模拟IO-bound进程频繁让出CPU
        if (current == io_bound && (tick % 2 == 0)) {
            scheduler_yield();
        }
        
        // 模拟交互式进程短时间运行
        if (current == interactive && (tick % 3 == 0)) {
            scheduler_yield();
        }
        
        // 定期报告
        if (tick % 20 == 0) {
            printf("[%03d] CPU: %d, IO: %d, Interactive: %d\n",
                   tick, cpu_time, io_time, interactive_time);
        }
    }
    
    printf("\nFinal time distribution:\n");
    printf("CPU-Bound:      %d ticks\n", cpu_time);
    printf("IO-Bound:       %d ticks\n", io_time);
    printf("Interactive:    %d ticks\n", interactive_time);
    
    float total = cpu_time + io_time + interactive_time;
    printf("\nPercentages:\n");
    printf("CPU-Bound:      %.1f%%\n", (cpu_time / total) * 100);
    printf("IO-Bound:       %.1f%%\n", (io_time / total) * 100);
    printf("Interactive:    %.1f%%\n", (interactive_time / total) * 100);
    
    // 验证公平性
    int passed = 1;
    float max_ratio = (float)cpu_time / interactive_time;
    if (max_ratio > 3.0 || max_ratio < 0.33) {
        printf("Error: Unfair scheduling detected (ratio: %.2f)\n", max_ratio);
        passed = 0;
    }
    
    printf("Result: %s\n", passed ? "✓ PASS" : "✗ FAIL");
    
    // 清理
    scheduler_terminate_process(cpu_bound->pid);
    scheduler_terminate_process(io_bound->pid);
    scheduler_terminate_process(interactive->pid);
    
    printf("\nFinal statistics:\n");
    scheduler_print_stats();
}

/* 主函数 */
int main(void) {
    printf("Round-Robin Scheduler Test Suite\n");
    printf("================================\n");
    
    test_rr_basic();
    test_rr_preemption();
    test_rr_varying_timeslices();
    test_rr_mixed_workload();
    
    printf("\n================================\n");
    printf("RR Test Suite Complete\n");
    printf("================================\n");
    
    return 0;
}