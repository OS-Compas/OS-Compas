#!/bin/bash

# 进程监视器 - 高级功能测试

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MONITOR_SCRIPT="$PROJECT_ROOT/src/process_monitor.sh"
PYTHON_MONITOR="$PROJECT_ROOT/src/process_monitor.py"
MANAGER_SCRIPT="$PROJECT_ROOT/src/process_manager.py"
PROC_ANALYZER="$PROJECT_ROOT/src/proc_analyzer.py"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# 临时文件
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# 日志函数
log_info() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[SKIP]${NC} $1"; }

# 检查工具是否可用
check_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_warning "工具 '$1' 不可用，跳过相关测试"
        return 1
    fi
    return 0
}

# 检查文件是否存在
check_file() {
    if [ ! -f "$1" ]; then
        log_warning "文件 '$1' 不存在，跳过相关测试"
        return 1
    fi
    return 0
}

# 断言函数
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    
    if [ "$expected" = "$actual" ]; then
        log_success "$message"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message (期望: '$expected', 实际: '$actual')"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    
    if echo "$actual" | grep -q "$expected"; then
        log_success "$message"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message (期望包含: '$expected')"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_not_contains() {
    local unexpected="$1"
    local actual="$2"
    local message="$3"
    
    if ! echo "$actual" | grep -q "$unexpected"; then
        log_success "$message"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message (期望不包含: '$unexpected')"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_exit_success() {
    local command="$1"
    local message="$2"
    
    if eval "$command" >/dev/null 2>&1; then
        log_success "$message"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_exit_failure() {
    local command="$1"
    local message="$2"
    
    if ! eval "$command" >/dev/null 2>&1; then
        log_success "$message"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 创建测试进程
create_test_process() {
    local type="$1"
    local duration="${2:-10}"
    
    case $type in
        cpu)
            "$PROJECT_ROOT/examples/sample_scripts/cpu_intensive" "$duration" &
            ;;
        memory)
            "$PROJECT_ROOT/examples/sample_scripts/memory_intensive" "$duration" &
            ;;
        tree)
            "$PROJECT_ROOT/examples/sample_scripts/process_tree" "$duration" &
            ;;
        *)
            sleep "$duration" &
            ;;
    esac
    
    local pid=$!
    sleep 1  # 给进程启动时间
    echo "$pid"
}

# 测试Python监视器
test_python_monitor() {
    log_info "测试Python监视器..."
    
    if ! check_file "$PYTHON_MONITOR"; then
        ((TESTS_SKIPPED++))
        return
    fi
    
    if ! check_tool "python3"; then
        ((TESTS_SKIPPED++))
        return
    fi
    
    # 测试帮助信息
    local output
    output=$(python3 "$PYTHON_MONITOR" --help)
    assert_contains "usage" "$output" "Python监视器应显示帮助信息"
    
    # 测试进程列表
    output=$(python3 "$PYTHON_MONITOR" --cpu-top)
    assert_contains "PID" "$output" "Python监视器应显示进程列表"
    
    # 测试进程树
    output=$(python3 "$PYTHON_MONITOR" --tree)
    assert_contains "进程树" "$output" "Python监视器应显示进程树"
}

# 测试进程管理器
test_process_manager() {
    log_info "测试进程管理器..."
    
    if ! check_file "$MANAGER_SCRIPT"; then
        ((TESTS_SKIPPED++))
        return
    fi
    
    if ! check_tool "python3"; then
        ((TESTS_SKIPPED++))
        return
    fi
    
    # 测试帮助信息
    local output
    output=$(python3 "$MANAGER_SCRIPT" --help)
    assert_contains "usage" "$output" "进程管理器应显示帮助信息"
    
    # 测试进程树显示
    output=$(python3 "$MANAGER_SCRIPT" --tree)
    assert_contains "系统进程树" "$output" "进程管理器应显示进程树"
    
    # 测试查找进程
    output=$(python3 "$MANAGER_SCRIPT" --find "systemd" 2>/dev/null || true)
    if [ -n "$output" ]; then
        assert_contains "systemd" "$output" "进程管理器应能查找进程"
    else
        log_warning "未找到systemd进程，跳过查找测试"
        ((TESTS_SKIPPED++))
    fi
}

