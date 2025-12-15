#!/bin/bash

# 基础功能测试脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../build"
LOG_DIR="$SCRIPT_DIR/../logs"

echo "=== Basic Functionality Test Suite ==="
echo "Testing UINTR and Pipe implementations"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 清理
echo "Step 1: Cleaning up..."
"$SCRIPT_DIR/../scripts/run_uintr_test.sh" 2>&1 | grep -q "Cleaning" || true
"$SCRIPT_DIR/../scripts/run_pipe_test.sh" 2>&1 | grep -q "Cleaning" || true
sleep 2

# 测试1: 构建测试
echo -e "\nTest 1: Build Test"
cd "$SCRIPT_DIR/../src"
if make clean && make; then
    echo "✓ Build test PASSED"
else
    echo "✗ Build test FAILED"
    exit 1
fi

# 测试2: 可执行文件存在性测试
echo -e "\nTest 2: Executable Files Test"
missing_files=0
for binary in uintr_server uintr_client pipe_server pipe_client; do
    if [ -f "$BUILD_DIR/$binary" ]; then
        echo "  ✓ $binary found"
    else
        echo "  ✗ $binary missing"
        missing_files=1
    fi
done

if [ $missing_files -eq 0 ]; then
    echo "✓ Executable test PASSED"
else
    echo "✗ Executable test FAILED"
    exit 1
fi

# 测试3: UINTR服务器启动测试
echo -e "\nTest 3: UINTR Server Startup Test"
timeout 5 "$BUILD_DIR/uintr_server" > "$LOG_DIR/test_server_start.log" 2>&1 &
SERVER_PID=$!
sleep 2

if ps -p $SERVER_PID > /dev/null; then
    echo "✓ UINTR server started successfully"
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
else
    echo "✗ UINTR server failed to start"
    cat "$LOG_DIR/test_server_start.log"
    exit 1
fi

# 测试4: 管道服务器启动测试
echo -e "\nTest 4: Pipe Server Startup Test"
timeout 5 "$BUILD_DIR/pipe_server" 3 > "$LOG_DIR/test_pipe_start.log" 2>&1 &
PIPE_PID=$!
sleep 1

if ps -p $PIPE_PID > /dev/null; then
    echo "✓ Pipe server started successfully"
    kill $PIPE_PID 2>/dev/null || true
    wait $PIPE_PID 2>/dev/null || true
else
    echo "✗ Pipe server failed to start"
    cat "$LOG_DIR/test_pipe_start.log"
    exit 1
fi

# 测试5: 简单通信测试
echo -e "\nTest 5: Basic Communication Test"

# 启动服务器
"$BUILD_DIR/uintr_server" > "$LOG_DIR/comms_server.log" 2>&1 &
COMMS_SERVER_PID=$!
sleep 2

# 运行客户端
"$BUILD_DIR/uintr_client" $COMMS_SERVER_PID 3 > "$LOG_DIR/comms_client.log" 2>&1
CLIENT_EXIT=$?

# 检查结果
if [ $CLIENT_EXIT -eq 0 ] && grep -q "Test completed" "$LOG_DIR/comms_client.log"; then
    echo "✓ Basic communication test PASSED"
else
    echo "✗ Basic communication test FAILED"
    echo "Client output:"
    tail -20 "$LOG_DIR/comms_client.log"
    exit 1
fi

# 清理
kill $COMMS_SERVER_PID 2>/dev/null || true
wait $COMMS_SERVER_PID 2>/dev/null || true

# 测试6: 错误处理测试
echo -e "\nTest 6: Error Handling Test"

# 测试无效参数
"$BUILD_DIR/uintr_client" 99999 1 > "$LOG_DIR/error_test.log" 2>&1
if [ $? -ne 0 ]; then
    echo "✓ Error handling test PASSED (invalid PID rejected)"
else
    echo "✗ Error handling test FAILED"
    exit 1
fi

# 测试7: 资源清理测试
echo -e "\nTest 7: Resource Cleanup Test"

# 创建一些测试资源
touch /tmp/test_pipe_12345
ipcs -m | grep $(whoami) | awk '{print $2}' | xargs -I {} ipcrm -m {} 2>/dev/null || true

# 运行清理脚本
"$SCRIPT_DIR/../scripts/fix_common_issues.sh" > "$LOG_DIR/cleanup_test.log" 2>&1

if [ ! -f /tmp/test_pipe_12345 ]; then
    echo "✓ Resource cleanup test PASSED"
else
    echo "✗ Resource cleanup test FAILED"
    exit 1
fi

echo -e "\n=== All Basic Tests PASSED! ==="
echo "Summary:"
echo "  7 tests completed successfully"
echo "  Logs available in: $LOG_DIR/"
echo "  Next step: Run performance tests with ./tests/test_perf.sh"