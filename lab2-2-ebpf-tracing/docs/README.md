# 实验2.2：使用eBPF跟踪内核函数

## 实验简介

本实验通过eBPF（扩展的伯克利包过滤器）和bpftrace工具，学习如何动态跟踪和分析内核函数、系统调用的执行情况。eBPF是一种革命性的内核技术，允许在不修改内核源代码的情况下，安全高效地运行自定义程序来观察和调试系统行为。

## 实验目标

### 知识目标
- 理解eBPF技术的基本原理和架构
- 掌握bpftrace工具的基本使用方法
- 了解kprobe和tracepoint的区别和应用场景
- 学习Linux内核跟踪和调试的基本方法

### 技能目标
- 能够编写简单的eBPF跟踪脚本
- 能够分析系统调用和内核函数的行为
- 能够使用eBPF进行系统性能分析
- 能够解决常见的eBPF环境问题

### 思维目标
- 培养系统级调试和分析能力
- 理解内核可观测性的重要性
- 掌握动态追踪技术的思想方法

## 环境要求

### 硬件要求
- x86_64或ARM64架构CPU
- 至少1GB可用内存
- 1GB可用磁盘空间

### 软件要求
- Linux内核版本 ≥ 4.1（推荐 ≥ 5.4）
- root权限或CAP_BPF、CAP_PERFMON能力
- 以下任一种Linux发行版：
  - Ubuntu 20.04+ / Debian 10+
  - CentOS 8+ / RHEL 8+
  - Fedora 32+
  - Arch Linux / Manjaro

### 内核配置要求
以下内核配置必须启用：
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_HAVE_EBPF_JIT=y
CONFIG_BPF_EVENTS=y
CONFIG_KPROBES=y
CONFIG_TRACEPOINTS=y

text

## 快速开始

### 1. 一键安装（推荐）

```bash
# 克隆实验代码（如果没有）
# git clone <repository-url>
# cd lab2-2-ebpf-tracing

# 安装所有依赖
chmod +x scripts/install_deps.sh
sudo ./scripts/install_deps.sh
2. 运行示例跟踪
bash
# 跟踪open系统调用（基础示例）
sudo ./scripts/run_open_trace.sh

# 在另一个终端执行以下命令来生成跟踪数据
cat /etc/hostname
ls -la /tmp
touch /tmp/testfile
3. 运行完整测试
bash
# 运行基础功能测试
chmod +x tests/test_basic.sh
sudo ./tests/test_basic.sh

# 运行读写频率测试
chmod +x tests/test_rw_freq.sh
sudo ./tests/test_rw_freq.sh
实验内容详解
核心脚本说明
1. 跟踪open系统调用 (src/trace_open.bt)
功能: 跟踪所有open()和openat()系统调用

输出: 进程名、PID、文件名、打开标志

用途: 理解文件访问模式，调试文件相关问题

2. 统计系统调用 (src/count_syscalls.bt)
功能: 统计所有系统调用，按进程和类型分类

输出: Top调用进程、调用类型分布、调用频率

用途: 系统负载分析，异常进程检测

3. 跟踪内存分配 (src/trace_kmalloc.bt)
功能: 跟踪内核内存分配函数（kmalloc/__kmalloc）

输出: 分配大小、GFP标志、调用栈

用途: 内存泄漏调试，内存使用模式分析

4. 读写频率时序图 (src/read_write_freq.bt)
功能: 绘制read/write系统调用频率时序图

输出: 时间窗口内的调用频率，可视化趋势

用途: I/O模式分析，性能瓶颈识别

关键概念
eBPF架构
验证器 (Verifier): 静态分析字节码，确保程序安全

JIT编译器: 将字节码编译为本地机器码

映射 (Map): eBPF程序与用户空间的数据通信机制

辅助函数 (Helper functions): 内核提供的安全函数调用

探针类型
类型	描述	示例
kprobe	内核函数入口探针	kprobe:vfs_read
kretprobe	内核函数返回探针	kretprobe:vfs_read
tracepoint	静态内核跟踪点	tracepoint:syscalls:sys_enter_open
uprobe	用户空间函数探针	uprobe:/bin/bash:readline
usdt	用户静态定义跟踪点	usdt:/usr/bin/python:function__entry
常用内置变量
pid / tid: 进程/线程ID

comm: 进程名（最多16字符）

nsecs: 纳秒时间戳

kstack / ustack: 内核/用户空间调用栈

arg0-argN: 函数参数

retval: 函数返回值（仅kretprobe）

实验步骤
阶段一：环境准备和验证（预计时间：15分钟）
检查系统要求

bash
uname -r  # 内核版本 ≥ 4.1
cat /proc/cpuinfo | grep flags | grep bpf  # CPU支持
安装依赖

bash
sudo ./scripts/install_deps.sh
验证安装

bash
sudo bpftrace -e 'BEGIN { printf("eBPF环境正常！\n"); exit(); }'
阶段二：基础跟踪实践（预计时间：30分钟）
运行open跟踪

bash
sudo ./scripts/run_open_trace.sh
# 在另一个终端：cat /etc/passwd
运行系统调用统计

bash
sudo ./scripts/run_syscall_stat.sh 20
分析输出结果

识别调用最多的进程

观察系统调用模式

理解跟踪数据含义

阶段三：高级功能探索（预计时间：45分钟）
内存分配跟踪

bash
sudo ./scripts/run_kmalloc_trace.sh 30
读写频率分析

bash
sudo ./scripts/run_rw_freq.sh 40 15
自定义跟踪脚本

bash
# 创建自定义跟踪
cat > /tmp/my_trace.bt << 'EOF'
tracepoint:syscalls:sys_enter_execve {
    printf("进程执行: %s -> %s\n", comm, str(args->filename));
}
EOF

sudo bpftrace /tmp/my_trace.bt
阶段四：问题分析和调试（预计时间：30分钟）
故障模拟

bash
# 模拟高系统调用负载
for i in {1..1000}; do ls /tmp > /dev/null; done
性能影响分析

bash
# 同时运行跟踪和性能测试
sudo ./scripts/run_syscall_stat.sh 10 &
dd if=/dev/zero of=/tmp/test bs=1M count=100
调试技巧实践

bash
# 查看可用tracepoint
sudo bpftrace -l 'tracepoint:syscalls:*' | head -20

# 查看内核符号
sudo cat /proc/kallsyms | grep kmalloc | head -10