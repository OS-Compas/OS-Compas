/**
 * demo_advanced.c - 高级调度演示程序
 * 展示MLFQ和复杂调度场景
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include "../include/scheduler.h"

/* 演示1: 多级反馈队列(MLFQ)完整演示 */
void demo_mlfq_full(void) {
    printf("\n=== Multi-Level Feedback Queue (MLFQ) Full Demo ===\n");
    
    scheduler_config_t config = {
        .type = SCHED_MLFQ,
        .mlfq_levels = 4,
        .boost_interval = 40,
        .enable_preemption = 1
    };
    
    scheduler_init(config);
    
    printf("MLFQ配置:\n");
    printf("  - 队列级数: %d\n", config.mlfq_levels);
    printf("  - 优先级提升间隔: %d ticks\n", config.boost_interval);
    printf("  - 时间片长度随优先级降低而增加\n\n");
    
    printf("创建4种不同类型的工作负载:\n");
    printf("1. 交互式进程 (频繁短时间运行)\n");
    printf("2. CPU密集型进程 (长时间运行)\n");
    printf("3. IO密集型进程 (经常让出CPU)\n");
    printf("4. 混合型进程 (中等长度运行)\n");
    
    // 创建进程
    pcb_t* interactive = scheduler_create_process("Interactive", 0);
    pcb_t* cpu_intensive = scheduler_create_process("CPU-Intensive", 0);
    pcb_t* io_bound = scheduler_create_process("IO-Bound", 0);
    pcb_t* mixed = scheduler_create_process("Mixed", 0);
    
    // 初始化统计
    int stats[4][3] = {0}; // [进程][运行时间, 优先级变化次数, 时间片数]
    int last_priority[4] = {0};
    
    printf("\n开始模拟 (运行200个时间单位):\n");
    printf("==============================\n");
    
    for (int tick = 0; tick < 200; tick++) {
        scheduler_tick();
        
        // 获取当前运行进程并更新统计
        pcb_t* current = scheduler_get_current_process();
        if (current) {
            int proc_index = -1;
            if (current == interactive) proc_index = 0;
            else if (current == cpu_intensive) proc_index = 1;
            else if (current == io_bound) proc_index = 2;
            else if (current == mixed) proc_index = 3;
            
            if (proc_index >= 0) {
                stats[proc_index][0]++; // 增加运行时间
                
                // 检查优先级变化
                if (current->priority != last_priority[proc_index]) {
                    stats[proc_index][1]++;
                    last_priority[proc_index] = current->priority;
                }
                
                // 检查时间片边界
                if (current->time_slice_used == 1) {
                    stats[proc_index][2]++;
                }
            }
            
            // 模拟不同类型进程的行为
            if (current == interactive && (tick % 3 == 0)) {
                // 交互式进程经常让出CPU
                scheduler_yield();
            }
            else if (current == io_bound && (tick % 4 == 0)) {
                // IO密集型进程经常阻塞/让出
                scheduler_yield();
            }
            else if (current == cpu_intensive) {
                // CPU密集型进程很少让出
                if (tick % 20 == 0) {
                    scheduler_yield(); // 偶尔让出
                }
            }
        }
        
        // 定期显示状态
        if (tick % 40 == 0) {
            printf("\n[%03d] 系统状态报告:\n", tick);
            printf("进程            运行时间  当前优先级  优先级变化\n");
            printf("------------------------------------------------\n");
            
            pcb_t* procs[] = {interactive, cpu_intensive, io_bound, mixed};
            char* names[] = {"Interactive", "CPU-Intensive", "IO-Bound", "Mixed"};
            
            for (int i = 0; i < 4; i++) {
                printf("%-15s %9d %11d %12d\n",
                       names[i],
                       stats[i][0],
                       procs[i]->priority,
                       stats[i][1]);
            }
            
            // 显示当前队列状态
            printf("\n就绪队列概要:\n");
            // 注意：这里需要访问调度器内部状态
            // 简化显示
            printf("  (需要访问调度器内部状态)\n");
        }
        
        // 模拟进程创建和终止
        if (tick == 80) {
            printf("\n[%03d] 新进程 'Late-Starter' 加入系统\n", tick);
            pcb_t* late = scheduler_create_process("Late-Starter", 2);
            (void)late; // 避免未使用变量警告
        }
        
        if (tick == 120) {
            printf("\n[%03d] 进程 'Mixed' 完成任务并退出\n", tick);
            scheduler_terminate_process(mixed->pid);
        }
    }
    
    printf("\n最终统计:\n");
    printf("===========\n");
    
    printf("进程            总运行时间  优先级变化  使用的时间片\n");
    printf("----------------------------------------------------\n");
    
    char* names[] = {"Interactive", "CPU-Intensive", "IO-Bound", "Mixed"};
    for (int i = 0; i < 4; i++) {
        printf("%-15s %11d %11d %14d\n",
               names[i],
               stats[i][0],
               stats[i][1],
               stats[i][2]);
    }
    
    // MLFQ特性分析
    printf("\nMLFQ特性验证:\n");
    printf("1. 交互式进程应保持较高优先级: ");
    if (interactive->priority <= 1) {
        printf("✓ (优先级: %d)\n", interactive->priority);
    } else {
        printf("✗ (优先级: %d)\n", interactive->priority);
    }
    
    printf("2. CPU密集型进程应被降级: ");
    if (cpu_intensive->priority > 1) {
        printf("✓ (从0降到%d)\n", cpu_intensive->priority);
    } else {
        printf("✗ (优先级: %d)\n", cpu_intensive->priority);
    }
    
    printf("3. IO密集型进程应获得较好响应: ");
    float io_ratio = (float)stats[2][0] / 200.0;
    if (io_ratio > 0.15) { // 至少15%的CPU时间
        printf("✓ (获得%.1f%% CPU时间)\n", io_ratio * 100);
    } else {
        printf("✗ (仅获得%.1f%% CPU时间)\n", io_ratio * 100);
    }
    
    // 清理
    scheduler_terminate_process(interactive->pid);
    scheduler_terminate_process(cpu_intensive->pid);
    scheduler_terminate_process(io_bound->pid);
    
    printf("\nMLFQ演示完成!\n");
    scheduler_print_stats();
}

