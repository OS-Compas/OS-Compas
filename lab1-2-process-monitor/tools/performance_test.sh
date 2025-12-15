#!/bin/bash

# 进程监视器 - 性能测试脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MONITOR_SCRIPT="$PROJECT_ROOT/src/process_monitor.sh"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查必需工具
check_requirements() {
    local missing=()
    
    for tool in bc time ps; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "缺少必需工具: ${missing[*]}"
        exit 1
    fi
    
    if [ ! -f "$MONITOR_SCRIPT" ]; then
        log_error "找不到监视器脚本: $MONITOR_SCRIPT"
        exit 1
    fi
}

# 性能测试函数
run_performance_test() {
    local test_name="$1"
    local command="$2"
    local iterations="${3:-5}"
    
    log_info "运行性能测试: $test_name"
    echo "命令: $command"
    echo "迭代次数: $iterations"
    echo "----------------------------------------"
    
    local total_real=0
    local total_user=0
    local total_sys=0
    
    for ((i=1; i<=iterations; i++)); do
        echo -n "第 $i 次测试... "
        
        # 使用time命令测量性能
        local output
        output=$(/usr/bin/time -p bash -c "$command" 2>&1)
        
        # 提取时间信息
        local real_time=$(echo "$output" | grep real | awk '{print $2}')
        local user_time=$(echo "$output" | grep user | awk '{print $2}')
        local sys_time=$(echo "$output" | grep sys | awk '{print $2}')
        
        echo "real: ${real_time}s, user: ${user_time}s, sys: ${sys_time}s"
        
        total_real=$(echo "$total_real + $real_time" | bc)
        total_user=$(echo "$total_user + $user_time" | bc)
        total_sys=$(echo "$total_sys + $sys_time" | bc)
    done
    
    # 计算平均值
    local avg_real=$(echo "scale=3; $total_real / $iterations" | bc)
    local avg_user=$(echo "scale=3; $total_user / $iterations" | bc)
    local avg_sys=$(echo "scale=3; $total_sys / $iterations" | bc)
    
    echo "----------------------------------------"
    echo -e "${GREEN}平均时间 - real: ${avg_real}s, user: ${avg_user}s, sys: ${avg_sys}s${NC}"
    echo
    
    # 返回结果
    echo "$avg_real|$avg_user|$avg_sys"
}

# 内存使用测试
test_memory_usage() {
    log_info "测试内存使用情况..."
    
    # 创建测试进程
    local test_pid
    "$PROJECT_ROOT/examples/sample_scripts/memory_intensive" &
    test_pid=$!
    
    sleep 2
    
    # 监视内存使用
    echo "测试进程内存使用:"
    "$MONITOR_SCRIPT" -p "$test_pid" -i 1 -c 3
    
    # 清理
    kill "$test_pid" 2>/dev/null || true
    echo
}

# CPU负载测试
test_cpu_load() {
    log_info "测试CPU负载下的性能..."
    
    # 创建CPU密集型进程
    local cpu_pid
    "$PROJECT_ROOT/examples/sample_scripts/cpu_intensive" &
    cpu_pid=$!
    
    sleep 1
    
    # 在CPU负载下测试监视器性能
    run_performance_test "CPU负载下进程列表" "$MONITOR_SCRIPT --cpu-top" 3
    
    # 清理
    kill "$cpu_pid" 2>/dev/null || true
    echo
}

# 多进程测试
test_multiple_processes() {
    log_info "测试多进程监视..."
    
    # 创建多个测试进程
    local pids=()
    for i in {1..5}; do
        "$PROJECT_ROOT/examples/sample_scripts/cpu_intensive" &
        pids+=($!)
    done
    
    sleep 1
    
    # 测试进程树功能
    run_performance_test "进程树显示" "$MONITOR_SCRIPT --tree" 3
    
    # 测试/proc分析
    run_performance_test "/proc分析" "$MONITOR_SCRIPT --analyze-proc" 3
    
    # 清理
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    echo
}

