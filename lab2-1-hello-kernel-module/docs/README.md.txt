# 实验2.1：Hello World内核模块

## 实验简介

本实验通过编写、编译、加载和卸载一个简单的"Hello World"内核模块，让学生初步掌握Linux内核模块开发的基本流程和工具链使用。

## 实验目标

- 理解Linux内核模块的基本概念
- 掌握内核模块的编写、编译和调试方法
- 学会使用模块参数和动态调试输出
- 熟悉内核开发的基本工具链

## 环境要求

- Linux操作系统（Ubuntu 20.04+ / CentOS 8+ 推荐）
- GCC编译器
- Linux内核头文件
- root权限（用于模块加载）

## 快速开始

### 1. 环境准备

```bash
# 安装构建依赖
sudo apt update
sudo apt install build-essential linux-headers-$(uname -r)

# 或者CentOS/RHEL
sudo yum groupinstall "Development Tools"
sudo yum install kernel-devel-$(uname -r)