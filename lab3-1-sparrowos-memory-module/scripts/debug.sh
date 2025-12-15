#!/bin/bash

# SparrowOS调试脚本
# 启动QEMU GDB服务器并连接到它

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
KERNEL_ELF="$BUILD_DIR/sparrowos.elf"

echo -e "${BLUE}=== SparrowOS Debug Script ===${NC}"

# 检查文件
if [ ! -f "$KERNEL_ELF" ]; then
    echo -e "${RED}Error: Kernel ELF not found: $KERNEL_ELF${NC}"
    echo -e "Please run build.sh first"
    exit 1
fi

# 检查GDB
GDB="riscv64-unknown-elf-gdb"
if ! command -v "$GDB" >/dev/null 2>&1; then
    echo -e "${RED}Error: GDB not found: $GDB${NC}"
    echo -e "Please install RISC-V GNU toolchain"
    exit 1
fi

# 检查QEMU
if ! command -v qemu-system-riscv64 >/dev/null 2>&1; then
    echo -e "${RED}Error: QEMU not found${NC}"
    exit 1
fi

# 创建GDB初始化脚本
GDBINIT="$BUILD_DIR/gdbinit"
cat > "$GDBINIT" << 'EOF'
# SparrowOS GDB初始化脚本

# 设置架构
set architecture riscv:rv64

# 加载符号
file sparrowos.elf

# 连接目标
target remote localhost:1234

# 设置断点
break main
break kmalloc
break kfree

# 显示反汇编
layout split

# 自动继续
# continue

echo "SparrowOS调试会话已启动\n"
echo "常用命令:"
echo "  continue (c) - 继续执行"
echo "  next (n)     - 单步跳过"
echo "  step (s)     - 单步进入"
echo "  backtrace (bt) - 显示调用栈"
echo "  print (p)    - 打印变量"
echo "  break (b)    - 设置断点"
echo "  info break   - 查看断点"
echo "\n按Ctrl+C中断执行\n"
EOF

# 启动QEMU在后台
echo -e "${GREEN}[1/3] Starting QEMU GDB server...${NC}"
QEMU_CMD="qemu-system-riscv64 -machine virt -nographic -bios none -kernel $BUILD_DIR/sparrowos.bin -s -S -m 128M"
echo -e "${BLUE}Command:${NC} $QEMU_CMD"

# 在后台启动QEMU
$QEMU_CMD > "$BUILD_DIR/qemu_debug.log" 2>&1 &
QEMU_PID=$!

echo -e "${GREEN}QEMU PID:${NC} $QEMU_PID"
echo -e "${GREEN}Log file:${NC} $BUILD_DIR/qemu_debug.log"

# 等待QEMU启动
echo -e "${GREEN}[2/3] Waiting for QEMU to start...${NC}"
sleep 2

# 检查QEMU是否在运行
if ! kill -0 $QEMU_PID 2>/dev/null; then
    echo -e "${RED}Error: QEMU failed to start${NC}"
    cat "$BUILD_DIR/qemu_debug.log"
    exit 1
fi

echo -e "${GREEN}[3/3] Starting GDB...${NC}"
echo -e "${BLUE}GDB command:${NC} $GDB -x $GDBINIT"

# 切换到构建目录并启动GDB
cd "$BUILD_DIR"
$GDB -x "$GDBINIT"

# GDB退出后清理
echo -e "\n${YELLOW}Cleaning up...${NC}"
kill $QEMU_PID 2>/dev/null || true
wait $QEMU_PID 2>/dev/null || true

echo -e "${GREEN}Debug session ended${NC}"