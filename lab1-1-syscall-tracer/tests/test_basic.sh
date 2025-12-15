#!/bin/bash

# test_basic.sh - 基础功能测试脚本
# 用于验证实验1.1的基础功能是否正常工作

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
EXAMPLES_DIR="$PROJECT_ROOT/examples"
TESTS_DIR="$PROJECT_ROOT/tests"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_test() {
    echo -e "${CYAN}[TEST]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if command -v "$1" &> /dev/null; then
        log_success "命令 $1 可用"
        return 0
    else
        log_error "命令 $1 未找到"
        return 1
    fi
}

# 检查文件是否存在
check_file() {
    if [ -f "$1" ]; then
        log_success "文件 $1 存在"
        return 0
    else
        log_error "文件 $1 不存在"
        return 1
    fi
}

# 检查目录是否存在
check_directory() {
    if [ -d "$1" ]; then
        log_success "目录 $1 存在"
        return 0
    else
        log_error "目录 $1 不存在"
        return 1
    fi
}

# 环境检查
test_environment() {
    log_test "测试 1: 环境检查"
    
    local all_checks_passed=true
    
    # 检查必需的命令
    log_info "检查系统命令..."
    check_command "strace" || all_checks_passed=false
    check_command "python3" || all_checks_passed=false
    check_command "gcc" || all_checks_passed=false
    check_command "make" || all_checks_passed=false
    
    # 检查项目目录结构
    log_info "检查项目目录结构..."
    check_directory "$SRC_DIR" || all_checks_passed=false
    check_directory "$EXAMPLES_DIR" || all_checks_passed=false
    check_directory "$TESTS_DIR" || all_checks_passed=false
    check_directory "$EXAMPLES_DIR/example_programs" || all_checks_passed=false
    check_directory "$EXAMPLES_DIR/sample_traces" || all_checks_passed=false
    
    # 检查源代码文件
    log_info "检查源代码文件..."
    check_file "$SRC_DIR/syscall_tracer.py" || all_checks_passed=false
    check_file "$SRC_DIR/trace_visualizer.py" || all_checks_passed=false
    check_file "$SRC_DIR/syscall_monitor.sh" || all_checks_passed=false
    
    # 检查示例程序
    log_info "检查示例程序..."
    check_file "$EXAMPLES_DIR/example_programs/file_ops.c" || all_checks_passed=false
    check_file "$EXAMPLES_DIR/example_programs/memory_ops.c" || all_checks_passed=false
    check_file "$EXAMPLES_DIR/example_programs/network_test.c" || all_checks_passed=false
    
    # 检查示例追踪文件
    log_info "检查示例追踪文件..."
    check_file "$EXAMPLES_DIR/sample_traces/ls_trace.log" || all_checks_passed=false
    check_file "$EXAMPLES_DIR/sample_traces/file_operation_trace.log" || all_checks_passed=false
    check_file "$EXAMPLES_DIR/sample_traces/network_trace.log" || all_checks_passed=false
    
    if [ "$all_checks_passed" = true ]; then
        log_success "环境检查通过"
        return 0
    else
        log_error "环境检查失败"
        return 1
    fi
}

# Python依赖检查
test_python_dependencies() {
    log_test "测试 2: Python依赖检查"
    
    log_info "检查Python依赖..."
    
    # 检查Python版本
    python3 --version
    if [ $? -eq 0 ]; then
        log_success "Python3 可用"
    else
        log_error "Python3 不可用"
        return 1
    fi
    
    # 检查必要的Python包
    local packages=("sys" "os" "re" "json" "argparse" "collections" "datetime")
    local missing_packages=()
    
    for package in "${packages[@]}"; do
        if python3 -c "import $package" 2>/dev/null; then
            log_success "Python包 $package 可用"
        else
            log_error "Python包 $package 缺失"
            missing_packages+=("$package")
        fi
    done
    
    # 检查可选的可视化包
    log_info "检查可选的可视化包..."
    local optional_packages=("matplotlib" "seaborn" "pandas" "numpy")
    local missing_optional=()
    
    for package in "${optional_packages[@]}"; do
        if python3 -c "import $package" 2>/dev/null; then
            log_success "可选包 $package 可用"
        else
            log_warning "可选包 $package 缺失 (可视化功能可能受限)"
            missing_optional+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -eq 0 ]; then
        log_success "Python依赖检查通过"
        return 0
    else
        log_error "缺少必要的Python包: ${missing_packages[*]}"
        return 1
    fi
}

