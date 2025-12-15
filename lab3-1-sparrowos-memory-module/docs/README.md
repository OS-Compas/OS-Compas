# 实验3.1：SparrowOS-内存管理模块

## 实验简介

本实验基于RISC-V架构的SparrowOS教学操作系统，实现一个完整的物理内存分配器。通过学习内存管理的核心概念和技术，掌握操作系统内存管理的设计与实现。

## 实验目标

1. **理解RISC-V Sv39分页模式**：掌握虚拟内存到物理内存的映射机制
2. **掌握物理内存布局**：了解内核启动时的内存区域划分
3. **实现空闲链表分配器**：实现基础的动态内存分配算法
4. **提供kmalloc/kfree接口**：为内核其他模块提供内存分配服务
5. **编写测试用例**：验证内存分配器的正确性和健壮性
6. **分析内存碎片**：理解外部碎片的产生机制和缓解方法

## 实验环境

### 硬件/模拟环境
- RISC-V 64位处理器 (RV64GC)
- QEMU virt 虚拟机器（默认128MB内存）
- Sv39分页模式

### 软件工具
- RISC-V GNU工具链 (`riscv64-unknown-elf-`)
- QEMU系统模拟器 (>= 6.0)
- Make构建工具
- 终端模拟器

### 环境搭建

```bash
# 1. 安装RISC-V工具链
# Ubuntu/Debian
sudo apt install gcc-riscv64-unknown-elf qemu-system-misc

# Arch Linux
sudo pacman -S riscv64-elf-gcc riscv64-elf-binutils qemu-system-riscv

# macOS (使用Homebrew)
brew install riscv-tools qemu

# 2. 克隆项目
git clone https://github.com/sparrow-os/lab3-1-memory.git
cd lab3-1-memory

# 3. 验证环境
make check