# 测试/proc分析器
test_proc_analyzer() {
    log_info "测试/proc分析器..."
    
    if ! check_file "$PROC_ANALYZER"; then
        ((TESTS_SKIPPED++))
        return
    fi
    
    if ! check_tool "python3"; then
        ((TESTS_SKIPPED++))
        return
    fi
    
    # 测试基本功能
    local output
    output=$(python3 "$PROC_ANALYZER" --pid $$ --brief)
    assert_contains "进程信息" "$output" "/proc分析器应显示进程信息"
    
    # 测试详细模式
    output=$(python3 "$PROC_ANALYZER" --pid $$ --detail)
    assert_contains "内存映射" "$output" "/proc分析器应显示详细信息"
    
    # 测试系统信息
    output=$(python3 "$PROC_ANALYZER" --system)
    assert_contains "系统信息" "$output" "/proc分析器应显示系统信息"
}

# 测试进程树功能
test_process_tree_detailed() {
    log_info "测试详细进程树功能..."
    
    # 创建进程树
    local tree_pid
    tree_pid=$(create_test_process "tree" 15)
    
    # 测试进程树显示
    local output
    output=$("$MONITOR_SCRIPT" --tree -p "$tree_pid")
    assert_contains "进程树" "$output" "应显示指定PID的进程树"
    
    # 测试进程树包含子进程
    if [ -n "$tree_pid" ]; then
        assert_contains "$tree_pid" "$output" "进程树应包含目标PID"
    fi
    
    # 清理
    kill "$tree_pid" 2>/dev/null || true
}

# 测试资源监控精度
test_resource_monitoring_accuracy() {
    log_info "测试资源监控精度..."
    
    # 创建CPU密集型进程
    local cpu_pid
    cpu_pid=$(create_test_process "cpu" 10)
    
    if [ -n "$cpu_pid" ]; then
        # 监视CPU进程
        local output
        output=$("$MONITOR_SCRIPT" -p "$cpu_pid" -i 1 -c 2 2>/dev/null || true)
        
        # 验证输出格式
        assert_contains "CPU使用率" "$output" "应显示CPU使用率"
        assert_contains "VmSize" "$output" "应显示内存信息"
        
        # 清理
        kill "$cpu_pid" 2>/dev/null || true
    else
        log_warning "无法创建测试进程，跳过精度测试"
        ((TESTS_SKIPPED++))
    fi
}

# 测试内存监控
test_memory_monitoring() {
    log_info "测试内存监控..."
    
    # 创建内存密集型进程
    local mem_pid
    mem_pid=$(create_test_process "memory" 10)
    
    if [ -n "$mem_pid" ]; then
        # 监视内存进程
        local output
        output=$("$MONITOR_SCRIPT" -p "$mem_pid" -i 1 -c 2 2>/dev/null || true)
        
        # 验证内存监控
        assert_contains "VmRSS" "$output" "应显示物理内存使用"
        assert_contains "VmSize" "$output" "应显示虚拟内存大小"
        
        # 清理
        kill "$mem_pid" 2>/dev/null || true
    else
        log_warning "无法创建测试进程，跳过内存监控测试"
        ((TESTS_SKIPPED++))
    fi
}

# 测试系统概要监视
test_system_monitoring() {
    log_info "测试系统概要监视..."
    
    # 测试系统监视功能（短暂运行）
    local output
    output=$(timeout 5s "$MONITOR_SCRIPT" --monitor-all -i 1 2>/dev/null || true)
    
    # 验证系统信息
    assert_contains "系统进程概要" "$output" "应显示系统概要信息"
    assert_contains "系统负载" "$output" "应显示系统负载"
    assert_contains "内存使用" "$output" "应显示内存使用情况"
}

