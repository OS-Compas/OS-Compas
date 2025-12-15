```markdown
# 故障排除指南

## 常见问题及解决方案

### 1. 编译问题

#### 问题1.1：缺少头文件
error: 'DHT11_DATA_PIN' undeclared

text
**解决方案：**
检查`rtconfig.h`或`sensor_config.h`中的引脚定义，确保已正确定义。

#### 问题1.2：链接错误
undefined reference to `dht_sensor_init'

text
**解决方案：**
1. 确保在SConscript中添加了`sensor_dht.c`
2. 运行`scons --target=mdk5`重新生成工程
3. 清理后重新编译：`scons -c && scons`

### 2. 烧录问题

#### 问题2.1：无法识别ST-Link
No ST-Link detected

text
**解决方案：**
1. 安装ST-Link驱动
2. 检查USB连接和数据线
3. 尝试不同的USB端口

#### 问题2.2：烧录失败
Error: Flash download failed

text
**解决方案：**
1. 检查Boot0和Boot1引脚状态（都应接地）
2. 降低烧录速度
3. 使用串口ISP模式烧录

### 3. 运行问题

#### 问题3.1：系统无法启动
No output on serial port

text
**解决方案：**
1. 检查串口波特率（115200）
2. 检查串口线连接（TX/RX交叉）
3. 检查系统时钟配置

#### 问题3.2：内存不足
rt_malloc failed

text
**解决方案：**
1. 增大堆内存：`#define RT_HEAP_SIZE (1024*20)`
2. 优化内存使用，减少缓冲区大小
3. 使用内存池代替动态分配

### 4. 传感器问题

#### 问题4.1：DHT11读取超时
[DHT] No response

text
**解决方案：**
1. 检查DATA引脚连接和上拉电阻
2. 检查电源电压（3.3V-5V）
3. 增加读取超时时间
4. 检查时序函数精度

#### 问题4.2：数据校验失败
[DHT] Checksum error

text
**解决方案：**
1. 增加读取之间的延迟（至少2秒）
2. 检查电源稳定性，添加滤波电容
3. 实现多次读取取平均

### 5. WiFi连接问题

#### 问题5.1：AT指令无响应
[WiFi] AT test failed

text
**解决方案：**
1. 检查ESP8266电源（必须3.3V！）
2. 检查串口引脚连接（TX/RX交叉）
3. 检查波特率（通常115200）
4. 按下RST键重置模块

#### 问题5.2：无法连接WiFi
[WiFi] Connect failed

text
**解决方案：**
1. 检查SSID和密码是否正确
2. 检查路由器设置（是否隐藏SSID）
3. 增加连接超时时间
4. 检查WiFi信号强度

### 6. MQTT连接问题

#### 问题6.1：连接服务器失败
[MQTT] Connect failed

text
**解决方案：**
1. 检查网络连接：`AT+PING="www.baidu.com"`
2. 检查MQTT服务器地址和端口
3. 检查防火墙设置
4. 尝试不同的公共MQTT服务器

#### 问题6.2：发布数据失败
[MQTT] Publish failed

text
**解决方案：**
1. 检查MQTT连接状态
2. 检查主题名称是否合法
3. 检查数据长度是否超限
4. 增加MQTT超时时间

### 7. OLED显示问题

#### 问题7.1：屏幕无显示
[OLED] Initialize failed

text
**解决方案：**
1. 检查I2C地址（通常0x78或0x7A）
2. 检查SCL/SDA引脚连接
3. 检查电源电压（3.3V）
4. 检查上拉电阻（4.7KΩ）

#### 问题7.2：显示乱码
显示乱码或花屏

text
**解决方案：**
1. 检查初始化序列是否正确
2. 检查字库数据
3. 清除显示缓冲区
4. 降低I2C通信速度

## 调试技巧

### 1. 串口调试
```c
// 添加详细的调试信息
#define DEBUG_LEVEL 3

#if DEBUG_LEVEL >= 1
#define LOG_D(fmt, ...) rt_kprintf("[D] %s:%d " fmt, \
                                  __FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define LOG_D(fmt, ...)
#endif
2. LED状态指示
c
// 使用LED显示系统状态
void system_status_led(void) {
    static int count = 0;
    
    if (wifi_is_connected() && mqtt_get_state() == MQTT_STATE_CONNECTED) {
        // 快速闪烁：正常运行
        if (count % 10 == 0) led_toggle();
    } else if (wifi_is_connected()) {
        // 慢速闪烁：WiFi已连接，MQTT未连接
        if (count % 50 == 0) led_toggle();
    } else {
        // 常亮：WiFi未连接
        led_on();
    }
    
    count++;
}
3. 系统监控
bash
# 查看任务状态
list_thread

# 查看内存使用
free

# 查看设备信息
list_device

# 查看定时器
list_timer
4. 网络诊断
bash
# 测试网络连通性
ping www.baidu.com

# 查看网络接口
ifconfig

# 测试DNS解析
nslookup www.baidu.com
性能优化建议
1. 内存优化
使用静态分配代替动态分配

合理设置栈大小

使用内存池管理频繁分配的对象

2. 功耗优化
合理设置采集间隔

使用低功耗模式

关闭未使用的外设

3. 实时性优化
合理设置任务优先级

减少临界区长度

使用无锁数据结构

紧急恢复
1. 系统卡死
按下复位键重启系统

检查看门狗是否启用

分析最后输出的调试信息

2. 配置丢失
恢复默认配置

检查Flash存储区域

重新烧录完整固件

3. 无法烧录
使用串口ISP模式

检查Boot引脚状态

使用不同版本的烧录工具

联系支持
如果以上方法无法解决问题，请提供以下信息：

硬件配置详情

软件版本信息

完整的错误日志

已经尝试的解决方法