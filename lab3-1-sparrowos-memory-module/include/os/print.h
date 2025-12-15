#ifndef _OS_PRINT_H
#define _OS_PRINT_H

#include <os/types.h>

// 打印级别
typedef enum {
    LOG_DEBUG = 0,
    LOG_INFO,
    LOG_WARNING,
    LOG_ERROR,
    LOG_CRITICAL
} log_level_t;

// 初始化串口
void print_init(void);

// 基础打印函数
void printk(const char *fmt, ...);
void printk_level(log_level_t level, const char *fmt, ...);

// 格式化打印
int snprintf(char *buf, size_t size, const char *fmt, ...);
int vsnprintf(char *buf, size_t size, const char *fmt, va_list args);

// 字符和字符串输出
void putchar(char c);
void puts(const char *s);

// 十六进制和十进制输出
void print_hex(uint64_t value, int width);
void print_dec(uint64_t value);
void print_bin(uint64_t value, int width);

// 调试宏
#ifdef DEBUG
#define DEBUG_PRINT(fmt, ...) printk_level(LOG_DEBUG, fmt, ##__VA_ARGS__)
#else
#define DEBUG_PRINT(fmt, ...) do {} while (0)
#endif

#define INFO_PRINT(fmt, ...)  printk_level(LOG_INFO, fmt, ##__VA_ARGS__)
#define WARN_PRINT(fmt, ...)  printk_level(LOG_WARNING, fmt, ##__VA_ARGS__)
#define ERROR_PRINT(fmt, ...) printk_level(LOG_ERROR, fmt, ##__VA_ARGS__)

#endif // _OS_PRINT_H