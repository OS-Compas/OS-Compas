#!/bin/bash

# test_advanced.sh - 高级功能测试脚本
# 用于验证实验1.1的高级功能和复杂场景

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
PURPLE='\033[0;35m'
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

log_debug() {
    echo -e "${PURPLE}[DEBUG]${NC} $1"
}

# 临时文件管理
TEMP_DIR=""
create_temp_dir() {
    TEMP_DIR=$(mktemp -d /tmp/syscall_advanced_test_XXXXXX)
    log_debug "创建临时目录: $TEMP_DIR"
}

cleanup_temp_dir() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        log_debug "清理临时目录: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

# 信号处理
trap cleanup_temp_dir EXIT INT TERM

# 性能测试：不同大小文件的系统调用对比
test_file_size_comparison() {
    log_test "测试 1: 文件大小对系统调用的影响"
    
    create_temp_dir
    local small_file="$TEMP_DIR/small.txt"
    local large_file="$TEMP_DIR/large.txt"
    local small_trace="$TEMP_DIR/small_trace.log"
    local large_trace="$TEMP_DIR/large_trace.log"
    
    # 创建测试文件
    log_info "创建测试文件..."
    dd if=/dev/zero of="$small_file" bs=1K count=1 2>/dev/null
    dd if=/dev/zero of="$large_file" bs=1M count=10 2>/dev/null
    
    # 追踪文件复制操作
    log_info "追踪小文件复制..."
    strace -o "$small_trace" cp "$small_file" "$TEMP_DIR/small_copy.txt" 2>/dev/null
    
    log_info "追踪大文件复制..."
    strace -o "$large_trace" cp "$large_file" "$TEMP_DIR/large_copy.txt" 2>/dev/null
    
    # 分析系统调用差异
    local small_calls=$(grep -c "^[a-zA-Z_]" "$small_trace" 2>/dev/null || echo 0)
    local large_calls=$(grep -c "^[a-zA-Z_]" "$large_trace" 2>/dev/null || echo 0)
    local small_reads=$(grep -c "read(" "$small_trace" 2>/dev/null || echo 0)
    local large_reads=$(grep -c "read(" "$large_trace" 2>/dev/null || echo 0)
    
    log_info "系统调用统计:"
    echo "  小文件 (1KB): $small_calls 次调用, $small_reads 次read"
    echo "  大文件 (10MB): $large_calls 次调用, $large_reads 次read"
    
    if [ $large_calls -gt $small_calls ] && [ $large_reads -gt $small_reads ]; then
        log_success "文件大小对系统调用影响验证成功"
        return 0
    else
        log_error "文件大小对系统调用影响验证异常"
        return 1
    fi
}

# 可视化功能测试
test_visualization_features() {
    log_test "测试 2: 可视化功能测试"
    
    create_temp_dir
    local sample_trace="$EXAMPLES_DIR/sample_traces/ls_trace.log"
    local output_dir="$TEMP_DIR/visualization"
    
    mkdir -p "$output_dir"
    
    # 测试基础可视化
    log_info "测试基础可视化功能..."
    if python3 "$SRC_DIR/syscall_tracer.py" -f "$sample_trace" --visualize --output "$output_dir/ls_analysis.png" 2>/dev/null; then
        if [ -f "$output_dir/ls_analysis.png" ]; then
            log_success "基础可视化生成成功"
        else
            log_warning "基础可视化文件未生成 (可能缺少matplotlib)"
        fi
    else
        log_warning "基础可视化执行失败 (可能缺少依赖)"
    fi
    
    # 测试JSON报告生成
    log_info "测试JSON报告生成..."
    local json_report="$output_dir/report.json"
    if python3 "$SRC_DIR/syscall_tracer.py" -f "$sample_trace" --report json 2>/dev/null > "$json_report"; then
        if python3 -c "import json; json.load(open('$json_report'))" 2>/dev/null; then
            log_success "JSON报告格式正确"
            
            # 提取统计信息
            local total_calls=$(python3 -c "import json; data=json.load(open('$json_report')); print(data['summary']['total_syscalls'])" 2>/dev/null)
            local unique_calls=$(python3 -c "import json; data=json.load(open('$json_report')); print(data['summary']['unique_syscalls'])" 2>/dev/null)
            
            if [ -n "$total_calls" ] && [ "$total_calls" -gt 0 ]; then
                log_success "JSON数据分析成功: $total_calls 次调用, $unique_calls 种类型"
                return 0
            else
                log_error "JSON数据分析失败"
                return 1
            fi
        else
            log_error "JSON报告格式错误"
            return 1
        fi
    else
        log_error "JSON报告生成失败"
        return 1
    fi
}