# 基础strace功能测试
test_strace_basic() {
    log_test "测试 3: strace基础功能"
    
    log_info "测试strace基本追踪..."
    
    # 创建一个简单的测试程序
    local test_program="/tmp/test_simple_program"
    cat > "${test_program}.c" << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello, strace test!\n");
    return 0;
}
EOF
    
    # 编译测试程序
    if gcc -o "$test_program" "${test_program}.c" 2>/dev/null; then
        log_success "测试程序编译成功"
    else
        log_error "测试程序编译失败"
        return 1
    fi
    
    # 使用strace追踪测试程序
    local trace_file="/tmp/strace_basic_test.log"
    if timeout 5s strace -o "$trace_file" "$test_program" 2>/dev/null; then
        log_success "strace追踪执行成功"
    else
        log_error "strace追踪执行失败"
        return 1
    fi
    
    # 检查追踪文件
    if [ -f "$trace_file" ] && [ -s "$trace_file" ]; then
        log_success "追踪文件生成成功"
        
        # 检查是否包含预期的系统调用
        if grep -q "write" "$trace_file"; then
            log_success "追踪文件包含write系统调用"
        else
            log_warning "追踪文件未找到write系统调用"
        fi
        
        if grep -q "execve" "$trace_file"; then
            log_success "追踪文件包含execve系统调用"
        else
            log_warning "追踪文件未找到execve系统调用"
        fi
        
    else
        log_error "追踪文件生成失败"
        return 1
    fi
    
    # 清理
    rm -f "${test_program}" "${test_program}.c" "$trace_file"
    
    log_success "strace基础功能测试通过"
    return 0
}

# 主分析工具测试
test_main_analyzer() {
    log_test "测试 4: 主分析工具功能"
    
    log_info "测试syscall_tracer.py..."
    
    # 测试帮助信息
    if python3 "$SRC_DIR/syscall_tracer.py" --help 2>/dev/null | grep -q "usage:"; then
        log_success "分析工具帮助信息正常"
    else
        log_error "分析工具帮助信息异常"
        return 1
    fi
    
    # 测试追踪文件分析
    local sample_trace="$EXAMPLES_DIR/sample_traces/ls_trace.log"
    if python3 "$SRC_DIR/syscall_tracer.py" -f "$sample_trace" 2>/dev/null; then
        log_success "追踪文件分析功能正常"
    else
        log_error "追踪文件分析功能异常"
        return 1
    fi
    
    # 测试JSON输出格式
    local json_output="/tmp/test_json_output.json"
    if python3 "$SRC_DIR/syscall_tracer.py" -f "$sample_trace" --report json 2>/dev/null > "$json_output"; then
        if [ -s "$json_output" ] && python3 -c "import json; json.load(open('$json_output'))" 2>/dev/null; then
            log_success "JSON输出格式正常"
        else
            log_error "JSON输出格式异常"
        fi
    else
        log_error "JSON输出功能异常"
    fi
    
    # 清理
    rm -f "$json_output"
    
    log_success "主分析工具功能测试通过"
    return 0
}

# 实时监控脚本测试
test_monitor_script() {
    log_test "测试 5: 实时监控脚本"
    
    log_info "测试syscall_monitor.sh..."
    
    # 测试帮助信息
    if "$SRC_DIR/syscall_monitor.sh" --help 2>/dev/null | grep -q "用法:"; then
        log_success "监控脚本帮助信息正常"
    else
        log_error "监控脚本帮助信息异常"
        return 1
    fi
    
    # 测试参数检查
    if ! "$SRC_DIR/syscall_monitor.sh" -p 999999 2>/dev/null; then
        log_success "无效PID检查正常"
    else
        log_error "无效PID检查异常"
        return 1
    fi
    
    # 测试进程名检查（使用当前shell）
    local current_shell=$(basename "$SHELL")
    if "$SRC_DIR/syscall_monitor.sh" -n "$current_shell" -t 1 -c 2>/dev/null; then
        log_success "进程名监控检查正常"
    else
        log_warning "进程名监控检查异常（可能权限不足）"
    fi
    
    log_success "实时监控脚本测试通过"
    return 0
}

