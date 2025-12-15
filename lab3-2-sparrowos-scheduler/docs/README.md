markdown
# 实验3.2：SparrowOS-进程调度器

## 实验简介

本实验旨在实现一个完整的进程调度器，从基础的FIFO调度器开始，逐步扩展到时间片轮转(RR)调度器和多级反馈队列(MLFQ)调度器。通过本实验，学生将深入理解操作系统进程调度的核心概念和实现机制。

## 实验目标

- 理解进程控制块(PCB)的结构和功能
- 掌握上下文切换的原理和实现
- 实现多种进程调度算法
- 理解中断处理和定时器机制
- 学习多级反馈队列调度器的设计和优化

## 环境要求

- Linux操作系统 (Ubuntu 20.04+ / CentOS 8+ 推荐)
- GCC编译器
- Make构建工具
- Git版本控制 (可选)
- 基本的C语言编程知识

## 快速开始

### 1. 环境准备

```bash
# 安装构建工具
sudo apt update
sudo apt install build-essential gdb nasm

# 或者CentOS/RHEL
sudo yum groupinstall "Development Tools"
sudo yum install gcc gdb nasm
2. 获取代码
bash
# 克隆项目或复制文件到本地
git clone <repository-url>
cd lab3-2-sparrowos-scheduler
3. 构建和运行
bash
# 运行完整测试套件
chmod +x scripts/*.sh
./scripts/run_test.sh

# 或者手动构建和测试
./scripts/build.sh
cd bin
./scheduler_test
4. 运行演示程序
bash
# 简单演示
./bin/demo_simple

# 高级演示
./bin/demo_advanced