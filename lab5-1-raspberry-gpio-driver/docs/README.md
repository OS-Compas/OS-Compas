# 实验5.1：树莓派GPIO设备驱动

## 实验简介

本实验通过在树莓派上编写、编译和加载一个字符设备驱动，实现对GPIO引脚的控制，点亮一个LED灯。通过本实验，学生将掌握Linux设备驱动开发的基本流程，理解字符设备驱动的工作原理。

## 实验目标

- 理解Linux字符设备驱动的基本架构
- 掌握GPIO控制的内核API使用
- 实现file_operations结构体的基本操作
- 学习用户空间与内核空间的通信机制
- 掌握树莓派上的驱动开发和测试流程

## 环境要求

### 硬件要求
- 树莓派（任何型号）
- LED灯一个
- 220Ω电阻一个
- 杜邦线若干
- 可选：按钮开关一个（用于扩展挑战）

### 软件要求
- 树莓派操作系统（Raspbian/Raspberry Pi OS）
- Linux内核头文件
- GCC编译器
- root权限

## 硬件连接

### 基本连接（LED控制）
树莓派 GPIO17（物理引脚11） → 220Ω电阻 → LED长脚（阳极）
LED短脚（阴极） → 树莓派 GND（物理引脚6）

text

### 扩展连接（按钮输入）
树莓派 GPIO27（物理引脚13） → 按钮一端
按钮另一端 → 树莓派 3.3V（物理引脚1）
树莓派 GPIO27（物理引脚13） → 10kΩ下拉电阻 → GND

text

## 快速开始

### 1. 环境准备
```bash
# 更新系统
sudo apt update
sudo apt upgrade -y

# 安装内核头文件
sudo apt install raspberrypi-kernel-headers

# 安装构建工具
sudo apt install build-essential
2. 构建驱动
bash
cd src
make
3. 加载驱动
bash
# 加载驱动模块
sudo insmod gpio_led.ko

# 创建设备节点
sudo mknod /dev/gpio_led c $(awk '/gpio_led/ {print $1}' /proc/devices) 0
sudo chmod 666 /dev/gpio_led
4. 测试驱动
bash
# 编译测试程序
gcc -o gpio_led_test gpio_led_test.c

# 测试LED控制
./gpio_led_test on    # 点亮LED
./gpio_led_test off   # 熄灭LED
./gpio_led_test blink # LED闪烁
5. 卸载驱动
bash
sudo rmmod gpio_led
sudo rm /dev/gpio_led
实验内容详解
代码结构
gpio_led.c - 主驱动代码，实现字符设备驱动

Makefile - 内核模块构建配置

gpio_led_test.c - 用户空间测试程序

关键概念
字符设备驱动 - 以字节流方式访问的设备

file_operations - 驱动操作函数集合

设备号管理 - major/minor设备编号

GPIO控制 - gpio_request, gpio_direction_output等API

用户-内核数据交换 - copy_from_user, copy_to_user

驱动工作流程
模块初始化：分配设备号、创建设备类、注册字符设备

GPIO初始化：请求GPIO、设置方向

实现操作函数：open、release、write、read

用户空间访问：通过设备文件进行控制

模块清理：释放所有资源

实验步骤
步骤1：环境准备
验证树莓派内核版本，安装必要工具包。

步骤2：硬件连接
按照电路图正确连接LED和电阻。

步骤3：代码理解
阅读并理解驱动代码中的关键部分。

步骤4：编译驱动
使用Makefile编译生成.ko文件。

步骤5：加载测试
加载驱动并测试基本功能。

步骤6：扩展实验
尝试修改代码，添加新功能。

故障排除
常见问题及解决方案请参考 troubleshooting.md。

思考问题
为什么用户程序不能直接操作GPIO的物理地址，而必须通过内核驱动？

字符设备驱动与平台设备驱动有何关联与区别？

扩展挑战
添加读取GPIO输入引脚的功能（按钮）

支持多个GPIO引脚控制

实现PWM控制实现LED亮度调节

添加sysfs接口支持

实现中断处理（按钮去抖动）

参考资源
Linux Device Drivers, 3rd Edition

Raspberry Pi GPIO Documentation

Linux Kernel GPIO API