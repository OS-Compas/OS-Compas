#!/bin/bash

# SparrowOS调度器测试运行脚本

set -e  # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$PROJECT_DIR/bin"
TEST_DIR="$PROJECT_DIR/tests"
EXAMPLES_DIR="$PROJECT_DIR/examples"

echo "=== SparrowOS Scheduler Test Runner ==="
echo "Project directory: $PROJECT_DIR"
echo ""

# 首先构建项目
echo "Step 1: Building the project..."
"$SCRIPT_DIR/build.sh"

# 检查构建是否成功
if [ ! -f "$BIN_DIR/scheduler_test" ]; then
    echo "Error: Build failed or executable not found"
    exit 1
fi

# 运行测试
echo -e "\nStep 2: Running test programs..."
echo "======================================"

# 运行FIFO测试
echo -e "\n--- Running FIFO Scheduler Tests ---"
if [ -f "$TEST_DIR/test_fifo.c" ]; then
    # 编译测试程序
    gcc -Wall -Wextra -O2 -g -I"$PROJECT_DIR/include" \
        "$TEST_DIR/test_fifo.c" "$PROJECT_DIR/src/scheduler.c" \
        -o "$BIN_DIR/test_fifo" -lm
    
    if [ -f "$BIN_DIR/test_fifo" ]; then
        echo "Executing FIFO tests..."
        "$BIN_DIR/test_fifo"
        FIFO_RESULT=$?
        if [ $FIFO_RESULT -eq 0 ]; then
            echo "✓ FIFO tests passed"
        else
            echo "✗ FIFO tests failed"
        fi
    fi
else
    echo "Warning: test_fifo.c not found"
fi

# 运行RR测试
echo -e "\n--- Running Round-Robin Tests ---"
if [ -f "$TEST_DIR/test_rr.c" ]; then
    gcc -Wall -Wextra -O2 -g -I"$PROJECT_DIR/include" \
        "$TEST_DIR/test_rr.c" "$PROJECT_DIR/src/scheduler.c" \
        -o "$BIN_DIR/test_rr" -lm
    
    if [ -f "$BIN_DIR/test_rr" ]; then
        echo "Executing RR tests..."
        "$BIN_DIR/test_rr"
        RR_RESULT=$?
        if [ $RR_RESULT -eq 0 ]; then
            echo "✓ RR tests passed"
        else
            echo "✗ RR tests failed"
        fi
    fi
else
    echo "Warning: test_rr.c not found"
fi

# 运行MLFQ测试
echo -e "\n--- Running MLFQ Tests ---"
if [ -f "$TEST_DIR/test_mlfq.c" ]; then
    gcc -Wall -Wextra -O2 -g -I"$PROJECT_DIR/include" \
        "$TEST_DIR/test_mlfq.c" "$PROJECT_DIR/src/scheduler.c" \
        -o "$BIN_DIR/test_mlfq" -lm
    
    if [ -f "$BIN_DIR/test_mlfq" ]; then
        echo "Executing MLFQ tests..."
        "$BIN_DIR/test_mlfq"
        MLFQ_RESULT=$?
        if [ $MLFQ_RESULT -eq 0 ]; then
            echo "✓ MLFQ tests passed"
        else
            echo "✗ MLFQ tests failed"
        fi
    fi
else
    echo "Warning: test_mlfq.c not found"
fi

# 运行主测试程序
echo -e "\n--- Running Main Test Program ---"
if [ -f "$BIN_DIR/scheduler_test" ]; then
    echo "Executing main scheduler test..."
    echo ""
    "$BIN_DIR/scheduler_test" <<< "5"  # 自动选择退出，避免交互
    MAIN_RESULT=$?
    if [ $MAIN_RESULT -eq 0 ]; then
        echo "✓ Main test program completed"
    else
        echo "✗ Main test program failed"
    fi
fi

# 运行示例程序
echo -e "\n--- Running Demo Programs ---"

# 简单演示
if [ -f "$EXAMPLES_DIR/demo_simple.c" ]; then
    gcc -Wall -Wextra -O2 -g -I"$PROJECT_DIR/include" \
        "$EXAMPLES_DIR/demo_simple.c" "$PROJECT_DIR/src/scheduler.c" \
        -o "$BIN_DIR/demo_simple" -lm
    
    if [ -f "$BIN_DIR/demo_simple" ]; then
        echo "Built simple demo program"
        # 注意：demo_simple需要交互输入，这里只检查编译
    fi
fi

# 高级演示
if [ -f "$EXAMPLES_DIR/demo_advanced.c" ]; then
    gcc -Wall -Wextra -O2 -g -I"$PROJECT_DIR/include" \
        "$EXAMPLES_DIR/demo_advanced.c" "$PROJECT_DIR/src/scheduler.c" \
        -o "$BIN_DIR/demo_advanced" -lm
    
    if [ -f "$BIN_DIR/demo_advanced" ]; then
        echo "Built advanced demo program"
    fi
fi

# 总结
echo -e "\n======================================"
echo "Test Run Summary:"
echo "--------------------------------------"

# 检查结果
ALL_PASSED=1
if [ -f "$BIN_DIR/test_fifo" ] && [ $FIFO_RESULT -ne 0 ]; then
    echo "✗ FIFO tests: FAILED"
    ALL_PASSED=0
elif [ -f "$BIN_DIR/test_fifo" ]; then
    echo "✓ FIFO tests: PASSED"
fi

if [ -f "$BIN_DIR/test_rr" ] && [ $RR_RESULT -ne 0 ]; then
    echo "✗ RR tests: FAILED"
    ALL_PASSED=0
elif [ -f "$BIN_DIR/test_rr" ]; then
    echo "✓ RR tests: PASSED"
fi

if [ -f "$BIN_DIR/test_mlfq" ] && [ $MLFQ_RESULT -ne 0 ]; then
    echo "✗ MLFQ tests: FAILED"
    ALL_PASSED=0
elif [ -f "$BIN_DIR/test_mlfq" ]; then
    echo "✓ MLFQ tests: PASSED"
fi

if [ -f "$BIN_DIR/scheduler_test" ] && [ $MAIN_RESULT -ne 0 ]; then
    echo "✗ Main program: FAILED"
    ALL_PASSED=0
elif [ -f "$BIN_DIR/scheduler_test" ]; then
    echo "✓ Main program: COMPLETED"
fi

echo -e "\nGenerated executables in $BIN_DIR/:"
ls -la "$BIN_DIR/" | grep -v "^total"

if [ $ALL_PASSED -eq 1 ]; then
    echo -e "\n🎉 All tests completed successfully!"
    echo "You can now run the demo programs manually:"
    echo "  $BIN_DIR/demo_simple    # Simple demonstrations"
    echo "  $BIN_DIR/demo_advanced  # Advanced demonstrations"
    echo "  $BIN_DIR/scheduler_test # Interactive test program"
else
    echo -e "\⚠️  Some tests failed. Check the output above for details."
    exit 1
fi

echo -e "\nTest run completed at $(date)"