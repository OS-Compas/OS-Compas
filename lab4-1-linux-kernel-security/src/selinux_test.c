/**
 * selinux_test.c - SELinux功能测试程序
 * 用于验证SELinux是否正常工作并测试强制访问控制
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <dirent.h>
#include <time.h>

// SELinux相关头文件
#ifdef WITH_SELINUX
#include <selinux/selinux.h>
#include <selinux/context.h>
#endif

#define TEST_FILE "/tmp/selinux_test_file.txt"
#define TEST_DIR "/tmp/selinux_test_dir"
#define TEST_SYMLINK "/tmp/selinux_test_symlink"
#define AUDIT_LOG "/var/log/audit/audit.log"
#define SYSLOG_AUTH "/var/log/auth.log"

// 颜色输出定义
#define COLOR_RED     "\033[1;31m"
#define COLOR_GREEN   "\033[1;32m"
#define COLOR_YELLOW  "\033[1;33m"
#define COLOR_BLUE    "\033[1;34m"
#define COLOR_RESET   "\033[0m"

void print_header(const char *title) {
    printf("\n%s========================================%s\n", COLOR_BLUE, COLOR_RESET);
    printf("%s%s%s\n", COLOR_BLUE, title, COLOR_RESET);
    printf("%s========================================%s\n", COLOR_BLUE, COLOR_RESET);
}

void print_success(const char *msg) {
    printf("%s[+]%s %s\n", COLOR_GREEN, COLOR_RESET, msg);
}

void print_failure(const char *msg) {
    printf("%s[-]%s %s\n", COLOR_RED, COLOR_RESET, msg);
}

void print_info(const char *msg) {
    printf("%s[*]%s %s\n", COLOR_YELLOW, COLOR_RESET, msg);
}

void check_system_info(void) {
    print_header("System Information");
    
    FILE *fp;
    char buffer[256];
    
    // 内核信息
    fp = popen("uname -a", "r");
    if (fp) {
        if (fgets(buffer, sizeof(buffer), fp)) {
            printf("Kernel: %s", buffer);
        }
        pclose(fp);
    }
    
    // 发行版信息
    fp = popen("cat /etc/os-release | grep PRETTY_NAME", "r");
    if (fp) {
        if (fgets(buffer, sizeof(buffer), fp)) {
            printf("Distribution: %s", buffer + 13); // 跳过 PRETTY_NAME="
        }
        pclose(fp);
    }
}

#ifdef WITH_SELINUX
void check_selinux_library(void) {
    print_header("SELinux Library Check");
    
    if (is_selinux_enabled() == 1) {
        print_success("SELinux library is available and enabled");
        
        int enforce = security_getenforce();
        if (enforce == 1) {
            print_info("SELinux is in ENFORCING mode");
        } else if (enforce == 0) {
            print_info("SELinux is in PERMISSIVE mode");
        } else {
            print_info("SELinux enforce status: Unknown");
        }
        
        // 获取当前进程上下文
        char *context;
        if (getcon(&context) == 0) {
            printf("Current process context: %s\n", context);
            freecon(context);
        }
    } else if (is_selinux_enabled() == 0) {
        print_info("SELinux library is available but disabled");
    } else {
        print_failure("SELinux library check failed (not compiled in kernel?)");
    }
}
#endif

void check_selinux_status(void) {
    print_header("SELinux Status Check");
    
    FILE *fp = popen("sestatus 2>/dev/null || getenforce 2>/dev/null", "r");
    if (fp) {
        char buffer[256];
        int found = 0;
        while (fgets(buffer, sizeof(buffer), fp)) {
            printf("%s", buffer);
            found = 1;
        }
        pclose(fp);
        
        if (!found) {
            print_failure("SELinux not found on this system");
            print_info("This system may be using AppArmor or no MAC system");
        }
    }
    
    // 检查SELinux文件系统
    if (access("/sys/fs/selinux", F_OK) == 0) {
        print_success("SELinux filesystem mounted at /sys/fs/selinux");
    } else {
        print_info("SELinux filesystem not found");
    }
}

void test_file_labeling(void) {
    print_header("File Security Context Test");
    
    // 创建测试文件
    int fd = open(TEST_FILE, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd < 0) {
        perror("Failed to create test file");
        return;
    }
    
    const char *content = "This is a test file for SELinux testing.\n";
    write(fd, content, strlen(content));
    close(fd);
    
    print_success("Created test file");
    printf("File: %s\n", TEST_FILE);
    
    // 尝试查看文件标签
    char command[256];
    snprintf(command, sizeof(command), "ls -lZ %s 2>/dev/null || ls -l %s", TEST_FILE, TEST_FILE);
    system(command);
    
    // 创建测试目录
    if (mkdir(TEST_DIR, 0755) == 0) {
        print_success("Created test directory");
        printf("Directory: %s\n", TEST_DIR);
        
        snprintf(command, sizeof(command), "ls -ldZ %s 2>/dev/null || ls -ld %s", TEST_DIR, TEST_DIR);
        system(command);
    }
    
    // 清理
    unlink(TEST_FILE);
    rmdir(TEST_DIR);
    print_info("Test files cleaned up");
}

void test_permission_checks(void) {
    print_header("Permission Check Simulation");
    
    printf("Testing access to system files:\n");
    
    const char *test_paths[] = {
        "/etc/shadow",
        "/etc/passwd",
        "/root/.bashrc",
        "/var/log/auth.log",
        "/tmp",
        NULL
    };
    
    for (int i = 0; test_paths[i] != NULL; i++) {
        if (access(test_paths[i], R_OK) == 0) {
            printf("  %-20s: %sReadable%s\n", test_paths[i], COLOR_GREEN, COLOR_RESET);
        } else {
            printf("  %-20s: %sNot readable%s (errno: %d)\n", 
                   test_paths[i], COLOR_RED, COLOR_RESET, errno);
        }
    }
}

void check_audit_logs(void) {
    print_header("Security Audit Logs Check");
    
    const char *log_files[] = {
        "/var/log/audit/audit.log",
        "/var/log/auth.log",
        "/var/log/syslog",
        "/var/log/messages",
        NULL
    };
    
    for (int i = 0; log_files[i] != NULL; i++) {
        if (access(log_files[i], R_OK) == 0) {
            printf("Checking: %s\n", log_files[i]);
            
            char command[512];
            // 查找最近的SELinux或安全相关日志
            snprintf(command, sizeof(command),
                    "tail -10 %s | grep -E -i '(selinux|avc|denied|audit|security)' | head -5",
                    log_files[i]);
            
            FILE *fp = popen(command, "r");
            if (fp) {
                char buffer[512];
                int found = 0;
                while (fgets(buffer, sizeof(buffer), fp)) {
                    printf("  %s", buffer);
                    found = 1;
                }
                pclose(fp);
                
                if (!found) {
                    printf("  No recent security events found\n");
                }
            }
            printf("\n");
        } else {
            printf("%s not accessible (try with sudo)\n", log_files[i]);
        }
    }
    
    // 检查审计服务状态
    printf("Audit service status:\n");
    system("systemctl status auditd 2>/dev/null | head -3 || echo 'Audit service not found'");
}

void test_selinux_commands(void) {
    print_header("SELinux Command Tests");
    
    const char *commands[] = {
        "id -Z 2>/dev/null || echo 'id -Z not available'",
        "ps -eZ 2>/dev/null | head -3 || echo 'ps -eZ not available'",
        "sestatus -v 2>/dev/null | head -10 || echo 'sestatus -v not available'",
        "getsebool -a 2>/dev/null | head -5 || echo 'getsebool not available'",
        "semanage boolean -l 2>/dev/null | head -3 || echo 'semanage not available'",
        NULL
    };
    
    for (int i = 0; commands[i] != NULL; i++) {
        printf("Command: %s\n", strtok(strdup(commands[i]), " "));
        system(commands[i]);
        printf("\n");
    }
}

void create_security_test_scenario(void) {
    print_header("Security Test Scenario");
    
    printf("Creating test scenario to trigger security events...\n");
    
    // 1. 尝试访问受保护的文件
    print_info("1. Attempting to read /etc/shadow:");
    system("sudo head -c 100 /etc/shadow 2>&1 | head -1");
    
    // 2. 创建非常规位置的可执行文件
    print_info("2. Creating executable in /tmp:");
    system("echo '#!/bin/sh\necho Test' > /tmp/test_script.sh");
    system("chmod +x /tmp/test_script.sh");
    system("ls -la /tmp/test_script.sh");
    
    // 3. 检查进程权限
    print_info("3. Checking current process capabilities:");
    system("cat /proc/self/status | grep -E '(Cap|NoNewPriv)' | head -5");
    
    // 清理
    system("rm -f /tmp/test_script.sh");
}

void generate_report(void) {
    print_header("Security Assessment Report");
    
    time_t now = time(NULL);
    printf("Report generated: %s", ctime(&now));
    
    printf("\nSummary:\n");
    printf("1. System Information - %sCompleted%s\n", COLOR_GREEN, COLOR_RESET);
    printf("2. SELinux Status Check - %sCompleted%s\n", COLOR_GREEN, COLOR_RESET);
    printf("3. File Context Testing - %sCompleted%s\n", COLOR_GREEN, COLOR_RESET);
    printf("4. Permission Checks - %sCompleted%s\n", COLOR_GREEN, COLOR_RESET);
    printf("5. Audit Log Review - %sCompleted%s\n", COLOR_GREEN, COLOR_RESET);
    printf("6. Security Scenario Test - %sCompleted%s\n", COLOR_GREEN, COLOR_RESET);
    
    printf("\nRecommendations:\n");
    printf("1. If SELinux is disabled, consider enabling it for enhanced security\n");
    printf("2. Review audit logs regularly for security events\n");
    printf("3. Ensure file contexts are properly labeled\n");
    printf("4. Use least privilege principle for all processes\n");
}

int main(int argc, char *argv[]) {
    printf("%s=== SELinux and Security Testing Tool ===%s\n", COLOR_BLUE, COLOR_RESET);
    printf("Version: 1.0\n");
    printf("Author: OS Security Lab\n");
    
    int run_all = 1;
    if (argc > 1) {
        run_all = 0;
    }
    
    if (run_all || (argc > 1 && strcmp(argv[1], "all") == 0)) {
        check_system_info();
        check_selinux_status();
        
        #ifdef WITH_SELINUX
        check_selinux_library();
        #endif
        
        test_file_labeling();
        test_permission_checks();
        check_audit_logs();
        test_selinux_commands();
        create_security_test_scenario();
        generate_report();
    } else if (argc > 1) {
        if (strcmp(argv[1], "status") == 0) {
            check_system_info();
            check_selinux_status();
        } else if (strcmp(argv[1], "test") == 0) {
            test_file_labeling();
            test_permission_checks();
        } else if (strcmp(argv[1], "logs") == 0) {
            check_audit_logs();
        } else if (strcmp(argv[1], "scenario") == 0) {
            create_security_test_scenario();
        } else if (strcmp(argv[1], "report") == 0) {
            generate_report();
        } else {
            printf("Usage: %s [command]\n", argv[0]);
            printf("Commands:\n");
            printf("  all       - Run all tests (default)\n");
            printf("  status    - Check system and SELinux status\n");
            printf("  test      - Run file and permission tests\n");
            printf("  logs      - Check security audit logs\n");
            printf("  scenario  - Create security test scenario\n");
            printf("  report    - Generate summary report\n");
            return 1;
        }
    }
    
    printf("\n%s=== Testing Completed ===%s\n", COLOR_GREEN, COLOR_RESET);
    printf("For detailed SELinux information, run:\n");
    printf("  sudo ausearch -m avc -ts recent  # View recent SELinux denials\n");
    printf("  sudo sealert -a /var/log/audit/audit.log  # Analyze SELinux alerts\n");
    
    return 0;
}