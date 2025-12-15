#!/bin/bash

# 运行open系统调用跟踪

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/../src"

echo "=== 跟踪open系统调用 ==="
echo "本脚本将跟踪所有open和openat系统调用"
echo "显示进程名、PID、文件名和打开标志"
echo "按 Ctrl+C 停止跟踪"
echo "========================="

# 检查权限
if [ "$EUID" -ne 0 ]; then 
    echo "需要root权限，尝试使用sudo..."
    exec sudo "$0" "$@"
fi

# 检查bpftrace是否安装
if ! command -v bpftrace &> /dev/null; then
    echo "错误: bpftrace未安装"
    echo "请先运行: ./scripts/install_deps.sh"
    exit 1
fi

# 检查脚本文件
if [ ! -f "$SRC_DIR/trace_open.bt" ]; then
    echo "错误: trace_open.bt 不存在于 $SRC_DIR"
    exit 1
fi

# 运行前显示提示
echo ""
echo "正在启动跟踪，你可以尝试在另一个终端执行:"
echo "  cat /etc/hostname"
echo "  ls /tmp"
echo "  touch /tmp/test_file"
echo "来生成一些open系统调用"
echo ""
echo "跟踪输出:"
echo "=========="

# 运行bpftrace脚本
bpftrace "$SRC_DIR/trace_open.bt"