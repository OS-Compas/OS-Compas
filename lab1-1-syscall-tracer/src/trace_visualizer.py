#!/usr/bin/env python3
"""
系统调用数据可视化工具
"""

import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
from collections import Counter
import numpy as np

def visualize_trace_data(tracer):
    """
    可视化追踪数据
    """
    if not tracer.syscall_stats:
        print("没有可可视化的数据")
        return
    
    # 设置中文字体和样式
    plt.rcParams['font.sans-serif'] = ['SimHei', 'DejaVu Sans']
    plt.rcParams['axes.unicode_minus'] = False
    sns.set_style("whitegrid")
    
    # 创建图表
    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    fig.suptitle('系统调用分析可视化', fontsize=16, fontweight='bold')
    
    # 1. 最频繁的系统调用 (柱状图)
    top_syscalls = dict(tracer.syscall_stats.most_common(10))
    axes[0, 0].barh(list(top_syscalls.keys()), list(top_syscalls.values()))
    axes[0, 0].set_title('最频繁的系统调用 (Top 10)')
    axes[0, 0].set_xlabel('调用次数')
    
    # 2. 系统调用分类饼图
    category_data = {}
    for syscall, count in tracer.syscall_stats.items():
        category_found = False
        for category, syscalls in tracer.syscall_categories.items():
            if syscall in syscalls:
                category_data[category] = category_data.get(category, 0) + count
                category_found = True
                break
        if not category_found:
            category_data['other'] = category_data.get('other', 0) + count
    
    if category_data:
        axes[0, 1].pie(category_data.values(), labels=category_data.keys(), autopct='%1.1f%%')
        axes[0, 1].set_title('系统调用分类分布')
    
    # 3. 错误统计
    if tracer.error_stats:
        error_data = dict(tracer.error_stats.most_common(8))
        axes[1, 0].bar(list(error_data.keys()), list(error_data.values()), color='red')
        axes[1, 0].set_title('系统调用错误统计')
        axes[1, 0].set_ylabel('错误次数')
        axes[1, 0].tick_params(axis='x', rotation=45)
    
    # 4. 耗时分析 (如果有数据)
    if tracer.timing_data:
        timing_df = pd.DataFrame(tracer.timing_data, columns=['syscall', 'duration'])
        top_timing = timing_df.groupby('syscall')['duration'].mean().nlargest(8)
        axes[1, 1].bar(top_timing.index, top_timing.values, color='green')
        axes[1, 1].set_title('平均耗时最长的系统调用 (Top 8)')
        axes[1, 1].set_ylabel('平均耗时(秒)')
        axes[1, 1].tick_params(axis='x', rotation=45)
    
    plt.tight_layout()
    
    # 保存图表
    output_file = f"visualization_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}.png"
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"可视化图表已保存至: {output_file}")
    
    plt.show()

def create_comparison_chart(trace_files, labels=None):
    """
    创建多个追踪文件的比较图表
    """
    if labels is None:
        labels = [f"Trace {i+1}" for i in range(len(trace_files))]
    
    all_data = []
    for file, label in zip(trace_files, labels):
        tracer = SyscallTracer()
        if tracer.parse_trace_file(file):
            all_data.append((label, tracer.syscall_stats))
    
    if not all_data:
        return
    
    # 选择共同的系统调用进行比较
    common_syscalls = set()
    for _, stats in all_data:
        common_syscalls.update(stats.keys())
    
    common_syscalls = list(common_syscalls)[:10]  # 取前10个
    
    fig, ax = plt.subplots(figsize=(12, 8))
    
    x = np.arange(len(common_syscalls))
    width = 0.8 / len(all_data)
    
    for i, (label, stats) in enumerate(all_data):
        counts = [stats.get(syscall, 0) for syscall in common_syscalls]
        ax.bar(x + i * width, counts, width, label=label)
    
    ax.set_xlabel('系统调用')
    ax.set_ylabel('调用次数')
    ax.set_title('不同程序的系统调用比较')
    ax.set_xticks(x + width * (len(all_data) - 1) / 2)
    ax.set_xticklabels(common_syscalls, rotation=45)
    ax.legend()
    
    plt.tight_layout()
    plt.show()

if __name__ == '__main__':
    # 示例用法
    print("这是一个可视化工具模块，请通过主程序调用")