# 示例程序编译测试
test_example_programs() {
    log_test "测试 6: 示例程序编译"
    
    local example_dir="$EXAMPLES_DIR/example_programs"
    local compiled_count=0
    local total_examples=0
    
    # 查找所有的C示例程序
    for c_file in "$example_dir"/*.c; do
        if [ -f "$c_file" ]; then
            total_examples=$((total_examples + 1))
            local base_name=$(basename "$c_file" .c)
            local output_file="/tmp/$base_name"
            
            log_info "编译 $c_file ..."
            if gcc -o "$output_file" "$c_file" 2>/dev/null; then
                log_success "编译成功: $base_name"
                compiled_count=$((compiled_count + 1))
                
                # 测试程序基本运行
                if timeout 2s "$output_file" --help 2>/dev/null | grep -q "用法:"; then
                    log_success "运行测试通过: $base_name"
                else
                    log_warning "运行测试警告: $base_name (可能无--help选项)"
                fi
                
                # 清理
                rm -f "$output_file"
            else
                log_error "编译失败: $base_name"
            fi
        fi
    done
    
    if [ $compiled_count -eq $total_examples ] && [ $total_examples -gt 0 ]; then
        log_success "示例程序编译测试通过 ($compiled_count/$total_examples)"
        return 0
    else
        log_error "示例程序编译测试失败 ($compiled_count/$total_examples)"
        return 1
    fi
}

# 追踪文件分析测试
test_trace_analysis() {
    log_test "测试 7: 追踪文件分析"
    
    local traces_dir="$EXAMPLES_DIR/sample_traces"
    local analyzed_count=0
    local total_traces=0
    
    # 分析所有示例追踪文件
    for trace_file in "$traces_dir"/*.log; do
        if [ -f "$trace_file" ]; then
            total_traces=$((total_traces + 1))
            local base_name=$(basename "$trace_file")
            
            log_info "分析追踪文件: $base_name"
            if python3 "$SRC_DIR/syscall_tracer.py" -f "$trace_file" 2>/dev/null; then
                log_success "分析成功: $base_name"
                analyzed_count=$((analyzed_count + 1))
            else
                log_error "分析失败: $base_name"
            fi
        fi
    done
    
    if [ $analyzed_count -eq $total_traces ] && [ $total_traces -gt 0 ]; then
        log_success "追踪文件分析测试通过 ($analyzed_count/$total_traces)"
        return 0
    else
        log_error "追踪文件分析测试失败 ($analyzed_count/$total_traces)"
        return 1
    fi
}

# 综合集成测试
test_integration() {
    log_test "测试 8: 综合集成测试"
    
    log_info "执行完整的追踪和分析流程..."
    
    # 创建临时目录
    local temp_dir="/tmp/syscall_test_$$"
    mkdir -p "$temp_dir"
    
    # 编译一个示例程序
    local test_program="$temp_dir/test_file_ops"
    if gcc -o "$test_program" "$EXAMPLES_DIR/example_programs/file_ops.c" 2>/dev/null; then
        log_success "示例程序编译成功"
    else
        log_error "示例程序编译失败"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 使用strace追踪
    local trace_file="$temp_dir/integration_trace.log"
    if timeout 10s strace -o "$trace_file" "$test_program" basic 2>/dev/null; then
        log_success "程序追踪成功"
    else
        log_error "程序追踪失败"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 使用分析工具分析追踪文件
    if python3 "$SRC_DIR/syscall_tracer.py" -f "$trace_file" 2>/dev/null; then
        log_success "追踪文件分析成功"
    else
        log_error "追踪文件分析失败"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 测试JSON输出
    local json_report="$temp_dir/report.json"
    if python3 "$SRC_DIR/syscall_tracer.py" -f "$trace_file" --report json 2>/dev/null > "$json_report"; then
        if [ -s "$json_report" ]; then
            log_success "JSON报告生成成功"
        else
            log_error "JSON报告生成失败"
        fi
    else
        log_error "JSON报告生成异常"
    fi
    
    # 清理
    rm -rf "$temp_dir"
    
    log_success "综合集成测试通过"
    return 0
}

# 运行所有测试
run_all_tests() {
    local tests_passed=0
    local tests_total=8
    
    echo -e "${CYAN}"
    echo "=========================================="
    echo "   实验1.1 基础功能测试套件"
    echo "=========================================="
    echo -e "${NC}"
    
    # 测试1: 环境检查
    if test_environment; then
        ((tests_passed++))
    fi
    echo
    
    # 测试2: Python依赖检查
    if test_python_dependencies; then
        ((tests_passed++))
    fi
    echo
    
    # 测试3: strace基础功能
    if test_strace_basic; then
        ((tests_passed++))
    fi
    echo
    
    # 测试4: 主分析工具功能
    if test_main_analyzer; then
        ((tests_passed++))
    fi
    echo
    
    # 测试5: 实时监控脚本
    if test_monitor_script; then
        ((tests_passed++))
    fi
    echo
    
    # 测试6: 示例程序编译
    if test_example_programs; then
        ((tests_passed++))
    fi
    echo
    
    # 测试7: 追踪文件分析
    if test_trace_analysis; then
        ((tests_passed++))
    fi
    echo
    
    # 测试8: 综合集成测试
    if test_integration; then
        ((tests_passed++))
    fi
    echo
    
    # 显示测试结果
    echo -e "${CYAN}"
    echo "=========================================="
    echo "   测试结果汇总"
    echo "=========================================="
    echo -e "${NC}"
    
    if [ "$tests_passed" -eq "$tests_total" ]; then
        log_success "所有测试通过! ($tests_passed/$tests_total)"
        echo
        echo "实验1.1基础功能验证完成，可以开始进行系统调用追踪实验!"
        return 0
    else
        log_warning "测试完成: 通过 $tests_passed/$tests_total"
        echo
        echo "部分测试失败，请检查环境配置后重试。"
        return 1
    fi
}

# 显示使用说明
show_usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -l, --list          列出所有测试"
    echo "  -t, --test TEST     运行单个测试 (1-8)"
    echo "  -e, --environment   只运行环境检查"
    echo "  -a, --all           运行所有测试 (默认)"
    echo ""
    echo "单个测试选项:"
    echo "  1 - 环境检查"
    echo "  2 - Python依赖检查"
    echo "  3 - strace基础功能"
    echo "  4 - 主分析工具功能"
    echo "  5 - 实时监控脚本"
    echo "  6 - 示例程序编译"
    echo "  7 - 追踪文件分析"
    echo "  8 - 综合集成测试"
    echo ""
    echo "示例:"
    echo "  $0                  运行所有测试"
    echo "  $0 -t 1            只运行环境检查"
    echo "  $0 -e              只运行环境检查"
    echo "  $0 -t 3 -t 4       运行测试3和4"
}

# 主函数
main() {
    local test_numbers=()
    local environment_only=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -l|--list)
                echo "可用测试:"
                echo "  1 - 环境检查"
                echo "  2 - Python依赖检查"
                echo "  3 - strace基础功能"
                echo "  4 - 主分析工具功能"
                echo "  5 - 实时监控脚本"
                echo "  6 - 示例程序编译"
                echo "  7 - 追踪文件分析"
                echo "  8 - 综合集成测试"
                exit 0
                ;;
            -t|--test)
                test_numbers+=("$2")
                shift 2
                ;;
            -e|--environment)
                environment_only=true
                shift
                ;;
            -a|--all)
                run_all_tests
                exit $?
                ;;
            *)
                log_error "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 如果没有指定测试，运行所有测试
    if [ ${#test_numbers[@]} -eq 0 ] && [ "$environment_only" = false ]; then
        run_all_tests
        exit $?
    fi
    
    # 运行环境检查
    if [ "$environment_only" = true ]; then
        test_environment
        exit $?
    fi
    
    # 运行指定的单个测试
    for test_num in "${test_numbers[@]}"; do
        case $test_num in
            1) test_environment ;;
            2) test_python_dependencies ;;
            3) test_strace_basic ;;
            4) test_main_analyzer ;;
            5) test_monitor_script ;;
            6) test_example_programs ;;
            7) test_trace_analysis ;;
            8) test_integration ;;
            *)
                log_error "无效的测试编号: $test_num"
                show_usage
                exit 1
                ;;
        esac
        echo
    done
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi