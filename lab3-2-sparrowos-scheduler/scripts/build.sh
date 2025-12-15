#!/bin/bash

# SparrowOS Scheduler Build Script
# 编译进程调度器测试程序

set -e  # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_DIR/src"
INCLUDE_DIR="$PROJECT_DIR/include"
BUILD_DIR="$PROJECT_DIR/build"
BIN_DIR="$PROJECT_DIR/bin"

echo "=== SparrowOS Scheduler Build System ==="

# 创建构建目录
mkdir -p "$BUILD_DIR"
mkdir -p "$BIN_DIR"

# 检查编译器
echo "Checking compiler..."
if ! command -v gcc &> /dev/null; then
    echo "Error: GCC compiler not found"
    echo "Install with: sudo apt install gcc"
    exit 1
fi

# 检查汇编器
if ! command -v nasm &> /dev/null; then
    echo "Warning: NASM assembler not found"
    echo "Install with: sudo apt install nasm"
    # 继续，因为不是所有文件都需要nasm
fi

# 设置编译选项
CFLAGS="-Wall -Wextra -O2 -g -I$INCLUDE_DIR"
LDFLAGS="-lm"

# 编译汇编文件（上下文切换）
echo "Compiling assembly files..."
if command -v nasm &> /dev/null; then
    nasm -f elf32 -o "$BUILD_DIR/context_switch.o" "$SRC_DIR/context_switch.S" 2>/dev/null || true
else
    echo "Skipping assembly compilation (nasm not available)"
fi

# 编译C源文件
echo "Compiling C source files..."
C_SOURCES=(
    "$SRC_DIR/scheduler.c"
    "$SRC_DIR/interrupt.c"
    "$SRC_DIR/main.c"
)

for source in "${C_SOURCES[@]}"; do
    if [ -f "$source" ]; then
        filename=$(basename "$source" .c)
        echo "  Compiling $filename.c..."
        gcc $CFLAGS -c "$source" -o "$BUILD_DIR/$filename.o"
    else
        echo "Warning: Source file not found: $source"
    fi
done

# 链接可执行文件
echo "Linking executable..."
OBJECT_FILES=(
    "$BUILD_DIR/scheduler.o"
    "$BUILD_DIR/interrupt.o"
    "$BUILD_DIR/main.o"
    "$BUILD_DIR/context_switch.o"
)

# 过滤掉不存在的文件
EXISTING_OBJECTS=()
for obj in "${OBJECT_FILES[@]}"; do
    if [ -f "$obj" ]; then
        EXISTING_OBJECTS+=("$obj")
    fi
done

if [ ${#EXISTING_OBJECTS[@]} -eq 0 ]; then
    echo "Error: No object files found"
    exit 1
fi

gcc "${EXISTING_OBJECTS[@]}" $LDFLAGS -o "$BIN_DIR/scheduler_test"

# 检查是否编译成功
if [ -f "$BIN_DIR/scheduler_test" ]; then
    echo -e "\nBuild successful!"
    echo "Executable: $BIN_DIR/scheduler_test"
    
    # 显示文件信息
    echo -e "\nFile information:"
    ls -lh "$BIN_DIR/scheduler_test"
    
    # 显示符号表（调试用）
    echo -e "\nExported symbols:"
    nm "$BIN_DIR/scheduler_test" | grep -E "(T|D) _" | head -20
    
else
    echo "Error: Linking failed"
    exit 1
fi

# 复制头文件到build目录（用于开发）
echo -e "\nCopying header files..."
cp "$INCLUDE_DIR"/*.h "$BUILD_DIR/" 2>/dev/null || true

echo -e "\nBuild completed at $(date)"