#!/bin/bash

# 读写频率跟踪测试脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/../src"
TEST_DIR="/tmp/ebpf_rw_test_$(date +%s)"

echo "========================================"
echo "   read/write频率跟踪测试"
echo "========================================"
echo "测试目录: $TEST_DIR"
echo "开始时间: $(date)"
echo "========================================"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 创建测试目录
mkdir -p "$TEST_DIR"

# 生成测试数据
generate_test_data() {
    echo "生成测试数据..."
    
    # 创建测试文件
    dd if=/dev/urandom of="$TEST_DIR/test_large.bin" bs=1M count=10 2>/dev/null
    echo "Test file content" > "$TEST_DIR/test_small.txt"
    
    # 创建测试脚本
    cat > "$TEST_DIR/test_io.sh" << 'EOF'
#!/bin/bash
TEST_DIR="$1"
echo "开始I/O测试..."
for i in {1..50}; do
    # 随机选择操作
    OP=$((RANDOM % 3))
    case $OP in
        0)
            # read操作
            cat "$TEST_DIR/test_large.bin" > /dev/null 2>&1
            ;;
        1)
            # write操作
            echo "Write test $i at $(date)" >> "$TEST_DIR/write_log.txt"
            ;;
        2)
            # 混合操作
            head -c 1024 "$TEST_DIR/test_large.bin" > /dev/null 2>&1
            echo "Mixed test $i" >> "$TEST_DIR/mixed_log.txt"
            ;;
    esac
    sleep 0.1
done
echo "I/O测试完成"
EOF
    
    chmod +x "$TEST_DIR/test_io.sh"
}

# 运行读写频率跟踪
run_rw_frequency_trace() {
    echo -e "\n${YELLOW}[阶段1: 运行读写频率跟踪]${NC}"
    echo "跟踪将持续15秒..."
    
    # 在后台启动跟踪
    sudo bpftrace -e '
BEGIN {
    printf("开始跟踪read/write系统调用频率...\n");
    printf("时间\t\t 读取\t 写入\t 图表\n");
    printf("=======================================\n");
}

tracepoint:syscalls:sys_enter_read {
    @read_total = count();
    @read_by_sec[nsecs/1000000000] = count();
}

tracepoint:syscalls:sys_enter_write {
    @write_total = count();
    @write_by_sec[nsecs/1000000000] = count();
}

interval:s:1 {
    $now = nsecs / 1000000000;
    $time_str = strftime("%H:%M:%S", nsecs);
    
    $read_sec = @read_by_sec[$now-1] != 0 ? @read_by_sec[$now-1] : 0;
    $write_sec = @write_by_sec[$now-1] != 0 ? @write_by_sec[$now-1] : 0;
    
    printf("%s %6d %6d ", $time_str, $read_sec, $write_sec);
    
    // 绘制简单柱状图
    $max = 20;
    $r_bar = $read_sec > $max ? $max : $read_sec;
    $w_bar = $write_sec > $max ? $max : $write_sec;
    
    for ($i = 0; $i < $max; $i++) {
        if ($i < $r_bar && $i < $w_bar) {
            printf("█");
        } else if ($i < $r_bar) {
            printf("R");
        } else if ($i < $w_bar) {
            printf("W");
        } else {
            printf(" ");
        }
    }
    printf("\n");
    
    // 清理旧数据（保留最近10秒）
    delete(@read_by_sec[$now-11]);
    delete(@write_by_sec[$now-11]);
}

END {
    printf("\n=======================================\n");
    printf("最终统计:\n");
    printf("总读取操作: %d\n", @read_total);
    printf("总写入操作: %d\n", @write_total);
    printf("平均频率: %.1f 读取/秒, %.1f 写入/秒\n", 
           @read_total/15.0, @write_total/15.0);
}' > "$TEST_DIR/trace_output.txt" 2>&1 &
    
    BPF_TRACE_PID=$!
    
    # 等待2秒让跟踪器启动
    sleep 2
    
    # 运行I/O测试
    echo -e "\n${YELLOW}[阶段2: 运行I/O负载测试]${NC}"
    "$TEST_DIR/test_io.sh" "$TEST_DIR" &
    IO_TEST_PID=$!
    
    # 同时运行一些系统命令增加负载
    (for i in {1..10}; do find /usr/include -name "*.h" 2>/dev/null | head -100 | xargs cat > /dev/null 2>&1; sleep 0.5; done) &
    FIND_PID=$!
    
    # 等待15秒
    sleep 15
    
    # 停止跟踪
    kill $BPF_TRACE_PID 2>/dev/null || true
    wait $IO_TEST_PID 2>/dev/null || true
    kill $FIND_PID 2>/dev/null || true
    
    # 等待确保跟踪器完全停止
    sleep 1
}