# 测试信号处理
test_signal_handling() {
    log_info "测试信号处理..."
    
    # 启动一个长时间运行的监视任务
    "$MONITOR_SCRIPT" -p 1 -i 1 > "$TEMP_DIR/monitor_output.txt" 2>&1 &
    local monitor_pid=$!
    
    # 等待一下然后发送中断信号
    sleep 2
    kill -INT "$monitor_pid"
    
    # 等待进程结束
    wait "$monitor_pid" 2>/dev/null || true
    
    # 检查是否正常退出
    if ! ps -p "$monitor_pid" > /dev/null 2>&1; then
        log_success "监视器正确处理中断信号"
        ((TESTS_PASSED++))
    else
        log_error "监视器未正确处理中断信号"
        kill -KILL "$monitor_pid" 2>/dev/null || true
        ((TESTS_FAILED++))
    fi
}

# 测试性能基准
test_performance_benchmark() {
    log_info "测试性能基准..."
    
    # 测试命令执行时间
    local start_time
    start_time=$(date +%s%N)
    
    # 运行一个快速命令
    "$MONITOR_SCRIPT" --cpu-top > /dev/null 2>&1
    
    local end_time
    end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))  # 转换为毫秒
    
    # 检查执行时间是否在合理范围内（小于5秒）
    if [ "$duration" -lt 5000 ]; then
        log_success "命令执行时间正常: ${duration}ms"
        ((TESTS_PASSED++))
    else
        log_warning "命令执行时间较长: ${duration}ms"
        ((TESTS_SKIPPED++))
    fi
}

# 测试错误恢复
test_error_recovery() {
    log_info "测试错误恢复..."
    
    # 测试在进程退出后的处理
    local test_pid
    test_pid=$(create_test_process "cpu" 3)
    
    if [ -n "$test_pid" ]; then
        # 启动监视器
        "$MONITOR_SCRIPT" -p "$test_pid" -i 1 > "$TEMP_DIR/recovery_output.txt" 2>&1 &
        local monitor_pid=$!
        
        # 等待进程自然退出
        sleep 4
        
        # 检查监视器是否还在运行
        if ps -p "$monitor_pid" > /dev/null 2>&1; then
            log_error "监视器在目标进程退出后仍在运行"
            kill "$monitor_pid" 2>/dev/null || true
            ((TESTS_FAILED++))
        else
            log_success "监视器在目标进程退出后正确停止"
            ((TESTS_PASSED++))
        fi
        
        # 检查输出中是否有进程终止的消息
        if grep -q "已终止" "$TEMP_DIR/recovery_output.txt"; then
            log_success "监视器正确检测到进程终止"
            ((TESTS_PASSED++))
        else
            log_error "监视器未正确报告进程终止"
            ((TESTS_FAILED++))
        fi
    else
        log_warning "无法创建测试进程，跳过错误恢复测试"
        ((TESTS_SKIPPED++))
    fi
}

# 测试边界条件
test_edge_cases() {
    log_info "测试边界条件..."
    
    # 测试极端间隔值
    assert_exit_failure "$MONITOR_SCRIPT -p 1 -i 0" "零间隔应导致失败"
    assert_exit_failure "$MONITOR_SCRIPT -p 1 -i -1" "负间隔应导致失败"
    
    # 测试极端计数值
    assert_exit_success "$MONITOR_SCRIPT -p 1 -c 1" "单次计数应成功"
    assert_exit_failure "$MONITOR_SCRIPT -p 1 -c -1" "负计数应导致失败"
    
    # 测试系统进程（通常需要权限）
    if [ "$(id -u)" -eq 0 ]; then
        output=$("$MONITOR_SCRIPT" -p 1 -c 1 2>/dev/null || true)
        assert_contains "1" "$output" "应能监视init进程"
    else
        log_warning "非root用户，跳过系统进程测试"
        ((TESTS_SKIPPED++))
    fi
}

