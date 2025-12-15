#!/bin/bash

# SparrowOS内存管理基础测试
# 测试基本分配和释放功能

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
SCRIPTS_DIR="$PROJECT_ROOT/scripts"

# 测试计数
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# 测试日志文件
TEST_LOG="$BUILD_DIR/test_basic_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$BUILD_DIR"

echo -e "${BLUE}=== SparrowOS Memory Manager - Basic Tests ===${NC}" | tee "$TEST_LOG"
echo -e "Test log: $TEST_LOG" | tee -a "$TEST_LOG"
echo -e "Timestamp: $(date)" | tee -a "$TEST_LOG"

# 辅助函数：运行测试
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "\n${YELLOW}[Test $TOTAL_TESTS] $test_name${NC}" | tee -a "$TEST_LOG"
    echo -e "Command: $test_cmd" >> "$TEST_LOG"
    
    # 运行测试命令
    if eval "$test_cmd" 2>&1 | tee -a "$TEST_LOG"; then
        echo -e "${GREEN}✓ PASSED${NC}" | tee -a "$TEST_LOG"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}" | tee -a "$TEST_LOG"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# 辅助函数：检查输出中是否包含特定文本
check_output() {
    local output="$1"
    local pattern="$2"
    local description="$3"
    
    if echo "$output" | grep -q "$pattern"; then
        echo -e "${GREEN}  ✓ $description${NC}" | tee -a "$TEST_LOG"
        return 0
    else
        echo -e "${RED}  ✗ $description${NC}" | tee -a "$TEST_LOG"
        echo -e "    Expected pattern: $pattern" | tee -a "$TEST_LOG"
        return 1
    fi
}

# 测试1: 构建系统
run_test "Build System" "
    cd '$PROJECT_ROOT' && \
    make clean && \
    make all && \
    [ -f '$BUILD_DIR/sparrowos.bin' ] && \
    [ -f '$BUILD_DIR/sparrowos.elf' ]
"

# 测试2: 运行基本测试（通过QEMU捕获输出）
run_test "Basic Allocation Test" "
    cd '$PROJECT_ROOT' && \
    timeout 10s make run 2>&1 | \
    tee '$BUILD_DIR/qemu_output.log' | \
    grep -q 'SparrowOS - Memory Manager'
"

# 分析QEMU输出
QEMU_OUTPUT=$(cat "$BUILD_DIR/qemu_output.log" 2>/dev/null || echo "")

echo -e "\n${BLUE}=== Analyzing Output ===${NC}" | tee -a "$TEST_LOG"

# 检查关键输出
check_output "$QEMU_OUTPUT" "Memory manager initialized" "Memory manager initialization"
check_output "$QEMU_OUTPUT" "Heap region:" "Heap region information"
check_output "$QEMU_OUTPUT" "Running memory tests" "Test suite execution"
check_output "$QEMU_OUTPUT" "Basic Allocation" "Basic allocation test"
check_output "$QEMU_OUTPUT" "PASSED" "Tests passed indication"
check_output "$QEMU_OUTPUT" "All tests PASSED" "All tests completed"

# 测试3: 检查内存统计
run_test "Memory Statistics" "
    echo '$QEMU_OUTPUT' | \
    grep -q 'Memory Statistics' && \
    echo '$QEMU_OUTPUT' | \
    grep -q 'Total Memory:' && \
    echo '$QEMU_OUTPUT' | \
    grep -q 'Free Memory:'
"

# 测试4: 检查无崩溃运行
run_test "No Crash/Exception" "
    ! echo '$QEMU_OUTPUT' | grep -q -i 'panic\|exception\|error\|fault' || \
    (echo 'Found errors in output:' && \
     echo '$QEMU_OUTPUT' | grep -i 'panic\|exception\|error\|fault' | head -5 && \
     false)
"

# 测试5: 验证具体分配模式
echo -e "\n${BLUE}=== Verifying Allocation Patterns ===${NC}" | tee -a "$TEST_LOG"

# 从输出中提取分配信息
ALLOC_INFO=$(echo "$QEMU_OUTPUT" | grep -A2 "Basic allocation:" | tail -5)
if echo "$ALLOC_INFO" | grep -q "Allocated:"; then
    echo -e "${GREEN}✓ Allocation patterns found${NC}" | tee -a "$TEST_LOG"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
else
    echo -e "${YELLOW}⚠ Allocation patterns not clearly visible${NC}" | tee -a "$TEST_LOG"
fi

# 最终统计
echo -e "\n${BLUE}=== Test Summary ===${NC}" | tee -a "$TEST_LOG"
echo -e "Total tests:  $TOTAL_TESTS" | tee -a "$TEST_LOG"
echo -e "Passed:       $TESTS_PASSED" | tee -a "$TEST_LOG"
echo -e "Failed:       $TESTS_FAILED" | tee -a "$TEST_LOG"

# 计算通过率
if [ $TOTAL_TESTS -gt 0 ]; then
    PASS_RATE=$((TESTS_PASSED * 100 / TOTAL_TESTS))
    echo -e "Pass rate:    $PASS_RATE%" | tee -a "$TEST_LOG"
else
    echo -e "Pass rate:    N/A (no tests run)" | tee -a "$TEST_LOG"
fi

# 显示QEMU输出摘要
echo -e "\n${BLUE}=== QEMU Output Summary ===${NC}" | tee -a "$TEST_LOG"
echo "$QEMU_OUTPUT" | tail -20 | tee -a "$TEST_LOG"

# 检查是否需要详细输出
if [ "$1" = "--verbose" ] || [ "$1" = "-v" ]; then
    echo -e "\n${BLUE}=== Full QEMU Output ===${NC}" | tee -a "$TEST_LOG"
    echo "$QEMU_OUTPUT" | tee -a "$TEST_LOG"
fi

# 保存测试结果
TEST_RESULT_FILE="$BUILD_DIR/test_results.json"
cat > "$TEST_RESULT_FILE" << EOF
{
  "test_suite": "basic_memory_tests",
  "timestamp": "$(date -Iseconds)",
  "total_tests": $TOTAL_TESTS,
  "passed": $TESTS_PASSED,
  "failed": $TESTS_FAILED,
  "pass_rate": $PASS_RATE,
  "environment": {
    "project_root": "$PROJECT_ROOT",
    "build_dir": "$BUILD_DIR",
    "kernel_size": "$(stat -c%s "$BUILD_DIR/sparrowos.bin" 2>/dev/null || echo 0)"
  }
}
EOF

echo -e "\n${GREEN}Test results saved to: $TEST_RESULT_FILE${NC}" | tee -a "$TEST_LOG"

# 决定退出码
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✅ All tests passed!${NC}" | tee -a "$TEST_LOG"
    exit 0
else
    echo -e "\n${RED}❌ $TESTS_FAILED test(s) failed${NC}" | tee -a "$TEST_LOG"
    exit 1
fi