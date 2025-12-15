#!/usr/bin/env python3
"""
系统调用追踪与分析工具
用于追踪进程的系统调用并生成分析报告
"""

import os
import sys
import subprocess
import argparse
import json
import re
from collections import Counter, defaultdict
from datetime import datetime
import matplotlib.pyplot as plt
import seaborn as sns

class SyscallTracer:
    def __init__(self):
        self.syscall_stats = Counter()
        self.error_stats = Counter()
        self.timing_data = []
        self.process_tree = defaultdict(list)
        
        # 常见系统调用分类
        self.syscall_categories = {
            'file_operations': ['open', 'read', 'write', 'close', 'stat', 'lseek'],
            'process_control': ['fork', 'execve', 'wait4', 'exit', 'clone'],
            'memory_management': ['brk', 'mmap', 'munmap', 'mprotect'],
            'network_operations': ['socket', 'connect', 'accept', 'send', 'recv'],
            'signals': ['kill', 'signal', 'sigaction'],
            'time_operations': ['time', 'gettimeofday', 'nanosleep']
        }
    
    def trace_program(self, program, args=None, output_file=None, duration=10):
        """
        追踪指定程序的系统调用
        """
        if args is None:
            args = []
            
        if output_file is None:
            output_file = f"trace_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        
        print(f"开始追踪程序: {program} {' '.join(args)}")
        print(f"输出文件: {output_file}")
        print(f"持续时间: {duration}秒")
        print("-" * 50)
        
        # 使用strace进行追踪
        strace_cmd = [
            'strace', 
            '-f',           # 跟踪子进程
            '-tt',          # 时间戳（微秒精度）
            '-T',           # 显示调用耗时
            '-e', 'trace=all',  # 跟踪所有系统调用
            '-o', output_file,
            program
        ] + args
        
        try:
            # 启动被追踪程序
            process = subprocess.Popen(strace_cmd)
            
            # 等待指定时间或程序结束
            try:
                process.wait(timeout=duration)
            except subprocess.TimeoutExpired:
                print(f"追踪超时({duration}秒)，终止程序...")
                process.terminate()
                process.wait()
                
        except FileNotFoundError:
            print(f"错误: 程序 '{program}' 未找到")
            return False
        except Exception as e:
            print(f"追踪过程中发生错误: {e}")
            return False
            
        print("追踪完成")
        return output_file
    
    def parse_trace_file(self, trace_file):
        """
        解析strace输出文件
        """
        print(f"解析追踪文件: {trace_file}")
        
        if not os.path.exists(trace_file):
            print(f"错误: 文件 '{trace_file}' 不存在")
            return False
        
        with open(trace_file, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
        
        # 解析每一行
        for line in lines:
            self._parse_trace_line(line)
        
        print(f"解析完成: 共处理 {len(lines)} 行")
        return True
    
    def _parse_trace_line(self, line):
        """
        解析单行追踪记录
        """
        # 匹配系统调用行: [时间] 系统调用(参数) = 返回值 <耗时>
        pattern = r'(\d+:\d+:\d+\.\d+)\s+(\w+)\((.*?)\)\s+=\s+([^<]+)(?:\s+<([^>]+)>)?'
        match = re.match(pattern, line)
        
        if match:
            timestamp, syscall, args, result, duration = match.groups()
            pid = 1  # 简化处理，实际应该从行中提取PID
            
            # 统计系统调用
            self.syscall_stats[syscall] += 1
            
            # 记录耗时
            if duration:
                try:
                    time_sec = float(duration)
                    self.timing_data.append((syscall, time_sec))
                except ValueError:
                    pass
            
            # 统计错误
            if result and '-' in result and result != '-1':
                self.error_stats[syscall] += 1
    
    def generate_report(self, output_format='text'):
        """
        生成分析报告
        """
        if not self.syscall_stats:
            print("没有可分析的数据")
            return
        
        total_calls = sum(self.syscall_stats.values())
        
        if output_format == 'text':
            self._generate_text_report(total_calls)
        elif output_format == 'json':
            self._generate_json_report(total_calls)
    
    def _generate_text_report(self, total_calls):
        """
        生成文本格式报告
        """
        print("\n" + "="*60)
        print("           系统调用分析报告")
        print("="*60)
        
        print(f"\n总系统调用次数: {total_calls}")
        print(f"不同系统调用类型: {len(self.syscall_stats)}")
        
        # 最频繁的系统调用
        print("\n📊 最频繁的系统调用 (Top 10):")
        print("-" * 40)
        for syscall, count in self.syscall_stats.most_common(10):
            percentage = (count / total_calls) * 100
            print(f"  {syscall:<20} {count:>6}次 ({percentage:5.1f}%)")
        
        # 错误统计
        if self.error_stats:
            print("\n❌ 系统调用错误统计:")
            print("-" * 40)
            for syscall, count in self.error_stats.most_common(5):
                total_for_syscall = self.syscall_stats[syscall]
                error_rate = (count / total_for_syscall) * 100
                print(f"  {syscall:<20} {count:>6}次错误 ({error_rate:5.1f}%)")
        
        # 分类统计
        print("\n📁 按类别统计:")
        print("-" * 40)
        category_stats = defaultdict(int)
        for syscall, count in self.syscall_stats.items():
            for category, syscalls in self.syscall_categories.items():
                if syscall in syscalls:
                    category_stats[category] += count
                    break
            else:
                category_stats['other'] += count
        
        for category, count in sorted(category_stats.items(), key=lambda x: x[1], reverse=True):
            percentage = (count / total_calls) * 100
            print(f"  {category:<20} {count:>6}次 ({percentage:5.1f}%)")
    
    def _generate_json_report(self, total_calls):
        """
        生成JSON格式报告
        """
        report = {
            'summary': {
                'total_syscalls': total_calls,
                'unique_syscalls': len(self.syscall_stats),
                'analysis_time': datetime.now().isoformat()
            },
            'top_syscalls': [
                {'syscall': syscall, 'count': count, 'percentage': (count/total_calls)*100}
                for syscall, count in self.syscall_stats.most_common(10)
            ],
            'errors': [
                {'syscall': syscall, 'error_count': count}
                for syscall, count in self.error_stats.most_common()
            ],
            'categories': {}
        }
        
        # 分类统计
        for category, syscalls in self.syscall_categories.items():
            category_count = sum(self.syscall_stats.get(s, 0) for s in syscalls)
            if category_count > 0:
                report['categories'][category] = {
                    'count': category_count,
                    'percentage': (category_count / total_calls) * 100
                }
        
        output_file = f"report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"JSON报告已保存至: {output_file}")

def main():
    parser = argparse.ArgumentParser(description='系统调用追踪与分析工具')
    parser.add_argument('program', nargs='?', help='要追踪的程序')
    parser.add_argument('args', nargs='*', help='程序参数')
    parser.add_argument('-f', '--file', help='分析已有的追踪文件')
    parser.add_argument('-o', '--output', help='输出文件名')
    parser.add_argument('-d', '--duration', type=int, default=10, help='追踪时长(秒)')
    parser.add_argument('-r', '--report', choices=['text', 'json'], default='text', help='报告格式')
    parser.add_argument('--visualize', action='store_true', help='生成可视化图表')
    
    args = parser.parse_args()
    
    tracer = SyscallTracer()
    
    if args.file:
        # 分析已有文件
        if tracer.parse_trace_file(args.file):
            tracer.generate_report(args.report)
            if args.visualize:
                from trace_visualizer import visualize_trace_data
                visualize_trace_data(tracer)
    elif args.program:
        # 追踪新程序
        trace_file = tracer.trace_program(args.program, args.args, args.output, args.duration)
        if trace_file and tracer.parse_trace_file(trace_file):
            tracer.generate_report(args.report)
            if args.visualize:
                from trace_visualizer import visualize_trace_data
                visualize_trace_data(tracer)
    else:
        parser.print_help()

if __name__ == '__main__':
    main()