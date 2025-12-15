#!/usr/bin/env python3
"""
分析文件操作追踪数据的示例脚本
"""

import re
from collections import Counter

def analyze_file_trace(trace_file):
    """分析文件操作追踪日志"""
    
    with open(trace_file, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    
    # 统计系统调用
    syscall_stats = Counter()
    file_operations = Counter()
    error_stats = Counter()
    
    # 文件操作相关的系统调用
    file_syscalls = {'open', 'openat', 'close', 'read', 'write', 'stat', 
                    'fstat', 'lseek', 'mkdir', 'opendir', 'readdir', 
                    'closedir', 'rename', 'unlink'}
    
    for line in lines:
        # 提取系统调用名
        match = re.match(r'\d+:\d+:\d+\.\d+\s+(\w+)', line)
        if match:
            syscall = match.group(1)
            syscall_stats[syscall] += 1
            
            # 统计文件操作
            if syscall in file_syscalls:
                file_operations[syscall] += 1
            
            # 统计错误
            if '= -1' in line:
                error_stats[syscall] += 1
    
    # 生成报告
    print("文件操作追踪分析报告")
    print("=" * 50)
    
    total_calls = sum(syscall_stats.values())
    file_calls = sum(file_operations.values())
    
    print(f"总系统调用次数: {total_calls}")
    print(f"文件相关系统调用: {file_calls} ({file_calls/total_calls*100:.1f}%)")
    print(f"错误次数: {sum(error_stats.values())}")
    
    print("\n最频繁的系统调用:")
    for syscall, count in syscall_stats.most_common(10):
        print(f"  {syscall:<15} {count:>6}次")
    
    print("\n文件操作统计:")
    for op, count in file_operations.most_common():
        print(f"  {op:<15} {count:>6}次")
    
    if error_stats:
        print("\n错误统计:")
        for syscall, count in error_stats.most_common():
            print(f"  {syscall:<15} {count:>6}次错误")

if __name__ == "__main__":
    analyze_file_trace("file_operation_trace.log")