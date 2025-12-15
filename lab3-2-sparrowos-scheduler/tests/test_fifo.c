/**
 * test_fifo.c - FIFO调度器测试程序
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "../include/scheduler.h"

/* 测试辅助函数 */
static void print_test_header(const char* test_name) {
    printf("\n================================\n");
    printf("Test: %s\n", test_name);
    printf("================================\n");
}

static void print_test_result(const char* test_name, int passed) {
    printf("%s: %s\n", test_name, passed ? "✓ PASS" : "✗ FAIL");
}

/* 测试1: 基本FIFO调度 */
void test_fifo_basic(void) {
    print_test_header("FIFO Basic Scheduling");
    
    scheduler_config_t config = {
        .type = SCHED_FIFO,
        .enable_preemption = 0
    };
    
    scheduler_init(config);
    
    // 创建3个进程
    pcb_t* p1 = scheduler_create_process("Test1", 0);
    pcb_t* p2 = scheduler_create_process("Test2", 0);
    pcb_t* p3 = scheduler_create_process("Test3", 0);
    
    int passed = 1;
    
    // 检查进程创建
    if (!p1 || !p2 || !p3) {
        printf("Error: Process creation failed\n");
        passed = 0;
    }
    
    // 执行调度
    scheduler_schedule();
    pcb_t* current = scheduler_get_current_process();
    
    // 第一个创建的进程应该先运行
    if (current != p1) {
        printf("Error: First process not scheduled (got PID=%d, expected PID=%d)\n", 
               current ? current->pid : -1, p1->pid);
        passed = 0;
    }
    
    // 终止进程
    scheduler_terminate_process(p1->pid);
    scheduler_schedule();
    current = scheduler_get_current_process();
    
    // 第二个进程应该运行
    if (current != p2) {
        printf("Error: Second process not scheduled after first termination\n");
        passed = 0;
    }
    
    print_test_result("Basic FIFO ordering", passed);
    
    // 清理
    scheduler_terminate_process(p2->pid);
    scheduler_terminate_process(p3->pid);
}

/* 测试2: FIFO进程状态转换 */
void test_fifo_state_transitions(void) {
    print_test_header("FIFO State Transitions");
    
    scheduler_config_t config = {
        .type = SCHED_FIFO,
        .enable_preemption = 0
    };
    
    scheduler_init(config);
    
    pcb_t* p1 = scheduler_create_process("StateTest", 0);
    int passed = 1;
    
    // 检查初始状态
    if (p1->state != PROCESS_READY) {
        printf("Error: New process should be in READY state\n");
        passed = 0;
    }
    
    // 调度进程
    scheduler_schedule();
    if (p1->state != PROCESS_RUNNING) {
        printf("Error: Scheduled process should be in RUNNING state\n");
        passed = 0;
    }
    
    // 终止进程
    scheduler_terminate_process(p1->pid);
    if (p1->state != PROCESS_TERMINATED) {
        printf("Error: Terminated process should be in TERMINATED state\n");
        passed = 0;
    }
    
    print_test_result("State transitions", passed);
}

/* 测试3: FIFO空队列处理 */
void test_fifo_empty_queue(void) {
    print_test_header("FIFO Empty Queue Handling");
    
    scheduler_config_t config = {
        .type = SCHED_FIFO,
        .enable_preemption = 0
    };
    
    scheduler_init(config);
    
    int passed = 1;
    
    // 空队列调度
    scheduler_schedule();
    pcb_t* current = scheduler_get_current_process();
    
    if (current != NULL) {
        printf("Error: Empty queue should return NULL\n");
        passed = 0;
    }
    
    // 创建并终止所有进程
    pcb_t* p = scheduler_create_process("Temp", 0);
    scheduler_terminate_process(p->pid);
    
    scheduler_schedule();
    current = scheduler_get_current_process();
    
    if (current != NULL) {
        printf("Error: All terminated should return NULL\n");
        passed = 0;
    }
    
    print_test_result("Empty queue handling", passed);
}

/* 测试4: FIFO统计信息 */
void test_fifo_statistics(void) {
    print_test_header("FIFO Statistics Collection");
    
    scheduler_config_t config = {
        .type = SCHED_FIFO,
        .enable_preemption = 0
    };
    
    scheduler_init(config);
    
    // 创建并运行一些进程
    for (int i = 0; i < 5; i++) {
        char name[32];
        snprintf(name, sizeof(name), "StatTest%d", i);
        pcb_t* p = scheduler_create_process(name, 0);
        
        scheduler_schedule();
        
        // 模拟一些运行时间
        for (int j = 0; j < 10; j++) {
            scheduler_tick();
        }
        
        scheduler_terminate_process(p->pid);
    }
    
    scheduler_stats_t stats = scheduler_get_stats();
    int passed = 1;
    
    if (stats.processes_completed != 5) {
        printf("Error: Expected 5 processes completed, got %d\n", 
               stats.processes_completed);
        passed = 0;
    }
    
    if (stats.context_switches < 5) {
        printf("Error: Too few context switches: %d\n", stats.context_switches);
        passed = 0;
    }
    
    print_test_result("Statistics collection", passed);
    
    printf("\nCollected statistics:\n");
    scheduler_print_stats();
}

/* 主测试函数 */
int main(void) {
    printf("FIFO Scheduler Test Suite\n");
    printf("=========================\n");
    
    test_fifo_basic();
    test_fifo_state_transitions();
    test_fifo_empty_queue();
    test_fifo_statistics();
    
    printf("\n================================\n");
    printf("FIFO Test Suite Complete\n");
    printf("================================\n");
    
    return 0;
}