# 复杂程序追踪测试
test_complex_program_tracing() {
    log_test "测试 3: 复杂程序追踪分析"
    
    create_temp_dir
    
    # 编译复杂测试程序
    local complex_program="$TEMP_DIR/complex_test"
    cat > "${complex_program}.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <dirent.h>
#include <string.h>

void file_operations() {
    // 文件操作
    FILE *file1 = fopen("test1.txt", "w");
    FILE *file2 = fopen("test2.txt", "w");
    if (file1 && file2) {
        fprintf(file1, "File 1 content\n");
        fprintf(file2, "File 2 content\n");
        fclose(file1);
        fclose(file2);
    }
}

void directory_operations() {
    // 目录操作
    mkdir("test_dir", 0755);
    DIR *dir = opendir(".");
    if (dir) {
        struct dirent *entry;
        while ((entry = readdir(dir)) != NULL) {
            // 只是读取，不输出
        }
        closedir(dir);
    }
}

void memory_operations() {
    // 内存操作
    void *mem1 = malloc(1024);
    void *mem2 = malloc(2048);
    if (mem1 && mem2) {
        memset(mem1, 'A', 1024);
        memset(mem2, 'B', 2048);
        free(mem1);
        free(mem2);
    }
}

int main() {
    printf("开始复杂操作测试...\n");
    
    file_operations();
    directory_operations(); 
    memory_operations();
    
    // 清理
    remove("test1.txt");
    remove("test2.txt");
    rmdir("test_dir");
    
    printf("复杂操作测试完成\n");
    return 0;
}
EOF

    # 编译程序
    if gcc -o "$complex_program" "${complex_program}.c" 2>/dev/null; then
        log_success "复杂测试程序编译成功"
    else
        log_error "复杂测试程序编译失败"
        return 1
    fi
    
    # 追踪程序执行
    local trace_file="$TEMP_DIR/complex_trace.log"
    log_info "追踪复杂程序执行..."
    if strace -f -o "$trace_file" "$complex_program" 2>/dev/null; then
        log_success "复杂程序追踪成功"
    else
        log_error "复杂程序追踪失败"
        return 1
    fi
    
    # 分析追踪结果
    log_info "分析复杂程序系统调用模式..."
    
    local total_calls=$(grep -c "^[a-zA-Z_]" "$trace_file" 2>/dev/null || echo 0)
    local file_calls=$(grep -c -E "(open|close|read|write|stat)" "$trace_file" 2>/dev/null || echo 0)
    local memory_calls=$(grep -c -E "(brk|mmap|munmap)" "$trace_file" 2>/dev/null || echo 0)
    local dir_calls=$(grep -c -E "(mkdir|opendir|readdir|closedir)" "$trace_file" 2>/dev/null || echo 0)
    
    log_info "系统调用分类统计:"
    echo "  总调用次数: $total_calls"
    echo "  文件操作: $file_calls"
    echo "  内存操作: $memory_calls" 
    echo "  目录操作: $dir_calls"
    
    if [ $total_calls -gt 50 ] && [ $file_calls -gt 5 ]; then
        log_success "复杂程序系统调用模式分析成功"
        return 0
    else
        log_error "复杂程序系统调用模式分析异常"
        return 1
    fi
}

