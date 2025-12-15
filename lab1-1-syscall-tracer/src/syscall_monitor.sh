#!/bin/bash

# 系统调用实时监控脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 显示使用说明
show_usage() {
    echo "系统调用实时监控工具"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -p, --pid PID       监控指定PID"
    echo "  -n, --name NAME     监控指定进程名"
    echo "  -t, --time SEC      监控时长(秒)"
    echo "  -o, --output FILE   输出到文件"
    echo "  -f, --filter SYS    过滤特定系统调用"
    echo "  -s, --summary       显示统计摘要"
    echo "  -h, --help         显示此帮助"
    echo ""
    echo "示例:"
    echo "  $0 -n firefox       监控Firefox进程"
    echo "  $0 -p 1234 -t 30   监控PID 1234，持续30秒"
    echo "  $0 -n bash -f open,read,write"
}

# 获取进程PID
get_pid() {
    local name=$1
    pid=$(pgrep -o "$name")
    if [ -z "$pid" ]; then
        echo -e "${RED}错误: 未找到进程 '$name'${NC}" >&2
        return 1
    fi
    echo $pid
}

# 实时监控
realtime_monitor() {
    local pid=$1
    local duration=$2
    local filter=$3
    local output=$4
    local summary=$5
    
    echo -e "${CYAN}开始监控进程 PID: $pid${NC}"
    echo -e "${CYAN}持续时间: ${duration:-"无限"}秒${NC}"
    if [ -n "$filter" ]; then
        echo -e "${CYAN}过滤器: $filter${NC}"
    fi
    echo -e "${CYAN}按 Ctrl+C 停止监控${NC}"
    echo ""
    
    # 构建strace命令
    strace_cmd="strace -p $pid -f -tt -T"
    
    if [ -n "$filter" ]; then
        strace_cmd="$strace_cmd -e trace=$filter"
    fi
    
    if [ -n "$output" ]; then
        strace_cmd="$strace_cmd -o $output"
        echo -e "${GREEN}输出保存到: $output${NC}"
    fi
    
    # 设置超时
    if [ -n "$duration" ]; then
        strace_cmd="timeout $duration $strace_cmd"
    fi
    
    # 执行监控
    eval $strace_cmd 2>&1 | while read -r line; do
        # 高亮显示不同类型的系统调用
        if echo "$line" | grep -q -E "(open|read|write|close)"; then
            # 文件操作 - 蓝色
            echo -e "${BLUE}$line${NC}"
        elif echo "$line" | grep -q -E "(socket|connect|accept|send|recv)"; then
            # 网络操作 - 绿色
            echo -e "${GREEN}$line${NC}"
        elif echo "$line" | grep -q -E "(fork|execve|clone|exit)"; then
            # 进程操作 - 黄色
            echo -e "${YELLOW}$line${NC}"
        elif echo "$line" | grep -q -E "= -1"; then
            # 错误 - 红色
            echo -e "${RED}$line${NC}"
        else
            # 其他 - 默认颜色
            echo "$line"
        fi
    done
    
    echo ""
    echo -e "${CYAN}监控结束${NC}"
    
    # 显示摘要
    if [ "$summary" = "true" ] && [ -n "$output" ] && [ -f "$output" ]; then
        echo ""
        echo -e "${CYAN}=== 监控摘要 ===${NC}"
        total_calls=$(grep -c "= [0-9]" "$output" 2>/dev/null || echo "0")
        unique_calls=$(grep -oP '^\d+:\d+:\d+\.\d+ \K\w+' "$output" 2>/dev/null | sort -u | wc -l)
        errors=$(grep -c "= -1" "$output" 2>/dev/null || echo "0")
        
        echo -e "总系统调用: $total_calls"
        echo -e "唯一系统调用类型: $unique_calls"
        echo -e "错误次数: $errors"
        
        if [ "$total_calls" -gt 0 ]; then
            error_rate=$((errors * 100 / total_calls))
            echo -e "错误率: $error_rate%"
        fi
        
        # 显示最频繁的系统调用
        echo ""
        echo -e "最频繁的系统调用:"
        grep -oP '^\d+:\d+:\d+\.\d+ \K\w+' "$output" 2>/dev/null | sort | uniq -c | sort -nr | head -5
    fi
}

# 主函数
main() {
    local pid=""
    local duration=""
    local filter=""
    local output=""
    local summary=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--pid)
                pid="$2"
                shift 2
                ;;
            -n|--name)
                pid=$(get_pid "$2")
                if [ $? -ne 0 ]; then
                    exit 1
                fi
                shift 2
                ;;
            -t|--time)
                duration="$2"
                shift 2
                ;;
            -o|--output)
                output="$2"
                shift 2
                ;;
            -f|--filter)
                filter="$2"
                shift 2
                ;;
            -s|--summary)
                summary=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}" >&2
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 验证参数
    if [ -z "$pid" ]; then
        echo -e "${RED}错误: 必须指定要监控的进程(使用 -p 或 -n)${NC}" >&2
        show_usage
        exit 1
    fi
    
    # 检查进程是否存在
    if ! kill -0 "$pid" 2>/dev/null; then
        echo -e "${RED}错误: 进程 $pid 不存在${NC}" >&2
        exit 1
    fi
    
    # 检查strace是否可用
    if ! command -v strace &> /dev/null; then
        echo -e "${RED}错误: 未找到 strace 命令${NC}" >&2
        echo "请安装: sudo apt install strace"
        exit 1
    fi
    
    # 执行监控
    realtime_monitor "$pid" "$duration" "$filter" "$output" "$summary"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi