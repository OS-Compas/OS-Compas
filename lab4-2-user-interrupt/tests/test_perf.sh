#!/bin/bash

# 性能测试脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
LOG_DIR="$SCRIPT_DIR/../logs"
ITERATIONS=1000

echo "=== Performance Test Suite ==="
echo "Iterations: $ITERATIONS"
echo "This will run comprehensive performance tests"

# 创建目录
mkdir -p "$RESULTS_DIR" "$LOG_DIR"

# 函数：运行单个性能测试
run_perf_test() {
    local test_name="$1"
    local cmd="$2"
    local log_file="$LOG_DIR/perf_${test_name}.log"
    
    echo -e "\nRunning $test_name..."
    
    # 运行测试
    eval "$cmd" > "$log_file" 2>&1
    
    # 提取性能数据
    if [ -f "$log_file" ]; then
        local latency=$(grep -oP "Average.*latency:\s*\K[\d.]+" "$log_file" | head -1)
        local throughput=$(grep -oP "throughput.*\K[\d.]+" "$log_file" 2>/dev/null || echo "0")
        
        echo "  Latency: ${latency:-N/A} us"
        echo "  Throughput: ${throughput:-N/A} calls/sec"
        
        # 保存结果
        echo "$test_name,$latency,$throughput" >> "$RESULTS_DIR/perf_summary.csv"
    else
        echo "  ✗ Test failed: log file not created"
    fi
}

# 初始化结果文件
echo "test_name,latency_us,throughput_calls_sec" > "$RESULTS_DIR/perf_summary.csv"

# 预热运行
echo "Step 1: Warm-up runs..."
"$SCRIPT_DIR/../scripts/run_uintr_test.sh" 2>&1 >/dev/null
"$SCRIPT_DIR/../scripts/run_pipe_test.sh" 2>&1 >/dev/null
sleep 2

# 测试1: UINTR延迟测试
run_perf_test "uintr_latency" \
    "$SCRIPT_DIR/../scripts/run_uintr_test.sh"

# 测试2: 管道延迟测试
run_perf_test "pipe_latency" \
    "$SCRIPT_DIR/../scripts/run_pipe_test.sh"

# 测试3: UINTR高负载测试
echo -e "\nTest 3: UINTR High Load Test"
for i in 1 2 3; do
    echo "  Run $i/3..."
    "$SCRIPT_DIR/../scripts/run_uintr_test.sh" 2>&1 >> "$LOG_DIR/uintr_highload.log"
    sleep 1
done

# 测试4: 管道高负载测试
echo -e "\nTest 4: Pipe High Load Test"
for i in 1 2 3; do
    echo "  Run $i/3..."
    "$SCRIPT_DIR/../scripts/run_pipe_test.sh" 2>&1 >> "$LOG_DIR/pipe_highload.log"
    sleep 1
done

# 测试5: 并发测试
echo -e "\nTest 5: Concurrency Test"
echo "Starting multiple clients..."

# 启动服务器
"$SCRIPT_DIR/../build/uintr_server" > "$LOG_DIR/concurrent_server.log" 2>&1 &
CONCURRENT_SERVER_PID=$!
sleep 2

# 启动多个客户端
CLIENT_PIDS=()
for i in 1 2 3; do
    "$SCRIPT_DIR/../build/uintr_client" $CONCURRENT_SERVER_PID 50 > "$LOG_DIR/concurrent_client_$i.log" 2>&1 &
    CLIENT_PIDS+=($!)
done

# 等待所有客户端完成
echo "  Waiting for clients to complete..."
for pid in "${CLIENT_PIDS[@]}"; do
    wait $pid 2>/dev/null || true
done

# 停止服务器
kill $CONCURRENT_SERVER_PID 2>/dev/null || true
wait $CONCURRENT_SERVER_PID 2>/dev/null || true

echo "  ✓ Concurrency test completed"

