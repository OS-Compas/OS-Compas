```markdown
# 树莓派GPIO设备驱动理论基础

## 1. Linux设备驱动模型

### 1.1 设备驱动分类
- **字符设备**：以字节流方式访问，如GPIO、串口
- **块设备**：以数据块方式访问，如硬盘、SD卡
- **网络设备**：面向数据包，如以太网、WiFi

### 1.2 设备号
- **主设备号**：标识设备类型
- **次设备号**：标识同一类型的不同设备
- 动态分配：`alloc_chrdev_region`
- 静态分配：`register_chrdev_region`

## 2. 字符设备驱动架构

### 2.1 核心数据结构
```c
struct file_operations {
    struct module *owner;
    int (*open)(struct inode *, struct file *);
    int (*release)(struct inode *, struct file *);
    ssize_t (*read)(struct file *, char __user *, size_t, loff_t *);
    ssize_t (*write)(struct file *, const char __user *, size_t, loff_t *);
    // ... 其他操作
};
2.2 驱动注册流程
分配设备号

初始化cdev结构

添加cdev到系统

创建设备类

创建设备文件

3. 树莓派GPIO编程
3.1 GPIO编号系统
BCM编号：Broadcom引脚编号（本实验使用）

物理编号：引脚物理位置编号

WiringPi编号：WiringPi库使用的编号

3.2 内核GPIO API
c
// 基本操作
int gpio_request(unsigned gpio, const char *label);
void gpio_free(unsigned gpio);
int gpio_direction_input(unsigned gpio);
int gpio_direction_output(unsigned gpio, int value);

// 读写操作
int gpio_get_value(unsigned gpio);
void gpio_set_value(unsigned gpio, int value);
3.3 树莓派GPIO特性
3.3V逻辑电平

可配置上拉/下拉电阻

部分引脚支持PWM、SPI、I2C等复用功能

4. 用户空间与内核空间通信
4.1 数据拷贝函数
c
// 用户空间 -> 内核空间
copy_from_user(void *to, const void __user *from, unsigned long n);

// 内核空间 -> 用户空间
copy_to_user(void __user *to, const void *from, unsigned long n);
4.2 权限控制
设备文件权限：通过chmod设置

驱动权限检查：在open函数中实现

5. 安全注意事项
5.1 输入验证
所有用户输入必须验证

检查参数范围

防止缓冲区溢出

5.2 资源管理
申请的资源必须释放

错误处理要完整

防止竞态条件

5.3 电气安全
树莓派GPIO最大电流：16mA/引脚，50mA/全部

必须使用限流电阻

避免短路

6. 调试技巧
6.1 内核调试
bash
# 查看内核消息
dmesg
dmesg -w  # 实时查看

# 查看模块信息
lsmod
modinfo module_name

# 查看设备号
cat /proc/devices
6.2 用户空间调试
bash
# 查看设备文件
ls -l /dev/gpio_led

# 直接操作设备
echo '1' > /dev/gpio_led
cat /dev/gpio_led
7. 性能考虑
7.1 延迟控制
GPIO操作延迟：微秒级

上下文切换开销：避免频繁切换

中断vs轮询：根据需求选择

7.2 功耗管理
未使用的GPIO设为输入

关闭不需要的功能

考虑睡眠模式

8. 扩展知识
8.1 设备树（Device Tree）
描述硬件信息

树莓派使用设备树

支持硬件抽象

8.2 平台设备驱动
针对特定硬件平台

与设备树配合使用

更好的硬件抽象

8.3 Sysfs接口
通过文件系统暴露设备信息

便于用户空间访问

标准化接口

text

### 3. **docs/troubleshooting.md** - 故障排除

```markdown
# 故障排除指南

## 常见问题及解决方案

### 1. 编译问题

#### 问题1：找不到内核头文件
错误：/lib/modules/xxx/build: No such file or directory

text

**解决方案**：
```bash
# 安装内核头文件
sudo apt update
sudo apt install raspberrypi-kernel-headers

# 或者安装完整内核源码
sudo apt install linux-source

# 检查内核版本
uname -r
ls /lib/modules/
问题2：编译错误
text
错误：隐式函数声明
解决方案：

