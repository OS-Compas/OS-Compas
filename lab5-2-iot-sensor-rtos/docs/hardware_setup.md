```markdown
# 硬件连接说明

## 所需器件清单

| 器件 | 型号 | 数量 | 备注 |
|------|------|------|------|
| 开发板 | STM32F103C8T6 | 1 | 蓝色药丸最小系统板 |
| 温湿度传感器 | DHT11 | 1 | 3针模块 |
| WiFi模块 | ESP8266-01S | 1 | 支持AT指令 |
| OLED显示屏 | SSD1306 | 1 | I2C接口，128x64（可选） |
| 面包板 | 830孔 | 1 | 用于连接电路 |
| 杜邦线 | 公对公 | 20 | 各种颜色 |
| USB转TTL | CP2102/CH340 | 1 | 用于串口调试 |
| 电阻 | 4.7KΩ | 1 | DHT11上拉电阻 |

## 详细连接方法

### 1. 电源连接
STM32 开发板	外设模块
3.3V (3V3)	DHT11 VCC
text
             | ESP8266 VCC
             | OLED VCC
GND | DHT11 GND
| ESP8266 GND
| OLED GND

text

### 2. DHT11传感器连接
DHT11引脚	STM32引脚	说明
VCC	3.3V	电源正极
DATA	PA1	数据信号
GND	GND	电源地
注意：需要在DATA引脚和3.3V之间接一个4.7KΩ上拉电阻

text

### 3. ESP8266模块连接
ESP8266引脚	STM32引脚	说明
VCC	3.3V	电源正极（重要：必须3.3V）
GND	GND	电源地
TX	PA3 (RX2)	发送数据到STM32
RX	PA2 (TX2)	接收STM32数据
CH_PD	3.3V	使能引脚（保持高电平）
GPIO0	悬空	正常工作模式
GPIO2	悬空	保持悬空或接高电平
text

### 4. OLED显示屏连接（扩展挑战）
OLED引脚	STM32引脚	说明
VCC	3.3V	电源正极
GND	GND	电源地
SCL	PB6	I2C时钟线
SDA	PB7	I2C数据线
text

### 5. 调试串口连接
STM32引脚	USB转TTL	说明
PA9 (TX1)	RX	发送调试信息
PA10 (RX1)	TX	接收控制命令
GND	GND	共地
text

## 引脚分配总表

| 功能 | STM32引脚 | 引脚模式 | 备注 |
|------|-----------|----------|------|
| DHT11数据 | PA1 | 输入/输出 | 单总线通信 |
| ESP8266 TX | PA3 | 输入 | UART2 RX |
| ESP8266 RX | PA2 | 输出 | UART2 TX |
| OLED SCL | PB6 | 复用开漏 | I2C1时钟 |
| OLED SDA | PB7 | 复用开漏 | I2C1数据 |
| 调试串口TX | PA9 | 复用推挽 | UART1 TX |
| 调试串口RX | PA10 | 输入 | UART1 RX |
| 用户LED | PC13 | 推挽输出 | 状态指示 |

## 电路原理图说明

### 1. 电源电路
3.3V稳压电路已在开发板上实现
需要确保总电流不超过200mA
建议为ESP8266单独供电（峰值电流可达300mA）

text

### 2. 上拉电阻配置
DHT11 DATA引脚：4.7KΩ上拉到3.3V
I2C总线：4.7KΩ上拉到3.3V（SSD1306内部通常已有）

text

### 3. 电平匹配
STM32 GPIO：3.3V电平
ESP8266：3.3V电平（注意：不要接5V！）
DHT11：3.3-5.5V工作电压
OLED：3.3V工作电压

text

## 硬件测试步骤

### 步骤1：基本连通性测试
1. 使用万用表检查所有电源连接
2. 确认3.3V和GND之间没有短路
3. 测量各模块供电电压是否正常

### 步骤2：ESP8266模块测试
```bash
# 连接ESP8266到USB转TTL
# 使用串口工具（115200波特率）
# 发送AT指令测试
AT
# 预期响应：OK
AT+GMR
# 查看固件版本
步骤3：DHT11传感器测试
c
// 简单测试程序
while(1) {
    float temp, humi;
    if(dht_read(&temp, &humi) == SUCCESS) {
        printf("Temp: %.1fC, Humi: %.1f%%\n", temp, humi);
    }
    delay(2000);
}
步骤4：OLED显示屏测试
c
// 显示测试图案
oled_init();
oled_clear();
oled_show_string(0, 0, "OLED Test", 16);
oled_show_string(0, 2, "Hello RT-Thread!", 12);
常见问题排查
Q1：ESP8266无法连接WiFi
A：检查WiFi名称和密码是否正确，确保信号强度足够，检查AT指令响应。

Q2：DHT11读取数据失败
A：检查DATA引脚上拉电阻，确保时序正确，检查电源电压是否稳定。

Q3：OLED不显示
A：检查I2C地址是否正确，检查SCL/SDA是否接反，检查电源连接。

Q4：系统工作不稳定
A：检查电源容量是否足够，添加滤波电容，检查地线连接。

安全注意事项
操作前务必断开电源

避免短路和反接

注意静电防护

大电流设备单独供电