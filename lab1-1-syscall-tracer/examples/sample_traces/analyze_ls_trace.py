#!/usr/bin/env python3
"""
分析ls命令追踪数据的示例脚本
专门用于实验1.1的教学演示
"""

import re
from collections import Counter

def analyze_ls_trace(trace_file):
    """分析ls命令的追踪日志"""
    
    with open(trace_file, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    
    # 统计系统调用
    syscall_stats = Counter()
    file_operations = Counter()
    
    print("ls命令系统调用分析报告")
    print("=" * 50)
    
    for line in lines:
        # 提取系统调用名
        match = re.match(r'\d+:\d+:\d+\.\d+\s+(\w+)', line)
        if match:
            syscall = match.group(1)
            syscall_stats[syscall] += 1
    
    total_calls = sum(syscall_stats.values())
    
    print(f"总系统调用次数: {total_calls}")
    print(f"不同系统调用类型: {len(syscall_stats)}")
    
    print("\n系统调用频率统计 (Top 10):")
    print("-" * 40)
    for syscall, count in syscall_stats.most_common(10):
        percentage = (count / total_calls) * 100
        print(f"  {syscall:<15} {count:>6}次 ({percentage:5.1f}%)")
    
    # 重点分析文件相关操作
    file_related = ['openat', 'stat', 'fstat', 'getdents64', 'close']
    file_calls = sum(syscall_stats.get(call, 0) for call in file_related)
    
    print(f"\n文件相关系统调用: {file_calls}次 ({file_calls/total_calls*100:.1f}%)")
    
    # 回答实验思考问题
    print("\n" + "=" * 50)
    print("实验思考问题分析:")
    print("-" * 50)
    
    most_common = syscall_stats.most_common(1)[0]
    print(f"1. ls命令执行过程中，哪个系统调用被使用的次数最多？")
    print(f"   答案: {most_common[0]} ({most_common[1]}次)")
    print(f"   原因: {most_common[0]}用于获取文件状态信息，ls需要为每个文件")
    print(f"         调用此系统调用来显示权限、大小、时间等信息")
    
    print(f"\n2. 如果追踪图形界面程序，输出会有什么不同？")
    print(f"   答案: 图形程序会有更多:")
    print(f"   - X11相关的系统调用 (XOpenDisplay, XCreateWindow等)")
    print(f"   - 事件处理系统调用 (poll, select)")
    print(f"   - 图形渲染系统调用")
    print(f"   - 进程间通信系统调用")
    
    return syscall_stats

def detailed_ls_analysis(trace_file):
    """详细的ls命令执行流程分析"""
    
    print("\n" + "=" * 50)
    print("ls命令执行流程详解")
    print("=" * 50)
    
    phases = {
        "程序加载": ["execve", "brk", "mmap", "mprotect"],
        "库加载": ["openat", "fstat", "close"],
        "环境设置": ["ioctl", "getcwd"],
        "目录读取": ["openat", "getdents64", "close"],
        "文件信息": ["stat", "fstat"],
        "输出结果": ["write"],
        "程序退出": ["close", "exit_group"]
    }
    
    with open(trace_file, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    
    syscall_stats = Counter()
    for line in lines:
        match = re.match(r'\d+:\d+:\d+\.\d+\s+(\w+)', line)
        if match:
            syscall_stats[match.group(1)] += 1
    
    print("执行阶段分析:")
    for phase, calls in phases.items():
        phase_calls = sum(syscall_stats.get(call, 0) for call in calls)
        print(f"  {phase:<12}: {phase_calls:>3}次系统调用")
    
    print(f"\n关键发现:")
    print(f"  - stat调用次数: {syscall_stats.get('stat', 0)}次")
    print(f"    对应目录中的文件数量 + 目录本身")
    print(f"  - write调用次数: {syscall_stats.get('write', 0)}次") 
    print(f"    对应输出行数 + 'total'行")
    print(f"  - getdents64调用: {syscall_stats.get('getdents64', 0)}次")
    print(f"    用于读取目录内容")

if __name__ == "__main__":
    # 分析ls追踪文件
    stats = analyze_ls_trace("ls_trace.log")
    detailed_ls_analysis("ls_trace.log")
    
    # 生成简单的统计命令示例
    print("\n" + "=" * 50)
    print("手动分析命令示例:")
    print("=" * 50)
    print("cat ls_trace.log | grep -oP '^\\d+:\\d+:\\d+\\.\\d+\\s+\\K\\w+' | sort | uniq -c | sort -nr")