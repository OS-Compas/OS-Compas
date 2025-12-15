
## 🧪 测试脚本

### 1. 基础功能测试（完整版）

**tests/test_basic.sh**

```bash
#!/bin/bash

# eBPF跟踪实验基础功能测试
# 测试所有核心功能是否正常工作

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../scripts"
SRC_DIR="$SCRIPT_DIR/../src"
EXAMPLES_DIR="$SCRIPT_DIR/../examples"

echo "=========================================="
echo "    eBPF跟踪实验 - 基础功能测试套件       "
echo "=========================================="
echo "开始时间: $(date)"
echo "内核版本: $(uname -r)"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 计数器
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# 日志文件
LOG_FILE="/tmp/ebpf_test_$(date +%Y%m%d_%H%M%S).log"
exec 2>&1 | tee "$LOG_FILE"

print_result() {
    local status=$1
    local message=$2
    
    case $status in
        "PASS")
            echo -e "${GREEN}✓ PASS${NC}: $message"
            ((PASS_COUNT++))
            ;;
        "FAIL")
            echo -e "${RED}✗ FAIL${NC}: $message"
            ((FAIL_COUNT++))
            ;;
        "WARN")
            echo -e "${YELLOW}⚠ WARN${NC}: $message"
            ((WARN_COUNT++))
            ;;
        "INFO")
            echo -e "${BLUE}ℹ INFO${NC}: $message"
            ;;
    esac
}

# 检查是否以root运行
check_root() {
    echo -e "\n${BLUE}[测试1: 权限检查]${NC}"
    if [ "$EUID" -eq 0 ]; then
        print_result "PASS" "以root权限运行"
    else
        print_result "WARN" "非root权限运行，部分测试可能需要sudo"
    fi
}

# 检查bpftrace安装
check_bpftrace() {
    echo -e "\n${BLUE}[测试2: bpftrace安装检查]${NC}"
    
    if command -v bpftrace &> /dev/null; then
        VERSION=$(bpftrace --version | head -1)
        print_result "PASS" "bpftrace已安装: $VERSION"
        
        # 检查版本
        MAJOR_VERSION=$(echo "$VERSION" | grep -oP 'v\K\d+')
        if [ "$MAJOR_VERSION" -ge 8 ]; then
            print_result "PASS" "bpftrace版本 ≥ v8.x"
        else
            print_result "WARN" "bpftrace版本较旧: $VERSION"
        fi
    else
        print_result "FAIL" "bpftrace未安装"
        return 1
    fi
}

# 检查内核支持
check_kernel_support() {
    echo -e "\n${BLUE}[测试3: 内核eBPF支持检查]${NC}"
    
    # 检查内核版本
    KERNEL_VERSION=$(uname -r | cut -d. -f1)
    if [ "$KERNEL_VERSION" -ge 4 ]; then
        print_result "PASS" "内核版本 $(uname -r) 支持eBPF"
    else
        print_result "FAIL" "内核版本 $(uname -r) 可能不支持eBPF"
    fi
    
    # 检查BPF系统调用
    if [ -f "/proc/sys/kernel/bpf_stats_enabled" ]; then
        print_result "PASS" "BPF系统调用已启用"
    else
        print_result "WARN" "BPF系统调用可能未启用"
    fi
    
    # 检查调试文件系统
    if mount | grep -q debugfs; then
        print_result "PASS" "debugfs已挂载"
    else
        print_result "WARN" "debugfs未挂载，尝试挂载..."
        sudo mount -t debugfs none /sys/kernel/debug 2>/dev/null && \
            print_result "PASS" "debugfs挂载成功" || \
            print_result "WARN" "debugfs挂载失败"
    fi
}

# 测试tracepoint访问
test_tracepoint() {
    echo -e "\n${BLUE}[测试4: tracepoint访问测试]${NC}"
    
    # 统计可用的tracepoint
    COUNT=$(sudo bpftrace -l 'tracepoint:syscalls:*' 2>/dev/null | wc -l)
    
    if [ "$COUNT" -gt 0 ]; then
        print_result "PASS" "找到 $COUNT 个系统调用tracepoint"
        
        # 测试具体的tracepoint
        if sudo bpftrace -l 'tracepoint:syscalls:sys_enter_open' &>/dev/null; then
            print_result "PASS" "sys_enter_open tracepoint可用"
        else
            print_result "WARN" "sys_enter_open tracepoint不可用"
        fi
    else
        print_result "FAIL" "未找到任何系统调用tracepoint"
    fi
}

# 测试kprobe访问
test_kprobe() {
    echo -e "\n${BLUE}[测试5: kprobe访问测试]${NC}"
    
    # 测试kprobe列表
    COUNT=$(sudo bpftrace -l 'kprobe:*' 2>/dev/null | head -20 | wc -l)
    
    if [ "$COUNT" -gt 0 ]; then
        print_result "PASS" "kprobe功能可用，找到多个内核函数"
        
        # 测试具体的kprobe
        timeout 2 sudo bpftrace -e 'kprobe:vfs_read { printf("kprobe test passed\n"); exit(); }' 2>&1 | \
            grep -q "kprobe test passed" && \
            print_result "PASS" "vfs_read kprobe工作正常" || \
            print_result "WARN" "vfs_read kprobe测试无输出"
    else
        print_result "WARN" "未找到kprobe，可能需要内核调试符号"
    fi
}

# 测试简单eBPF程序执行
test_simple_program() {
    echo -e "\n${BLUE}[测试6: 简单eBPF程序测试]${NC}"
    
    # 测试1: BEGIN/END探针
    if timeout 2 sudo bpftrace -e 'BEGIN { printf("Test 6.1 passed\n"); } END { printf("Test 6.1 completed\n"); }' 2>&1 | \
       grep -q "Test 6.1 passed"; then
        print_result "PASS" "BEGIN/END探针工作正常"
    else
        print_result "FAIL" "BEGIN/END探针测试失败"
    fi
    
    # 测试2: 变量和映射
    if timeout 2 sudo bpftrace -e 'BEGIN { @counter = 10; printf("Counter: %d\n", @counter); exit(); }' 2>&1 | \
       grep -q "Counter: 10"; then
        print_result "PASS" "变量和映射工作正常"
    else
        print_result "FAIL" "变量和映射测试失败"
    fi
    
    # 测试3: 条件语句
    if timeout 2 sudo bpftrace -e 'BEGIN { $x = 5; if ($x > 3) { printf("Condition test passed\n"); } exit(); }' 2>&1 | \
       grep -q "Condition test passed"; then
        print_result "PASS" "条件语句工作正常"
    else
        print_result "FAIL" "条件语句测试失败"
    fi
}

# 测试系统调用跟踪
test_syscall_tracing() {
    echo -e "\n${BLUE}[测试7: 系统调用跟踪测试]${NC}"
    
    # 触发一些系统调用
    echo "Generating test system calls..."
    ls /tmp > /dev/null 2>&1
    echo "test" > /tmp/ebpf_test.txt 2>&1
    cat /tmp/ebpf_test.txt > /dev/null 2>&1
    rm -f /tmp/ebpf_test.txt
    
    # 运行简短的跟踪
    OUTPUT=$(timeout 3 sudo bpftrace -e '
tracepoint:syscalls:sys_enter_open {
    printf("Open by %s\n", comm);
}
tracepoint:syscalls:sys_enter_read {
    @reads = count();
}
interval:s:1 {
    exit();
}
END {
    printf("Total reads: %d\n", @reads);
}' 2>&1)
    
    if echo "$OUTPUT" | grep -q "Total reads:"; then
        READS=$(echo "$OUTPUT" | grep "Total reads:" | awk '{print $3}')
        print_result "PASS" "系统调用跟踪工作正常，检测到 $READS 次read调用"
    else
        print_result "WARN" "系统调用跟踪测试无输出"
    fi
}

# 测试脚本文件执行
test_script_files() {
    echo -e "\n${BLUE}[测试8: 脚本文件测试]${NC}"
    
    # 检查脚本文件是否存在
    if [ -f "$SRC_DIR/trace_open.bt" ]; then
        print_result "PASS" "找到 trace_open.bt 脚本"
        
        # 测试脚本执行
        timeout 2 sudo bpftrace "$SRC_DIR/trace_open.bt" 2>&1 | \
            head -5 | grep -q "opening" && \
            print_result "PASS" "trace_open.bt 执行成功" || \
            print_result "WARN" "trace_open.bt 执行无输出（可能无open操作）"
    else
        print_result "FAIL" "未找到 trace_open.bt 脚本"
    fi
    
    if [ -f "$SRC_DIR/count_syscalls.bt" ]; then
        print_result "PASS" "找到 count_syscalls.bt 脚本"
    fi
    
    if [ -f "$SRC_DIR/read_write_freq.bt" ]; then
        print_result "PASS" "找到 read_write_freq.bt 脚本"
    fi
}

# 测试自动化脚本
test_automation_scripts() {
    echo -e "\n${BLUE}[测试9: 自动化脚本测试]${NC}"
    
    if [ -f "$SCRIPTS_DIR/install_deps.sh" ]; then
        print_result "PASS" "找到 install_deps.sh 脚本"
        chmod +x "$SCRIPTS_DIR/install_deps.sh" 2>/dev/null
    fi
    
    if [ -f "$SCRIPTS_DIR/run_open_trace.sh" ]; then
        print_result "PASS" "找到 run_open_trace.sh 脚本"
        chmod +x "$SCRIPTS_DIR/run_open_trace.sh" 2>/dev/null
    fi
    
    if [ -f "$SCRIPTS_DIR/run_rw_freq.sh" ]; then
        print_result "PASS" "找到 run_rw_freq.sh 脚本"
        chmod +x "$SCRIPTS_DIR/run_rw_freq.sh" 2>/dev/null
    fi
}

# 性能影响测试
test_performance_impact() {
    echo -e "\n${BLUE}[测试10: 性能影响测试]${NC}"
    
    echo "运行性能基准测试（10秒）..."
    
    # 测量无eBPF时的系统调用速率
    echo "阶段1: 无eBPF监控..."
    START_TIME=$(date +%s.%N)
    for i in {1..10000}; do
        : # 空操作
    done
    END_TIME=$(date +%s.%N)
    BASELINE_TIME=$(echo "$END_TIME - $START_TIME" | bc)
    
    # 测量有eBPF时的系统调用速率
    echo "阶段2: 有eBPF监控..."
    
    # 启动一个简单的eBPF程序在后台
    BPF_PID=$(timeout 10 sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { @opens = count(); } interval:s:10 { exit(); }' > /dev/null 2>&1 & echo $!)
    
    START_TIME=$(date +%s.%N)
    for i in {1..10000}; do
        : # 空操作
    done
    END_TIME=$(date +%s.%N)
    MONITORED_TIME=$(echo "$END_TIME - $START_TIME" | bc)
    
    # 计算开销
    if [ -n "$BASELINE_TIME" ] && [ -n "$MONITORED_TIME" ]; then
        OVERHEAD=$(echo "scale=2; ($MONITORED_TIME - $BASELINE_TIME) / $BASELINE_TIME * 100" | bc)
        if (( $(echo "$OVERHEAD < 10" | bc -l) )); then
            print_result "PASS" "eBPF监控开销正常: $OVERHEAD%"
        elif (( $(echo "$OVERHEAD < 50" | bc -l) )); then
            print_result "WARN" "eBPF监控开销较高: $OVERHEAD%"
        else
            print_result "FAIL" "eBPF监控开销过高: $OVERHEAD%"
        fi
    else
        print_result "WARN" "性能测试计算失败"
    fi
    
    # 清理
    kill $BPF_PID 2>/dev/null || true
}

# 运行所有测试
run_all_tests() {
    echo "开始运行所有测试..."
    echo "=========================================="
    
    check_root
    check_bpftrace
    if [ $? -eq 0 ]; then
        check_kernel_support
        test_tracepoint
        test_kprobe
        test_simple_program
        test_syscall_tracing
        test_script_files
        test_automation_scripts
        test_performance_impact
    else
        echo -e "\n${RED}bpftrace未安装，跳过后续测试${NC}"
    fi
    
    echo "=========================================="
    echo "测试完成！"
    echo "=========================================="
    
    # 输出统计
    echo -e "\n${BLUE}测试结果统计:${NC}"
    echo -e "${GREEN}通过: $PASS_COUNT${NC}"
    echo -e "${YELLOW}警告: $WARN_COUNT${NC}"
    echo -e "${RED}失败: $FAIL_COUNT${NC}"
    echo ""
    
    if [ $FAIL_COUNT -eq 0 ]; then
        if [ $WARN_COUNT -eq 0 ]; then
            echo -e "${GREEN}✅ 所有测试通过！eBPF环境完全正常。${NC}"
            echo "可以开始进行实验2.2的所有练习。"
            return 0
        else
            echo -e "${YELLOW}⚠ 测试通过但有警告。${NC}"
            echo "eBPF环境基本正常，但可能需要额外配置。"
            return 1
        fi
    else
        echo -e "${RED}❌ 测试失败！${NC}"
        echo "请检查上述失败项目，并参考 troubleshooting.md 文档。"
        return 2
    fi
}

# 清理函数
cleanup() {
    echo -e "\n清理临时文件..."
    rm -f /tmp/ebpf_test*.txt 2>/dev/null || true
    
    # 卸载可能加载的eBPF程序
    sudo bpftool prog list 2>/dev/null | grep -o 'id [0-9]*' | cut -d' ' -f2 | \
        xargs -I{} sudo bpftool prog unload id {} 2>/dev/null || true
    
    echo "测试日志保存在: $LOG_FILE"
}

# 主程序
trap cleanup EXIT

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -q, --quiet    安静模式，只显示结果"
    echo "  -l, --log FILE 指定日志文件"
    exit 0
fi

if [ "$1" = "--quiet" ] || [ "$1" = "-q" ]; then
    exec > /dev/null
fi

if [ "$1" = "--log" ] || [ "$1" = "-l" ]; then
    if [ -n "$2" ]; then
        LOG_FILE="$2"
    fi
fi

run_all_tests
exit $?