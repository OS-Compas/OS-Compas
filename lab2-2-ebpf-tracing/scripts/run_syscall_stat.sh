#!/bin/bash

# 运行系统调用统计

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/../src"

DURATION=${1:-30}  # 默认运行30秒

echo "=== 系统调用统计 ==="
echo "本脚本将统计所有系统调用"
echo "运行时长: $DURATION 秒"
echo "显示调用最多的进程和系统调用类型"
echo "每5秒更新一次统计"
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
if [ ! -f "$SRC_DIR/count_syscalls.bt" ]; then
    echo "错误: count_syscalls.bt 不存在于 $SRC_DIR"
    exit 1
fi

echo ""
echo "正在启动系统调用统计..."
echo "你可以在另一个终端执行命令来观察统计变化"
echo "按 Ctrl+C 提前结束统计"
echo ""
echo "统计输出:"
echo "=========="

# 运行bpftrace脚本
timeout $DURATION bpftrace "$SRC_DIR/count_syscalls.bt" || {
    if [ $? -eq 124 ]; then
        echo -e "\n统计已完成（超时 $DURATION 秒）"
    else
        echo -e "\n统计异常结束"
    fi
}