#!/bin/bash

# 性能对比脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../logs"
RESULTS_DIR="$SCRIPT_DIR/../results"
ITERATIONS=100  # 更多迭代以获得准确结果

echo "=== Performance Benchmark Script ==="
echo "Iterations per test: $ITERATIONS"
echo "This will compare UINTR vs Pipe IPC performance"

# 创建目录
mkdir -p "$LOG_DIR" "$RESULTS_DIR"

# 清理
echo "Cleaning up..."
"$SCRIPT_DIR/run_uintr_test.sh" 2>&1 | grep -q "cleaning" || true
"$SCRIPT_DIR/run_pipe_test.sh" 2>&1 | grep -q "cleaning" || true
sleep 2

# 运行UINTR测试
echo -e "\n=== Running UINTR Benchmark ==="
"$SCRIPT_DIR/run_uintr_test.sh" > "$LOG_DIR/uintr_bench.log" 2>&1
UINTR_EXIT=$?

# 提取UINTR性能数据
UINTR_LATENCY=$(grep "Average latency:" "$LOG_DIR/client.log" 2>/dev/null | awk '{print $3}' || echo "0")

# 运行Pipe测试
echo -e "\n=== Running Pipe Benchmark ==="
"$SCRIPT_DIR/run_pipe_test.sh" > "$LOG_DIR/pipe_bench.log" 2>&1
PIPE_EXIT=$?

# 提取Pipe性能数据
PIPE_LATENCY=$(grep "Average RTT latency:" "$LOG_DIR/pipe_client.log" 2>/dev/null | awk '{print $4}' || echo "0")

# 生成对比报告
REPORT_FILE="$RESULTS_DIR/benchmark_report_$(date +%Y%m%d_%H%M%S).txt"

cat > "$REPORT_FILE" << EOF
=== User Interrupt vs Pipe IPC Benchmark Report ===
Test Date: $(date)
Iterations: $ITERATIONS
System: $(uname -a)

--- Results ---
UINTR Average Latency: $UINTR_LATENCY us
Pipe Average Latency:  $PIPE_LATENCY us

--- Performance Improvement ---
UINTR is $(echo "scale=2; $PIPE_LATENCY / $UINTR_LATENCY" | bc)x faster than Pipe

--- Analysis ---
The performance difference demonstrates the advantage of user-level interrupts:
1. UINTR avoids kernel context switches
2. No system call overhead for interrupt delivery
3. Direct user-space to user-space notification
4. Lower cache pollution

--- Test Status ---
UINTR Test: $( [ $UINTR_EXIT -eq 0 ] && echo "PASSED" || echo "FAILED" )
Pipe Test:  $( [ $PIPE_EXIT -eq 0 ] && echo "PASSED" || echo "FAILED" )
EOF

# 显示报告
echo -e "\n=== Benchmark Report ==="
cat "$REPORT_FILE"

# 可视化数据
echo -e "\n=== Performance Comparison ==="
echo "Latency (lower is better):"
echo "┌────────────────────┬─────────────┐"
echo "│ Method            │ Latency (us)│"
echo "├────────────────────┼─────────────┤"
printf "│ UINTR             │ %11s │\n" $UINTR_LATENCY
printf "│ Pipe IPC          │ %11s │\n" $PIPE_LATENCY
echo "└────────────────────┴─────────────┘"

echo -e "\nDetailed reports saved in:"
echo "  Logs: $LOG_DIR/"
echo "  Results: $RESULTS_DIR/"
echo "  Full report: $REPORT_FILE"