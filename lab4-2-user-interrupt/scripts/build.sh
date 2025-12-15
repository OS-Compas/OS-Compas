#!/bin/bash

# 用户态中断实验构建脚本

set -e  # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/../src"
BUILD_DIR="$SCRIPT_DIR/../build"

echo "=== User Interrupt Experiment Build Script ==="
echo "Script directory: $SCRIPT_DIR"
echo "Source directory: $SRC_DIR"

# 创建构建目录
mkdir -p "$BUILD_DIR"

# 检查gcc
echo "Checking GCC compiler..."
if ! command -v gcc &> /dev/null; then
    echo "Error: GCC not found. Please install:"
    echo "  Ubuntu/Debian: sudo apt install gcc"
    echo "  CentOS/RHEL: sudo yum install gcc"
    exit 1
fi

# 进入源码目录
cd "$SRC_DIR"

# 清理之前的构建
echo "Cleaning previous build..."
make clean > /dev/null 2>&1 || true

# 构建所有目标
echo "Building all targets..."
if make; then
    # 复制到构建目录
    cp uintr_server uintr_client pipe_server pipe_client "$BUILD_DIR/" 2>/dev/null || true
    
    echo "Build successful!"
    echo "Generated binaries:"
    ls -la "$BUILD_DIR"/* 2>/dev/null | grep -v "^d"
    
    # 检查是否支持UINTR
    echo -e "\nChecking UINTR support..."
    if grep -q "uintr" /proc/cpuinfo; then
        echo "✓ CPU supports UINTR"
    else
        echo "⚠ CPU does not support UINTR (simulation mode only)"
    fi
    
    if [ -f /usr/include/linux/uintr.h ]; then
        echo "✓ UINTR headers found"
    else
        echo "⚠ UINTR headers not found (need kernel 5.19+)"
    fi
else
    echo "Build failed!"
    exit 1
fi

# 设置执行权限
chmod +x "$BUILD_DIR"/* 2>/dev/null || true
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

echo -e "\nBuild completed successfully!"