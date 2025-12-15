/**
 * sensor_dht.c - DHT11/DHT22温湿度传感器驱动
 * 支持单总线通信协议
 */

#include <rtthread.h>
#include <rtdevice.h>
#include <drv_gpio.h>
#include "sensor_dht.h"

/* 传感器引脚配置 */
#ifndef DHT11_DATA_PIN
#define DHT11_DATA_PIN    GET_PIN(A, 1)  /* PA1 */
#endif

/* 传感器类型 */
#define DHT11     1
#define DHT22     2

/* 全局变量 */
static rt_base_t dht_pin;
static rt_uint8_t sensor_type = DHT11;

/* 延时函数（微秒级） */
static void dht_delay_us(rt_uint32_t us) {
    rt_uint32_t ticks;
    rt_uint32_t told, tnow, tcnt = 0;
    rt_uint32_t reload = SysTick->LOAD;
    
    ticks = us * reload / (1000000 / RT_TICK_PER_SECOND);
    told = SysTick->VAL;
    while (1) {
        tnow = SysTick->VAL;
        if (tnow != told) {
            if (tnow < told) {
                tcnt += told - tnow;
            } else {
                tcnt += reload - tnow + told;
            }
            told = tnow;
            if (tcnt >= ticks) {
                break;
            }
        }
    }
}

/* 设置引脚模式 */
static void dht_pin_mode(rt_uint8_t mode) {
    if (mode) {
        /* 输出模式 */
        rt_pin_mode(dht_pin, PIN_MODE_OUTPUT);
    } else {
        /* 输入模式 */
        rt_pin_mode(dht_pin, PIN_MODE_INPUT);
    }
}

/* 发送开始信号 */
static void dht_start_signal(void) {
    dht_pin_mode(1);           /* 设置为输出 */
    rt_pin_write(dht_pin, 0);  /* 拉低至少18ms */
    dht_delay_us(20000);       /* 20ms */
    rt_pin_write(dht_pin, 1);  /* 拉高20-40us */
    dht_delay_us(30);
    dht_pin_mode(0);           /* 设置为输入 */
}

/* 等待响应信号 */
static rt_err_t dht_wait_response(void) {
    rt_uint32_t timeout = 0;
    
    /* 等待DHT拉低 */
    while (rt_pin_read(dht_pin) && timeout < 100) {
        timeout++;
        dht_delay_us(1);
    }
    if (timeout >= 100) return -RT_ERROR;
    
    timeout = 0;
    /* 等待DHT拉高 */
    while (!rt_pin_read(dht_pin) && timeout < 100) {
        timeout++;
        dht_delay_us(1);
    }
    if (timeout >= 100) return -RT_ERROR;
    
    return RT_EOK;
}

/* 读取一个字节的数据 */
static rt_uint8_t dht_read_byte(void) {
    rt_uint8_t i, data = 0;
    
    for (i = 0; i < 8; i++) {
        /* 等待低电平结束 */
        while (!rt_pin_read(dht_pin));
        dht_delay_us(40);  /* 延时40us */
        
        /* 判断数据位是0还是1 */
        if (rt_pin_read(dht_pin)) {
            data |= (1 << (7 - i));
            /* 等待高电平结束 */
            while (rt_pin_read(dht_pin));
        }
    }
    
    return data;
}

/* 初始化DHT传感器 */
rt_err_t dht_sensor_init(void) {
    dht_pin = DHT11_DATA_PIN;
    
    /* 设置引脚为上拉输入 */
    rt_pin_mode(dht_pin, PIN_MODE_INPUT_PULLUP);
    
    rt_thread_delay(RT_TICK_PER_SECOND);  /* 等待传感器稳定 */
    
    rt_kprintf("[DHT] Sensor initialized on pin %d\n", dht_pin);
    return RT_EOK;
}

/* 读取温湿度数据 */
rt_err_t dht_sensor_read(float *temperature, float *humidity) {
    rt_uint8_t data[5] = {0};
    rt_uint8_t checksum;
    rt_err_t ret = RT_EOK;
    
    /* 发送开始信号 */
    dht_start_signal();
    
    /* 等待响应 */
    if (dht_wait_response() != RT_EOK) {
        rt_kprintf("[DHT] No response\n");
        return -RT_ERROR;
    }
    
    /* 读取40位数据 */
    for (rt_uint8_t i = 0; i < 5; i++) {
        data[i] = dht_read_byte();
    }
    
    /* 校验数据 */
    checksum = data[0] + data[1] + data[2] + data[3];
    if (checksum != data[4]) {
        rt_kprintf("[DHT] Checksum error: %d != %d\n", checksum, data[4]);
        return -RT_ERROR;
    }
    
    /* 解析数据（DHT11） */
    if (sensor_type == DHT11) {
        *humidity = data[0];           /* 整数部分 */
        *temperature = data[2];        /* 整数部分 */
    } 
    /* DHT22解析略... */
    
    return RT_EOK;
}

/* 设置传感器类型 */
void dht_set_type(rt_uint8_t type) {
    sensor_type = type;
    rt_kprintf("[DHT] Sensor type set to: %s\n", 
               type == DHT11 ? "DHT11" : "DHT22");
}