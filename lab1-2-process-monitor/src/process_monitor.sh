#!/bin/bash

# process_monitor.sh - 进程资源监视器
# 实验1.2：进程资源监视与分析

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# 显示使用说明
show_usage() {
    echo "进程资源监视器 - 实验1.2"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -p, --pid PID       监视指定PID的进程"
    echo "  -n, --name NAME     监视指定名称的进程"
    echo "  -i, --interval SEC  更新间隔(秒)，默认: 2"
    echo "  -c, --count NUM     监视次数，默认: 无限"
    echo "  --cpu-top           显示CPU使用率最高的10个进程"
    echo "  --mem-top           显示内存使用率最高的10个进程"
    echo "  --tree              显示进程树"
    echo "  --analyze-proc      分析/proc文件系统"
    echo "  --monitor-all       监视所有进程的概要"
    echo ""
    echo "示例:"
    echo "  $0 -p 1234                  # 监视PID 1234"
    echo "  $0 -n firefox -i 5         # 每5秒监视firefox进程"
    echo "  $0 --cpu-top               # 显示CPU使用TOP 10"
    echo "  $0 --analyze-proc          # 分析/proc文件系统"
}

# 获取进程PID
get_pid_by_name() {
    local process_name=$1
    local pids=$(pgrep "$process_name")
    
    if [ -z "$pids" ]; then
        log_error "未找到进程: $process_name"
        return 1
    fi
    
    # 如果多个PID，选择第一个
    echo $(echo "$pids" | head -1)
}

# 检查进程是否存在
check_process_exists() {
    local pid=$1
    if [ -d "/proc/$pid" ]; then
        return 0
    else
        return 1
    fi
}

# 从/proc获取进程信息
get_proc_info() {
    local pid=$1
    local proc_dir="/proc/$pid"
    
    if [ ! -d "$proc_dir" ]; then
        echo "进程不存在: $pid"
        return 1
    fi
    
    # 进程状态信息
    if [ -f "$proc_dir/status" ]; then
        echo "=== 进程 $pid 详细信息 (/proc/$pid/status) ==="
        grep -E "^(Name|Pid|PPid|State|VmSize|VmRSS|VmPeak|Threads|voluntary|nonvoluntary)" "$proc_dir/status" | while read line; do
            echo "  $line"
        done
    fi
    
    # 进程命令行
    if [ -f "$proc_dir/cmdline" ]; then
        local cmdline=$(tr '\0' ' ' < "$proc_dir/cmdline")
        if [ -n "$cmdline" ]; then
            echo "  命令行: $cmdline"
        fi
    fi
    
    # CPU统计信息
    if [ -f "$proc_dir/stat" ]; then
        local utime stime cutime cstime start_time
        read -r pid comm state ppid pgrp session tty_nr tpgid flags minflt cminflt majflt cmajflt utime stime cutime cstime priority nice num_threads itrealvalue starttime < "$proc_dir/stat"
        
        echo "  CPU时间: 用户态=${utime}时钟滴答, 内核态=${stime}时钟滴答"
    fi
}

# 计算CPU使用率
calculate_cpu_usage() {
    local pid=$1
    local interval=$2
    
    # 第一次采样
    local stat1=$(cat "/proc/$pid/stat" 2>/dev/null)
    local total1=$(cat /proc/stat | grep "^cpu " | awk '{for(i=2;i<=NF;i++) sum+=$i} END {print sum}')
    
    sleep "$interval"
    
    # 第二次采样
    local stat2=$(cat "/proc/$pid/stat" 2>/dev/null)
    local total2=$(cat /proc/stat | grep "^cpu " | awk '{for(i=2;i<=NF;i++) sum+=$i} END {print sum}')
    
    if [ -z "$stat1" ] || [ -z "$stat2" ]; then
        echo "N/A"
        return
    fi
    
    # 提取进程CPU时间
    local pid_time1=$(echo "$stat1" | awk '{print $14+$15}')
    local pid_time2=$(echo "$stat2" | awk '{print $14+$15}')
    
    local pid_delta=$((pid_time2 - pid_time1))
    local total_delta=$((total2 - total1))
    
    if [ $total_delta -eq 0 ]; then
        echo "0.0"
        return
    fi
    
    local cpu_usage=$(echo "scale=2; 100 * $pid_delta / $total_delta" | bc)
    echo "$cpu_usage"
}

