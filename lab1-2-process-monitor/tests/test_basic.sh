#!/bin/bash

# 进程监视器 - 基础功能测试

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MONITOR_SCRIPT="$PROJECT_ROOT/src/process_monitor.sh"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0

# 日志函数
log_info() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }

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

# 测试帮助信息
test_help() {
    log_info "测试帮助信息..."
    
    local output
    output=$("$MONITOR_SCRIPT" --help)
    
    assert_contains "用法" "$output" "帮助信息应包含用法说明"
    assert_contains "选项" "$output" "帮助信息应包含选项说明"
}

# 测试进程列表功能
test_process_listing() {
    log_info "测试进程列表功能..."
    
    local output
    output=$("$MONITOR_SCRIPT" --cpu-top)
    
    assert_contains "USER" "$output" "进程列表应包含USER列"
    assert_contains "PID" "$output" "进程列表应包含PID列"
    assert_contains "%CPU" "$output" "进程列表应包含%CPU列"
}

# 测试进程树功能
test_process_tree() {
    log_info "测试进程树功能..."
    
    local output
    output=$("$MONITOR_SCRIPT" --tree)
    
    assert_contains "进程树" "$output" "进程树输出应包含标题"
}

# 测试/proc分析功能
test_proc_analysis() {
    log_info "测试/proc分析功能..."
    
    local output
    output=$("$MONITOR_SCRIPT" --analyze-proc)
    
    assert_contains "/proc" "$output" "/proc分析应包含/proc信息"
    assert_contains "进程数量" "$output" "/proc分析应包含进程数量"
}

# 测试无效PID处理
test_invalid_pid() {
    log_info "测试无效PID处理..."
    
    # 使用不存在的PID
    assert_exit_failure "$MONITOR_SCRIPT -p 999999" "无效PID应导致失败"
}

# 测试无效进程名处理
test_invalid_process_name() {
    log_info "测试无效进程名处理..."
    
    # 使用不存在的进程名
    assert_exit_failure "$MONITOR_SCRIPT -n nonexistent_process_12345" "无效进程名应导致失败"
}

# 测试自我监视
test_self_monitoring() {
    log_info "测试自我监视..."
    
    local output
    output=$("$MONITOR_SCRIPT" -p $$ -c 1)
    
    assert_contains "$$" "$output" "自我监视应包含当前PID"
    assert_contains "CPU使用率" "$output" "自我监视应包含CPU使用率"
}

# 测试参数验证
test_parameter_validation() {
    log_info "测试参数验证..."
    
    # 测试缺少必要参数
    assert_exit_failure "$MONITOR_SCRIPT -p" "缺少PID参数应导致失败"
    assert_exit_failure "$MONITOR_SCRIPT -n" "缺少进程名参数应导致失败"
    
    # 测试无效间隔
    assert_exit_failure "$MONITOR_SCRIPT -p 1 -i 0" "无效间隔应导致失败"
    assert_exit_failure "$MONITOR_SCRIPT -p 1 -i -1" "负间隔应导致失败"
}

# 测试监视功能
test_monitoring_function() {
    log_info "测试进程监视功能..."
    
    # 启动一个后台进程进行监视
    sleep 10 &
    local test_pid=$!
    
    # 监视一次
    local output
    output=$("$MONITOR_SCRIPT" -p "$test_pid" -c 1)
    
    assert_contains "$test_pid" "$output" "监视输出应包含目标PID"
    assert_contains "VmSize" "$output" "监视输出应包含内存信息"
    
    # 清理
    kill "$test_pid" 2>/dev/null || true
}

# 运行所有测试
run_all_tests() {
    log_info "开始基础功能测试..."
    echo "========================================"
    
    test_help
    test_process_listing
    test_process_tree
    test_proc_analysis
    test_invalid_pid
    test_invalid_process_name
    test_self_monitoring
    test_parameter_validation
    test_monitoring_function
    
    echo
    echo "========================================"
    log_info "测试完成"
    echo "通过: $TESTS_PASSED"
    echo "失败: $TESTS_FAILED"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "所有基础功能测试通过！"
        return 0
    else
        log_error "有 $TESTS_FAILED 个测试失败"
        return 1
    fi
}

# 显示帮助信息
show_help() {
    echo "进程监视器 - 基础功能测试"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -v, --verbose  详细输出模式"
    echo ""
    echo "示例:"
    echo "  $0             # 运行所有测试"
    echo "  $0 --verbose   # 详细模式运行测试"
}

# 参数解析
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--verbose)
        set -x
        run_all_tests
        ;;
    *)
        run_all_tests
        ;;
esac