以下是完整的 **docs/troubleshooting.md** 文档内容：

---

# 故障排除指南

## 常见问题及解决方案

## 1. 环境配置问题

### 问题1.1：找不到内核头文件
```
错误：/lib/modules/$(uname -r)/build: No such file or directory
```

**解决方案**：
```bash
# 树莓派/Ubuntu/Debian系统
sudo apt update
sudo apt install linux-headers-$(uname -r)

# 或者安装通用版本
sudo apt install raspberrypi-kernel-headers  # 树莓派专用
sudo apt install linux-headers-generic       # Ubuntu通用

# CentOS/RHEL系统
sudo yum install kernel-devel-$(uname -r)
```

**验证安装**：
```bash
# 检查内核头文件是否存在
ls -d /lib/modules/$(uname -r)/build

# 检查内核版本
uname -r
```

### 问题1.2：gcc编译器未安装
```
错误：gcc: command not found
```

**解决方案**：
```bash
# 安装开发工具链
sudo apt install build-essential      # Debian/Ubuntu
sudo yum groupinstall "Development Tools"  # CentOS/RHEL

# 验证安装
gcc --version
make --version
```

## 2. 编译构建问题

### 问题2.1：Makefile错误
```
错误：make: *** No rule to make target 'modules'
```

**解决方案**：
1. 确认Makefile语法正确：
```makefile
obj-m += gpio_led.o
KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)
```

2. 检查内核构建路径：
```bash
# 确认内核构建目录存在
ls /lib/modules/$(uname -r)/

# 如果不存在，创建符号链接
sudo ln -s /usr/src/linux-headers-$(uname -r) /lib/modules/$(uname -r)/build
```

### 问题2.2：头文件找不到
```
错误：linux/module.h: No such file or directory
```

**解决方案**：
```bash
# 重新安装内核头文件
sudo apt install --reinstall linux-headers-$(uname -r)

# 或者手动指定头文件路径
# 在Makefile中添加：
EXTRA_CFLAGS += -I/usr/src/linux-headers-$(uname -r)/include
```

## 3. 模块加载/卸载问题

### 问题3.1：insmod权限不足
```
错误：insmod: ERROR: could not insert module: Operation not permitted
```

**解决方案**：
```bash
# 使用sudo权限
sudo insmod gpio_led.ko

# 或者将用户加入sudoers
sudo usermod -aG sudo $USER
# 注销后重新登录
```

### 问题3.2：模块依赖错误
```
错误：insmod: ERROR: could not insert module: Unknown symbol in module
```

**解决方案**：
```bash
# 检查模块依赖
modinfo gpio_led.ko

# 查看缺少的符号
dmesg | tail -20

# 确保所有依赖模块已加载
sudo modprobe <missing_module>
```

### 问题3.3：设备号冲突
```
错误：insmod: ERROR: could not insert module: Device or resource busy
```

**解决方案**：
```bash
# 查看已占用的设备号
cat /proc/devices

# 检查是否有同名模块已加载
lsmod | grep gpio_led

# 如果已加载，先卸载
sudo rmmod gpio_led

# 或者修改驱动中的设备名称
# 修改gpio_led.c中的DEVICE_NAME
```

## 4. GPIO硬件问题

### 问题4.1：GPIO请求失败
```
GPIO_LED: Failed to request GPIO17
```

**解决方案**：

**检查步骤**：
```bash
# 1. 查看GPIO状态
ls /sys/class/gpio/

# 2. 查看GPIO使用情况
cat /sys/kernel/debug/gpio

# 3. 检查GPIO是否已被其他驱动占用
dmesg | grep -i gpio

# 4. 手动导出/取消导出测试
echo 17 > /sys/class/gpio/export
echo 17 > /sys/class/gpio/unexport
```

**可能的原因及解决**：
1. **GPIO被系统占用**：树莓派某些GPIO有特殊功能
2. **GPIO引脚错误**：确认使用BCM编号而非物理编号
3. **权限问题**：确保有GPIO访问权限

```bash
# 释放被占用的GPIO
echo 17 > /sys/class/gpio/unexport 2>/dev/null || true

# 将用户加入gpio组
sudo usermod -aG gpio $USER
sudo reboot
```

### 问题4.2：GPIO方向设置失败
```
GPIO_LED: Failed to set GPIO17 as output
```