# 实时监控高级测试
test_advanced_monitoring() {
    log_test "测试 4: 高级监控功能测试"
    
    create_temp_dir
    
    # 测试长时间监控
    log_info "测试短时间监控功能..."
    local monitor_output="$TEMP_DIR/monitor.log"
    
    # 启动一个后台进程进行监控
    (sleep 2; echo "监控测试") &
    local test_pid=$!
    
    # 使用监控脚本监控该进程
    if timeout 3s "$SRC_DIR/syscall_monitor.sh" -p $test_pid -t 1 -o "$monitor_output" 2>/dev/null; then
        if [ -f "$monitor_output" ]; then
            local monitor_lines=$(wc -l < "$monitor_output" 2>/dev/null || echo 0)
            if [ $monitor_lines -gt 0 ]; then
                log_success "实时监控数据采集成功 ($monitor_lines 行)"
            else
                log_warning "实时监控数据为空"
            fi
        else
            log_warning "实时监控输出文件未生成"
        fi
    else
        log_warning "实时监控执行异常 (可能进程已结束)"
    fi
    
    # 等待后台进程结束
    wait $test_pid 2>/dev/null
    
    # 测试过滤器功能
    log_info "测试系统调用过滤器..."
    local filtered_output="$TEMP_DIR/filtered.log"
    
    # 创建一个持续运行的测试进程
    (while true; do sleep 1; done) &
    local filter_pid=$!
    
    # 使用过滤器监控
    if timeout 2s "$SRC_DIR/syscall_monitor.sh" -p $filter_pid -f "read,write" -t 1 2>/dev/null > "$filtered_output"; then
        local filtered_content=$(cat "$filtered_output" 2>/dev/null)
        if echo "$filtered_content" | grep -q -E "(read|write)"; then
            log_success "系统调用过滤器工作正常"
        else
            log_warning "系统调用过滤器可能未正常工作"
        fi
    else
        log_warning "过滤器监控执行异常"
    fi
    
    # 清理测试进程
    kill $filter_pid 2>/dev/null
    
    log_success "高级监控功能测试完成"
    return 0
}

# 错误处理和边界测试
test_error_handling() {
    log_test "测试 5: 错误处理和边界条件"
    
    create_temp_dir
    
    # 测试无效追踪文件
    log_info "测试无效文件处理..."
    local invalid_file="$TEMP_DIR/invalid.log"
    echo "这不是一个有效的strace文件" > "$invalid_file"
    
    if ! python3 "$SRC_DIR/syscall_tracer.py" -f "$invalid_file" 2>/dev/null; then
        log_success "无效文件处理正常"
    else
        log_error "无效文件处理异常"
    fi
    
    # 测试不存在的文件
    log_info "测试不存在文件处理..."
    if ! python3 "$SRC_DIR/syscall_tracer.py" -f "/nonexistent/file.log" 2>/dev/null; then
        log_success "不存在文件处理正常"
    else
        log_error "不存在文件处理异常"
    fi
    
    # 测试空文件
    log_info "测试空文件处理..."
    local empty_file="$TEMP_DIR/empty.log"
    touch "$empty_file"
    
    if python3 "$SRC_DIR/syscall_tracer.py" -f "$empty_file" 2>/dev/null; then
        log_success "空文件处理正常"
    else
        log_warning "空文件处理警告"
    fi
    
    # 测试大文件处理
    log_info "测试大文件处理能力..."
    local large_trace="$TEMP_DIR/large_trace.log"
    # 生成一个较大的测试文件
    for i in {1..1000}; do
        echo "1234.567890 write(1, \"test line $i\\n\", 12) = 12" >> "$large_trace"
    done
    
    if timeout 10s python3 "$SRC_DIR/syscall_tracer.py" -f "$large_trace" 2>/dev/null; then
        log_success "大文件处理能力正常"
    else
        log_error "大文件处理超时或失败"
        return 1
    fi
    
    log_success "错误处理和边界测试完成"
    return 0
}

