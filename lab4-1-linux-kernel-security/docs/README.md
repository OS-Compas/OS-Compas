# 实验4.1：为Linux内核实现一个简单的安全特性

## 实验简介

本实验通过编译自定义Linux内核并启用安全增强特性（SELinux和KASAN），让学生掌握内核安全配置、编译和测试的基本流程。实验涵盖从内核源码获取、配置、编译到安全特性测试的全过程。

## 实验目标

- 理解Linux内核安全机制的基本概念
- 掌握内核配置和编译的完整流程
- 学习启用和测试SELinux强制访问控制
- 了解KASAN内存错误检测工具的使用
- 培养内核级故障排除能力
- 理解安全特性对系统性能的影响

## 实验环境要求

### 硬件要求
- 至少20GB可用磁盘空间
- 4GB以上可用内存
- 多核CPU（推荐4核以上）
- 稳定的网络连接

### 软件要求
- Linux操作系统（Ubuntu 20.04+ / CentOS 8+ 推荐）
- GCC编译器及相关构建工具
- Git版本控制工具
- 终端模拟器

### 权限要求
- root权限（用于内核编译和模块加载）
- 稳定的电源供应（编译过程耗时较长）


## 快速开始

### 步骤1：环境准备

```bash
# 克隆实验仓库（如果是远程仓库）
git clone <repository-url>
cd lab4-1-linux-kernel-security

# 或者直接使用提供的文件

# 赋予执行权限
chmod +x scripts/*.sh
chmod +x src/*.sh

# 运行环境准备脚本（需要root权限）
sudo ./scripts/setup_environment.sh

步骤2：内核编译（启用安全特性）
bash
# 运行内核编译脚本（需要1-3小时，取决于硬件）
sudo ./scripts/build_kernel.sh

# 或者使用分步编译
sudo ./src/kernel_build.sh
步骤3：重启到新内核
bash
# 重启系统
sudo reboot

# 在GRUB菜单中选择新编译的内核
# 通常是最新的或第一个条目

# 验证新内核
uname -r
# 应该显示自定义版本号
步骤4：启用和测试SELinux
bash
# 启用SELinux
sudo ./scripts/enable_selinux.sh

# 运行SELinux测试程序
cd src
gcc selinux_test.c -o selinux_test -lselinux
./selinux_test all
步骤5：测试KASAN
bash
# 运行KASAN测试
sudo ./scripts/test_kasan.sh

# 或者手动测试
cd src
make  # 编译测试模块
sudo insmod kasan_module.ko test_mode=1 debug=1
dmesg | tail -30
sudo rmmod kasan_module
实验内容详解
1. 内核安全特性
SELinux (Security-Enhanced Linux)
类型：强制访问控制(MAC)系统

原理：基于安全策略的访问控制，默认拒绝原则

模式：Disabled（禁用）、Permissive（许可）、Enforcing（强制）

测试：通过尝试违反策略的操作，观察审计日志

KASAN (Kernel Address SANitizer)
类型：动态内存错误检测工具

检测范围：越界访问、使用后释放、双重释放等

性能影响：约2倍内存开销，1.5-2倍速度下降

用途：开发调试，不适合生产环境

2. 实验模块
内核编译模块 (kernel_build.sh)
自动化内核下载、配置、编译、安装

集成安全特性配置片段

提供编译进度和错误处理

SELinux测试模块 (selinux_test.c)
系统信息收集

SELinux状态检查

文件上下文测试

权限验证

审计日志分析

KASAN测试模块 (kasan_module.c)
安全内存操作（基线测试）

越界访问测试

使用后释放测试

双重释放测试

可配置测试模式

实验步骤详情
阶段一：环境准备（30分钟）
系统更新和依赖安装

SELinux工具安装

开发环境配置

审计系统设置

阶段二：内核编译（1-3小时）
内核源码获取

安全特性配置

内核编译

模块编译

系统安装

阶段三：特性测试（1小时）
SELinux启用和配置

强制访问控制测试

KASAN功能验证

内存错误检测

阶段四：结果分析（30分钟）
日志分析

性能评估

实验报告撰写

思考问题
问题1：SELinux访问控制类型
SELinux是基于"自主访问控制"还是"强制访问控制"？它与传统的Unix文件权限有何本质区别？

SELinux基于强制访问控制(MAC)

传统Unix权限是自主访问控制(DAC)

本质区别：

DAC由资源所有者控制权限（用户决定谁可以访问）

MAC由系统策略控制（策略决定访问权限，用户无法覆盖）

DAC基于用户身份，MAC基于安全上下文

DAC简单但脆弱，MAC复杂但安全

问题2：内核编译常见问题
内核编译是一个复杂且耗时的过程，可能遇到哪些常见问题？

依赖缺失：缺少头文件、库文件或工具链

配置冲突：选项不兼容或依赖关系错误

编译错误：代码错误、版本不兼容

资源不足：磁盘空间、内存不足

引导问题：GRUB配置错误、initramfs问题

硬件兼容性：驱动缺失或不支持

时间消耗：编译耗时过长，系统无响应

网络问题：源码下载失败

扩展挑战
挑战1：深入SELinux策略编写
编写自定义SELinux策略模块，允许特定程序访问通常被拒绝的资源。

步骤：

分析现有策略

编写策略模块(.te文件)

编译策略模块(.pp文件)

安装和测试策略

分析审计日志

挑战2：KASAN高级测试
创建更复杂的内存错误场景，测试KASAN的检测能力极限。

场景：

栈溢出与堆溢出对比

内存泄漏检测

初始化前使用检测

竞争条件导致的内存错误

挑战3：集成其他安全特性
研究并启用以下安全特性之一：

LSM框架：了解Linux安全模块架构

AppArmor：配置基于路径的MAC系统

SMAP/SMEP：防止内核态执行用户空间代码

内核堆栈保护：防止栈溢出攻击

控制流完整性：防止代码重用攻击

安全注意事项
⚠️ 重要警告：

内核编译风险：编译错误的内核可能导致系统无法启动

测试环境：始终在虚拟机或测试机上操作

数据备份：编译前备份重要数据

电源稳定：确保编译过程中不断电

生产环境：不要在生产服务器上直接测试

故障排除
常见问题及解决方案请参考 troubleshooting.md。

主要问题包括：

编译失败处理

系统无法启动

SELinux配置问题

KASAN测试问题

性能问题分析

参考资源
官方文档
Linux Kernel Documentation

SELinux Project Wiki

Kernel SANitizers (KASAN)

学习资源
Linux Kernel Build Guide

SELinux Coloring Book

Linux Kernel Teaching

社区支持
Kernel Newbies

Stack Exchange

Linux Kernel Mailing List