# 测试6: 内存使用测试
echo -e "\nTest 6: Memory Usage Test"

# 使用time命令测量资源使用
echo "Measuring UINTR memory usage..."
/usr/bin/time -v "$SCRIPT_DIR/../build/uintr_server" 2>&1 | grep -E "(Maximum resident|Page size)" > "$LOG_DIR/mem_uintr.log" &
UINTR_MEM_PID=$!
sleep 1
kill $UINTR_MEM_PID 2>/dev/null || true

echo "Measuring Pipe memory usage..."
/usr/bin/time -v "$SCRIPT_DIR/../build/pipe_server" 5 2>&1 | grep -E "(Maximum resident|Page size)" > "$LOG_DIR/mem_pipe.log" &
PIPE_MEM_PID=$!
sleep 1
kill $PIPE_MEM_PID 2>/dev/null || true

# 生成性能报告
echo -e "\n=== Generating Performance Report ==="

# 计算平均延迟
UINTR_AVG=$(grep "uintr_latency" "$RESULTS_DIR/perf_summary.csv" | cut -d',' -f2)
PIPE_AVG=$(grep "pipe_latency" "$RESULTS_DIR/perf_summary.csv" | cut -d',' -f2)

if [ -n "$UINTR_AVG" ] && [ -n "$PIPE_AVG" ] && [ "$UINTR_AVG" != "0" ]; then
    SPEEDUP=$(echo "scale=2; $PIPE_AVG / $UINTR_AVG" | bc)
else
    SPEEDUP="N/A"
fi

# 创建详细报告
REPORT_FILE="$RESULTS_DIR/performance_report_$(date +%Y%m%d_%H%M%S).txt"

cat > "$REPORT_FILE" << EOF
=== Performance Test Report ===
Test Date: $(date)
System: $(uname -a)
CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2)
Iterations per test: $ITERATIONS

--- Results Summary ---
UINTR Average Latency: ${UINTR_AVG:-N/A} µs
Pipe Average Latency:  ${PIPE_AVG:-N/A} µs
Performance Speedup:   ${SPEEDUP}x

--- Detailed Results ---
$(cat "$RESULTS_DIR/perf_summary.csv" | column -t -s',')

--- Analysis ---
1. Latency Comparison:
   - UINTR: Avoids kernel context switches
   - Pipe: Requires full system call round-trip

2. Memory Usage:
   - UINTR: Minimal kernel involvement
   - Pipe: Additional buffer allocations

3. Scalability:
   - UINTR: Better for high-frequency notifications
   - Pipe: Better for large data transfers

--- Recommendations ---
1. Use UINTR for:
   - Low-latency IPC
   - High-frequency events
   - Real-time systems

2. Use Pipe for:
   - Large data transfers
   - Compatibility with older systems
   - Streaming data

--- Test Environment ---
Kernel: $(uname -r)
Available memory: $(free -h | grep Mem | awk '{print $2}')
CPU cores: $(nproc)
EOF

# 显示报告摘要
echo -e "\n=== Report Summary ==="
tail -20 "$REPORT_FILE"

# 可视化数据
echo -e "\n=== Performance Comparison Chart ==="
echo "Latency (lower is better):"
echo "┌────────────────────┬─────────────┬────────────────┐"
echo "│ Method            │ Latency (µs)│ Relative Speed │"
echo "├────────────────────┼─────────────┼────────────────┤"
printf "│ UINTR             │ %11s │ %14s │\n" "${UINTR_AVG:-N/A}" "1.0x (baseline)"
printf "│ Pipe IPC          │ %11s │ %14s │\n" "${PIPE_AVG:-N/A}" "${SPEEDUP}x"
echo "└────────────────────┴─────────────┴────────────────┘"

echo -e "\n=== Performance Tests Completed ==="
echo "Full report saved to: $REPORT_FILE"
echo "Raw data in: $RESULTS_DIR/perf_summary.csv"
echo "Logs in: $LOG_DIR/"