# 压力测试
stress_test() {
    log_info "运行压力测试..."
    
    local stress_duration=30
    local monitor_interval=2
    
    echo "压力测试将持续 ${stress_duration} 秒"
    echo "监视器将以 ${monitor_interval} 秒间隔运行"
    echo
    
    # 启动监视器在后台运行
    local monitor_pid
    {
        for ((i=0; i<stress_duration/monitor_interval; i++)); do
            echo "=== 第 $((i+1)) 次采样 ==="
            "$MONITOR_SCRIPT" --cpu-top | head -15
            echo
            sleep "$monitor_interval"
        done
    } > "/tmp/process_monitor_stress_test.log" 2>&1 &
    monitor_pid=$!
    
    # 创建一些负载
    local load_pids=()
    for i in {1..3}; do
        "$PROJECT_ROOT/examples/sample_scripts/cpu_intensive" &
        load_pids+=($!)
    done
    
    # 等待监视器完成
    wait "$monitor_pid"
    
    # 清理负载进程
    for pid in "${load_pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    
    log_success "压力测试完成"
    echo "日志文件: /tmp/process_monitor_stress_test.log"
    echo "最后几行输出:"
    tail -10 "/tmp/process_monitor_stress_test.log"
    echo
}

# 资源使用分析
analyze_resource_usage() {
    log_info "分析资源使用情况..."
    
    # 使用ps分析监视器脚本的资源使用
    echo "监视器脚本资源使用:"
    ps aux | grep process_monitor | grep -v grep | head -5
    
    echo
    echo "系统资源状态:"
    free -h
    echo
    echo "CPU使用率:"
    top -bn1 | grep "Cpu(s)" | head -1
    echo
}

# 生成性能报告
generate_report() {
    local report_file="/tmp/process_monitor_performance_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "进程监视器性能测试报告"
        echo "生成时间: $(date)"
        echo "系统信息: $(uname -a)"
        echo "========================================"
        echo
    } > "$report_file"
    
    log_info "性能报告已生成: $report_file"
}

# 主测试函数
main() {
    log_info "开始进程监视器性能测试"
    echo "========================================"
    
    check_requirements
    
    echo "1. 基础性能测试"
    echo "----------------------------------------"
    run_performance_test "进程列表" "$MONITOR_SCRIPT --cpu-top" 5
    run_performance_test "进程树" "$MONITOR_SCRIPT --tree" 3
    run_performance_test "/proc分析" "$MONITOR_SCRIPT --analyze-proc" 3
    
    echo
    echo "2. 内存使用测试"
    echo "----------------------------------------"
    test_memory_usage
    
    echo
    echo "3. CPU负载测试"
    echo "----------------------------------------"
    test_cpu_load
    
    echo
    echo "4. 多进程测试"
    echo "----------------------------------------"
    test_multiple_processes
    
    echo
    echo "5. 资源使用分析"
    echo "----------------------------------------"
    analyze_resource_usage
    
    echo
    echo "6. 压力测试"
    echo "----------------------------------------"
    read -p "是否运行压力测试？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        stress_test
    fi
    
    generate_report
    
    log_success "性能测试完成！"
    log_info "建议:"
    echo "  - 对于生产环境，建议监视间隔不小于2秒"
    echo "  - 在高负载系统中，考虑使用Python版本以获得更好性能"
    echo "  - 定期检查日志文件以监控资源使用趋势"
}

# 显示帮助信息
show_help() {
    echo "进程监视器 - 性能测试脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -q, --quick    快速测试（跳过压力测试）"
    echo "  -f, --full     完整测试（包含压力测试）"
    echo ""
    echo "示例:"
    echo "  $0             # 标准测试"
    echo "  $0 --quick     # 快速测试"
}

# 参数解析
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -q|--quick)
        # 快速测试模式
        stress_test() { log_info "跳过压力测试"; }
        main
        ;;
    -f|--full)
        # 完整测试模式（默认）
        main
        ;;
    *)
        main
        ;;
esac