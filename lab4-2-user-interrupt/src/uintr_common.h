/**
 * uintr_common.h - 用户态中断公共头文件
 * 
 * 包含UINTR相关的系统调用包装和常量定义
 */

#ifndef _UINTR_COMMON_H
#define _UINTR_COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <sys/syscall.h>
#include <errno.h>
#include <time.h>

/* UINTR 相关的系统调用号 */
#ifndef __NR_uintr_register_handler
#define __NR_uintr_register_handler 460
#endif

#ifndef __NR_uintr_unregister_handler
#define __NR_uintr_unregister_handler 461
#endif

#ifndef __NR_uintr_create_fd
#define __NR_uintr_create_fd 462
#endif

#ifndef __NR_uintr_register_sender
#define __NR_uintr_register_sender 463
#endif

#ifndef __NR_uintr_unregister_sender
#define __NR_uintr_unregister_sender 464
#endif

#ifndef __NR_senduipi
#define __NR_senduipi 465
#endif

/* 系统调用包装函数 */
static inline int uintr_register_handler(unsigned int handler, unsigned int flags)
{
    return syscall(__NR_uintr_register_handler, handler, flags);
}

static inline int uintr_unregister_handler(unsigned int handler, unsigned int flags)
{
    return syscall(__NR_uintr_unregister_handler, handler, flags);
}

static inline int uintr_create_fd(void)
{
    return syscall(__NR_uintr_create_fd);
}

static inline int uintr_register_sender(int fd, unsigned int flags)
{
    return syscall(__NR_uintr_register_sender, fd, flags);
}

static inline int uintr_unregister_sender(int uipi_index, unsigned int flags)
{
    return syscall(__NR_uintr_unregister_sender, uipi_index, flags);
}

static inline int senduipi(int uipi_index)
{
    return syscall(__NR_senduipi, uipi_index);
}

/* 性能测量相关 */
typedef struct {
    struct timeval start_time;
    struct timeval end_time;
    long long total_latency;
    int iterations;
} benchmark_t;

static inline void start_timing(benchmark_t *bench)
{
    gettimeofday(&bench->start_time, NULL);
}

static inline void stop_timing(benchmark_t *bench)
{
    gettimeofday(&bench->end_time, NULL);
}

static inline long long get_latency_us(benchmark_t *bench)
{
    long long start_us = bench->start_time.tv_sec * 1000000LL + bench->start_time.tv_usec;
    long long end_us = bench->end_time.tv_sec * 1000000LL + bench->end_time.tv_usec;
    return end_us - start_us;
}

static inline double get_average_latency_us(benchmark_t *bench)
{
    return (double)bench->total_latency / bench->iterations;
}

/* 共享内存相关 */
typedef struct {
    int vector;        // UINTR向量号
    int ready;         // 就绪标志
    char message[256]; // 通信消息
    int response;      // 响应值
} shared_data_t;

#define SHARED_SIZE 4096

#endif /* _UINTR_COMMON_H */