**解决方案**：
```bash
# 检查GPIO是否支持输出
cat /sys/kernel/debug/gpio | grep gpio-17

# 检查引脚复用情况（树莓派）
# 部分GPIO引脚有特殊功能（如I2C、SPI、UART）
# 参考：https://pinout.xyz/
```

## 5. 设备文件问题

### 问题5.1：设备文件不存在
```
open /dev/gpio_led: No such file or directory
```

**解决方案**：
```bash
# 1. 获取主设备号
MAJOR=$(awk '/gpio_led/ {print $1}' /proc/devices)

# 2. 创建设备文件
sudo mknod /dev/gpio_led c $MAJOR 0

# 3. 设置权限
sudo chmod 666 /dev/gpio_led

# 4. 验证创建
ls -l /dev/gpio_led
```

### 问题5.2：权限不足
```
open /dev/gpio_led: Permission denied
```

**解决方案**：
```bash
# 方法1：使用sudo
sudo ./gpio_led_test on

# 方法2：修改设备文件权限
sudo chmod 666 /dev/gpio_led

# 方法3：修改设备文件所有者
sudo chown $USER /dev/gpio_led

# 方法4：使用udev规则（永久生效）
echo 'KERNEL=="gpio_led", MODE="0666"' | sudo tee /etc/udev/rules.d/99-gpio-led.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## 6. 硬件连接问题

### 问题6.1：LED不亮

**故障排除流程图**：
```
LED不亮
    │
    ├── 检查电源
    │    ├── 测量GPIO电压：应有3.3V
    │    └── 测量GND连接：应为0V
    │
    ├── 检查LED极性
    │    ├── 长脚为阳极（+）
    │    └── 短脚为阴极（-）
    │
    ├── 检查电阻值
    │    ├── 典型值：220Ω-1kΩ
    │    └── 测量电阻：不应开路
    │
    ├── 检查GPIO设置
    │    ├── 确认GPIO号码正确
    │    └── 确认设置为输出
    │
    └── 测试LED单独工作
         ├── 用3.3V和GND直接测试
         └── 确认LED未损坏
```

**详细检查步骤**：
```bash
# 1. 检查GPIO输出
echo 17 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio17/direction
echo 1 > /sys/class/gpio/gpio17/value  # 应输出3.3V
echo 0 > /sys/class/gpio/gpio17/value  # 应输出0V

# 2. 使用万用表测量电压
#    GPIO输出高电平：约3.3V
#    GPIO输出低电平：约0V

# 3. 使用LED测试仪或简单电路测试LED
#    3.3V → 220Ω电阻 → LED+ → LED- → GND
```

### 问题6.2：按钮不工作

**故障排除步骤**：
1. **检查连接**
   ```
   树莓派3.3V (pin 1) → 按钮 → GPIO27 (pin 13)
   GPIO27 (pin 13) → 10kΩ电阻 → GND (pin 6)
   ```

2. **测试按钮**
   ```bash
   # 配置GPIO为输入
   echo 27 > /sys/class/gpio/export
   echo in > /sys/class/gpio/gpio27/direction
   
   # 读取按钮状态
   cat /sys/class/gpio/gpio27/value
   # 按下时应为1，释放时应为0
   ```

3. **检查上拉/下拉电阻**
   ```bash
   # 设置内部上拉电阻
   echo 27 > /sys/class/gpio/export
   echo in > /sys/class/gpio/gpio27/direction
   echo high > /sys/class/gpio/gpio27/direction  # 内部上拉
   ```

## 7. 内核调试问题

### 问题7.1：看不到printk输出
```
# dmesg没有输出驱动消息
```

**解决方案**：
```bash
# 1. 检查printk级别
#    默认只显示KERN_WARNING及以上级别
#    修改为显示所有级别
echo 8 > /proc/sys/kernel/printk

# 2. 使用适当的printk级别
printk(KERN_INFO "Message\n");    # 需要printk级别>=4
printk(KERN_DEBUG "Debug\n");     # 需要printk级别>=7

# 3. 实时查看内核消息
sudo dmesg -w

