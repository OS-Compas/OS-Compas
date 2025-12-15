#!/bin/bash

# 运行读写频率时序图

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/../src"

DURATION=${1:-30}  # 默认运行30秒
WINDOW=${2:-10}    # 默认时间窗口10秒

echo "=== 读写系统调用频率时序图 ==="
echo "本脚本将绘制read/write系统调用的频率时序图"
echo "运行时长: $DURATION 秒"
echo "时间窗口: $WINDOW 秒"
echo "显示格式: R次数/W次数"
echo "每列代表1秒的数据"
echo "===================================="

# 检查权限
if [ "$EUID" -ne 0 ]; then 
    echo "需要root权限，尝试使用sudo..."
    exec sudo "$0" "$@"
fi

# 检查bpftrace是否安装
if ! command -v bpftrace &> /dev/null; then
    echo "错误: bpftrace未安装"
    echo "请先运行: ./scripts/install_deps.sh"
    exit 1
fi

echo ""
echo "正在启动读写频率监控..."
echo "你可以尝试在另一个终端执行以下操作来生成读写:"
echo "  1. 读取文件: cat /var/log/syslog | head -100"
echo "  2. 写入文件: echo 'test' > /tmp/testfile"
echo "  3. 复制文件: cp /etc/passwd /tmp/"
echo ""
echo "时序图输出:"
echo "============"

# 使用命令行版本，便于调整参数
timeout $DURATION bpftrace -e "
BEGIN {
    printf(\"读写系统调用频率时序图 (窗口: ${WINDOW}秒)\\n\");
    printf(\"R: read次数, W: write次数\\n\");
    printf(\"每列显示该秒内的 R次数/W次数\\n\");
    printf(\"====================================\\n\");
    
    @window_size = $WINDOW;
}

tracepoint:syscalls:sys_enter_read {
    \$sec = nsecs / 1000000000;
    @read_counts[\$sec] = count();
}

tracepoint:syscalls:sys_enter_write {
    \$sec = nsecs / 1000000000;
    @write_counts[\$sec] = count();
}

interval:s:1 {
    \$now = nsecs / 1000000000;
    \$window_start = \$now - @window_size;
    
    printf(\"\\n[%02d:%02d:%02d] \", 
           \$now / 3600 % 24,
           \$now / 60 % 60,
           \$now % 60);
    
    // 显示时间窗口内的数据
    for (\$i = 0; \$i < @window_size; \$i++) {
        \$time = \$now - \$i;
        
        \$r = @read_counts[\$time];
        \$w = @write_counts[\$time];
        
        if (\$r == 0 && \$w == 0) {
            printf(\" · \");
        } else {
            printf(\" %d/%d \", \$r, \$w);
        }
        
        // 清理过期数据
        delete(@read_counts[\$now - @window_size - 1]);
        delete(@write_counts[\$now - @window_size - 1]);
    }
}

END {
    printf(\"\\n\\n=== 监控结束 ===\\n\");
    
    // 计算总调用次数
    \$total_reads = 0;
    \$total_writes = 0;
    
    foreach (\$time in @read_counts) {
        \$total_reads += @read_counts[\$time];
    }
    
    foreach (\$time in @write_counts) {
        \$total_writes += @write_counts[\$time];
    }
    
    printf(\"总read调用: %d 次\\n\", \$total_reads);
    printf(\"总write调用: %d 次\\n\", \$total_writes);
    printf(\"read/write比例: %.2f\\n\", \$total_reads * 1.0 / (\$total_writes + 1));
}" || {
    if [ $? -eq 124 ]; then
        echo -e "\n监控已完成（超时 $DURATION 秒）"
    else
        echo -e "\n监控异常结束"
    fi
}