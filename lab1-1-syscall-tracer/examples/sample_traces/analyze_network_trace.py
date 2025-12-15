#!/usr/bin/env python3
"""
分析网络操作追踪数据的示例脚本
专门用于实验1.1的网络系统调用教学演示
"""

import re
from collections import Counter

def analyze_network_trace(trace_file):
    """分析网络操作追踪日志"""
    
    with open(trace_file, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    
    # 统计系统调用
    syscall_stats = Counter()
    network_syscalls = Counter()
    error_stats = Counter()
    
    # 网络相关的系统调用
    network_calls = {'socket', 'bind', 'listen', 'accept', 'connect', 
                    'sendto', 'recvfrom', 'setsockopt', 'getsockopt',
                    'gethostbyname', 'inet_pton', 'inet_ntop', 'fcntl'}
    
    print("网络操作系统调用分析报告")
    print("=" * 60)
    
    for line in lines:
        # 提取系统调用名
        match = re.match(r'\d+:\d+:\d+\.\d+\s+(\w+)', line)
        if match:
            syscall = match.group(1)
            syscall_stats[syscall] += 1
            
            # 统计网络操作
            if syscall in network_calls:
                network_syscalls[syscall] += 1
            
            # 统计错误
            if '= -1' in line:
                error_stats[syscall] += 1
    
    total_calls = sum(syscall_stats.values())
    network_calls_count = sum(network_syscalls.values())
    
    print(f"总系统调用次数: {total_calls}")
    print(f"网络相关系统调用: {network_calls_count} ({network_calls_count/total_calls*100:.1f}%)")
    print(f"错误次数: {sum(error_stats.values())}")
    
    print("\n最频繁的系统调用 (Top 10):")
    print("-" * 40)
    for syscall, count in syscall_stats.most_common(10):
        percentage = (count / total_calls) * 100
        print(f"  {syscall:<15} {count:>6}次 ({percentage:5.1f}%)")
    
    print("\n网络系统调用详细统计:")
    print("-" * 40)
    for syscall, count in network_syscalls.most_common():
        print(f"  {syscall:<15} {count:>6}次")
    
    if error_stats:
        print("\n网络错误统计:")
        print("-" * 40)
        for syscall, count in error_stats.most_common():
            print(f"  {syscall:<15} {count:>6}次错误")
    
    return syscall_stats, network_syscalls

def network_protocol_analysis(trace_file):
    """网络协议类型分析"""
    
    print("\n" + "=" * 60)
    print("网络协议类型分析")
    print("=" * 60)
    
    protocol_stats = {
        'TCP操作': 0,
        'UDP操作': 0,
        'DNS解析': 0,
        '地址转换': 0,
        'Socket控制': 0
    }
    
    with open(trace_file, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # 分析不同协议的操作
    if 'SOCK_STREAM' in content:
        protocol_stats['TCP操作'] += content.count('SOCK_STREAM')
    if 'SOCK_DGRAM' in content:
        protocol_stats['UDP操作'] += content.count('SOCK_DGRAM')
    if 'gethostbyname' in content:
        protocol_stats['DNS解析'] += content.count('gethostbyname')
    if 'inet_pton' in content or 'inet_ntop' in content:
        protocol_stats['地址转换'] += content.count('inet_pton') + content.count('inet_ntop')
    if 'setsockopt' in content or 'fcntl' in content:
        protocol_stats['Socket控制'] += content.count('setsockopt') + content.count('fcntl')
    
    print("协议类型分布:")
    for protocol, count in protocol_stats.items():
        if count > 0:
            print(f"  {protocol:<15}: {count:>3}次操作")

def compare_with_file_operations():
    """与文件操作的系统调用对比"""
    
    print("\n" + "=" * 60)
    print("网络操作 vs 文件操作 系统调用对比")
    print("=" * 60)
    
    network_calls = {
        'socket', 'bind', 'listen', 'accept', 'connect',
        'send', 'recv', 'sendto', 'recvfrom', 'setsockopt',
        'getsockopt', 'gethostbyname', 'inet_pton', 'inet_ntop'
    }
    
    file_calls = {
        'open', 'openat', 'close', 'read', 'write', 'stat',
        'fstat', 'lseek', 'mkdir', 'opendir', 'readdir',
        'closedir', 'rename', 'unlink'
    }
    
    print("网络特有系统调用:")
    print("  " + ", ".join(sorted(network_calls)))
    
    print("\n文件特有系统调用:")
    print("  " + ", ".join(sorted(file_calls)))
    
    print("\n共同系统调用:")
    common = network_calls.intersection(file_calls)
    if common:
        print("  " + ", ".join(sorted(common)))
    else:
        print("  无")

def educational_insights():
    """教学洞察"""
    
    print("\n" + "=" * 60)
    print("实验1.1教学洞察")
    print("=" * 60)
    
    insights = [
        "1. 网络程序相比文件程序有更多类型的系统调用",
        "2. socket() 是网络编程的基础，类似于文件的open()",
        "3. TCP需要三次握手 (socket->bind->listen->accept)",
        "4. UDP是无连接的，直接sendto/recvfrom",
        "5. 网络错误处理更复杂 (连接拒绝、超时等)",
        "6. 网络程序大量使用非阻塞I/O和超时设置",
        "7. DNS解析将域名转换为IP地址",
        "8. 地址转换函数处理网络字节序"
    ]
    
    for insight in insights:
        print(f"  {insight}")

if __name__ == "__main__":
    # 分析网络追踪文件
    stats, network_stats = analyze_network_trace("network_trace.log")
    network_protocol_analysis("network_trace.log")
    compare_with_file_operations()
    educational_insights()
    
    # 生成手动分析命令
    print("\n" + "=" * 60)
    print("手动分析命令示例")
    print("=" * 60)
    print("cat network_trace.log | grep -oP '^\\d+:\\d+:\\d+\\.\\d+\\s+\\K\\w+' | sort | uniq -c | sort -nr")
    print("\n只查看网络相关调用:")
    print("cat network_trace.log | grep -E '(socket|bind|listen|accept|connect|send|recv)'")