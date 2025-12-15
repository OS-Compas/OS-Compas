markdown
# 实验5.2：基于小型OS的物联网数据采集器

## 实验简介
本实验基于RT-Thread实时操作系统，在STM32开发板上实现一个完整的物联网数据采集器。系统整合DHT11温湿度传感器，通过ESP8266 WiFi模块连接网络，使用MQTT协议将数据上报到云端服务器。

## 实验目标
- 掌握RT-Thread实时操作系统的使用
- 理解传感器驱动开发方法
- 掌握WiFi模块的网络连接配置
- 实现MQTT客户端的数据发布功能
- 理解嵌入式系统的分层架构

## 硬件要求
- STM32F103C8T6最小系统板（蓝色药丸）
- DHT11温湿度传感器
- ESP8266 WiFi模块（ESP-01S）
- SSD1306 OLED显示屏（扩展挑战）
- 杜邦线若干
- USB转TTL串口模块（用于调试）

## 软件要求
- RT-Thread Studio或ENV工具链
- ARM GCC工具链
- STM32CubeMX（可选）
- MQTT客户端工具（如MQTT.fx）

## 快速开始

### 1. 硬件连接
STM32	DHT11	ESP8266	OLED
PA1	DATA		
3.3V	VCC	VCC	VCC
GND	GND	GND	GND
PA2 (TX)		RX	
PA3 (RX)		TX	
PB6			SCL
PB7			SDA
text

### 2. 环境搭建
```bash
# 安装RT-Thread ENV工具
git clone https://github.com/RT-Thread/env.git

# 配置工具链
scons --menuconfig

# 选择硬件平台
# BSP -> stm32 -> stm32f103-blue-pill

# 启用软件包
# IoT -> paho-mqtt
# peripheral -> dhtxx
# tools -> cJSON
3. 编译和烧录
bash
# 生成工程
scons --target=mdk5

# 使用Keil MDK打开工程并编译
# 或者直接使用scons编译
scons

# 烧录到开发板
# 使用ST-Link或串口下载
4. 运行测试
bash
# 通过串口查看输出
# 波特率：115200

# 预期输出：
=== IoT Sensor Data Collector ===
RT-Thread Version: 4.0.3
[DHT] Sensor initialized on pin 1
[WiFi] Connecting to: Your_WiFi_SSID
[WiFi] Connected to WiFi
[MQTT] Connecting to broker: test.mosquitto.org:1883
[传感器] Temp: 25.5C, Humi: 60.2%
[MQTT] Published: {"temp":25.5,"humi":60.2,"time":1234567}
实验步骤详解
步骤1：RT-Thread环境搭建
安装RT-Thread Studio或ENV工具

配置交叉编译工具链

创建STM32F103C8T6的BSP工程

步骤2：传感器驱动开发
理解DHT11单总线通信协议

实现温度读取函数

添加数据校验和错误处理

步骤3：WiFi模块集成
配置ESP8266的AT指令通信

实现WiFi连接管理

处理网络状态变化

步骤4：MQTT客户端实现
集成Paho MQTT客户端库

实现MQTT连接管理

设计数据发布机制

步骤5：系统整合测试
创建多任务调度

实现数据采集周期

测试端到端功能

关键代码解析
1. 多任务调度
c
// 创建传感器采集任务
sensor_thread = rt_thread_create("sensor", sensor_thread_entry, 
                                RT_NULL, 2048, 10, 10);
2. 传感器数据读取
c
// DHT11数据读取流程
dht_start_signal();      // 发送开始信号
dht_wait_response();     // 等待传感器响应
data = dht_read_byte();  // 读取数据字节
3. MQTT数据发布
c
// 构造JSON格式的MQTT消息
rt_snprintf(payload, sizeof(payload),
           "{\"temp\":%.1f,\"humi\":%.1f,\"time\":%d}",
           temperature, humidity, timestamp);
扩展挑战
1. 添加OLED显示
实现SSD1306的I2C驱动

显示实时温湿度数据

显示网络连接状态

2. 数据本地存储
添加SPI Flash存储

实现数据缓存和历史查询

断电数据保护

3. 远程控制
实现MQTT命令订阅

添加LED控制功能

支持OTA固件升级

故障排除
常见问题请参考 troubleshooting.md

思考问题
嵌入式实时操作系统与Linux这样的通用操作系统在任务调度和内存管理上有何主要区别？

在本实验中，整个软件栈从下到上包含了哪些层次？

参考资源
RT-Thread文档中心

ESP8266 AT指令集

MQTT协议规范

DHT11数据手册