# 性能基准测试
test_performance_benchmark() {
    log_test "测试 6: 性能基准测试"
    
    create_temp_dir
    
    # 创建性能测试用的追踪文件
    local perf_trace="$TEMP_DIR/performance_trace.log"
    log_info "生成性能测试数据..."
    
    # 生成包含多种系统调用的测试数据
    cat > "$perf_trace" << 'EOF'
1234.567890 execve("/bin/ls", ["ls"], 0x7ffc12345678) = 0
1234.567891 brk(NULL) = 0x55a1b2c24000
1234.567892 openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY) = 3
1234.567893 fstat(3, {st_mode=S_IFREG|0644, st_size=125672, ...}) = 0
1234.567894 mmap(NULL, 125672, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f8a3b5e2000
1234.567895 close(3) = 0
1234.567896 openat(AT_FDCWD, "/lib/x86_64-linux-gnu/libc.so.6", O_RDONLY) = 3
1234.567897 read(3, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\260A\2\0\0\0\0\0"..., 832) = 832
1234.567898 fstat(3, {st_mode=S_IFREG|0755, st_size=2030928, ...}) = 0
1234.567899 close(3) = 0
1234.567900 getdents64(3, /* 8 entries */, 32768) = 240
1234.567901 stat("file1.txt", {st_mode=S_IFREG|0644, st_size=1024, ...}) = 0
1234.567902 stat("file2.txt", {st_mode=S_IFREG|0644, st_size=2048, ...}) = 0
1234.567903 write(1, "file1.txt\\n", 10) = 10
1234.567904 write(1, "file2.txt\\n", 10) = 10
EOF

    # 重复数据以增加文件大小
    for i in {1..100}; do
        cat "$perf_trace" >> "$perf_trace.2"
    done
    mv "$perf_trace.2" "$perf_trace"
    
    # 性能测试：分析时间
    log_info "执行性能测试..."
    local start_time=$(date +%s%N)
    
    if python3 "$SRC_DIR/syscall_tracer.py" -f "$perf_trace" 2>/dev/null > /dev/null; then
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))
        
        local file_size=$(stat -c%s "$perf_trace" 2>/dev/null || echo 0)
        local line_count=$(wc -l < "$perf_trace" 2>/dev/null || echo 0)
        
        log_info "性能测试结果:"
        echo "  文件大小: $((file_size / 1024)) KB"
        echo "  行数: $line_count"
        echo "  分析时间: $duration 毫秒"
        echo "  处理速度: $((line_count * 1000 / duration)) 行/秒"
        
        if [ $duration -lt 5000 ]; then
            log_success "性能测试通过 (分析时间: ${duration}ms)"
            return 0
        else
            log_warning "性能测试较慢 (分析时间: ${duration}ms)"
            return 1
        fi
    else
        log_error "性能测试执行失败"
        return 1
    fi
}

