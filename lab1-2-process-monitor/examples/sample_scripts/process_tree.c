/**
 * 进程树测试程序
 * 用于测试进程监视器的进程树显示功能
 * 
 * 编译: gcc -o process_tree process_tree.c
 * 运行: ./process_tree [深度] [分支因子] [运行时间(秒)]
 * 
 * 实验1.2：进程资源监视器 - 进程树测试程序
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <signal.h>
#include <sys/wait.h>
#include <errno.h>

// 全局变量
volatile int running = 1;
volatile int process_count = 0;

// 进程节点信息结构
typedef struct {
    pid_t pid;
    pid_t ppid;
    int depth;
    int child_num;
    char name[32];
} process_info_t;

// 信号处理函数
void handle_signal(int sig) {
    printf("\n进程 %d 接收到信号 %d，正在停止...\n", getpid(), sig);
    running = 0;
}

// 生成随机的进程名称
void generate_process_name(char* buffer, int depth, int child_num) {
    const char* types[] = {
        "worker", "task", "service", "daemon", "thread",
        "processor", "handler", "manager", "controller", "executor"
    };
    
    const char* domains[] = {
        "data", "network", "io", "compute", "memory",
        "storage", "cache", "queue", "log", "monitor"
    };
    
    int type_idx = (depth * child_num) % 10;
    int domain_idx = (depth + child_num) % 10;
    
    snprintf(buffer, 32, "%s-%s-%d", types[type_idx], domains[domain_idx], getpid() % 1000);
}

// 显示进程信息
void show_process_info(int depth, int child_num, const char* action) {
    char process_name[32];
    generate_process_name(process_name, depth, child_num);
    
    printf("进程 %s (PID: %d, PPID: %d) - 深度: %d, 子进程号: %d - %s\n",
           process_name, getpid(), getppid(), depth, child_num, action);
}

// 显示进程树结构
void show_process_tree_structure(pid_t root_pid, int depth, int child_num) {
    // 生成缩进字符串
    char indent[64] = {0};
    for (int i = 0; i < depth && i < 15; i++) {
        strcat(indent, "  ");
    }
    
    char process_name[32];
    generate_process_name(process_name, depth, child_num);
    
    if (depth == 0) {
        printf("┌─ 根进程: %s (PID: %d)\n", process_name, root_pid);
    } else {
        printf("%s├─ %s (PID: %d, PPID: %d)\n", indent, process_name, getpid(), getppid());
    }
}

// 工作进程函数
void worker_process(int depth, int max_depth, int branch_factor, int sleep_time, int child_num) {
    // 设置信号处理
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    
    // 显示进程信息
    show_process_info(depth, child_num, "启动");
    show_process_tree_structure(getpid(), depth, child_num);
    
    // 更新进程计数
    process_count++;
    
    // 如果未达到最大深度，创建子进程
    if (depth < max_depth) {
        pid_t child_pids[branch_factor];
        int active_children = 0;
        
        // 创建子进程
        for (int i = 0; i < branch_factor; i++) {
            pid_t pid = fork();
            
            if (pid == 0) {
                // 子进程
                worker_process(depth + 1, max_depth, branch_factor, sleep_time, i);
                exit(0);
            } else if (pid > 0) {
                // 父进程记录子进程PID
                child_pids[active_children++] = pid;
            } else {
                perror("fork失败");
            }
        }
        
        // 父进程等待所有子进程结束或超时
        printf("进程 %d 等待 %d 个子进程...\n", getpid(), active_children);
        
        int remaining_children = active_children;
        time_t start_time = time(NULL);
        
        while (running && remaining_children > 0) {
            // 非阻塞等待子进程
            pid_t exited_pid = waitpid(-1, NULL, WNOHANG);
            
            if (exited_pid > 0) {
                printf("进程 %d: 子进程 %d 已结束\n", getpid(), exited_pid);
                remaining_children--;
            } else if (exited_pid == -1 && errno != ECHILD) {
                perror("waitpid错误");
                break;
            }
            
            // 检查是否超时
            if (sleep_time > 0 && (time(NULL) - start_time) >= sleep_time) {
                printf("进程 %d: 运行时间到达，准备退出\n", getpid());
                break;
            }
            
            // 短暂睡眠避免CPU占用过高
            sleep(1);
        }
        
        // 如果还有子进程在运行，发送终止信号
        if (remaining_children > 0) {
            printf("进程 %d: 向 %d 个子进程发送终止信号\n", getpid(), remaining_children);
            for (int i = 0; i < active_children; i++) {
                kill(child_pids[i], SIGTERM);
            }
            
            // 等待子进程结束
            sleep(2);
        }
    } else {
        // 叶子进程 - 执行一些工作
        printf("进程 %d (叶子进程) 开始工作...\n", getpid());
        
        time_t start_time = time(NULL);
        int work_cycles = 0;
        
        while (running) {
            // 模拟一些工作
            for (int i = 0; i < 1000000; i++) {
                // 一些简单的计算
                volatile int x = i * i;
                (void)x; // 防止编译器警告
            }
            
            work_cycles++;
            
            // 定期报告状态
            if (work_cycles % 10 == 0) {
                printf("进程 %d: 已完成 %d 个工作周期\n", getpid(), work_cycles);
            }
            
            // 检查是否应该退出
            if (sleep_time > 0 && (time(NULL) - start_time) >= sleep_time) {
                printf("进程 %d: 工作完成，准备退出\n", getpid());
                break;
            }
            
            // 检查信号
            if (!running) {
                break;
            }
        }
    }
    
    show_process_info(depth, child_num, "退出");
}

// 创建特定拓扑的进程树
void create_special_topology(int topology_type, int sleep_time) {
    printf("创建特殊拓扑类型: %d\n", topology_type);
    
    switch (topology_type) {
        case 1: {
            // 线性链式拓扑
            printf("拓扑: 线性链式\n");
            pid_t pid = getpid();
            
            for (int i = 1; i <= 4; i++) {
                if (fork() == 0) {
                    // 子进程
                    char process_name[32];
                    snprintf(process_name, 32, "chain-%d", i);
                    printf("├─ %s (PID: %d, PPID: %d)\n", process_name, getpid(), getppid());
                    
                    if (i < 4) {
                        // 继续创建下一个链节点
                        continue;
                    } else {
                        // 最后一个节点
                        printf("│  └─ (末端)\n");
                    }
                    
                    sleep(sleep_time);
                    exit(0);
                } else {
                    // 父进程等待
                    wait(NULL);
                    break;
                }
            }
            break;
        }
        
        case 2: {
            // 星型拓扑
            printf("拓扑: 星型\n");
            pid_t root_pid = getpid();
            printf("┌─ 中心节点 (PID: %d)\n", root_pid);
            
            for (int i = 0; i < 5; i++) {
                if (fork() == 0) {
                    // 子节点
                    char process_name[32];
                    snprintf(process_name, 32, "star-%d", i);
                    printf("├─ %s (PID: %d)\n", process_name, getpid());
                    sleep(sleep_time);
                    exit(0);
                }
            }
            
            // 等待所有子进程
            for (int i = 0; i < 5; i++) {
                wait(NULL);
            }
            break;
        }
        
        case 3: {
            // 二叉树拓扑
            printf("拓扑: 二叉树\n");
            
            struct node {
                int depth;
                int max_depth;
            };
            
            // 使用递归函数创建二叉树
            void create_binary_tree(int depth, int max_depth) {
                if (depth >= max_depth) return;
                
                char indent[32] = {0};
                for (int i = 0; i < depth; i++) strcat(indent, "  ");
                
                printf("%s├─ 节点-深度%d (PID: %d)\n", indent, depth, getpid());
                
                // 创建左子树
                if (fork() == 0) {
                    create_binary_tree(depth + 1, max_depth);
                    exit(0);
                } else {
                    wait(NULL);
                }
                
                // 创建右子树
                if (fork() == 0) {
                    create_binary_tree(depth + 1, max_depth);
                    exit(0);
                } else {
                    wait(NULL);
                }
            }
            
            create_binary_tree(0, 3);
            break;
        }
        
        default:
            printf("未知拓扑类型: %d\n", topology_type);
            break;
    }
}

// 显示使用说明
void show_usage(const char* program_name) {
    printf("进程树测试程序\n");
    printf("用法: %s [深度] [分支因子] [运行时间(秒)]\n", program_name);
    printf("参数:\n");
    printf("  深度:        进程树的最大深度（默认: 3）\n");
    printf("  分支因子:    每个节点的子进程数（默认: 2）\n");
    printf("  运行时间:    进程运行时间（默认: 30秒）\n");
    printf("\n特殊模式:\n");
    printf("  %s linear     # 线性链式拓扑\n", program_name);
    printf("  %s star       # 星型拓扑\n", program_name);
    printf("  %s binary     # 二叉树拓扑\n", program_name);
    printf("\n示例:\n");
    printf("  %s                    # 深度3，分支2，运行30秒\n", program_name);
    printf("  %s 4 3 60            # 深度4，分支3，运行60秒\n", program_name);
    printf("  %s linear 20          # 线性拓扑，运行20秒\n", program_name);
    printf("\n说明:\n");
    printf("  该程序创建复杂的进程树结构，用于测试进程监视器的进程树显示功能。\n");
    printf("  程序会显示进程树的层次结构，并在指定时间后自动退出。\n");
}

int main(int argc, char* argv[]) {
    int depth = 3;           // 默认深度
    int branch_factor = 2;   // 默认分支因子
    int sleep_time = 30;     // 默认运行时间
    int special_topology = 0; // 特殊拓扑模式
    
    // 解析命令行参数
    if (argc > 1) {
        if (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0) {
            show_usage(argv[0]);
            return 0;
        } else if (strcmp(argv[1], "linear") == 0) {
            special_topology = 1;
        } else if (strcmp(argv[1], "star") == 0) {
            special_topology = 2;
        } else if (strcmp(argv[1], "binary") == 0) {
            special_topology = 3;
        } else {
            depth = atoi(argv[1]);
        }
    }
    
    if (argc > 2 && special_topology == 0) {
        branch_factor = atoi(argv[2]);
    } else if (argc > 2 && special_topology > 0) {
        sleep_time = atoi(argv[2]);
    }
    
    if (argc > 3 && special_topology == 0) {
        sleep_time = atoi(argv[3]);
    }
    
    // 验证参数
    if (depth <= 0) depth = 3;
    if (branch_factor <= 0) branch_factor = 2;
    if (sleep_time <= 0) sleep_time = 30;
    
    // 显示启动信息
    printf("==========================================\n");
    printf("进程树测试程序启动\n");
    printf("根进程PID: %d\n", getpid());
    
    if (special_topology > 0) {
        const char* topology_names[] = {"", "线性链式", "星型", "二叉树"};
        printf("拓扑类型: %s\n", topology_names[special_topology]);
    } else {
        printf("进程树深度: %d\n", depth);
        printf("分支因子: %d\n", branch_factor);
        printf("预计进程数: ~%d\n", 
               (int)((1 - pow(branch_factor, depth + 1)) / (1 - branch_factor)));
    }
    
    printf("运行时间: %d 秒\n", sleep_time);
    printf("开始时间: %s", ctime(&(time_t){time(NULL)}));
    printf("==========================================\n");
    
    // 设置信号处理
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    
    if (special_topology > 0) {
        // 特殊拓扑模式
        create_special_topology(special_topology, sleep_time);
    } else {
        // 普通进程树模式
        printf("开始创建进程树...\n");
        worker_process(0, depth, branch_factor, sleep_time, 0);
    }
    
    printf("==========================================\n");
    printf("进程树测试程序结束\n");
    printf("根进程PID: %d\n", getpid());
    printf("总进程数: %d\n", process_count);
    printf("结束时间: %s", ctime(&(time_t){time(NULL)}));
    printf("==========================================\n");
    
    return 0;
}