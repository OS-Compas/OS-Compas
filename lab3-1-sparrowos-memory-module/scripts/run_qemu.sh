#!/bin/bash

# SparrowOS QEMU运行脚本
# 运行内存管理实验

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
KERNEL_BIN="$BUILD_DIR/sparrowos.bin"

echo -e "${BLUE}=== SparrowOS Memory Manager - QEMU Runner ===${NC}"

# 检查内核文件
if [ ! -f "$KERNEL_BIN" ]; then
    echo -e "${RED}Error: Kernel binary not found: $KERNEL_BIN${NC}"
    echo -e "Please run build.sh first"
    exit 1
fi

echo -e "${GREEN}Kernel:${NC} $KERNEL_BIN"
echo -e "${GREEN}Size:${NC} $(stat -c%s "$KERNEL_BIN") bytes"

# QEMU参数
QEMU="qemu-system-riscv64"
MACHINE="virt"
MEMORY="128M"
SMP="1"  # CPU核心数
NETDEV="user"
NETPORT="5555"

# 构建QEMU命令
QEMU_CMD="$QEMU \
    -machine $MACHINE \
    -nographic \
    -bios none \
    -kernel $KERNEL_BIN \
    -m $MEMORY \
    -smp $SMP \
    -netdev $NETDEV,id=net0,hostfwd=tcp::$NETPORT-:22 \
    -device virtio-net-device,netdev=net0 \
    -drive file=disk.img,if=none,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0"

# 检查是否需要串口日志
if [ "$1" = "--debug" ] || [ "$1" = "-d" ]; then
    echo -e "${BLUE}Debug mode enabled${NC}"
    LOG_FILE="$BUILD_DIR/qemu_$(date +%Y%m%d_%H%M%S).log"
    QEMU_CMD="$QEMU_CMD -serial file:$LOG_FILE -serial mon:stdio"
    echo -e "Logging to: $LOG_FILE"
else
    QEMU_CMD="$QEMU_CMD -serial mon:stdio"
fi

# 检查是否启用GDB
if [ "$1" = "--gdb" ] || [ "$1" = "-g" ]; then
    echo -e "${BLUE}GDB server enabled on port 1234${NC}"
    QEMU_CMD="$QEMU_CMD -s -S"
    echo -e "Connect with: riscv64-unknown-elf-gdb $BUILD_DIR/sparrowos.elf"
    echo -e "Then in GDB: target remote localhost:1234"
fi

# 显示配置
echo -e "\n${GREEN}QEMU Configuration:${NC}"
echo -e "  Machine:    $MACHINE"
echo -e "  Memory:     $MEMORY"
echo -e "  CPUs:       $SMP"
echo -e "  Network:    $NETDEV (SSH on port $NETPORT)"

echo -e "\n${GREEN}Command:${NC}"
echo "$QEMU_CMD"

echo -e "\n${BLUE}Starting SparrowOS...${NC}"
echo -e "${BLUE}========================================${NC}"

# 运行QEMU
exec $QEMU_CMD

# 如果QEMU退出，显示退出代码
QEMU_EXIT=$?
echo -e "\n${BLUE}========================================${NC}"
echo -e "QEMU exited with code: $QEMU_EXIT"
exit $QEMU_EXIT