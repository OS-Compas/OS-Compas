#!/bin/bash

# 运行kmalloc内存分配跟踪

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/../src"

DURATION=${1:-20}  # 默认运行20秒

echo "=== 跟踪kmalloc内存分配 ==="
echo "本脚本将跟踪内核内存分配函数 (kmalloc/__kmalloc)"
echo "运行时长: $DURATION 秒"
echo "显示分配大小、GFP标志和调用进程"
echo "================================"

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
if [ ! -f "$SRC_DIR/trace_kmalloc.bt" ]; then
    echo "错误: trace_kmalloc.bt 不存在于 $SRC_DIR"
    exit 1
fi

echo ""
echo "正在启动内存分配跟踪..."
echo "你可以尝试在另一个终端执行以下命令来生成内存分配:"
echo "  1. 创建大文件: dd if=/dev/zero of=/tmp/largefile bs=1M count=10"
echo "  2. 编译程序: gcc -o /tmp/test test.c"
echo "  3. 使用find命令: find /usr/include -name '*.h' | xargs grep 'stdio'"
echo ""
echo "跟踪输出:"
echo "=========="

# 运行bpftrace脚本
timeout $DURATION bpftrace "$SRC_DIR/trace_kmalloc.bt" || {
    if [ $? -eq 124 ]; then
        echo -e "\n跟踪已完成（超时 $DURATION 秒）"
    else
        echo -e "\n跟踪异常结束"
    fi
}