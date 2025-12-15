/**
 * rtconfig.h - RT-Thread内核配置文件
 * 针对STM32F103C8T6最小系统板配置
 */

#ifndef RT_CONFIG_H__
#define RT_CONFIG_H__

/* 自动生成部分，不要手动修改 */
#define RT_THREAD

/* RT-Thread内核配置 */
#define RT_USING_OVERFLOW_CHECK
#define RT_DEBUG
#define RT_DEBUG_INIT 1
#define RT_USING_MUTEX
#define RT_USING_SEMAPHORE
#define RT_USING_MESSAGEQUEUE
#define RT_USING_MAILBOX
#define RT_USING_HEAP

/* 内核对象名称最大长度 */
#define RT_NAME_MAX 8

/* Tick频率 (1000 tick/s) */
#define RT_TICK_PER_SECOND 1000

/* 字节对齐 */
#define RT_ALIGN_SIZE 4

/* 使用Hook */
#define RT_USING_HOOK

/* 使用IDLE Hook */
#define RT_USING_IDLE_HOOK

/* 使用组件初始化 */
#define RT_USING_COMPONENTS_INIT

/* 使用用户主函数 */
#define RT_USING_USER_MAIN

/* 主线程栈大小 */
#define RT_MAIN_THREAD_STACK_SIZE 2048

/* 主线程优先级 */
#define RT_MAIN_THREAD_PRIORITY 10

/* 设备驱动配置 */
#define RT_USING_DEVICE
#define RT_USING_DEVICE_IPC
#define RT_USING_SERIAL
#define RT_SERIAL_RB_BUFSZ 64

/* 控制台配置 */
#define RT_USING_CONSOLE
#define RT_CONSOLEBUF_SIZE 128
#define RT_CONSOLE_DEVICE_NAME "uart1"

/* FinSH shell配置 */
#define RT_USING_FINSH
#define FINSH_THREAD_NAME "tshell"
#define FINSH_USING_HISTORY
#define FINSH_HISTORY_LINES 5
#define FINSH_USING_SYMTAB
#define FINSH_THREAD_PRIORITY 20
#define FINSH_THREAD_STACK_SIZE 4096
#define FINSH_CMD_SIZE 80

/* 内存管理配置 */
#define RT_USING_MEMPOOL
#define RT_USING_MEMHEAP
#define RT_USING_SMALL_MEM
#define RT_USING_HEAP

/* 系统时钟配置 */
#define RT_USING_TIMER_SOFT
#ifndef RT_TIMER_THREAD_PRIO
#define RT_TIMER_THREAD_PRIO 4
#endif
#ifndef RT_TIMER_THREAD_STACK_SIZE
#define RT_TIMER_THREAD_STACK_SIZE 512
#endif

/* 板载特定配置 */
#define STM32F103x8
#define RT_HSE_VALUE 8000000
#define BOARD_STM32_MINI

/* UART配置 */
#define BSP_USING_UART1
#define BSP_UART1_TX_PIN "PA9"
#define BSP_UART1_RX_PIN "PA10"

#define BSP_USING_UART2  /* ESP8266 */
#define BSP_UART2_TX_PIN "PA2"
#define BSP_UART2_RX_PIN "PA3"

/* I2C配置（OLED） */
#define BSP_USING_I2C1
#define BSP_I2C1_SCL_PIN "PB6"
#define BSP_I2C1_SDA_PIN "PB7"

/* GPIO配置 */
#define BSP_USING_GPIO
#define BSP_USING_PIN

/* 启用DHT传感器支持 */
#define PKG_USING_DHTXX

/* 启用Paho MQTT */
#define PKG_USING_PAHOMQTT

/* 启用cJSON */
#define PKG_USING_CJSON

#endif /* RT_CONFIG_H__ */