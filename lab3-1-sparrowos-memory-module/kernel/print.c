/**
 * print.c - SparrowOS 串口打印实现
 * 
 * 实现基于UART 16550的串口输出
 */

#include <os/print.h>
#include <os/types.h>
#include <riscv/riscv.h>
#include <stdarg.h>

// UART 16550寄存器偏移
#define UART0_BASE 0x10000000

#define UART_RBR 0     // 接收缓冲寄存器
#define UART_THR 0     // 发送保持寄存器
#define UART_IER 1     // 中断使能寄存器
#define UART_IIR 2     // 中断标识寄存器
#define UART_FCR 2     // FIFO控制寄存器
#define UART_LCR 3     // 线路控制寄存器
#define UART_MCR 4     // Modem控制寄存器
#define UART_LSR 5     // 线路状态寄存器
#define UART_MSR 6     // Modem状态寄存器
#define UART_SCR 7     // Scratch寄存器

#define UART_LSR_DR   0x01  // 数据就绪
#define UART_LSR_EMPTY 0x40 // 发送保持寄存器空

// 简单内存映射IO访问
static inline uint8_t mmio_read8(uint64_t addr)
{
    return *(volatile uint8_t *)addr;
}

static inline void mmio_write8(uint64_t addr, uint8_t value)
{
    *(volatile uint8_t *)addr = value;
}

// 当前日志级别
static log_level_t current_log_level = LOG_INFO;

/**
 * 初始化UART
 */
void print_init(void)
{
    // 禁用中断
    mmio_write8(UART0_BASE + UART_IER, 0x00);
    
    // 设置波特率除数（115200波特率）
    mmio_write8(UART0_BASE + UART_LCR, 0x80); // 启用DLAB
    mmio_write8(UART0_BASE + 0, 0x03);        // 除数低位
    mmio_write8(UART0_BASE + 1, 0x00);        // 除数高位
    
    // 8N1格式，禁用DLAB
    mmio_write8(UART0_BASE + UART_LCR, 0x03);
    
    // 启用FIFO，清除它们，8字节阈值
    mmio_write8(UART0_BASE + UART_FCR, 0xC7);
    
    // 启用中断
    mmio_write8(UART0_BASE + UART_IER, 0x01);
    
    // 测试UART
    putchar('\n');
}

/**
 * 检查UART是否就绪发送
 */
static int uart_tx_ready(void)
{
    return mmio_read8(UART0_BASE + UART_LSR) & UART_LSR_EMPTY;
}

/**
 * 等待并发送一个字符
 */
void putchar(char c)
{
    // 等待发送缓冲区空
    while (!uart_tx_ready())
        ;
    
    mmio_write8(UART0_BASE + UART_THR, c);
    
    // 如果发送换行，需要发送回车
    if (c == '\n') {
        while (!uart_tx_ready())
            ;
        mmio_write8(UART0_BASE + UART_THR, '\r');
    }
}

/**
 * 输出字符串
 */
void puts(const char *s)
{
    while (*s) {
        putchar(*s++);
    }
}

/**
 * 简单printf实现
 */
void printk(const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    
    char buffer[256];
    int len = vsnprintf(buffer, sizeof(buffer), fmt, args);
    
    for (int i = 0; i < len; i++) {
        putchar(buffer[i]);
    }
    
    va_end(args);
}

/**
 * 带级别的打印
 */
void printk_level(log_level_t level, const char *fmt, ...)
{
    if (level < current_log_level) {
        return;
    }
    
    // 级别前缀
    const char *level_str;
    switch (level) {
        case LOG_DEBUG:    level_str = "[DEBUG] "; break;
        case LOG_INFO:     level_str = "[INFO]  "; break;
        case LOG_WARNING:  level_str = "[WARN]  "; break;
        case LOG_ERROR:    level_str = "[ERROR] "; break;
        case LOG_CRITICAL: level_str = "[CRIT]  "; break;
        default:           level_str = "[UNKN]  "; break;
    }
    
    puts(level_str);
    
    va_list args;
    va_start(args, fmt);
    
    char buffer[256];
    int len = vsnprintf(buffer, sizeof(buffer), fmt, args);
    
    for (int i = 0; i < len; i++) {
        putchar(buffer[i]);
    }
    
    va_end(args);
}

/**
 * 十六进制输出
 */
void print_hex(uint64_t value, int width)
{
    const char *hex_digits = "0123456789abcdef";
    char buffer[20];
    int pos = sizeof(buffer) - 1;
    buffer[pos] = '\0';
    
    if (value == 0) {
        buffer[--pos] = '0';
    } else {
        while (value > 0 && pos > 0) {
            buffer[--pos] = hex_digits[value & 0xF];
            value >>= 4;
        }
    }
    
    // 填充前导零
    while ((sizeof(buffer) - 1 - pos) < width && pos > 0) {
        buffer[--pos] = '0';
    }
    
    puts("0x");
    puts(&buffer[pos]);
}

