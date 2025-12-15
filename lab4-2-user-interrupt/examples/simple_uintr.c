```c
/**
 * simple_uintr.c - 最简UINTR示例
 * 
 * 展示UINTR最基本的使用方法
 * 这个示例去除了所有复杂功能，只展示核心流程
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/syscall.h>
#include <stdint.h>

/* 简化的UINTR系统调用定义 */
#ifndef __NR_uintr_register_handler
#define __NR_uintr_register_handler 460
#endif

#ifndef __NR_uintr_create_fd
#define __NR_uintr_create_fd 462
#endif

#ifndef __NR_uintr_register_sender
#define __NR_uintr_register_sender 463
#endif

#ifndef __NR_senduipi
#define __NR_senduipi 465
#endif

/* 系统调用包装函数 */
static inline int uintr_register_handler(unsigned long handler, unsigned int flags)
{
    return syscall(__NR_uintr_register_handler, handler, flags);
}

static inline int uintr_create_fd(void)
{
    return syscall(__NR_uintr_create_fd);
}

static inline int uintr_register_sender(int fd, unsigned int flags)
{
    return syscall(__NR_uintr_register_sender, fd, flags);
}

static inline int senduipi(int uipi_index)
{
    return syscall(__NR_senduipi, uipi_index);
}

/* 共享状态 */
static volatile int interrupt_received = 0;
static int uipi_index = -1;
static int uipi_fd = -1;

/* 最简单的中断处理函数 */
static void __attribute__((interrupt)) simple_handler(void)
{
    interrupt_received = 1;
    printf("[Handler] ✓ User interrupt received!\n");
}

/* 清理函数 */
static void cleanup(void)
{
    printf("[Cleanup] Cleaning up resources\n");
    
    if (uipi_fd >= 0) {
        close(uipi_fd);
    }
    
    // 注意：实际应用中应该注销handler，这里简化处理
}

/* 发送者进程 */
static void run_sender(void)
{
    printf("[Sender] Starting sender process (PID: %d)\n", getpid());
    
    // 等待接收者准备就绪
    sleep(1);
    
    if (uipi_index < 0) {
        printf("[Sender] Error: No UINTR vector available\n");
        return;
    }
    
    printf("[Sender] Sending UINTR...\n");
    
    // 发送用户态中断
    int ret = senduipi(uipi_index);
    if (ret < 0) {
        perror("[Sender] senduipi failed");
    } else {
        printf("[Sender] ✓ UINTR sent successfully\n");
    }
}

/* 接收者进程 */
static void run_receiver(void)
{
    printf("[Receiver] Starting receiver process (PID: %d)\n", getpid());
    
    // 1. 注册中断处理函数
    printf("[Receiver] Registering UINTR handler...\n");
    int ret = uintr_register_handler((unsigned long)simple_handler, 0);
    if (ret < 0) {
        perror("[Receiver] uintr_register_handler failed");
        printf("[Receiver] Note: UINTR可能未启用，需要:\n");
        printf("  1. Linux 5.19+ 内核\n");
        printf("  2. CPU支持UINTR (Intel Sapphire Rapids+)\n");
        printf("  3. 或者在QEMU中运行\n");
        return;
    }
    printf("[Receiver] ✓ Handler registered\n");
    
    // 2. 创建UINTR文件描述符
    printf("[Receiver] Creating UINTR file descriptor...\n");
    uipi_fd = uintr_create_fd();
    if (uipi_fd < 0) {
        perror("[Receiver] uintr_create_fd failed");
        return;
    }
    printf("[Receiver] ✓ UINTR FD created: %d\n", uipi_fd);
    
    // 3. 注册发送者（自己）
    printf("[Receiver] Registering sender...\n");
    uipi_index = uintr_register_sender(uipi_fd, 0);
    if (uipi_index < 0) {
        perror("[Receiver] uintr_register_sender failed");
        return;
    }
    printf("[Receiver] ✓ Sender registered with vector: %d\n", uipi_index);
    
    // 4. 准备接收中断
    printf("[Receiver] Ready to receive interrupts\n");
    printf("[Receiver] Waiting for interrupt...\n");
    
    // 简单轮询等待
    int timeout = 100; // 10秒超时
    while (!interrupt_received && timeout > 0) {
        usleep(100000); // 100ms
        timeout--;
        
        if (timeout % 10 == 0) {
            printf("[Receiver] Still waiting... (%d seconds left)\n", timeout/10);
        }
    }
    
    if (interrupt_received) {
        printf("[Receiver] ✓ Successfully received and processed UINTR\n");
    } else {
        printf("[Receiver] ✗ Timeout waiting for interrupt\n");
    }
    
    cleanup();
}

/* 主函数 */
int main(void)
{
    printf("=== Simple UINTR Example ===\n");
    printf("Demonstrates basic UINTR functionality\n\n");
    
    // 创建管道用于进程间通信
    int pipefd[2];
    if (pipe(pipefd) < 0) {
        perror("pipe failed");
        return 1;
    }
    
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork failed");
        return 1;
    }
    
    if (pid == 0) {
        // 子进程 - 发送者
        close(pipefd[0]); // 关闭读端
        
        // 等待父进程信号
        char ready_signal;
        read(pipefd[1], &ready_signal, 1);
        
        run_sender();
        
        // 通知父进程完成
        write(pipefd[1], "D", 1);
        close(pipefd[1]);
        exit(0);
    } else {
        // 父进程 - 接收者
        close(pipefd[1]); // 关闭写端
        
        // 启动接收者
        run_receiver();
        
        // 通知子进程开始
        write(pipefd[0], "G", 1);
        
        // 等待子进程完成
        char done_signal;
        read(pipefd[0], &done_signal, 1);
        
        close(pipefd[0]);
        wait(NULL);
    }
    
    printf("\n=== Example Completed ===\n");
    printf("Key takeaways:\n");
    printf("  1. UINTR allows user-space interrupt handling\n");
    printf("  2. No kernel context switch required\n");
    printf("  3. Much lower latency than traditional IPC\n");
    printf("  4. Requires hardware/emulator support\n");
    
    return 0;
}

/* 编译说明：
 * 1. 确保系统支持UINTR (Linux 5.19+, Intel Sapphire Rapids+)
 * 2. 编译命令: gcc -o simple_uintr simple_uintr.c
 * 3. 运行需要root权限或适当的能力: sudo ./simple_uintr
 * 
 * 如果硬件不支持，可以使用QEMU模拟:
 * qemu-system-x86_64 -cpu host -enable-kvm -smp 2 -m 2G \
 *   -device uintr-ipi-device -device uintr-receiver-device \
 *   -kernel /boot/vmlinuz -initrd /boot/initrd.img \
 *   -append "root=/dev/sda1 console=ttyS0"
 */
编译和运行说明：

bash
# 编译最简示例
cd examples
gcc -o simple_uintr simple_uintr.c

# 运行（可能需要root权限）
sudo ./simple_uintr

# 如果提示UINTR不支持，可以尝试在QEMU中运行
# 首先准备一个支持UINTR的QEMU环境
qemu-system-x86_64 \
  -cpu host \
  -enable-kvm \
  -smp 2 \
  -m 2G \
  -device uintr-ipi-device \
  -device uintr-receiver-device \
  -hda ubuntu.img \
  -nographic