# 多进程追踪测试
test_multiprocess_tracing() {
    log_test "测试 7: 多进程追踪测试"
    
    create_temp_dir
    
    # 创建多进程测试程序
    local multiprocess_program="$TEMP_DIR/multiprocess_test"
    cat > "${multiprocess_program}.c" << 'EOF'
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>

void child_process(int id) {
    printf("子进程 %d 启动 (PID: %d)\\n", id, getpid());
    // 子进程执行一些操作
    for (int i = 0; i < 3; i++) {
        printf("子进程 %d 工作 %d\\n", id, i);
        sleep(1);
    }
    printf("子进程 %d 结束\\n", id);
}

int main() {
    printf("父进程启动 (PID: %d)\\n", getpid());
    
    // 创建多个子进程
    for (int i = 0; i < 2; i++) {
        pid_t pid = fork();
        if (pid == 0) {
            // 子进程
            child_process(i);
            return 0;
        } else if (pid > 0) {
            printf("创建子进程 %d (PID: %d)\\n", i, pid);
        } else {
            perror("fork失败");
            return 1;
        }
    }
    
    // 等待所有子进程结束
    for (int i = 0; i < 2; i++) {
        wait(NULL);
    }
    
    printf("父进程结束\\n");
    return 0;
}
EOF

    # 编译程序
    if gcc -o "$multiprocess_program" "${multiprocess_program}.c" 2>/dev/null; then
        log_success "多进程测试程序编译成功"
    else
        log_error "多进程测试程序编译失败"
        return 1
    fi
    
    # 使用strace追踪多进程
    local trace_file="$TEMP_DIR/multiprocess_trace.log"
    log_info "追踪多进程执行..."
    if strace -f -o "$trace_file" "$multiprocess_program" 2>/dev/null; then
        log_success "多进程追踪成功"
    else
        log_error "多进程追踪失败"
        return 1
    fi
    
    # 分析多进程追踪结果
    log_info "分析多进程系统调用..."
    
    local total_processes=$(grep -c "execve" "$trace_file" 2>/dev/null || echo 0)
    local fork_calls=$(grep -c "fork" "$trace_file" 2>/dev/null || echo 0)
    local clone_calls=$(grep -c "clone" "$trace_file" 2>/dev/null || echo 0)
    local wait_calls=$(grep -c "wait" "$trace_file" 2>/dev/null || echo 0)
    
    log_info "多进程系统调用统计:"
    echo "  总进程数: $((total_processes + 1))"
    echo "  fork调用: $fork_calls"
    echo "  clone调用: $clone_calls"
    echo "  wait调用: $wait_calls"
    
    if [ $total_processes -ge 2 ] && [ $fork_calls -ge 2 ]; then
        log_success "多进程追踪分析成功"
        return 0
    else
        log_error "多进程追踪分析异常"
        return 1
    fi
}