# 获取内存信息
get_memory_info() {
    local pid=$1
    local status_file="/proc/$pid/status"
    
    if [ ! -f "$status_file" ]; then
        echo "N/A|N/A"
        return
    fi
    
    local vmsize=$(grep "VmSize:" "$status_file" | awk '{print $2}')
    local vmrss=$(grep "VmRSS:" "$status_file" | awk '{print $2}')
    
    echo "${vmsize:-0}|${vmrss:-0}"
}

# 监视单个进程
monitor_single_process() {
    local pid=$1
    local interval=$2
    local count=$3
    
    local current_count=0
    
    echo -e "${CYAN}开始监视进程 PID: $pid${NC}"
    echo -e "${CYAN}更新间隔: ${interval}秒${NC}"
    echo "=========================================="
    
    # 显示列标题
    printf "%-20s | %-8s | %-12s | %-12s | %-15s\n" "时间" "PID" "CPU使用率%" "VmSize(KB)" "VmRSS(KB)"
    echo "------------------------------------------------------------"
    
    while true; do
        if ! check_process_exists "$pid"; then
            echo -e "${RED}进程 $pid 已终止${NC}"
            break
        fi
        
        # 获取当前时间
        local current_time=$(date '+%Y-%m-%d %H:%M:%S')
        
        # 计算CPU使用率
        local cpu_usage=$(calculate_cpu_usage "$pid" "$interval")
        
        # 获取内存信息
        local memory_info=$(get_memory_info "$pid")
        local vmsize=$(echo "$memory_info" | cut -d'|' -f1)
        local vmrss=$(echo "$memory_info" | cut -d'|' -f2)
        
        # 输出监控信息
        if [ "$cpu_usage" = "N/A" ]; then
            printf "%-20s | %-8s | %-12s | %-12s | %-15s\n" \
                   "$current_time" "$pid" "N/A" "${vmsize}" "${vmrss}"
        else
            printf "%-20s | %-8s | %-12s | %-12s | %-15s\n" \
                   "$current_time" "$pid" "$cpu_usage" "${vmsize}" "${vmrss}"
        fi
        
        current_count=$((current_count + 1))
        
        # 检查监视次数
        if [ "$count" -gt 0 ] && [ "$current_count" -ge "$count" ]; then
            echo -e "${GREEN}监视完成，共 $current_count 次采样${NC}"
            break
        fi
    done
}

# 显示CPU使用率TOP 10
show_cpu_top() {
    echo -e "${CYAN}CPU使用率最高的10个进程:${NC}"
    echo "=========================================="
    ps aux --sort=-%cpu | head -11 | awk '
    BEGIN {printf "%-8s %-8s %-6s %-6s %-12s %s\n", "USER", "PID", "%CPU", "%MEM", "VSZ", "COMMAND"}
    NR>1 {printf "%-8s %-8s %-6.1f %-6.1f %-12s %s\n", $1, $2, $3, $4, $5, $11}'
}

# 显示内存使用率TOP 10
show_memory_top() {
    echo -e "${CYAN}内存使用率最高的10个进程:${NC}"
    echo "=========================================="
    ps aux --sort=-%mem | head -11 | awk '
    BEGIN {printf "%-8s %-8s %-6s %-6s %-12s %s\n", "USER", "PID", "%CPU", "%MEM", "VSZ", "COMMAND"}
    NR>1 {printf "%-8s %-8s %-6.1f %-6.1f %-12s %s\n", $1, $2, $3, $4, $5, $11}'
}

# 显示进程树
show_process_tree() {
    local pid=${1:-1}  # 默认从init进程(1)开始
    
    echo -e "${CYAN}进程树 (从PID $pid 开始):${NC}"
    echo "=========================================="
    
    # 简单的进程树显示
    ps -eo pid,ppid,comm --forest | awk -v target="$pid" '
    function print_tree(pid, indent) {
        for (i in child) {
            if (ppid[i] == pid) {
                printf("%s├─ %s (%s)\n", indent, comm[i], i)
                print_tree(i, indent "│  ")
            }
        }
    }
    {
        ppid[$1] = $2
        comm[$1] = $3
        child[$2] = $2
    }
    END {
        print_tree(target, "")
    }'
}

# 分析/proc文件系统
analyze_proc_filesystem() {
    echo -e "${CYAN}/proc 文件系统分析${NC}"
    echo "=========================================="
    
    # 显示/proc目录结构
    echo "1. /proc 目录主要内容:"
    ls -la /proc | grep -E "^(drwxr-xr-x|total)" | head -10
    
    echo
    echo "2. 系统信息文件:"
    for file in version uptime meminfo cpuinfo; do
        if [ -f "/proc/$file" ]; then
            echo "   /proc/$file: 存在"
        fi
    done
    
    echo
    echo "3. 进程数量统计:"
    local process_count=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
    echo "   当前进程数: $process_count"
    
    echo
    echo "4. 自我进程信息示例 (/proc/self):"
    if [ -f "/proc/self/status" ]; then
        echo "   名称: $(grep '^Name:' /proc/self/status | awk '{print $2}')"
        echo "   PID: $(grep '^Pid:' /proc/self/status | awk '{print $2}')"
        echo "   VmSize: $(grep '^VmSize:' /proc/self/status | awk '{print $2 $3}')"
        echo "   VmRSS: $(grep '^VmRSS:' /proc/self/status | awk '{print $2 $3}')"
    fi
}

# 监视所有进程概要
monitor_all_processes() {
    local interval=${1:-5}
    
    echo -e "${CYAN}系统进程概要监视 (每${interval}秒更新)${NC}"
    echo "=========================================="
    
    while true; do
        clear
        echo "更新时间: $(date)"
        echo
        
        # 系统负载
        echo "--- 系统负载 ---"
        uptime
        
        echo
        echo "--- 内存使用 ---"
        free -h
        
        echo
        echo "--- 进程统计 ---"
        echo "总进程数: $(ps -e | wc -l)"
        echo "运行中: $(ps -e -o state | grep R | wc -l)"
        echo "睡眠中: $(ps -e -o state | grep S | wc -l)"
        
        echo
        echo "--- TOP 5 CPU进程 ---"
        ps aux --sort=-%cpu | head -6 | awk '
        BEGIN {printf "%-8s %-8s %-6s %-12s %s\n", "USER", "PID", "%CPU", "VSZ", "COMMAND"}
        NR>1 {printf "%-8s %-8s %-6.1f %-12s %s\n", $1, $2, $3, $5, $11}'
        
        sleep "$interval"
    done
}

# 主函数
main() {
    local target_pid=""
    local process_name=""
    local interval=2
    local count=0
    local action="monitor"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -p|--pid)
                target_pid="$2"
                shift 2
                ;;
            -n|--name)
                process_name="$2"
                shift 2
                ;;
            -i|--interval)
                interval="$2"
                shift 2
                ;;
            -c|--count)
                count="$2"
                shift 2
                ;;
            --cpu-top)
                action="cpu_top"
                shift
                ;;
            --mem-top)
                action="mem_top"
                shift
                ;;
            --tree)
                action="tree"
                shift
                ;;
            --analyze-proc)
                action="analyze_proc"
                shift
                ;;
            --monitor-all)
                action="monitor_all"
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 执行相应操作
    case $action in
        monitor)
            if [ -n "$process_name" ]; then
                target_pid=$(get_pid_by_name "$process_name")
                if [ $? -ne 0 ]; then
                    exit 1
                fi
            fi
            
            if [ -z "$target_pid" ]; then
                log_error "必须指定要监视的进程 (使用 -p 或 -n)"
                show_usage
                exit 1
            fi
            
            if ! check_process_exists "$target_pid"; then
                log_error "进程不存在: $target_pid"
                exit 1
            fi
            
            # 显示进程信息
            get_proc_info "$target_pid"
            echo
            monitor_single_process "$target_pid" "$interval" "$count"
            ;;
        cpu_top)
            show_cpu_top
            ;;
        mem_top)
            show_memory_top
            ;;
        tree)
            show_process_tree "$target_pid"
            ;;
        analyze_proc)
            analyze_proc_filesystem
            ;;
        monitor_all)
            monitor_all_processes "$interval"
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 检查是否安装了bc (用于浮点计算)
    if ! command -v bc >/dev/null 2>&1; then
        echo "错误: 需要安装 bc 工具"
        echo "请运行: sudo apt install bc"
        exit 1
    fi
    
    main "$@"
fi