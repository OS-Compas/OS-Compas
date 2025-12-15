#!/bin/bash

# 串口监视脚本
# 用于查看RT-Thread系统输出

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

# 默认串口配置
DEFAULT_PORT="/dev/ttyUSB0"
DEFAULT_BAUD="115200"
LOG_FILE="$LOG_DIR/serial_$(date +%Y%m%d_%H%M%S).log"

# 检测可用串口
detect_ports() {
    echo "Available serial ports:"
    ls /dev/ttyUSB* 2>/dev/null | while read port; do
        echo "  $port"
    done
    
    ls /dev/ttyACM* 2>/dev/null | while read port; do
        echo "  $port"
    done
    
    echo ""
}

# 选择串口
select_port() {
    if [ -n "$1" ]; then
        PORT="$1"
    else
        detect_ports
        echo -n "Enter serial port [$DEFAULT_PORT]: "
        read user_port
        PORT="${user_port:-$DEFAULT_PORT}"
    fi
    
    if [ ! -e "$PORT" ]; then
        echo "Error: Port $PORT does not exist"
        exit 1
    fi
}

# 选择波特率
select_baud() {
    if [ -n "$1" ]; then
        BAUD="$1"
    else
        echo -n "Enter baud rate [$DEFAULT_BAUD]: "
        read user_baud
        BAUD="${user_baud:-$DEFAULT_BAUD}"
    fi
}

# 检查串口工具
check_tools() {
    echo -e "\nChecking serial tools..."
    
    # 优先使用picocom
    if command -v picocom >/dev/null 2>&1; then
        TOOL="picocom"
        echo "Using picocom"
    elif command -v screen >/dev/null 2>&1; then
        TOOL="screen"
        echo "Using screen"
    elif command -v minicom >/dev/null 2>&1; then
        TOOL="minicom"
        echo "Using minicom"
    else
        echo "Error: No serial terminal found!"
        echo "Please install one of: picocom, screen, minicom"
        exit 1
    fi
}

# 启动串口监视
start_monitor() {
    echo -e "\nStarting serial monitor..."
    echo "Port: $PORT"
    echo "Baud: $BAUD"
    echo "Log file: $LOG_FILE"
    echo "Tool: $TOOL"
    echo "Press Ctrl+A, Ctrl+X to exit (picocom)"
    echo "Press Ctrl+A, K then Y to exit (screen)"
    echo ""
    
    # 设置串口权限
    sudo chmod 666 "$PORT" 2>/dev/null || true
    
    case $TOOL in
        picocom)
            # 使用picocom，支持日志记录
            picocom -b $BAUD $PORT \
                   --imap lfcrlf \
                   --echo \
                   --logfile "$LOG_FILE"
            ;;
        screen)
            # 使用screen
            screen -L -Logfile "$LOG_FILE" $PORT $BAUD
            ;;
        minicom)
            # 使用minicom
            minicom -D $PORT -b $BAUD -C "$LOG_FILE"
            ;;
    esac
}

# 查看日志
view_log() {
    echo -e "\nRecent log files:"
    ls -lt "$LOG_DIR"/*.log 2>/dev/null | head -5
    
    echo -n "View latest log? [y/N]: "
    read answer
    if [[ $answer =~ ^[Yy]$ ]]; then
        latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
        if [ -n "$latest_log" ]; then
            less "$latest_log"
        else
            echo "No log files found"
        fi
    fi
}

# 过滤特定消息
filter_log() {
    echo -e "\nFilter options:"
    echo "1. Show all messages"
    echo "2. Show sensor data only"
    echo "3. Show WiFi/MQTT messages"
    echo "4. Show error messages"
    echo "5. Custom filter"
    echo -n "Choice [1-5]: "
    
    read choice
    
    latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -z "$latest_log" ]; then
        echo "No log files found"
        return
    fi
    
    case $choice in
        1)
            cat "$latest_log"
            ;;
        2)
            grep -E "(sensor|Sensor|TEMP|HUMI|temp|humi)" "$latest_log"
            ;;
        3)
            grep -E "(wifi|WiFi|WIFI|mqtt|MQTT|connect|Connect)" "$latest_log"
            ;;
        4)
            grep -E "(error|Error|ERROR|fail|Fail|FAIL)" "$latest_log"
            ;;
        5)
            echo -n "Enter search pattern: "
            read pattern
            grep -i "$pattern" "$latest_log"
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
}

# 清空日志
clean_logs() {
    echo -n "Delete all log files? [y/N]: "
    read answer
    if [[ $answer =~ ^[Yy]$ ]]; then
        rm -f "$LOG_DIR"/*.log
        echo "Logs cleared"
    fi
}

# 主菜单
main_menu() {
    while true; do
        echo -e "\n========================================"
        echo "Serial Monitor for RT-Thread IoT"
        echo "========================================"
        echo "1. Start serial monitor"
        echo "2. View logs"
        echo "3. Filter logs"
        echo "4. Clean logs"
        echo "5. Detect serial ports"
        echo "6. Exit"
        echo -n "Choice [1-6]: "
        
        read choice
        
        case $choice in
            1)
                select_port
                select_baud
                check_tools
                start_monitor
                ;;
            2)
                view_log
                ;;
            3)
                filter_log
                ;;
            4)
                clean_logs
                ;;
            5)
                detect_ports
                ;;
            6)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid choice!"
                ;;
        esac
    done
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -b|--baud)
            BAUD="$2"
            shift 2
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -p, --port PORT    Serial port (default: $DEFAULT_PORT)"
            echo "  -b, --baud BAUD    Baud rate (default: $DEFAULT_BAUD)"
            echo "  -l, --log FILE     Log file"
            echo "  -h, --help         Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# 启动主菜单
main_menu