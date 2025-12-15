#!/bin/bash

# SparrowOS调度器调试脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$PROJECT_DIR/bin"
BUILD_DIR="$PROJECT_DIR/build"

echo "=== SparrowOS Scheduler Debug Tool ==="
echo ""

# 检查调试器
if ! command -v gdb &> /dev/null; then
    echo "Error: GDB debugger not found"
    echo "Install with: sudo apt install gdb"
    exit 1
fi

# 构建调试版本
echo "Step 1: Building debug version..."
cd "$PROJECT_DIR"

# 使用调试标志重新编译
CFLAGS="-Wall -Wextra -O0 -g -DDEBUG -I$PROJECT_DIR/include"
LDFLAGS="-lm"

echo "Compiling with debug symbols..."
gcc $CFLAGS -c "$PROJECT_DIR/src/scheduler.c" -o "$BUILD_DIR/scheduler_debug.o"
gcc $CFLAGS -c "$PROJECT_DIR/src/interrupt.c" -o "$BUILD_DIR/interrupt_debug.o"
gcc $CFLAGS -c "$PROJECT_DIR/src/main.c" -o "$BUILD_DIR/main_debug.o"

# 链接
echo "Linking debug executable..."
gcc "$BUILD_DIR/scheduler_debug.o" \
    "$BUILD_DIR/interrupt_debug.o" \
    "$BUILD_DIR/main_debug.o" \
    $LDFLAGS -o "$BIN_DIR/scheduler_debug"

if [ ! -f "$BIN_DIR/scheduler_debug" ]; then
    echo "Error: Debug build failed"
    exit 1
fi

echo "Debug executable created: $BIN_DIR/scheduler_debug"

# 创建GDB命令文件
GDB_SCRIPT="$BUILD_DIR/debug_commands.gdb"
cat > "$GDB_SCRIPT" << 'EOF'
# GDB调试脚本 for SparrowOS Scheduler
set pagination off

# 设置断点
echo "Setting breakpoints...\n"

# 主要断点
break main
break scheduler_init
break scheduler_create_process
break scheduler_terminate_process
break scheduler_schedule
break scheduler_tick
break scheduler_yield

# FIFO调度
break scheduler_fifo_schedule
break scheduler_fifo_init

# RR调度
break scheduler_rr_schedule
break scheduler_rr_init

# MLFQ调度
break scheduler_mlfq_schedule
break scheduler_mlfq_init
break scheduler_mlfq_boost_priority

# 辅助函数
break add_to_ready_queue
break remove_from_ready_queue
break find_free_pcb

echo "\nBreakpoints set. Type 'run' to start debugging.\n"
echo "Useful commands:"
echo "  run           - 启动程序"
echo "  continue/c    - 继续执行"
echo "  next/n        - 单步执行（不进入函数）"
echo "  step/s        - 单步执行（进入函数）"
echo "  print/p       - 打印变量"
echo "  backtrace/bt  - 显示调用栈"
echo "  info break    - 显示断点信息"
echo "  delete        - 删除所有断点"
echo "\nType 'quit' to exit GDB.\n"
EOF

echo -e "\nStep 2: Starting GDB debug session..."
echo "======================================"

# 运行GDB
gdb -q -x "$GDB_SCRIPT" "$BIN_DIR/scheduler_debug"

# 提供调试提示
echo -e "\nDebugging tips:"
echo "1. 可以使用Valgrind检查内存错误:"
echo "   valgrind --leak-check=full $BIN_DIR/scheduler_debug"
echo ""
echo "2. 可以使用strace跟踪系统调用:"
echo "   strace -o strace.log $BIN_DIR/scheduler_debug"
echo ""
echo "3. 调试特定测试用例:"
echo "   gdb -ex 'break scheduler_create_process' \\"
echo "       -ex 'run' \\"
echo "       $BIN_DIR/scheduler_debug"