# 4. 查看完整内核日志
sudo journalctl -k
```

### 问题7.2：驱动导致系统崩溃
```
# 加载驱动后系统挂起或重启
```

**紧急恢复步骤**：
1. **使用串口控制台**（如果有）
2. **使用SSH连接**（如果网络还通）
3. **安全模式启动**：
   ```bash
   # 在启动时编辑内核参数
   # 添加：systemd.unit=rescue.target
   ```

**预防措施**：
```c
// 在驱动中添加错误检查
static int __init gpio_led_init(void)
{
    int ret;
    
    // 每一步都检查返回值
    ret = gpio_request(gpio_pin, "gpio_led");
    if (ret) {
        printk(KERN_ERR "GPIO request failed: %d\n", ret);
        return ret;  // 及时返回，避免进一步错误
    }
    
    // 使用资源管理函数
    devm_gpio_request(&pdev->dev, gpio_pin, "gpio_led");
}
```

## 8. 性能问题

### 问题8.1：GPIO操作太慢
```
# 按钮响应延迟，LED闪烁不平滑
```

**优化方案**：
```c
// 1. 减少内核-用户空间切换
//    批量操作GPIO，避免频繁write/read

// 2. 使用GPIO库的快速函数
gpio_set_value(gpio_pin, 1);  // 直接设置值
gpio_get_value(gpio_pin);     // 直接读取值

// 3. 避免不必要的延迟
//    减少usleep/sleep调用
//    使用硬件定时器或高精度定时器

// 4. 考虑使用中断代替轮询（对于按钮）
request_irq(gpio_to_irq(gpio_pin), button_handler,
           IRQF_TRIGGER_RISING | IRQF_TRIGGER_FALLING,
           "gpio_button", NULL);
```

### 问题8.2：驱动占用过多CPU
```
# top显示驱动进程CPU使用率高
```

**检查方法**：
```bash
# 查看系统负载
top
htop

# 查看中断统计
cat /proc/interrupts

# 查看进程统计
pidstat -u 1
```

**优化建议**：
1. **减少轮询频率**
2. **使用等待队列替代忙等待**
3. **合理使用锁，避免死锁**
4. **考虑使用工作队列处理长时间任务**

## 9. 常见错误代码及含义

| 错误代码 | 宏定义 | 含义 | 常见原因 |
|---------|--------|------|---------|
| -1 | -EPERM | 操作不允许 | 权限不足，没有root权限 |
| -2 | -ENOENT | 文件或目录不存在 | 设备文件未创建 |
| -5 | -EIO | 输入输出错误 | 硬件故障，GPIO访问失败 |
| -6 | -ENXIO | 设备或地址不存在 | GPIO编号无效 |
| -11 | -EAGAIN | 资源暂时不可用 | 非阻塞操作，数据未就绪 |
| -12 | -ENOMEM | 内存不足 | 内核内存分配失败 |
| -13 | -EACCES | 权限拒绝 | 设备文件权限错误 |
| -14 | -EFAULT | 地址错误 | 用户空间内存访问错误 |
| -16 | -EBUSY | 设备或资源忙 | GPIO已被占用 |
| -19 | -ENODEV | 设备不存在 | 模块未加载或设备未注册 |
| -22 | -EINVAL | 无效参数 | GPIO参数错误，方向设置失败 |

**错误处理示例**：
```c
ssize_t gpio_write(struct file *file, const char __user *buf,
                   size_t len, loff_t *offset)
{
    char value;
    
    // 检查参数有效性
    if (len != 1)
        return -EINVAL;  // 无效参数
    
    if (copy_from_user(&value, buf, 1))
        return -EFAULT;  // 地址错误
    
    if (value != '0' && value != '1')
        return -EINVAL;  // 无效参数
    
    // GPIO操作
    if (!gpio_is_valid(gpio_pin))
        return -ENXIO;   // 设备不存在
    
    // ... 其他操作
}
```

## 10. 高级调试技巧

### 10.1 使用GDB调试内核模块
```bash
# 1. 编译带调试信息的模块
# 在Makefile中添加：
EXTRA_CFLAGS += -g -O0

# 2. 启动KGDB（需要串口连接）
# 在内核参数添加：
kgdboc=ttyS0,115200 kgdbwait

# 3. 使用GDB连接
gdb vmlinux
(gdb) target remote /dev/ttyS0
```

### 10.2 使用SystemTap动态追踪
```bash
# 安装SystemTap
sudo apt install systemtap systemtap-sdt-dev

# 编写跟踪脚本
# gpio_trace.stp:
probe module("gpio_led").function("gpio_write")
{
    printf("gpio_write called: arg1=%d\n", $len);
}

