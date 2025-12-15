#!/bin/bash

# eBPF/bpftrace 环境依赖安装脚本

set -e

echo "=== eBPF跟踪实验 - 环境准备 ==="

# 检测发行版
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "无法检测操作系统"
    exit 1
fi

echo "检测到操作系统: $OS $VERSION_ID"

# 安装依赖
case $OS in
    ubuntu|debian)
        echo "更新包列表..."
        sudo apt update
        
        echo "安装bpftrace和相关工具..."
        sudo apt install -y \
            bpftrace \
            linux-tools-$(uname -r) \
            linux-headers-$(uname -r) \
            bpfcc-tools \
            libbpf-dev \
            clang \
            llvm
            
        echo "安装调试符号（推荐）..."
        sudo apt install -y linux-image-$(uname -r)-dbgsym || \
        echo "调试符号安装失败，但bpftrace仍可工作"
        ;;
        
    centos|rhel|fedora)
        echo "安装EPEL仓库..."
        sudo yum install -y epel-release || true
        
        echo "安装bpftrace和相关工具..."
        sudo yum install -y \
            bpftrace \
            kernel-devel-$(uname -r) \
            kernel-headers-$(uname -r) \
            bcc-tools \
            clang \
            llvm
            
        if [ "$OS" = "fedora" ]; then
            sudo dnf debuginfo-install -y kernel || true
        fi
        ;;
        
    *)
        echo "不支持的操作系统: $OS"
        echo "请手动安装:"
        echo "1. bpftrace (https://github.com/iovisor/bpftrace)"
        echo "2. 内核头文件"
        echo "3. clang/llvm"
        exit 1
        ;;
esac

# 验证安装
echo -e "\n验证安装:"
if command -v bpftrace &> /dev/null; then
    echo "✓ bpftrace 版本: $(bpftrace --version | head -1)"
else
    echo "✗ bpftrace 未安装"
    exit 1
fi

if [ -d "/sys/kernel/debug/tracing" ]; then
    echo "✓ 内核跟踪支持已启用"
else
    echo "⚠ 内核跟踪可能未启用，尝试启用..."
    sudo mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
fi

echo -e "\n=== 环境准备完成 ==="
echo "可以运行以下命令测试:"
echo "1. sudo bpftrace -e 'BEGIN { printf(\"Hello eBPF!\\n\"); }'"
echo "2. ./scripts/run_open_trace.sh"