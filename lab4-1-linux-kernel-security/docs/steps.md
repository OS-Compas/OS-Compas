```markdown
# 实验4.1详细步骤指南

## 实验概述

本实验分为四个主要阶段，预计总耗时4-6小时：

1. **环境准备阶段**（30分钟）：安装必要的工具和依赖
2. **内核编译阶段**（2-3小时）：编译启用安全特性的内核
3. **特性测试阶段**（1小时）：测试SELinux和KASAN功能
4. **分析报告阶段**（30分钟）：分析结果并完成实验报告

## 阶段一：环境准备（30分钟）

### 步骤1.1：系统信息检查

```bash
# 检查当前系统信息
uname -a
cat /etc/os-release
free -h
df -h /

# 记录以下信息：
# - 内核版本
# - 发行版版本
# - 可用内存
# - 磁盘空间
预期输出示例：

text
Linux ubuntu 5.4.0-generic #1 SMP ...
Ubuntu 20.04.3 LTS
Mem: 7.8Gi total, 1.2Gi used
/dev/sda1       50G   15G   33G  31% /
步骤1.2：安装基础依赖
bash
# 更新系统包列表
sudo apt update

# 安装编译工具链
sudo apt install -y build-essential git curl wget

# 安装内核编译依赖
sudo apt install -y \
    libncurses-dev \
    libssl-dev \
    bc \
    flex \
    bison \
    libelf-dev \
    dwarves
步骤1.3：获取实验代码
bash
# 创建实验目录
mkdir -p ~/kernel-security-lab
cd ~/kernel-security-lab

# 如果从git仓库获取
git clone https://github.com/your-lab/lab4-1-kernel-security.git
cd lab4-1-kernel-security

# 或者直接使用提供的文件