# 分析结果
analyze_results() {
    echo -e "\n${YELLOW}[阶段3: 分析跟踪结果]${NC}"
    
    if [ ! -f "$TEST_DIR/trace_output.txt" ]; then
        echo -e "${RED}错误: 跟踪输出文件未找到${NC}"
        return 1
    fi
    
    # 显示跟踪结果摘要
    echo "跟踪结果摘要:"
    echo "----------------------------------------"
    tail -20 "$TEST_DIR/trace_output.txt"
    echo "----------------------------------------"
    
    # 提取统计数据
    TOTAL_READ=$(grep "总读取操作" "$TEST_DIR/trace_output.txt" | awk '{print $NF}')
    TOTAL_WRITE=$(grep "总写入操作" "$TEST_DIR/trace_output.txt" | awk '{print $NF}')
    AVG_READ=$(grep "平均频率" "$TEST_DIR/trace_output.txt" | awk '{print $4}')
    AVG_WRITE=$(grep "平均频率" "$TEST_DIR/trace_output.txt" | awk '{print $6}')
    
    echo -e "\n${YELLOW}统计结果:${NC}"
    echo "总读取操作: $TOTAL_READ"
    echo "总写入操作: $TOTAL_WRITE"
    echo "平均读取频率: $AVG_READ 操作/秒"
    echo "平均写入频率: $AVG_WRITE 操作/秒"
    
    # 验证结果
    echo -e "\n${YELLOW}[验证测试结果]${NC}"
    
    if [ -n "$TOTAL_READ" ] && [ "$TOTAL_READ" -gt 0 ]; then
        echo -e "${GREEN}✓ 读取跟踪成功: 检测到 $TOTAL_READ 次读取操作${NC}"
    else
        echo -e "${RED}✗ 读取跟踪失败: 未检测到读取操作${NC}"
        return 1
    fi
    
    if [ -n "$TOTAL_WRITE" ] && [ "$TOTAL_WRITE" -gt 0 ]; then
        echo -e "${GREEN}✓ 写入跟踪成功: 检测到 $TOTAL_WRITE 次写入操作${NC}"
    else
        echo -e "${YELLOW}⚠ 写入跟踪警告: 检测到较少写入操作 ($TOTAL_WRITE)${NC}"
    fi
    
    # 检查是否有图表输出
    if grep -q "█" "$TEST_DIR/trace_output.txt"; then
        echo -e "${GREEN}✓ 时序图表生成成功${NC}"
    else
        echo -e "${YELLOW}⚠ 时序图表生成警告: 未检测到图表字符${NC}"
    fi
    
    # 生成可视化报告
    generate_report
}

# 生成HTML报告
generate_report() {
    cat > "$TEST_DIR/report.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>eBPF读写频率测试报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .stats { background: #f9f9f9; padding: 15px; margin: 20px 0; border-left: 4px solid #4CAF50; }
        .trace-output { background: #333; color: #0f0; padding: 15px; font-family: monospace; white-space: pre; overflow: auto; }
        .success { color: #4CAF50; }
        .warning { color: #FF9800; }
        .error { color: #F44336; }
    </style>
</head>
<body>
    <div class="header">
        <h1>eBPF读写频率跟踪测试报告</h1>
        <p>测试时间: $(date)</p>
        <p>内核版本: $(uname -r)</p>
    </div>
    
    <div class="stats">
        <h2>统计结果</h2>
        <p><strong>总读取操作:</strong> $TOTAL_READ</p>
        <p><strong>总写入操作:</strong> $TOTAL_WRITE</p>
        <p><strong>平均读取频率:</strong> $AVG_READ 操作/秒</p>
        <p><strong>平均写入频率:</strong> $AVG_WRITE 操作/秒</p>
    </div>
    
    <div>
        <h2>跟踪输出</h2>
        <div class="trace-output">
$(tail -30 "$TEST_DIR/trace_output.txt" | sed 's/</\&lt;/g; s/>/\&gt;/g')
        </div>
    </div>
    
    <div>
        <h2>测试文件</h2>
        <ul>
            <li><a href="trace_output.txt">完整跟踪输出</a></li>
            <li><a href="test_io.sh">I/O测试脚本</a></li>
        </ul>
    </div>
</body>
</html>
EOF
    
    echo -e "\n${GREEN}测试报告已生成:${NC}"
    echo "HTML报告: $TEST_DIR/report.html"
    echo "跟踪输出: $TEST_DIR/trace_output.txt"
}

# 清理函数
cleanup() {
    echo -e "\n${YELLOW}[清理阶段]${NC}"
    
    # 杀死所有后台进程
    pkill -f "bpftrace" 2>/dev/null || true
    pkill -f "test_io.sh" 2>/dev/null || true
    
    # 显示测试目录内容
    echo "测试文件保留在: $TEST_DIR"
    echo "如需清理，请运行: rm -rf $TEST_DIR"
    
    echo -e "\n${GREEN}测试完成！${NC}"
}

# 主程序
trap cleanup EXIT

# 检查权限
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}警告: 需要root权限，尝试使用sudo...${NC}"
    exec sudo "$0" "$@"
fi

# 运行测试
generate_test_data
run_rw_frequency_trace
analyze_results

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✅ 读写频率跟踪测试通过！${NC}"
    echo "所有功能正常工作。"
    exit 0
else
    echo -e "\n${RED}❌ 读写频率跟踪测试失败或部分失败${NC}"
    echo "请检查上述错误信息。"
    exit 1
fi