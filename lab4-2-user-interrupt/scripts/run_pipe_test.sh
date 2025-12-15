#!/bin/bash

# 管道测试脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../build"
LOG_DIR="$SCRIPT_DIR/../logs"
ITERATIONS=10

echo "=== Pipe Test Script ==="
echo "Iterations: $ITERATIONS"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 清理之前的进程
echo "Cleaning up previous processes..."
pkill -f "pipe_server" 2>/dev/null || true
pkill -f "pipe_client" 2>/dev/null || true
sleep 1

# 清理管道文件
echo "Cleaning up pipe files..."
rm -f /tmp/pipe_server_* 2>/dev/null || true

# 启动服务器
echo "Starting Pipe server..."
"$BUILD_DIR/pipe_server" $ITERATIONS > "$LOG_DIR/pipe_server.log" 2>&1 &
SERVER_PID=$!

echo "Server PID: $SERVER_PID"
sleep 1  # 给服务器时间创建管道

# 检查服务器是否运行
if ! ps -p $SERVER_PID > /dev/null; then
    echo "Error: Server failed to start"
    cat "$LOG_DIR/pipe_server.log"
    exit 1
fi

# 启动客户端
echo "Starting Pipe client..."
"$BUILD_DIR/pipe_client" $SERVER_PID $ITERATIONS > "$LOG_DIR/pipe_client.log" 2>&1
CLIENT_EXIT=$?

# 等待客户端完成
wait $CLIENT_PID 2>/dev/null || true

# 停止服务器
sleep 1
echo "Stopping server..."
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

# 显示结果
echo -e "\n=== Test Results ==="
echo "Client exit code: $CLIENT_EXIT"

if [ $CLIENT_EXIT -eq 0 ]; then
    echo "✓ Pipe test passed"
    
    # 显示性能数据
    echo -e "\nPerformance summary:"
    grep -A 5 "Test Results:" "$LOG_DIR/pipe_client.log" || true
    grep -A 5 "Pipe Test Results:" "$LOG_DIR/pipe_server.log" || true
else
    echo "✗ Pipe test failed"
    echo -e "\nServer log:"
    tail -20 "$LOG_DIR/pipe_server.log"
    echo -e "\nClient log:"
    tail -20 "$LOG_DIR/pipe_client.log"
fi

echo -e "\nLog files saved in: $LOG_DIR"