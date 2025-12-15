#!/bin/bash

# SparrowOS内存管理实验构建脚本
# RISC-V 64位，QEMU virt机器

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
SRC_DIR="$PROJECT_ROOT/src"
KERNEL_DIR="$PROJECT_ROOT/kernel"
INCLUDE_DIR="$PROJECT_ROOT/include"

echo -e "${BLUE}=== SparrowOS Memory Manager Build Script ===${NC}"
echo -e "Project root: $PROJECT_ROOT"
echo -e "Build directory: $BUILD_DIR"

# 检查必要的目录
echo -e "\n${YELLOW}[1/6] Checking project structure...${NC}"
if [ ! -d "$SRC_DIR" ]; then
    echo -e "${RED}Error: Source directory not found: $SRC_DIR${NC}"
    exit 1
fi

if [ ! -d "$KERNEL_DIR" ]; then
    echo -e "${RED}Error: Kernel directory not found: $KERNEL_DIR${NC}"
    exit 1
fi

# 创建构建目录
mkdir -p "$BUILD_DIR"

# 检查工具链
echo -e "\n${YELLOW}[2/6] Checking toolchain...${NC}"
TOOLCHAIN_PREFIX="riscv64-unknown-elf-"
CC="${TOOLCHAIN_PREFIX}gcc"
LD="${TOOLCHAIN_PREFIX}ld"
OBJCOPY="${TOOLCHAIN_PREFIX}objcopy"
OBJDUMP="${TOOLCHAIN_PREFIX}objdump"

# 检查必要的工具
for tool in "$CC" "$LD" "$OBJCOPY"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo -e "${RED}Error: Tool not found: $tool${NC}"
        echo -e "Please install RISC-V GNU toolchain:"
        echo -e "  Ubuntu/Debian: sudo apt install gcc-riscv64-unknown-elf"
        echo -e "  Arch Linux: sudo pacman -S riscv64-elf-gcc"
        echo -e "  macOS: brew install riscv-tools"
        exit 1
    fi
done

echo -e "${GREEN}✓ Toolchain found:${NC}"
echo -e "  CC: $(which $CC)"
echo -e "  LD: $(which $LD)"
echo -e "  OBJCOPY: $(which $OBJCOPY)"

# 检查QEMU
echo -e "\n${YELLOW}[3/6] Checking QEMU...${NC}"
if ! command -v qemu-system-riscv64 >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: QEMU not found. You won't be able to run the OS.${NC}"
    echo -e "Install QEMU:"
    echo -e "  Ubuntu/Debian: sudo apt install qemu-system-misc"
    echo -e "  Arch Linux: sudo pacman -S qemu-system-riscv"
    echo -e "  macOS: brew install qemu"
else
    echo -e "${GREEN}✓ QEMU found: $(which qemu-system-riscv64)${NC}"
fi

# 清理之前的构建
echo -e "\n${YELLOW}[4/6] Cleaning previous build...${NC}"
cd "$PROJECT_ROOT"
make clean >/dev/null 2>&1 || true
rm -f "$BUILD_DIR"/*.elf "$BUILD_DIR"/*.bin "$BUILD_DIR"/*.map

# 编译内核
echo -e "\n${YELLOW}[5/6] Building SparrowOS...${NC}"
cd "$PROJECT_ROOT"

echo -e "Compiling kernel files..."
# 编译每个源文件
for file in "$KERNEL_DIR"/*.c "$KERNEL_DIR"/*.S "$SRC_DIR"/*.c; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo -e "  ${BLUE}→${NC} $filename"
    fi
done

if ! make all 2>&1 | tee "$BUILD_DIR/build.log"; then
    echo -e "${RED}Build failed! Check $BUILD_DIR/build.log for details${NC}"
    exit 1
fi

# 复制生成的文件到构建目录
cp sparrowos.elf sparrowos.bin "$BUILD_DIR/" 2>/dev/null || true

# 生成反汇编文件用于调试
echo -e "\n${YELLOW}[6/6] Generating debug information...${NC}"
$OBJDUMP -d sparrowos.elf > "$BUILD_DIR/sparrowos.disasm"
$OBJDUMP -h sparrowos.elf > "$BUILD_DIR/sparrowos.sections"
$OBJDUMP -t sparrowos.elf > "$BUILD_DIR/sparrowos.symbols"

# 计算大小信息
echo -e "\n${GREEN}Build successful!${NC}"
echo -e "\n${BLUE}Generated files:${NC}"
ls -lh "$BUILD_DIR"/sparrowos.* 2>/dev/null | awk '{print $5, $9}'

echo -e "\n${BLUE}Section sizes:${NC}"
$OBJDUMP -h sparrowos.elf 2>/dev/null | grep -E '\.text|\.data|\.bss|\.rodata' | \
    awk '{printf "  %-10s %8s bytes\n", $2, strtonum("0x"$3)}' || true

echo -e "\n${BLUE}Entry point:${NC}"
$OBJDUMP -t sparrowos.elf 2>/dev/null | grep -w _start | \
    awk '{print "  _start at " $1}' || echo "  Not found"

echo -e "\n${GREEN}Ready to run:${NC}"
echo -e "  make run      # Run in QEMU"
echo -e "  make debug    # Run with GDB server"
echo -e "  make disasm   # View disassembly"
echo -e "\n${BLUE}Build completed at $(date)${NC}"