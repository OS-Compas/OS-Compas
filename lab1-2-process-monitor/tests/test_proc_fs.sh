#!/bin/bash

# 进程监视器 - /proc文件系统测试

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MONITOR_SCRIPT="$PROJECT_ROOT/src/process_monitor.sh"
PROC_ANALYZER="$PROJECT_ROOT/src/proc_analyzer.py"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
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
log_debug() { echo -e "${CYAN}[DEBUG]${NC} $1"; }

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

assert_file_exists() {
    local file="$1"
    local message="$2"
    
    if [ -f "$file" ]; then
        log_success "$message"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message (文件不存在: '$file')"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_directory_exists() {
    local dir="$1"
    local message="$2"
    
    if [ -d "$dir" ]; then
        log_success "$message"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message (目录不存在: '$dir')"
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

# 检查/proc文件系统可访问性
check_proc_accessible() {
    if [ ! -d "/proc" ]; then
        log_error "/proc 目录不存在，系统可能不支持proc文件系统"
        return 1
    fi
    
    if [ ! -r "/proc/self" ]; then
        log_error "无法读取 /proc/self，权限不足"
        return 1
    fi
    
    return 0
}

# 获取当前进程的/proc信息
get_self_proc_info() {
    local pid=$$
    echo "/proc/$pid"
}

# 测试/proc目录结构
test_proc_directory_structure() {
    log_info "测试/proc目录结构..."
    
    assert_directory_exists "/proc" "/proc目录应存在"
    assert_directory_exists "/proc/self" "/proc/self应存在"
    assert_directory_exists "/proc/1" "/proc/1(init进程)应存在"
    
    # 检查关键文件
    for file in "version" "uptime" "meminfo" "cpuinfo" "loadavg"; do
        assert_file_exists "/proc/$file" "/proc/$file应存在"
    done
    
    # 检查进程目录数量
    local process_count
    process_count=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
    if [ "$process_count" -gt 0 ]; then
        log_success "系统中有 $process_count 个进程目录"
        ((TESTS_PASSED++))
    else
        log_error "未找到任何进程目录"
        ((TESTS_FAILED++))
    fi
}

# 测试进程状态文件
test_process_status_files() {
    log_info "测试进程状态文件..."
    
    local proc_dir
    proc_dir=$(get_self_proc_info)
    
    # 检查关键状态文件
    for file in "status" "stat" "cmdline" "io" "fd"; do
        if [ -e "$proc_dir/$file" ]; then
            log_success "进程状态文件存在: $file"
            ((TESTS_PASSED++))
        else
            log_warning "进程状态文件不存在: $file"
            ((TESTS_SKIPPED++))
        fi
    done
    
    # 测试status文件内容
    if [ -f "$proc_dir/status" ]; then
        local status_content
        status_content=$(cat "$proc_dir/status")
        
        assert_contains "Name:" "$status_content" "status文件应包含Name字段"
        assert_contains "Pid:" "$status_content" "status文件应包含Pid字段"
        assert_contains "State:" "$status_content" "status文件应包含State字段"
        assert_contains "VmSize:" "$status_content" "status文件应包含VmSize字段"
    fi
    
    # 测试stat文件内容
    if [ -f "$proc_dir/stat" ]; then
        local stat_content
        stat_content=$(cat "$proc_dir/stat")
        
        # stat文件应该包含多个字段
        local field_count
        field_count=$(echo "$stat_content" | wc -w)
        if [ "$field_count" -gt 20 ]; then
            log_success "stat文件包含 $field_count 个字段，格式正确"
            ((TESTS_PASSED++))
        else
            log_error "stat文件字段数异常: $field_count"
            ((TESTS_FAILED++))
        fi
    fi
}

# 测试系统信息文件
test_system_info_files() {
    log_info "测试系统信息文件..."
    
    # 测试/proc/version
    if [ -f "/proc/version" ]; then
        local version_content
        version_content=$(cat /proc/version)
        assert_contains "Linux" "$version_content" "/proc/version应包含Linux信息"
    fi
    
    # 测试/proc/uptime
    if [ -f "/proc/uptime" ]; then
        local uptime_content
        uptime_content=$(cat /proc/uptime)
        # 检查是否包含两个浮点数
        if echo "$uptime_content" | grep -qE "^[0-9]+\.[0-9]+ [0-9]+\.[0-9]+$"; then
            log_success "/proc/uptime格式正确"
            ((TESTS_PASSED++))
        else
            log_error "/proc/uptime格式异常: $uptime_content"
            ((TESTS_FAILED++))
        fi
    fi
    
    # 测试/proc/meminfo
    if [ -f "/proc/meminfo" ]; then
        local meminfo_content
        meminfo_content=$(cat /proc/meminfo | head -10)  # 只检查前10行
        
        assert_contains "MemTotal:" "$meminfo_content" "/proc/meminfo应包含MemTotal"
        assert_contains "MemFree:" "$meminfo_content" "/proc/meminfo应包含MemFree"
        assert_contains "MemAvailable:" "$meminfo_content" "/proc/meminfo应包含MemAvailable"
    fi
    
    # 测试/proc/cpuinfo
    if [ -f "/proc/cpuinfo" ]; then
        local cpuinfo_content
        cpuinfo_content=$(cat /proc/cpuinfo | head -20)  # 只检查前20行
        
        assert_contains "processor" "$cpuinfo_content" "/proc/cpuinfo应包含processor信息"
        assert_contains "model name" "$cpuinfo_content" "/proc/cpuinfo应包含model name"
    fi
    
    # 测试/proc/loadavg
    if [ -f "/proc/loadavg" ]; then
        local loadavg_content
        loadavg_content=$(cat /proc/loadavg)
        # 检查负载平均值格式
        if echo "$loadavg_content" | grep -qE "^[0-9]+\.[0-9]+ [0-9]+\.[0-9]+ [0-9]+\.[0-9]+"; then
            log_success "/proc/loadavg格式正确"
            ((TESTS_PASSED++))
        else
            log_error "/proc/loadavg格式异常: $loadavg_content"
            ((TESTS_FAILED++))
        fi
    fi
}

# 测试进程IO统计
test_process_io_stats() {
    log_info "测试进程IO统计..."
    
    local proc_dir
    proc_dir=$(get_self_proc_info)
    
    if [ -f "$proc_dir/io" ]; then
        local io_content
        io_content=$(cat "$proc_dir/io")
        
        assert_contains "rchar:" "$io_content" "IO统计应包含rchar"
        assert_contains "wchar:" "$io_content" "IO统计应包含wchar"
        assert_contains "read_bytes:" "$io_content" "IO统计应包含read_bytes"
        assert_contains "write_bytes:" "$io_content" "IO统计应包含write_bytes"
        
        log_debug "当前进程IO统计:"
        echo "$io_content" | while read line; do
            log_debug "  $line"
        done
    else
        log_warning "IO统计文件不存在，跳过测试"
        ((TESTS_SKIPPED++))
    fi
}

# 测试进程内存映射
test_process_memory_maps() {
    log_info "测试进程内存映射..."
    
    local proc_dir
    proc_dir=$(get_self_proc_info)
    
    if [ -f "$proc_dir/maps" ]; then
        local maps_content
        maps_content=$(cat "$proc_dir/maps" | head -20)  # 只检查前20行
        
        # maps文件应该包含内存地址范围
        if echo "$maps_content" | grep -qE "^[0-9a-f]+-[0-9a-f]+"; then
            log_success "内存映射文件格式正确"
            ((TESTS_PASSED++))
        else
            log_error "内存映射文件格式异常"
            ((TESTS_FAILED++))
        fi
        
        # 检查常见的库映射
        if echo "$maps_content" | grep -q "libc"; then
            log_success "内存映射包含libc库"
            ((TESTS_PASSED++))
        fi
    else
        log_warning "内存映射文件不存在，跳过测试"
        ((TESTS_SKIPPED++))
    fi
}

# 测试进程环境变量
test_process_environment() {
    log_info "测试进程环境变量..."
    
    local proc_dir
    proc_dir=$(get_self_proc_info)
    
    if [ -f "$proc_dir/environ" ]; then
        local environ_content
        environ_content=$(cat "$proc_dir/environ" | tr '\0' '\n' | head -10)
        
        # 环境变量应该包含PATH等常见变量
        if echo "$environ_content" | grep -q "PATH="; then
            log_success "环境变量包含PATH"
            ((TESTS_PASSED++))
        fi
        
        if echo "$environ_content" | grep -q "USER="; then
            log_success "环境变量包含USER"
            ((TESTS_PASSED++))
        fi
        
        log_debug "前10个环境变量:"
        echo "$environ_content" | while read line; do
            log_debug "  $line"
        done
    else
        log_warning "环境变量文件不存在，跳过测试"
        ((TESTS_SKIPPED++))
    fi
}

# 测试进程文件描述符
test_process_file_descriptors() {
    log_info "测试进程文件描述符..."
    
    local proc_dir
    proc_dir=$(get_self_proc_info)
    
    if [ -d "$proc_dir/fd" ]; then
        local fd_count
        fd_count=$(ls "$proc_dir/fd" | wc -l)
        
        if [ "$fd_count" -gt 0 ]; then
            log_success "进程有 $fd_count 个打开的文件描述符"
            ((TESTS_PASSED++))
            
            # 检查标准文件描述符
            for fd in 0 1 2; do
                if [ -e "$proc_dir/fd/$fd" ]; then
                    log_success "标准文件描述符 $fd 存在"
                    ((TESTS_PASSED++))
                fi
            done
        else
            log_warning "未找到打开的文件描述符"
            ((TESTS_SKIPPED++))
        fi
    else
        log_warning "文件描述符目录不存在，跳过测试"
        ((TESTS_SKIPPED++))
    fi
}

# 测试进程命令行参数
test_process_command_line() {
    log_info "测试进程命令行参数..."
    
    local proc_dir
    proc_dir=$(get_self_proc_info)
    
    if [ -f "$proc_dir/cmdline" ]; then
        local cmdline_content
        cmdline_content=$(cat "$proc_dir/cmdline")
        
        if [ -n "$cmdline_content" ]; then
            log_success "命令行参数不为空"
            ((TESTS_PASSED++))
            
            # 将空字符替换为空格以便阅读
            local readable_cmdline
            readable_cmdline=$(echo "$cmdline_content" | tr '\0' ' ')
            log_debug "命令行: $readable_cmdline"
        else
            log_warning "命令行参数为空"
            ((TESTS_SKIPPED++))
        fi
    else
        log_warning "命令行文件不存在，跳过测试"
        ((TESTS_SKIPPED++))
    fi
}

# 测试进程统计信息
test_process_statistics() {
    log_info "测试进程统计信息..."
    
    local proc_dir
    proc_dir=$(get_self_proc_info)
    
    # 测试statm文件（内存统计）
    if [ -f "$proc_dir/statm" ]; then
        local statm_content
        statm_content=$(cat "$proc_dir/statm")
        
        # statm应该包含多个数字字段
        local field_count
        field_count=$(echo "$statm_content" | wc -w)
        if [ "$field_count" -ge 3 ]; then
            log_success "statm文件包含 $field_count 个内存统计字段"
            ((TESTS_PASSED++))
        fi
    fi
    
    # 测试limits文件
    if [ -f "$proc_dir/limits" ]; then
        local limits_content
        limits_content=$(cat "$proc_dir/limits" | head -10)
        
        assert_contains "Limit" "$limits_content" "limits文件应包含Limit标题"
        assert_contains "Soft" "$limits_content" "limits文件应包含Soft限制"
        assert_contains "Hard" "$limits_content" "limits文件应包含Hard限制"
    fi
}

# 测试监视器的/proc分析功能
test_monitor_proc_analysis() {
    log_info "测试监视器的/proc分析功能..."
    
    local output
    output=$("$MONITOR_SCRIPT" --analyze-proc)
    
    assert_contains "/proc 文件系统分析" "$output" "应显示/proc分析标题"
    assert_contains "系统信息文件" "$output" "应显示系统信息文件"
    assert_contains "进程数量" "$output" "应显示进程数量统计"
    assert_contains "自我进程信息" "$output" "应显示自我进程信息"
    
    # 验证输出包含实际数据
    if echo "$output" | grep -q "[0-9]\+"; then
        log_success "/proc分析包含数字数据"
        ((TESTS_PASSED++))
    fi
}

# 测试Python分析器的/proc功能
test_python_proc_analyzer() {
    log_info "测试Python /proc分析器..."
    
    if [ ! -f "$PROC_ANALYZER" ]; then
        log_warning "Python分析器不存在，跳过测试"
        ((TESTS_SKIPPED++))
        return
    fi
    
    if ! command -v python3 >/dev/null 2>&1; then
        log_warning "Python3不可用，跳过测试"
        ((TESTS_SKIPPED++))
        return
    fi
    
    # 测试基本信息
    local output
    output=$(python3 "$PROC_ANALYZER" --pid $$ --brief)
    
    assert_contains "进程信息" "$output" "Python分析器应显示进程信息"
    assert_contains "状态" "$output" "Python分析器应显示进程状态"
    assert_contains "内存" "$output" "Python分析器应显示内存信息"
    
    # 测试详细模式
    output=$(python3 "$PROC_ANALYZER" --pid $$ --detail)
    assert_contains "内存映射" "$output" "详细模式应显示内存映射"
    assert_contains "环境变量" "$output" "详细模式应显示环境变量"
    
    # 测试系统信息
    output=$(python3 "$PROC_ANALYZER" --system)
    assert_contains "系统信息" "$output" "应显示系统信息"
    assert_contains "CPU" "$output" "应显示CPU信息"
    assert_contains "内存" "$output" "应显示内存信息"
}

# 测试/proc权限和访问控制
test_proc_permissions() {
    log_info "测试/proc权限和访问控制..."
    
    local proc_dir
    proc_dir=$(get_self_proc_info)
    
    # 测试文件权限
    if [ -r "$proc_dir/status" ]; then
        log_success "当前用户可读取进程状态文件"
        ((TESTS_PASSED++))
    else
        log_error "当前用户无法读取进程状态文件"
        ((TESTS_FAILED++))
    fi
    
    # 测试其他进程的访问（如果可能）
    local other_process
    other_process=$(ls -d /proc/[0-9]* 2>/dev/null | grep -v "/proc/$$" | head -1)
    
    if [ -n "$other_process" ] && [ -r "$other_process/status" ]; then
        log_success "可读取其他进程状态文件: $other_process/status"
        ((TESTS_PASSED++))
    else
        log_warning "无法读取其他进程状态文件，权限可能受限"
        ((TESTS_SKIPPED++))
    fi
    
    # 测试root进程访问（如果当前是root）
    if [ "$(id -u)" -eq 0 ]; then
        log_info "当前是root用户，测试系统进程访问..."
        if [ -r "/proc/1/status" ]; then
            log_success "root用户可读取init进程状态"
            ((TESTS_PASSED++))
        fi
    else
        log_warning "非root用户，跳过系统进程访问测试"
        ((TESTS_SKIPPED++))
    fi
}

# 测试/proc虚拟文件系统的特性
test_proc_virtual_filesystem() {
    log_info "测试/proc虚拟文件系统特性..."
    
    # 测试文件大小（虚拟文件通常显示为0大小）
    local proc_dir
    proc_dir=$(get_self_proc_info)
    
    if [ -f "$proc_dir/status" ]; then
        local file_size
        file_size=$(stat -c%s "$proc_dir/status" 2>/dev/null || echo "unknown")
        
        # 虚拟文件的大小可能为0或者是实际内容大小
        if [ "$file_size" -eq 0 ] || [ "$file_size" -gt 0 ]; then
            log_success "虚拟文件大小合理: $file_size 字节"
            ((TESTS_PASSED++))
        else
            log_warning "虚拟文件大小异常: $file_size"
            ((TESTS_SKIPPED++))
        fi
    fi
    
    # 测试文件修改时间
    local mtime
    mtime=$(stat -c%Y "$proc_dir/status" 2>/dev/null || echo "0")
    local current_time
    current_time=$(date +%s)
    
    # 修改时间应该在合理范围内（不是未来时间）
    if [ "$mtime" -le "$current_time" ]; then
        log_success "文件修改时间合理"
        ((TESTS_PASSED++))
    else
        log_warning "文件修改时间异常"
        ((TESTS_SKIPPED++))
    fi
}

# 运行所有/proc文件系统测试
run_all_proc_fs_tests() {
    log_info "开始/proc文件系统测试..."
    echo "========================================"
    echo "测试环境:"
    echo "  当前PID: $$"
    echo "  /proc目录: /proc"
    echo "  临时目录: $TEMP_DIR"
    echo "========================================"
    
    # 检查/proc可访问性
    if ! check_proc_accessible; then
        log_error "/proc文件系统不可访问，终止测试"
        exit 1
    fi
    
    test_proc_directory_structure
    test_process_status_files
    test_system_info_files
    test_process_io_stats
    test_process_memory_maps
    test_process_environment
    test_process_file_descriptors
    test_process_command_line
    test_process_statistics
    test_monitor_proc_analysis
    test_python_proc_analyzer
    test_proc_permissions
    test_proc_virtual_filesystem
    
    echo
    echo "========================================"
    log_info "/proc文件系统测试完成"
    echo "通过: $TESTS_PASSED"
    echo "失败: $TESTS_FAILED"
    echo "跳过: $TESTS_SKIPPED"
    echo "总计: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        if [ $TESTS_SKIPPED -gt 0 ]; then
            log_warning "所有运行的测试通过，但有 $TESTS_SKIPPED 个测试被跳过"
            return 0
        else
            log_success "所有/proc文件系统测试通过！"
            return 0
        fi
    else
        log_error "有 $TESTS_FAILED 个测试失败"
        return 1
    fi
}

# 显示帮助信息
show_help() {
    echo "进程监视器 - /proc文件系统测试"
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
    echo "  directory           测试/proc目录结构"
    echo "  status              测试进程状态文件"
    echo "  system              测试系统信息文件"
    echo "  io                  测试进程IO统计"
    echo "  memory              测试内存映射"
    echo "  environment         测试环境变量"
    echo "  fd                  测试文件描述符"
    echo "  cmdline             测试命令行参数"
    echo "  stats               测试进程统计信息"
    echo "  monitor             测试监视器分析功能"
    echo "  python              测试Python分析器"
    echo "  permissions         测试权限和访问控制"
    echo "  virtual             测试虚拟文件系统特性"
    echo ""
    echo "示例:"
    echo "  $0                           # 运行所有测试"
    echo "  $0 --test directory         # 仅测试目录结构"
    echo "  $0 --test memory --verbose  # 详细模式测试内存映射"
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
        # 检查/proc可访问性
        if ! check_proc_accessible; then
            log_error "/proc文件系统不可访问，无法运行测试"
            exit 1
        fi
        
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
run_all_proc_fs_tests