/* 演示2: 饥饿问题与解决方案 */
void demo_starvation_solution(void) {
    printf("\n=== Starvation Problem and Solution Demo ===\n");
    
    printf("问题: 低优先级进程可能永远得不到CPU时间\n");
    printf("解决方案: 优先级提升(boost)机制\n\n");
    
    // 演示没有boost的情况
    printf("第一阶段: 没有优先级提升\n");
    printf("------------------------\n");
    
    scheduler_config_t no_boost_config = {
        .type = SCHED_MLFQ,
        .mlfq_levels = 4,
        .boost_interval = 0,  // 无boost
        .enable_preemption = 1
    };
    
    scheduler_init(no_boost_config);
    
    // 创建高优先级和低优先级进程
    pcb_t* high_prio = scheduler_create_process("High-Priority", 0);
    pcb_t* low_prio = scheduler_create_process("Low-Priority", 3);
    
    printf("创建进程:\n");
    printf("  - High-Priority: 优先级 0 (最高)\n");
    printf("  - Low-Priority:  优先级 3 (最低)\n\n");
    
    int low_prio_ran = 0;
    
    for (int tick = 0; tick < 50; tick++) {
        scheduler_tick();
        
        pcb_t* current = scheduler_get_current_process();
        if (current == low_prio) {
            low_prio_ran = 1;
        }
        
        if (tick % 10 == 0) {
            printf("[%02d] Current: %s, Low运行次数: %d\n",
                   tick, 
                   current ? current->name : "None",
                   low_prio->time_used);
        }
    }
    
    printf("\n结果: 低优先级进程%s获得CPU时间\n",
           low_prio_ran ? "成功" : "未能");
    
    if (!low_prio_ran) {
        printf("-> 出现饥饿问题!\n");
    }
    
    // 清理
    scheduler_terminate_process(high_prio->pid);
    scheduler_terminate_process(low_prio->pid);
    
    // 演示有boost的情况
    printf("\n\n第二阶段: 启用优先级提升\n");
    printf("--------------------------\n");
    
    scheduler_config_t with_boost_config = {
        .type = SCHED_MLFQ,
        .mlfq_levels = 4,
        .boost_interval = 25,  // 每25个tick提升一次
        .enable_preemption = 1
    };
    
    scheduler_init(with_boost_config);
    
    high_prio = scheduler_create_process("High-Priority", 0);
    low_prio = scheduler_create_process("Low-Priority", 3);
    
    printf("相同配置，但启用boost (间隔=%d ticks)\n", with_boost_config.boost_interval);
    
    int boost_count = 0;
    low_prio_ran = 0;
    
    for (int tick = 0; tick < 80; tick++) {
        scheduler_tick();
        
        pcb_t* current = scheduler_get_current_process();
        if (current == low_prio) {
            low_prio_ran = 1;
        }
        
        // 检测boost事件
        if (low_prio->priority == 0 && tick > 10) {
            // 低优先级进程被提升到最高优先级
            if (boost_count == 0 || tick - boost_count * 25 > 20) {
                printf("[%02d] *** BOOST! Low-Priority提升到优先级0 ***\n", tick);
                boost_count++;
            }
        }
        
        if (tick % 15 == 0) {
            printf("[%02d] High运行: %d, Low运行: %d, Low优先级: %d\n",
                   tick,
                   high_prio->time_used,
                   low_prio->time_used,
                   low_prio->priority);
        }
    }
    
    printf("\n结果:\n");
    printf("  - 低优先级进程获得CPU时间: %s\n", low_prio_ran ? "是" : "否");
    printf("  - 发生的boost次数: %d\n", boost_count);
    printf("  - Low最终优先级: %d\n", low_prio->priority);
    printf("  - High总运行时间: %d\n", high_prio->time_used);
    printf("  - Low总运行时间: %d\n", low_prio->time_used);
    
    if (low_prio_ran && low_prio->time_used > 0) {
        printf("\n✓ 饥饿问题得到解决!\n");
    } else {
        printf("\n✗ 饥饿问题仍然存在\n");
    }
    
    // 清理
    scheduler_terminate_process(high_prio->pid);
    scheduler_terminate_process(low_prio->pid);
}