# 运行跟踪
sudo stap gpio_trace.stp
```

### 10.3 使用Ftrace内核跟踪
```bash
# 启用Ftrace
sudo mount -t debugfs debugfs /sys/kernel/debug

# 设置跟踪函数
echo gpio_write > /sys/kernel/debug/tracing/set_ftrace_filter
echo function > /sys/kernel/debug/tracing/current_tracer

# 开始跟踪
echo 1 > /sys/kernel/debug/tracing/tracing_on

# 执行测试操作
echo '1' > /dev/gpio_led

# 查看跟踪结果
cat /sys/kernel/debug/tracing/trace
```

## 11. 树莓派特定问题

### 问题11.1：GPIO编号混淆
**解决方案**：
- **BCM编号**：Broadcom芯片引脚编号（本实验使用）
- **物理编号**：板子上的物理引脚位置
- **WiringPi编号**：WiringPi库使用的编号

**转换表（部分）**：
| BCM编号 | 物理引脚 | WiringPi | 功能 |
|---------|----------|----------|------|
| 17 | 11 | 0 | GPIO |
| 27 | 13 | 2 | GPIO |
| 22 | 15 | 3 | GPIO |
| 5 | 29 | 21 | GPIO |

**参考网站**：https://pinout.xyz/

### 问题11.2：电压和电流限制
- **逻辑电平**：3.3V（5V会损坏树莓派！）
- **最大输出电流**：16mA/引脚，50mA/全部GPIO总和
- **建议操作电流**：≤8mA/引脚

**保护措施**：
```bash
# 使用串联电阻限制电流
# LED典型电路：3.3V → 220Ω → LED → GND
# 计算电阻：R = (3.3V - V_led) / I_led
# 假设V_led=2.0V, I_led=10mA
# R = (3.3-2.0)/0.01 = 130Ω，使用220Ω更安全
```

## 12. 获取更多帮助

### 官方资源
- **树莓派论坛**：https://www.raspberrypi.org/forums/
- **Linux内核文档**：/usr/src/linux/Documentation/
- **内核邮件列表**：kernelnewbies.org

### 调试工具清单
```bash
# 基本调试工具
dmesg          # 内核消息
lsmod          # 已加载模块
modinfo        # 模块信息
strace         # 系统调用跟踪
lsof           # 打开文件列表

# 硬件调试工具
gpio           # 树莓派GPIO命令行工具
raspi-gpio     # 官方GPIO工具
i2c-tools      # I2C总线调试
spi-tools      # SPI总线调试

# 性能分析工具
perf           # 性能分析
vmstat         # 虚拟内存统计
iostat         # IO统计
sar            # 系统活动报告
```

### 最小化测试
如果问题复杂，尝试最小化测试：
```c
// minimal.c - 最小化驱动测试
#include <linux/module.h>
static int __init test_init(void) {
    printk(KERN_INFO "Minimal test\n");
    return 0;
}
static void __exit test_exit(void) {
    printk(KERN_INFO "Minimal exit\n");
}
module_init(test_init);
module_exit(test_exit);
```

**记住**：驱动开发需要耐心，一步步调试，从简单到复杂，逐步添加功能并测试。

---

## 故障排除检查表

### 加载驱动前检查
- [ ] 内核头文件已安装
- [ ] gcc编译器已安装
- [ ] 有root权限
- [ ] 硬件正确连接
- [ ] GPIO引脚空闲

### 编译时检查
- [ ] Makefile语法正确
- [ ] 内核路径正确
- [ ] 头文件存在
- [ ] 编译无错误

### 加载时检查
- [ ] 使用sudo加载
- [ ] 设备号不冲突
- [ ] GPIO未占用
- [ ] 查看dmesg输出

### 运行时检查
- [ ] 设备文件存在
- [ ] 设备文件有权限
- [ ] GPIO方向设置正确
- [ ] 硬件工作正常

### 卸载时检查
- [ ] 释放所有资源
- [ ] 删除设备文件
- [ ] 清理GPIO状态
- [ ] 查看dmesg确认

如果所有检查都通过但问题仍然存在，考虑在论坛或邮件列表中提问，提供以下信息：
1. 完整的错误信息
2. dmesg输出
3. 内核版本（uname -a）
4. 硬件连接图
5. 已尝试的解决方法

**祝调试顺利！**

---