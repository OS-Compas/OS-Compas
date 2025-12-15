/**
 * wifi_esp8266.c - ESP8266 WiFi模块驱动
 * 基于AT指令集
 */

#include <rtthread.h>
#include <rtdevice.h>
#include <string.h>
#include "wifi_config.h"
#include "wifi_esp8266.h"

/* UART设备名称 */
#define ESP8266_UART_NAME    "uart2"

/* 全局变量 */
static rt_device_t serial;
static struct rt_semaphore rx_sem;
static rt_uint8_t wifi_connected = 0;

/* 接收回调函数 */
static rt_err_t uart_rx_ind(rt_device_t dev, rt_size_t size) {
    rt_sem_release(&rx_sem);
    return RT_EOK;
}

/* 发送AT指令并等待响应 */
static rt_err_t esp8266_send_cmd(const char *cmd, const char *expect, 
                                 rt_uint32_t timeout) {
    char response[512];
    rt_size_t len;
    rt_tick_t start_tick;
    
    /* 清空接收缓冲区 */
    while (rt_device_read(serial, 0, response, sizeof(response)) > 0);
    
    /* 发送AT指令 */
    len = rt_strlen(cmd);
    rt_device_write(serial, 0, cmd, len);
    
    /* 等待响应 */
    start_tick = rt_tick_get();
    while (1) {
        /* 等待接收信号量 */
        if (rt_sem_take(&rx_sem, RT_TICK_PER_SECOND) != RT_EOK) {
            if (rt_tick_get() - start_tick > timeout) {
                rt_kprintf("[WiFi] Command timeout: %s\n", cmd);
                return -RT_ETIMEOUT;
            }
            continue;
        }
        
        /* 读取响应 */
        len = rt_device_read(serial, 0, response, sizeof(response) - 1);
        if (len > 0) {
            response[len] = '\0';
            
            /* 检查是否包含期望的响应 */
            if (rt_strstr(response, expect) != RT_NULL) {
                rt_kprintf("[WiFi] Response: %s\n", response);
                return RT_EOK;
            }
            
            /* 检查错误响应 */
            if (rt_strstr(response, "ERROR") != RT_NULL ||
                rt_strstr(response, "FAIL") != RT_NULL) {
                rt_kprintf("[WiFi] Command failed: %s\n", cmd);
                return -RT_ERROR;
            }
        }
        
        if (rt_tick_get() - start_tick > timeout) {
            rt_kprintf("[WiFi] Response timeout\n");
            return -RT_ETIMEOUT;
        }
    }
}

/* 初始化WiFi模块 */
rt_err_t wifi_init(void) {
    rt_err_t ret;
    
    /* 查找串口设备 */
    serial = rt_device_find(ESP8266_UART_NAME);
    if (!serial) {
        rt_kprintf("[WiFi] UART device %s not found!\n", ESP8266_UART_NAME);
        return -RT_ERROR;
    }
    
    /* 初始化信号量 */
    rt_sem_init(&rx_sem, "wifi_rx", 0, RT_IPC_FLAG_FIFO);
    
    /* 打开串口设备 */
    ret = rt_device_open(serial, RT_DEVICE_FLAG_INT_RX);
    if (ret != RT_EOK) {
        rt_kprintf("[WiFi] Open UART failed: %d\n", ret);
        return ret;
    }
    
    /* 设置接收回调 */
    rt_device_set_rx_indicate(serial, uart_rx_ind);
    
    /* 设置串口参数：115200 8N1 */
    struct serial_configure config = RT_SERIAL_CONFIG_DEFAULT;
    config.baud_rate = BAUD_RATE_115200;
    rt_device_control(serial, RT_DEVICE_CTRL_CONFIG, &config);
    
    rt_kprintf("[WiFi] UART initialized: %s\n", ESP8266_UART_NAME);
    
    /* 测试AT指令 */
    rt_thread_delay(2000);  /* 等待模块启动 */
    
    ret = esp8266_send_cmd("AT\r\n", "OK", 2000);
    if (ret != RT_EOK) {
        rt_kprintf("[WiFi] AT test failed\n");
        return ret;
    }
    
    rt_kprintf("[WiFi] Module ready\n");
    
    /* 设置WiFi模式为STA */
    ret = esp8266_send_cmd("AT+CWMODE=1\r\n", "OK", 3000);
    if (ret != RT_EOK) {
        return ret;
    }
    
    /* 连接到WiFi */
    char cmd[128];
    rt_snprintf(cmd, sizeof(cmd), 
               "AT+CWJAP=\"%s\",\"%s\"\r\n", 
               WIFI_SSID, WIFI_PASSWORD);
    
    rt_kprintf("[WiFi] Connecting to: %s\n", WIFI_SSID);
    ret = esp8266_send_cmd(cmd, "WIFI CONNECTED", 10000);
    if (ret != RT_EOK) {
        rt_kprintf("[WiFi] Connect failed\n");
        return ret;
    }
    
    rt_kprintf("[WiFi] Connected to WiFi\n");
    wifi_connected = 1;
    
    /* 获取IP地址 */
    esp8266_send_cmd("AT+CIFSR\r\n", "+CIFSR", 3000);
    
    /* 设置单连接模式 */
    esp8266_send_cmd("AT+CIPMUX=0\r\n", "OK", 3000);
    
    return RT_EOK;
}

/* 检查WiFi连接状态 */
rt_uint8_t wifi_is_connected(void) {
    return wifi_connected;
}

/* 发送TCP数据 */
rt_err_t wifi_send_tcp(const char *ip, rt_uint16_t port, 
                      const char *data, rt_size_t len) {
    char cmd[64];
    rt_err_t ret;
    
    /* 建立TCP连接 */
    rt_snprintf(cmd, sizeof(cmd), "AT+CIPSTART=\"TCP\",\"%s\",%d\r\n", ip, port);
    ret = esp8266_send_cmd(cmd, "CONNECT", 10000);
    if (ret != RT_EOK) {
        return ret;
    }
    
    /* 发送数据 */
    rt_snprintf(cmd, sizeof(cmd), "AT+CIPSEND=%d\r\n", len);
    ret = esp8266_send_cmd(cmd, ">", 3000);
    if (ret != RT_EOK) {
        return ret;
    }
    
    /* 发送实际数据 */
    rt_device_write(serial, 0, data, len);
    
    /* 等待发送完成 */
    esp8266_send_cmd("", "SEND OK", 5000);
    
    /* 关闭连接 */
    esp8266_send_cmd("AT+CIPCLOSE\r\n", "CLOSED", 3000);
    
    return RT_EOK;
}