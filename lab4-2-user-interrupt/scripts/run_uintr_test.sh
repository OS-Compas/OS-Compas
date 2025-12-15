#!/bin/bash

# UINTR测试脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../build"
LOG_DIR="$SCRIPT_DIR/../logs"
ITERATIONS=10

echo "=== UINTR Test Script ==="
echo "Iterations: $ITERATIONS"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 清理之前的进程
echo "Cleaning up previous processes..."
pkill -f "uintr_server" 2>/dev/null || true
pkill -f "uintr_client" 2>/dev/null || true
sleep 1

# 清理共享内存
echo "Cleaning up shared memory..."
ipcs -m | grep $(whoami) | awk '{print $2}' | xargs -I {} ipcrm -m {} 2>/dev/null || true

# 启动服务器
echo "Starting UINTR server..."
"$BUILD_DIR/uintr_server" > "$LOG_DIR/server.log" 2>&1 &
SERVER_PID=$!

echo "Server PID: $SERVER_PID"
sleep 2  # 给服务器时间初始化

# 检查服务器是否运行
if ! ps -p $SERVER_PID > /dev/null; then
    echo "Error: Server failed to start"
    cat "$LOG_DIR/server.log"
    exit 1
fi

# 启动客户端
echo "Starting UINTR client..."
"$BUILD_DIR/uintr_client" $SERVER_PID $ITERATIONS > "$LOG_DIR/client.log" 2>&1
CLIENT_EXIT=$?

# 等待客户端完成
wait $CLIENT_PID 2>/dev/null || true

# 停止服务器
echo "Stopping server..."
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

# 显示结果
echo -e "\n=== Test Results ==="
echo "Client exit code: $CLIENT_EXIT"

if [ $CLIENT_EXIT -eq 0 ]; then
    echo "✓ UINTR test passed"
    
    # 显示性能数据
    echo -e "\nPerformance summary:"
    grep -A 5 "Test Results:" "$LOG_DIR/client.log" || true
else
    echo "✗ UINTR test failed"
    echo -e "\nServer log:"
    tail -20 "$LOG_DIR/server.log"
    echo -e "\nClient log:"
    tail -20 "$LOG_DIR/client.log"
fi

echo -e "\nLog files saved in: $LOG_DIR"