/* 演示3: 实时系统调度模拟 */
void demo_real_time_simulation(void) {
    printf("\n=== Real-Time System Simulation ===\n");
    
    printf("模拟实时系统中的调度需求:\n");
    printf("- 周期性任务 (定期执行)\n");
    printf("- 截止时间要求\n");
    printf("- 优先级抢占\n\n");
    
    scheduler_config_t config = {
        .type = SCHED_RR,  // 使用RR作为基础
        .time_quantum = 2,  // 很短的时间片
        .enable_preemption = 1
    };
    
    scheduler_init(config);
    
    printf("创建实时任务:\n");
    printf("1. 控制任务 (周期: 10 ticks, 运行时间: 2 ticks)\n");
    printf("2. 数据采集任务 (周期: 15 ticks, 运行时间: 3 ticks)\n");
    printf("3. 监控任务 (周期: 20 ticks, 运行时间: 4 ticks)\n");
    printf("4. 后台任务 (非实时, 低优先级)\n");
    
    // 创建任务
    pcb_t* control_task = scheduler_create_process("Control", 0);
    pcb_t* data_task = scheduler_create_process("Data-Acq", 1);
    pcb_t* monitor_task = scheduler_create_process("Monitor", 2);
    pcb_t* background = scheduler_create_process("Background", 3);
    
    // 任务参数
    int control_period = 10;
    int data_period = 15;
    int monitor_period = 20;
    
    int control_last_run = -control_period;
    int data_last_run = -data_period;
    int monitor_last_run = -monitor_period;
    
    int control_deadlines_missed = 0;
    int data_deadlines_missed = 0;
    int monitor_deadlines_missed = 0;
    
    printf("\n开始实时调度模拟 (100 ticks):\n");
    printf("===============================\n");
    
    for (int tick = 0; tick < 100; tick++) {
        scheduler_tick();
        
        // 检查周期性任务是否该运行
        if (tick - control_last_run >= control_period) {
            printf("[%03d] Control任务就绪 (周期: %d)\n", tick, control_period);
            control_last_run = tick;
            // 在实际系统中，这里会设置就绪标志
        }
        
        if (tick - data_last_run >= data_period) {
            printf("[%03d] Data采集任务就绪\n", tick);
            data_last_run = tick;
        }
        
        if (tick - monitor_last_run >= monitor_period) {
            printf("[%03d] Monitor任务就绪\n", tick);
            monitor_last_run = tick;
        }
        
        // 检查截止时间错过
        if (control_task->state != PROCESS_RUNNING && 
            tick - control_last_run > 2) { // 允许2个tick的延迟
            control_deadlines_missed++;
        }
        
        // 显示当前运行任务
        if (tick % 10 == 0) {
            pcb_t* current = scheduler_get_current_process();
            printf("\n[%03d] 状态检查:\n", tick);
            printf("  当前运行: %s\n", current ? current->name : "None");
            printf("  Control运行时间: %d\n", control_task->time_used);
            printf("  Data运行时间: %d\n", data_task->time_used);
            printf("  Monitor运行时间: %d\n", monitor_task->time_used);
            printf("  Background运行时间: %d\n", background->time_used);
        }
        
        // 模拟任务完成
        if (control_task->state == PROCESS_RUNNING && 
            control_task->time_slice_used >= 2) {
            printf("[%03d] Control任务完成本次执行\n", tick);
            scheduler_yield();
        }
    }
    
    printf("\n实时调度模拟结果:\n");
    printf("==================\n");
    
    printf("任务             总运行时间  占总时间比例  截止时间错过\n");
    printf("------------------------------------------------------\n");
    
    int total_time = control_task->time_used + data_task->time_used + 
                     monitor_task->time_used + background->time_used;
    
    printf("%-12s %12d %13.1f%% %12d\n",
           "Control",
           control_task->time_used,
           (float)control_task->time_used / total_time * 100,
           control_deadlines_missed);
    
    printf("%-12s %12d %13.1f%% %12d\n",
           "Data-Acq",
           data_task->time_used,
           (float)data_task->time_used / total_time * 100,
           data_deadlines_missed);
    
    printf("%-12s %12d %13.1f%% %12d\n",
           "Monitor",
           monitor_task->time_used,
           (float)monitor_task->time_used / total_time * 100,
           monitor_deadlines_missed);
    
    printf("%-12s %12d %13.1f%% %12s\n",
           "Background",
           background->time_used,
           (float)background->time_used / total_time * 100,
           "N/A");
    
    // 实时性评估
    printf("\n实时性评估:\n");
    if (control_deadlines_missed == 0) {
        printf("✓ Control任务满足实时要求\n");
    } else {
        printf("✗ Control任务错过 %d 个截止时间\n", control_deadlines_missed);
    }
    
    printf("高优先级任务总CPU占比: %.1f%%\n",
           (float)(control_task->time_used + data_task->time_used) / total_time * 100);
    
    // 清理
    scheduler_terminate_process(control_task->pid);
    scheduler_terminate_process(data_task->pid);
    scheduler_terminate_process(monitor_task->pid);
    scheduler_terminate_process(background->pid);
}