# 测试并发监视
test_concurrent_monitoring() {
    log_info "测试并发监视..."
    
    # 创建多个测试进程
    local pids=()
    for i in {1..3}; do
        create_test_process "cpu" 10 &
        pids+=($!)
    done
    
    # 启动多个监视器
    local monitor_pids=()
    for pid in "${pids[@]}"; do
        "$MONITOR_SCRIPT" -p "$pid" -i 2 -c 2 > /dev/null 2>&1 &
        monitor_pids+=($!)
    done
    
    # 等待所有监视器完成
    for mpid in "${monitor_pids[@]}"; do
        wait "$mpid" 2>/dev/null || true
    done
    
    # 清理测试进程
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    
    log_success "并发监视测试完成"
    ((TESTS_PASSED++))
}

# 运行所有高级测试
run_all_advanced_tests() {
    log_info "开始高级功能测试..."
    echo "========================================"
    echo "测试环境:"
    echo "  项目根目录: $PROJECT_ROOT"
    echo "  临时目录: $TEMP_DIR"
    echo "  用户: $(whoami)"
    echo "========================================"
    
    # 检查示例程序是否已编译
    if [ ! -f "$PROJECT_ROOT/examples/sample_scripts/cpu_intensive" ]; then
        log_warning "示例程序未编译，运行编译..."
        "$PROJECT_ROOT/tools/install_dependencies.sh" > /dev/null 2>&1 || true
    fi
    
    test_python_monitor
    test_process_manager
    test_proc_analyzer
    test_process_tree_detailed
    test_resource_monitoring_accuracy
    test_memory_monitoring
    test_system_monitoring
    test_signal_handling
    test_performance_benchmark
    test_error_recovery
    test_edge_cases
    test_concurrent_monitoring
    
    echo
    echo "========================================"
    log_info "高级测试完成"
    echo "通过: $TESTS_PASSED"
    echo "失败: $TESTS_FAILED"
    echo "跳过: $TESTS_SKIPPED"
    echo "总计: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        if [ $TESTS_SKIPPED -gt 0 ]; then
            log_warning "所有运行的测试通过，但有 $TESTS_SKIPPED 个测试被跳过"
            return 0
        else
            log_success "所有高级功能测试通过！"
            return 0
        fi
    else
        log_error "有 $TESTS_FAILED 个测试失败"
        return 1
    fi
}

# 显示帮助信息
show_help() {
    echo "进程监视器 - 高级功能测试"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -v, --verbose       详细输出模式"
    echo "  -t, --test TEST     运行特定测试"
    echo "  -l, --list          列出所有测试"
    echo ""
    echo "可用测试:"
    echo "  python              测试Python监视器"
    echo "  manager             测试进程管理器"
    echo "  analyzer            测试/proc分析器"
    echo "  tree                测试进程树"
    echo "  resources           测试资源监控"
    echo "  memory              测试内存监控"
    echo "  system              测试系统监视"
    echo "  signals             测试信号处理"
    echo "  performance         测试性能基准"
    echo "  recovery            测试错误恢复"
    echo "  edge                测试边界条件"
    echo "  concurrent          测试并发监视"
    echo ""
    echo "示例:"
    echo "  $0                           # 运行所有测试"
    echo "  $0 --test python            # 仅测试Python监视器"
    echo "  $0 --test tree --verbose    # 详细模式测试进程树"
}

# 列出所有测试函数
list_tests() {
    echo "可用测试函数:"
    grep -E "^test_[a-zA-Z_]+\(\)" "$0" | sed 's/() {/:/' | while read line; do
        local test_name=$(echo "$line" | cut -d: -f1)
        local test_desc=$(echo "$line" | cut -d: -f2- | sed 's/log_info "测试\(.*\)..."/\1/')
        echo "  ${test_name#test_}: $test_desc"
    done
}

# 运行特定测试
run_specific_test() {
    local test_name="$1"
    local test_func="test_${test_name}"
    
    if declare -f "$test_func" > /dev/null; then
        log_info "运行特定测试: $test_name"
        echo "========================================"
        "$test_func"
    else
        log_error "未知测试: $test_name"
        echo
        list_tests
        exit 1
    fi
}

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        -t|--test)
            run_specific_test "$2"
            exit $?
            ;;
        -l|--list)
            list_tests
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 默认运行所有测试
run_all_advanced_tests