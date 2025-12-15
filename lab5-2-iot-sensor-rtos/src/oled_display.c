/**
 * oled_display.c - SSD1306 OLED显示屏驱动
 * I2C接口，128x64分辨率
 */

#include <rtthread.h>
#include <rtdevice.h>
#include <string.h>
#include "oled_display.h"

/* I2C设备配置 */
#ifndef OLED_I2C_BUS
#define OLED_I2C_BUS     "i2c1"
#endif

#ifndef OLED_I2C_ADDR
#define OLED_I2C_ADDR    0x78  /* 7位地址 */
#endif

/* OLED命令定义 */
#define OLED_CMD         0x00
#define OLED_DATA        0x40

#define OLED_WIDTH       128
#define OLED_HEIGHT      64

/* 全局变量 */
static rt_device_t i2c_dev;
static rt_uint8_t oled_buffer[OLED_WIDTH * OLED_HEIGHT / 8];

/* 发送命令到OLED */
static void oled_write_cmd(rt_uint8_t cmd) {
    rt_uint8_t buffer[2] = {OLED_CMD, cmd};
    rt_device_write(i2c_dev, 0, buffer, 2);
}

/* 发送数据到OLED */
static void oled_write_data(rt_uint8_t data) {
    rt_uint8_t buffer[2] = {OLED_DATA, data};
    rt_device_write(i2c_dev, 0, buffer, 2);
}

/* 初始化OLED显示屏 */
rt_err_t oled_init(void) {
    rt_err_t ret;
    
    /* 查找I2C设备 */
    i2c_dev = rt_device_find(OLED_I2C_BUS);
    if (i2c_dev == RT_NULL) {
        rt_kprintf("[OLED] I2C device %s not found!\n", OLED_I2C_BUS);
        return -RT_ERROR;
    }
    
    /* 打开I2C设备 */
    ret = rt_device_open(i2c_dev, RT_DEVICE_FLAG_RDWR);
    if (ret != RT_EOK) {
        rt_kprintf("[OLED] Open I2C failed: %d\n", ret);
        return ret;
    }
    
    /* 初始化序列 */
    rt_thread_delay(100);  /* 等待OLED上电稳定 */
    
    oled_write_cmd(0xAE);  /* 关闭显示 */
    
    oled_write_cmd(0xD5);  /* 设置时钟分频 */
    oled_write_cmd(0x80);
    
    oled_write_cmd(0xA8);  /* 设置多路复用 */
    oled_write_cmd(0x3F);
    
    oled_write_cmd(0xD3);  /* 设置显示偏移 */
    oled_write_cmd(0x00);
    
    oled_write_cmd(0x40);  /* 设置起始行 */
    
    oled_write_cmd(0x8D);  /* 电荷泵设置 */
    oled_write_cmd(0x14);
    
    oled_write_cmd(0x20);  /* 内存地址模式 */
    oled_write_cmd(0x00);
    
    oled_write_cmd(0xA1);  /* 段重映射 */
    oled_write_cmd(0xC8);  /* 扫描方向 */
    
    oled_write_cmd(0xDA);  /* COM引脚配置 */
    oled_write_cmd(0x12);
    
    oled_write_cmd(0x81);  /* 对比度控制 */
    oled_write_cmd(0xCF);
    
    oled_write_cmd(0xD9);  /* 预充电周期 */
    oled_write_cmd(0xF1);
    
    oled_write_cmd(0xDB);  /* VCOMH取消选择级别 */
    oled_write_cmd(0x40);
    
    oled_write_cmd(0xA4);  /* 全亮显示 */
    oled_write_cmd(0xA6);  /* 正常显示 */
    
    oled_write_cmd(0x2E);  /* 停止滚动 */
    oled_write_cmd(0xAF);  /* 开启显示 */
    
    /* 清空显示缓冲区 */
    oled_clear();
    
    rt_kprintf("[OLED] Initialized successfully\n");
    
    return RT_EOK;
}

/* 清空屏幕 */
void oled_clear(void) {
    rt_memset(oled_buffer, 0, sizeof(oled_buffer));
    oled_refresh();
}

/* 刷新显示 */
void oled_refresh(void) {
    oled_write_cmd(0x21);  /* 设置列地址 */
    oled_write_cmd(0);
    oled_write_cmd(127);
    
    oled_write_cmd(0x22);  /* 设置页地址 */
    oled_write_cmd(0);
    oled_write_cmd(7);
    
    /* 写入显示数据 */
    for (rt_uint16_t i = 0; i < sizeof(oled_buffer); i++) {
        oled_write_data(oled_buffer[i]);
    }
}

/* 在指定位置显示一个字符 */
void oled_show_char(rt_uint8_t x, rt_uint8_t y, char ch, rt_uint8_t size) {
    rt_uint8_t i, j;
    rt_uint8_t *pfont;
    
    if (x > OLED_WIDTH - 1 || y > OLED_HEIGHT - 1) {
        return;
    }
    
    /* 获取字模数据 */
    // 这里需要字库，简化实现，只显示ASCII字符
    // 实际应用中应该包含完整的字库
    
    /* 更新显示缓冲区 */
    for (i = 0; i < size; i++) {
        for (j = 0; j < size; j++) {
            if (1) {  /* 根据字模数据设置像素 */
                oled_draw_point(x + j, y + i, 1);
            }
        }
    }
    
    /* 刷新显示 */
    oled_refresh();
}

/* 显示字符串 */
void oled_show_string(rt_uint8_t x, rt_uint8_t y, const char *str, rt_uint8_t size) {
    while (*str) {
        if (x > OLED_WIDTH - size) {
            x = 0;
            y += size;
        }
        if (y > OLED_HEIGHT - size) {
            y = x = 0;
            oled_clear();
        }
        
        oled_show_char(x, y, *str, size);
        x += size / 2;
        str++;
    }
    
    oled_refresh();
}

/* 画点 */
void oled_draw_point(rt_uint8_t x, rt_uint8_t y, rt_uint8_t color) {
    rt_uint8_t page, bit;
    
    if (x >= OLED_WIDTH || y >= OLED_HEIGHT) {
        return;
    }
    
    page = y / 8;
    bit = y % 8;
    
    if (color) {
        oled_buffer[x + page * OLED_WIDTH] |= (1 << bit);
    } else {
        oled_buffer[x + page * OLED_WIDTH] &= ~(1 << bit);
    }
}

/* 显示数字 */
void oled_show_num(rt_uint8_t x, rt_uint8_t y, rt_uint32_t num, 
                  rt_uint8_t len, rt_uint8_t size) {
    char str[12];
    rt_snprintf(str, sizeof(str), "%d", num);
    oled_show_string(x, y, str, size);
}

/* 关闭OLED显示 */
void oled_display_off(void) {
    oled_write_cmd(0xAE);
}

/* 开启OLED显示 */
void oled_display_on(void) {
    oled_write_cmd(0xAF);
}