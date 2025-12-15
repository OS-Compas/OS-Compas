/**
 * main.c - RT-Thread物联网数据采集器主程序
 * 基于RT-Thread Nano + STM32 + DHT11 + ESP8266 + MQTT
 */

#include <rtthread.h>
#include <rtdevice.h>
#include "sensor_dht.h"
#include "wifi_esp8266.h"
#include "mqtt_client.h"
#include "oled_display.h"

/* 定义线程控制块 */
static rt_thread_t sensor_thread = RT_NULL;
static rt_thread_t mqtt_thread = RT_NULL;
static rt_thread_t display_thread = RT_NULL;

/* 定义信号量 */
static rt_sem_t data_ready_sem = RT_NULL;

/* 传感器数据结构 */
struct sensor_data {
    float temperature;
    float humidity;
    rt_tick_t timestamp;
};

static struct sensor_data current_data;

/* 传感器数据采集线程 */
static void sensor_thread_entry(void *parameter) {
    rt_err_t result;
    
    rt_kprintf("[Sensor] Thread started\n");
    
    /* 初始化DHT传感器 */
    if (dht_sensor_init() != RT_EOK) {
        rt_kprintf("[Sensor] Initialize failed!\n");
        return;
    }
    
    rt_kprintf("[Sensor] Initialize success\n");
    
    while (1) {
        /* 读取传感器数据 */
        result = dht_sensor_read(&current_data.temperature, &current_data.humidity);
        current_data.timestamp = rt_tick_get();
        
        if (result == RT_EOK) {
            rt_kprintf("[Sensor] Temp: %.1fC, Humi: %.1f%%\n", 
                      current_data.temperature, current_data.humidity);
            
            /* 发布信号量通知数据就绪 */
            rt_sem_release(data_ready_sem);
        } else {
            rt_kprintf("[Sensor] Read failed!\n");
        }
        
        /* 每5秒采集一次 */
        rt_thread_delay(5 * RT_TICK_PER_SECOND);
    }
}

/* MQTT发布线程 */
static void mqtt_thread_entry(void *parameter) {
    char payload[100];
    
    rt_kprintf("[MQTT] Thread started\n");
    
    /* 等待WiFi连接 */
    while (!wifi_is_connected()) {
        rt_kprintf("[MQTT] Waiting for WiFi...\n");
        rt_thread_delay(RT_TICK_PER_SECOND);
    }
    
    rt_kprintf("[MQTT] WiFi connected\n");
    
    /* 初始化MQTT客户端 */
    if (mqtt_client_init() != RT_EOK) {
        rt_kprintf("[MQTT] Initialize failed!\n");
        return;
    }
    
    rt_kprintf("[MQTT] Initialize success\n");
    
    while (1) {
        /* 等待传感器数据就绪 */
        if (rt_sem_take(data_ready_sem, RT_WAITING_FOREVER) == RT_EOK) {
            /* 构造JSON格式的MQTT消息 */
            rt_snprintf(payload, sizeof(payload),
                       "{\"temp\":%.1f,\"humi\":%.1f,\"time\":%d}",
                       current_data.temperature,
                       current_data.humidity,
                       current_data.timestamp);
            
            /* 发布到MQTT主题 */
            mqtt_publish_data("sensors/dht11/data", payload);
            
            rt_kprintf("[MQTT] Published: %s\n", payload);
        }
    }
}

/* OLED显示线程（扩展挑战） */
static void display_thread_entry(void *parameter) {
#ifdef OLED_ENABLE
    rt_kprintf("[OLED] Thread started\n");
    
    /* 初始化OLED显示屏 */
    if (oled_init() != RT_EOK) {
        rt_kprintf("[OLED] Initialize failed!\n");
        return;
    }
    
    oled_clear();
    oled_show_string(0, 0, "IoT Sensor", 16);
    oled_show_string(0, 2, "Initializing...", 12);
    
    while (1) {
        /* 显示传感器数据 */
        char temp_str[20], humi_str[20];
        
        rt_snprintf(temp_str, sizeof(temp_str), "Temp: %.1fC", current_data.temperature);
        rt_snprintf(humi_str, sizeof(humi_str), "Humi: %.1f%%", current_data.humidity);
        
        oled_show_string(0, 4, temp_str, 12);
        oled_show_string(0, 6, humi_str, 12);
        
        /* 显示连接状态 */
        if (wifi_is_connected()) {
            oled_show_string(0, 8, "WiFi: Connected", 12);
        } else {
            oled_show_string(0, 8, "WiFi: Disconnected", 12);
        }
        
        rt_thread_delay(RT_TICK_PER_SECOND);
    }
#endif
}

int main(void) {
    rt_kprintf("\n=== IoT Sensor Data Collector ===\n");
    rt_kprintf("RT-Thread Version: %s\n", RT_VERSION);
    rt_kprintf("Board: STM32F103C8T6\n");
    
    /* 创建信号量 */
    data_ready_sem = rt_sem_create("data_sem", 0, RT_IPC_FLAG_FIFO);
    if (data_ready_sem == RT_NULL) {
        rt_kprintf("[Error] Create semaphore failed!\n");
        return -1;
    }
    
    /* 初始化WiFi模块 */
    rt_kprintf("[WiFi] Initializing...\n");
    if (wifi_init() != RT_EOK) {
        rt_kprintf("[WiFi] Initialize failed!\n");
    }
    
    /* 创建传感器线程 */
    sensor_thread = rt_thread_create("sensor",
                                     sensor_thread_entry, 
                                     RT_NULL,
                                     2048,  /* 栈大小 */
                                     10,    /* 优先级 */
                                     10);   /* 时间片 */
    if (sensor_thread != RT_NULL) {
        rt_thread_startup(sensor_thread);
    }
    
    /* 创建MQTT线程 */
    mqtt_thread = rt_thread_create("mqtt",
                                   mqtt_thread_entry,
                                   RT_NULL,
                                   4096,
                                   8,
                                   10);
    if (mqtt_thread != RT_NULL) {
        rt_thread_startup(mqtt_thread);
    }
    
    /* 创建显示线程（扩展挑战） */
#ifdef OLED_ENABLE
    display_thread = rt_thread_create("display",
                                      display_thread_entry,
                                      RT_NULL,
                                      2048,
                                      12,
                                      10);
    if (display_thread != RT_NULL) {
        rt_thread_startup(display_thread);
    }
#endif
    
    rt_kprintf("[System] All threads started successfully!\n");
    
    return 0;
}