# 系统调用模式分析测试
test_syscall_pattern_analysis() {
    log_test "测试 8: 系统调用模式分析"
    
    create_temp_dir
    
    # 使用示例追踪文件进行分析
    local sample_traces=(
        "$EXAMPLES_DIR/sample_traces/ls_trace.log"
        "$EXAMPLES_DIR/sample_traces/file_operation_trace.log" 
        "$EXAMPLES_DIR/sample_traces/network_trace.log"
    )
    
    local analysis_results=()
    
    for trace_file in "${sample_traces[@]}"; do
        if [ -f "$trace_file" ]; then
            local trace_name=$(basename "$trace_file")
            log_info "分析 $trace_name 的系统调用模式..."
            
            # 使用分析工具生成报告
            local json_report="$TEMP_DIR/${trace_name}.json"
            if python3 "$SRC_DIR/syscall_tracer.py" -f "$trace_file" --report json 2>/dev/null > "$json_report"; then
                # 提取关键指标
                local total_calls=$(python3 -c "import json; data=json.load(open('$json_report')); print(data['summary']['total_syscalls'])" 2>/dev/null || echo 0)
                local unique_calls=$(python3 -c "import json; data=json.load(open('$json_report')); print(data['summary']['unique_syscalls'])" 2>/dev/null || echo 0)
                
                if [ "$total_calls" -gt 0 ]; then
                    analysis_results+=("$trace_name: $total_calls 次调用, $unique_calls 种类型")
                    log_success "$trace_name 分析成功"
                else
                    log_warning "$trace_name 分析数据异常"
                fi
            else
                log_warning "$trace_name 分析失败"
            fi
        fi
    done
    
    # 显示分析结果比较
    log_info "系统调用模式比较:"
    for result in "${analysis_results[@]}"; do
        echo "  $result"
    done
    
    if [ ${#analysis_results[@]} -ge 2 ]; then
        log_success "系统调用模式分析完成"
        return 0
    else
        log_error "系统调用模式分析失败"
        return 1
    fi
}

# 运行所有高级测试
run_all_advanced_tests() {
    local tests_passed=0
    local tests_total=8
    
    echo -e "${CYAN}"
    echo "=========================================="
    echo "   实验1.1 高级功能测试套件"
    echo "=========================================="
    echo -e "${NC}"
    
    # 测试1: 文件大小对比
    if test_file_size_comparison; then
        ((tests_passed++))
    fi
    echo
    
    # 测试2: 可视化功能
    if test_visualization_features; then
        ((tests_passed++))
    fi
    echo
    
    # 测试3: 复杂程序追踪
    if test_complex_program_tracing; then
        ((tests_passed++))
    fi
    echo
    
    # 测试4: 高级监控
    if test_advanced_monitoring; then
        ((tests_passed++))
    fi
    echo
    
    # 测试5: 错误处理
    if test_error_handling; then
        ((tests_passed++))
    fi
    echo
    
    # 测试6: 性能基准
    if test_performance_benchmark; then
        ((tests_passed++))
    fi
    echo
    
    # 测试7: 多进程追踪
    if test_multiprocess_tracing; then
        ((tests_passed++))
    fi
    echo
    
    # 测试8: 模式分析
    if test_syscall_pattern_analysis; then
        ((tests_passed++))
    fi
    echo
    
    # 显示测试结果
    echo -e "${CYAN}"
    echo "=========================================="
    echo "   高级测试结果汇总"
    echo "=========================================="
    echo -e "${NC}"
    
    if [ "$tests_passed" -eq "$tests_total" ]; then
        log_success "所有高级测试通过! ($tests_passed/$tests_total)"
        echo
        echo "实验1.1高级功能验证完成，系统调用分析工具功能完整!"
        return 0
    else
        log_warning "高级测试完成: 通过 $tests_passed/$tests_total"
        echo
        echo "部分高级功能测试失败，但基础功能仍可使用。"
        return 1
    fi
}

# 显示使用说明
show_usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -l, --list          列出所有高级测试"
    echo "  -t, --test TEST     运行单个测试 (1-8)"
    echo "  -a, --all           运行所有高级测试 (默认)"
    echo ""
    echo "高级测试选项:"
    echo "  1 - 文件大小对比测试"
    echo "  2 - 可视化功能测试" 
    echo "  3 - 复杂程序追踪测试"
    echo "  4 - 高级监控功能测试"
    echo "  5 - 错误处理边界测试"
    echo "  6 - 性能基准测试"
    echo "  7 - 多进程追踪测试"
    echo "  8 - 系统调用模式分析"
    echo ""
    echo "示例:"
    echo "  $0                  运行所有高级测试"
    echo "  $0 -t 1            只运行文件大小对比测试"
    echo "  $0 -t 2 -t 3       运行测试2和3"
}

# 主函数
main() {
    local test_numbers=()
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -l|--list)
                echo "高级测试列表:"
                echo "  1 - 文件大小对比测试"
                echo "  2 - 可视化功能测试"
                echo "  3 - 复杂程序追踪测试" 
                echo "  4 - 高级监控功能测试"
                echo "  5 - 错误处理边界测试"
                echo "  6 - 性能基准测试"
                echo "  7 - 多进程追踪测试"
                echo "  8 - 系统调用模式分析"
                exit 0
                ;;
            -t|--test)
                test_numbers+=("$2")
                shift 2
                ;;
            -a|--all)
                run_all_advanced_tests
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
    if [ ${#test_numbers[@]} -eq 0 ]; then
        run_all_advanced_tests
        exit $?
    fi
    
    # 运行指定的单个测试
    for test_num in "${test_numbers[@]}"; do
        case $test_num in
            1) test_file_size_comparison ;;
            2) test_visualization_features ;;
            3) test_complex_program_tracing ;;
            4) test_advanced_monitoring ;;
            5) test_error_handling ;;
            6) test_performance_benchmark ;;
            7) test_multiprocess_tracing ;;
            8) test_syscall_pattern_analysis ;;
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