# 赋予执行权限
chmod +x scripts/*.sh
chmod +x src/*.sh
步骤1.4：运行环境准备脚本
bash
# 运行自动化环境准备
sudo ./scripts/setup_environment.sh

# 脚本将自动：
# 1. 安装所有必要依赖
# 2. 配置SELinux工具
# 3. 设置审计系统
# 4. 创建测试用户
# 5. 配置环境变量
脚本执行后验证：

bash
# 验证关键工具安装
gcc --version
make --version
git --version

# 验证SELinux工具
which sestatus
which getenforce
which auditctl

# 运行测试脚本
./scripts/test_all.sh
阶段二：内核编译（2-3小时）
步骤2.1：选择内核版本
bash
# 运行内核编译脚本
sudo ./scripts/build_kernel.sh

# 脚本将提示选择内核版本，建议选择：
# - 5.15.x (LTS版本，稳定性好)
# - 6.1.x (较新LTS版本)
步骤2.2：配置内核选项
脚本将启动 make menuconfig 界面：

text
┌───────────────────────── Linux Kernel Configuration ──────────────────────────┐
│  Arrow keys navigate the menu.  <Enter> selects submenus ---> (or empty      │
│  submenus ----).  Highlighted letters are hotkeys.  Pressing <Y> includes,   │
│  <N> excludes, <M> modularizes features.  Press <Esc><Esc> to exit, <?> for  │
│  Help, </> for Search.  Legend: [*] built-in  [ ] excluded  <M> module  < >  │
│ ┌──────────────────────────────────────────────────────────────────────────┐ │
│ │        [*] 64-bit kernel                                                 │ │
│ │        [*] Enable loadable module support  --->                          │ │
│ │        [*] Enable the block layer  --->                                  │ │
│ │        -*- Support for large (2TB+) block devices and files              │ │
│ │            General setup  --->                                           │ │
│ │        [*] Enable loadable module support  --->                          │ │
│ │        [*] Module versioning support                                     │ │
│ │        [*] Source checksum for all modules                               │ │
│ │            -*- Enable the block layer  --->                              │ │
│ │            Processor type and features  --->                             │ │
│ │            Power management and ACPI options  --->                       │ │
│ │            Firmware Drivers  --->                                        │ │
│ │            Virtualization  --->                                          │ │
│ │            General architecture-dependent options  --->                  │ │
│ │            Bus options (PCI etc.)  --->                                  │ │
│ │            Binary Emulations  --->                                       │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
│    <Select>    < Exit >    < Help >    < Save >    < Load >                  │
└──────────────────────────────────────────────────────────────────────────────┘
必须启用的安全选项：

进入 Security options → Enable different security models

启用 SELinux Support

启用 Enable SELinux boot parameter

进入 Kernel hacking → Memory Debugging

启用 KASAN: runtime memory debugger

选择 KASAN mode → Generic (full-featured)

启用 KASAN inline instrumentation

步骤2.3：开始编译
bash
# 脚本将自动开始编译，输出类似：
[1/8] Installing dependencies...
[2/8] Downloading kernel source...
[3/8] Preparing build directory...
[4/8] Configuring kernel with security features...
[5/8] Compiling kernel (this may take 30-90 minutes)...
[6/8] Installing new kernel...
[7/8] Updating boot configuration...
[8/8] Build completed successfully!
编译过程监控：

bash
# 查看编译进度（另一个终端）
tail -f logs/kernel_compile.log

# 查看系统资源使用
htop
watch -n 5 'ps aux | grep make | grep -v grep'
步骤2.4：安装并重启
bash
# 编译完成后，脚本会提示重启
# 选择"y"重启系统
sudo reboot

# 在GRUB菜单中选择新内核
# 通常是最上面的条目，标注有版本号和日期
步骤2.5：验证新内核
bash
# 系统启动后，验证新内核
uname -r
# 应显示自定义编译的版本，如：5.15.0-custom

# 检查内核配置
zcat /proc/config.gz | grep -E "(SELINUX|KASAN)"

# 应看到：
# CONFIG_SECURITY_SELINUX=y
# CONFIG_KASAN=y
# CONFIG_KASAN_GENERIC=y
阶段三：安全特性测试（1小时）
步骤3.1：SELinux基础配置
bash
# 运行SELinux配置脚本
sudo ./scripts/enable_selinux.sh

# 脚本将：
# 1. 检查SELinux支持
# 2. 安装SELinux策略
# 3. 设置为Permissive模式
# 4. 配置审计系统
# 5. 创建测试环境
步骤3.2：SELinux状态验证
bash
# 验证SELinux状态
sestatus

# 预期输出：
# SELinux status:                 enabled
# SELinuxfs mount:                /sys/fs/selinux
# SELinux root directory:         /etc/selinux
# Loaded policy name:             targeted
# Current mode:                   permissive
# Mode from config file:          permissive
# ...

# 检查当前模式
getenforce
# 应返回：Permissive
步骤3.3：SELinux功能测试
bash
# 编译并运行SELinux测试程序
cd src
gcc selinux_test.c -o selinux_test
./selinux_test all

# 测试程序将执行：
# 1. 系统信息检查
# 2. SELinux状态检查
# 3. 文件上下文测试
# 4. 权限检查
# 5. 审计日志检查
步骤3.4：创建SELinux测试场景
bash
# 进入测试目录
cd /selinux_test

# 查看测试文件
ls -laZ

# 运行违反策略的测试
./violation_test.sh

# 观察输出，应该看到：
# - 某些操作被允许（permissive模式）
# - 审计日志记录
步骤3.5：分析SELinux审计日志
bash
# 查看最近的SELinux拒绝信息
sudo ausearch -m avc -ts recent

# 使用sealert分析日志
sudo sealert -a /var/log/audit/audit.log

# 预期看到类似：
# SELinux is preventing /usr/bin/touch from write access on the file ...
# *****  Plugin catchall (100. confidence) suggests  **************************
# ...
步骤3.6：KASAN功能测试
bash
# 运行KASAN测试脚本
sudo ./scripts/test_kasan.sh

# 脚本将：
# 1. 检查KASAN支持
# 2. 编译测试模块
# 3. 运行安全操作测试
# 4. 运行内存错误测试
# 5. 生成测试报告
步骤3.7：手动KASAN测试
bash
# 进入源码目录
cd src

# 编译KASAN测试模块
make

# 测试安全操作（不应触发错误）
sudo insmod kasan_module.ko test_mode=0 debug=1
sudo rmmod kasan_module

# 测试越界访问（应触发KASAN）
sudo insmod kasan_module.ko test_mode=1 debug=1 panic_on_error=0
sudo rmmod kasan_module

# 检查内核日志
dmesg | tail -30 | grep -i kasan
步骤3.8：验证KASAN错误报告
bash
# 查看详细的KASAN报告
dmesg | grep -A 10 -B 5 "KASAN"

# 预期看到类似：
# ==================================================================
# BUG: KASAN: slab-out-of-bounds in kasan_module_init+0xXX/0xXXX
# Write of size 1 at addr ffff88800abcdef0 by task insmod/1234
# 
# The buggy address belongs to the object at ffff88800abcdef0
#  which belongs to the cache kmalloc-16 of size 16
# ...
阶段四：分析与报告（30分钟）
步骤4.1：收集实验数据
bash
# 收集系统信息
uname -a > ~/experiment_results.txt
sestatus >> ~/experiment_results.txt

# 收集KASAN配置
zcat /proc/config.gz | grep -E "(KASAN|DEBUG)" >> ~/experiment_results.txt

# 收集测试日志
tail -50 /var/log/audit/audit.log >> ~/experiment_results.txt
dmesg | grep -i kasan >> ~/experiment_results.txt
步骤4.2：性能影响测试
bash
# 测试系统调用性能（可选）
sudo apt install -y sysbench

# 测试内存性能
sysbench memory --memory-block-size=1K --memory-total-size=10G run

# 测试CPU性能
sysbench cpu --cpu-max-prime=20000 run

# 记录结果，与原始内核对比
步骤4.3：回答思考问题
根据实验观察，回答以下问题：

SELinux是基于"自主访问控制"还是"强制访问控制"？它与传统的Unix文件权限有何本质区别？

内核编译是一个复杂且耗时的过程，可能遇到哪些常见问题？

步骤4.4：完成实验报告
创建实验报告，包含以下部分：

实验信息

姓名、学号、实验日期

实验环境（硬件、软件版本）

实验过程记录

各步骤执行情况

遇到的问题和解决方案

关键命令和输出截图

测试结果分析

SELinux测试结果

KASAN测试结果

性能影响分析

思考问题回答

问题1详细回答

问题2详细回答

实验总结

学到的主要知识点

遇到的难点和解决方法

对内核安全的新认识

步骤4.5：清理环境（可选）
bash
# 如果需要恢复原始内核
sudo update-grub
# 重启并选择原始内核

# 恢复SELinux设置（如果需要）
sudo setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# 清理编译文件
sudo rm -rf /usr/src/linux-*
sudo rm -rf ~/kernel-security-lab/build
常见问题解决
问题1：编译过程中内存不足
症状：编译被杀死，dmesg显示OOM killer

解决方案：

bash
# 增加交换空间
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 减少编译并发数
# 编辑脚本，将 make -j$(nproc) 改为 make -j2
问题2：系统无法启动新内核
症状：重启后卡住或进入紧急模式

解决方案：

重启选择旧内核

检查日志：journalctl -xb

常见原因：

缺少initramfs：sudo update-initramfs -u -k 新内核版本

驱动缺失：重新配置内核，启用更多驱动

问题3：SELinux阻止正常操作
症状：正常程序无法运行

解决方案：

bash
# 临时设置为permissive模式
sudo setenforce 0

# 分析并修复策略
sudo sealert -a /var/log/audit/audit.log

# 创建允许规则
sudo audit2allow -a -M mypolicy
sudo semodule -i mypolicy.pp
问题4：KASAN导致系统过慢
症状：系统响应极慢

解决方案：

bash
# 这是预期行为，KASAN会显著降低性能
# 测试完成后，重启到非KASAN内核
# 或编译新内核时禁用KASAN
扩展任务
任务1：编写自定义SELinux策略
bash
# 1. 分析现有策略
sesearch -A | grep httpd

# 2. 编写策略模块
vim /etc/selinux/mypolicy.te

# 3. 编译策略
make -f /usr/share/selinux/devel/Makefile mypolicy.pp

# 4. 安装策略
semodule -i mypolicy.pp
任务2：测试更多内存错误类型
修改 kasan_module.c，添加：

栈溢出测试

整数溢出测试

初始化前使用测试

任务3：性能对比测试
比较：

无安全特性的内核

仅SELinux的内核

仅KASAN的内核

全安全特性的内核

实验成功标准
✅ 成功编译并启动新内核

✅ SELinux正确启用并测试

✅ KASAN正确检测内存错误

✅ 完整记录实验过程

✅ 正确回答思考问题

✅ 完成实验报告

注意事项
⚠️ 安全警告：

不要在生产环境进行本实验

编译前备份重要数据

确保电源稳定

准备好系统恢复方案

⏰ 时间管理：

内核编译可能耗时2-3小时

合理安排时间，避免中断

可以在编译期间学习理论部分

📚 学习建议：

理解原理而不仅是步骤

记录遇到的每个问题和解决过程

查阅官方文档和社区资源

与同学讨论交流