/* 演示4: 调度算法比较 */
void demo_scheduler_comparison(void) {
    printf("\n=== Scheduler Algorithm Comparison ===\n");
    
    printf("比较三种调度算法在相同工作负载下的表现:\n");
    printf("1. FIFO (先来先服务)\n");
    printf("2. Round-Robin (时间片轮转)\n");
    printf("3. MLFQ (多级反馈队列)\n\n");
    
    // 相同的工作负载
    struct workload {
        char* name;
        int priority;
        int behavior; // 0=CPU密集型, 1=IO密集型, 2=交互式
    } workloads[] = {
        {"CPU-Task1", 0, 0},
        {"CPU-Task2", 0, 0},
        {"IO-Task1", 0, 1},
        {"IO-Task2", 0, 1},
        {"Interactive1", 0, 2},
        {"Interactive2", 0, 2},
    };
    
    const int num_workloads = 6;
    const char* scheduler_names[] = {"FIFO", "Round-Robin", "MLFQ"};
    
    for (int sched_type = 0; sched_type < 3; sched_type++) {
        printf("\n=== %s 调度算法 ===\n", scheduler_names[sched_type]);
        
        scheduler_config_t config;
        config.enable_preemption = 1;
        
        switch (sched_type) {
            case 0: // FIFO
                config.type = SCHED_FIFO;
                break;
            case 1: // RR
                config.type = SCHED_RR;
                config.time_quantum = 5;
                break;
            case 2: // MLFQ
                config.type = SCHED_MLFQ;
                config.mlfq_levels = 4;
                config.boost_interval = 30;
                break;
        }
        
        scheduler_init(config);
        
        // 创建工作负载
        pcb_t* processes[num_workloads];
        for (int i = 0; i < num_workloads; i++) {
            processes[i] = scheduler_create_process(workloads[i].name, 
                                                   workloads[i].priority);
        }
        
        // 运行模拟
        for (int tick = 0; tick < 150; tick++) {
            scheduler_tick();
            
            // 模拟不同类型进程的行为
            pcb_t* current = scheduler_get_current_process();
            if (current) {
                // 查找当前进程的类型
                int behavior = -1;
                for (int i = 0; i < num_workloads; i++) {
                    if (current == processes[i]) {
                        behavior = workloads[i].behavior;
                        break;
                    }
                }
                
                // 根据行为类型模拟
                if (behavior == 1 && (tick % 3 == 0)) { // IO密集型
                    scheduler_yield();
                } else if (behavior == 2 && (tick % 4 == 0)) { // 交互式
                    scheduler_yield();
                }
            }
        }
        
        // 收集统计信息
        printf("\n工作负载完成情况:\n");
        printf("任务名称        类型          总运行时间  最终优先级\n");
        printf("---------------------------------------------------\n");
        
        int total_runtime = 0;
        int interactive_time = 0;
        int io_time = 0;
        int cpu_time = 0;
        
        for (int i = 0; i < num_workloads; i++) {
            int runtime = processes[i]->time_used;
            total_runtime += runtime;
            
            // 分类统计
            if (workloads[i].behavior == 0) cpu_time += runtime;
            else if (workloads[i].behavior == 1) io_time += runtime;
            else if (workloads[i].behavior == 2) interactive_time += runtime;
            
            char* type_str = "Unknown";
            if (workloads[i].behavior == 0) type_str = "CPU-bound";
            else if (workloads[i].behavior == 1) type_str = "IO-bound";
            else if (workloads[i].behavior == 2) type_str = "Interactive";
            
            printf("%-12s %-12s %12d %12d\n",
                   workloads[i].name,
                   type_str,
                   runtime,
                   processes[i]->priority);
        }
        
        printf("\n性能指标:\n");
        printf("总CPU利用率: %d ticks\n", total_runtime);
        printf("CPU密集型任务占比: %.1f%%\n", (float)cpu_time / total_runtime * 100);
        printf("IO密集型任务占比: %.1f%%\n", (float)io_time / total_runtime * 100);
        printf("交互式任务占比:   %.1f%%\n", (float)interactive_time / total_runtime * 100);
        
        scheduler_stats_t stats = scheduler_get_stats();
        printf("上下文切换次数: %d\n", stats.context_switches);
        printf("平均周转时间:   %d ticks\n", stats.avg_turnaround_time);
        
        // 清理
        for (int i = 0; i < num_workloads; i++) {
            scheduler_terminate_process(processes[i]->pid);
        }
    }
    
    printf("\n比较总结:\n");
    printf("=========\n");
    printf("FIFO: 简单，但可能导致响应时间差\n");
    printf("RR:   公平性好，适合分时系统\n");
    printf("MLFQ: 结合了响应时间和吞吐量的优点\n");
}

/* 主函数 */
int main(void) {
    printf("SparrowOS高级调度演示程序\n");
    printf("==========================\n");
    
    srand(time(NULL)); // 初始化随机种子
    
    int choice;
    
    do {
        printf("\n选择高级演示项目:\n");
        printf("1. MLFQ完整演示\n");
        printf("2. 饥饿问题与解决方案\n");
        printf("3. 实时系统调度模拟\n");
        printf("4. 调度算法比较\n");
        printf("5. 退出\n");
        printf("请输入选择 (1-5): ");
        
        if (scanf("%d", &choice) != 1) {
            printf("输入错误!\n");
            while (getchar() != '\n');
            continue;
        }
        
        switch (choice) {
            case 1:
                demo_mlfq_full();
                break;
            case 2:
                demo_starvation_solution();
                break;
            case 3:
                demo_real_time_simulation();
                break;
            case 4:
                demo_scheduler_comparison();
                break;
            case 5:
                printf("退出高级演示程序。\n");
                break;
            default:
                printf("无效选择，请重试。\n");
        }
        
        if (choice != 5) {
            printf("\n按Enter键继续...");
            while (getchar() != '\n');
            getchar();
        }
        
    } while (choice != 5);
    
    return 0;
}