检查是否包含必要的头文件

确认内核版本兼容性

检查Makefile中的内核路径

2. 模块加载问题
问题1：insmod失败
text
insmod: ERROR: could not insert module: Operation not permitted
解决方案：

bash
# 使用sudo权限
sudo insmod gpio_led.ko

# 检查模块依赖
modinfo gpio_led.ko
问题2：设备号冲突
text
insmod: ERROR: could not insert module: Device or resource busy
解决方案：

bash
# 查看已占用的设备号
cat /proc/devices

# 卸载冲突模块
sudo rmmod conflicting_module

# 或者使用动态分配
alloc_chrdev_region(&dev_num, 0, 1, DEVICE_NAME);
3. GPIO操作问题
问题1：GPIO请求失败
text
GPIO_LED: Failed to request GPIO17
解决方案：

bash
# 检查GPIO是否已被占用
ls /sys/class/gpio/

# 查看GPIO状态
cat /sys/kernel/debug/gpio

# 释放被占用的GPIO
echo 17 > /sys/class/gpio/unexport
问题2：GPIO方向设置失败
text
GPIO_LED: Failed to set GPIO17 as output
解决方案：

确认GPIO引脚可用作GPIO

检查是否被其他功能复用

确认引脚编号正确（BCM编号）

4. 设备文件问题
问题1：设备文件不存在
text
open /dev/gpio_led: No such file or directory
解决方案：

bash
# 获取主设备号
awk '/gpio_led/ {print $1}' /proc/devices

# 创建设备文件
sudo mknod /dev/gpio_led c [major] 0

# 设置权限
sudo chmod 666 /dev/gpio_led
问题2：权限不足
text
open /dev/gpio_led: Permission denied
解决方案：

bash
# 修改设备文件权限
sudo chmod 666 /dev/gpio_led

# 或者将用户加入相关组
sudo usermod -aG gpio $USER
5. 硬件连接问题
问题1：LED不亮
检查步骤：

确认电源连接正确

检查LED极性（长脚为正极）

确认电阻值合适（220Ω-1kΩ）

测量GPIO电压

测试LED单独工作

问题2：按钮不响应
检查步骤：

确认按钮连接正确

检查上拉/下拉电阻

确认GPIO设置为输入

测量按钮按下时的电压

6. 调试技巧
查看内核消息
bash
# 查看所有内核消息
dmesg

# 查看最后20条消息
dmesg | tail -20

# 过滤相关消息
dmesg | grep -i gpio
dmesg | grep -i led

# 实时查看
sudo dmesg -w
检查系统状态
bash
# 查看加载的模块
lsmod

# 查看设备文件
ls -l /dev/gpio_led

# 查看GPIO状态
cat /sys/kernel/debug/gpio
用户空间测试
bash
# 直接写入设备文件
echo '1' > /dev/gpio_led
echo '0' > /dev/gpio_led

# 读取设备文件
cat /dev/gpio_led

# 使用测试程序
./gpio_led_test status
./gpio_led_test on
./gpio_led_test read
7. 高级问题
问题1：竞态条件
现象：多进程访问时出现不一致结果

解决方案：

使用互斥锁（mutex）

使用信号量（semaphore）

实现适当的同步机制

问题2：内存泄漏
现象：系统内存逐渐减少

解决方案：

确保所有kmalloc都有对应的kfree

使用devm_系列函数自动管理资源

检查错误路径的资源释放

问题3：内核崩溃（Oops）
现象：系统挂起或重启

解决方案：

bash
# 查看Oops信息
dmesg | grep -A 10 -B 5 oops

# 检查栈跟踪
dmesg | grep -i stack

# 分析问题原因
# 1. 空指针解引用
# 2. 内存访问越界
# 3. 未初始化指针
8. 性能优化
问题：GPIO操作延迟过大
解决方案：

使用GPIO库的批量操作

避免频繁的用户-内核切换

考虑使用mmap映射内存

联系支持
如果问题仍无法解决：

查看内核文档：/usr/src/linux/Documentation/

查阅在线资源：Raspberry Pi官方论坛

检查硬件问题：使用万用表测量电路

简化测试：使用最简代码复现问题