/**
 * 十进制输出
 */
void print_dec(uint64_t value)
{
    char buffer[20];
    int pos = sizeof(buffer) - 1;
    buffer[pos] = '\0';
    
    if (value == 0) {
        buffer[--pos] = '0';
    } else {
        while (value > 0 && pos > 0) {
            buffer[--pos] = '0' + (value % 10);
            value /= 10;
        }
    }
    
    puts(&buffer[pos]);
}

/**
 * 二进制输出
 */
void print_bin(uint64_t value, int width)
{
    puts("0b");
    
    if (width > 64) width = 64;
    
    for (int i = width - 1; i >= 0; i--) {
        putchar((value >> i) & 1 ? '1' : '0');
        if (i > 0 && i % 4 == 0) putchar('_');
    }
}

/**
 * 简单的vsnprintf实现
 */
int vsnprintf(char *buf, size_t size, const char *fmt, va_list args)
{
    if (size == 0) return 0;
    
    char *ptr = buf;
    const char *end = buf + size - 1;  // 保留一个位置给'\0'
    
    while (*fmt && ptr < end) {
        if (*fmt == '%') {
            fmt++;
            
            // 处理格式说明符
            switch (*fmt) {
                case 'd':
                case 'i': {
                    int val = va_arg(args, int);
                    if (val < 0) {
                        *ptr++ = '-';
                        val = -val;
                    }
                    
                    // 转换为字符串
                    char num_buf[20];
                    char *num_ptr = &num_buf[19];
                    *num_ptr = '\0';
                    
                    do {
                        *--num_ptr = '0' + (val % 10);
                        val /= 10;
                    } while (val > 0);
                    
                    while (*num_ptr && ptr < end) {
                        *ptr++ = *num_ptr++;
                    }
                    break;
                }
                
                case 'u': {
                    unsigned int val = va_arg(args, unsigned int);
                    char num_buf[20];
                    char *num_ptr = &num_buf[19];
                    *num_ptr = '\0';
                    
                    do {
                        *--num_ptr = '0' + (val % 10);
                        val /= 10;
                    } while (val > 0);
                    
                    while (*num_ptr && ptr < end) {
                        *ptr++ = *num_ptr++;
                    }
                    break;
                }
                
                case 'x':
                case 'p': {
                    unsigned long val;
                    if (*fmt == 'p') {
                        val = (unsigned long)va_arg(args, void *);
                    } else {
                        val = va_arg(args, unsigned int);
                    }
                    
                    const char *hex = "0123456789abcdef";
                    char hex_buf[20];
                    char *hex_ptr = &hex_buf[19];
                    *hex_ptr = '\0';
                    
                    do {
                        *--hex_ptr = hex[val & 0xF];
                        val >>= 4;
                    } while (val > 0);
                    
                    if (*fmt == 'p') {
                        *ptr++ = '0';
                        *ptr++ = 'x';
                    }
                    
                    while (*hex_ptr && ptr < end) {
                        *ptr++ = *hex_ptr++;
                    }
                    break;
                }
                
                case 'c': {
                    char c = (char)va_arg(args, int);
                    *ptr++ = c;
                    break;
                }
                
                case 's': {
                    const char *str = va_arg(args, const char *);
                    if (!str) str = "(null)";
                    
                    while (*str && ptr < end) {
                        *ptr++ = *str++;
                    }
                    break;
                }
                
                case '%': {
                    *ptr++ = '%';
                    break;
                }
                
                case 'l': {
                    // 处理%llx等
                    if (fmt[1] == 'l' && fmt[2] == 'x') {
                        fmt += 2;
                        uint64_t val = va_arg(args, uint64_t);
                        
                        const char *hex = "0123456789abcdef";
                        char hex_buf[20];
                        char *hex_ptr = &hex_buf[19];
                        *hex_ptr = '\0';
                        
                        do {
                            *--hex_ptr = hex[val & 0xF];
                            val >>= 4;
                        } while (val > 0);
                        
                        while (*hex_ptr && ptr < end) {
                            *ptr++ = *hex_ptr++;
                        }
                    }
                    break;
                }
                
                default:
                    *ptr++ = '%';
                    *ptr++ = *fmt;
                    break;
            }
            fmt++;
        } else {
            *ptr++ = *fmt++;
        }
    }
    
    *ptr = '\0';
    return ptr - buf;
}

/**
 * snprintf实现
 */
int snprintf(char *buf, size_t size, const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    int len = vsnprintf(buf, size, fmt, args);
    va_end(args);
    return len;
}