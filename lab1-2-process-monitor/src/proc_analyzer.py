#!/usr/bin/env python3
"""
/proc 文件系统深度分析工具
实验1.2：深入探索Linux进程信息接口
"""

import os
import sys
import re
import glob
import json
from pathlib import Path
from datetime import datetime, timedelta
import argparse

class ProcAnalyzer:
    def __init__(self):
        self.proc_path = Path("/proc")
        self.colors = {
            'RED': '\033[91m',
            'GREEN': '\033[92m',
            'YELLOW': '\033[93m',
            'BLUE': '\033[94m',
            'CYAN': '\033[96m',
            'PURPLE': '\033[95m',
            'END': '\033[0m'
        }
    
    def color_text(self, text, color):
        """为文本添加颜色"""
        return f"{self.colors.get(color, '')}{text}{self.colors['END']}"
    
    def get_system_overview(self):
        """获取系统概览信息"""
        print(self.color_text("=== 系统概览 ===", 'CYAN'))
        
        # 内核版本
        try:
            with open(self.proc_path / "version", 'r') as f:
                version = f.read().strip()
                print(f"内核版本: {version}")
        except:
            print("无法读取内核版本")
        
        # 系统运行时间
        try:
            with open(self.proc_path / "uptime", 'r') as f:
                uptime_seconds = float(f.read().split()[0])
                uptime_str = str(timedelta(seconds=uptime_seconds))
                print(f"系统运行时间: {uptime_str}")
        except:
            print("无法读取系统运行时间")
        
        # 负载平均值
        try:
            with open(self.proc_path / "loadavg", 'r') as f:
                loadavg = f.read().strip()
                print(f"负载平均值: {loadavg}")
        except:
            print("无法读取负载平均值")
        
        print()
    
    def analyze_memory_info(self):
        """分析内存信息"""
        print(self.color_text("=== 内存信息 ===", 'CYAN'))
        
        try:
            with open(self.proc_path / "meminfo", 'r') as f:
                meminfo = f.readlines()
            
            # 提取关键内存信息
            key_fields = ['MemTotal', 'MemFree', 'MemAvailable', 'Buffers', 'Cached', 'SwapTotal', 'SwapFree']
            for line in meminfo:
                for field in key_fields:
                    if line.startswith(field + ':'):
                        print(f"  {line.strip()}")
                        break
            
            # 计算内存使用率
            mem_total = None
            mem_available = None
            
            for line in meminfo:
                if line.startswith('MemTotal:'):
                    mem_total = int(line.split()[1])
                elif line.startswith('MemAvailable:'):
                    mem_available = int(line.split()[1])
            
            if mem_total and mem_available:
                mem_used = mem_total - mem_available
                mem_usage_percent = (mem_used / mem_total) * 100
                print(f"  内存使用率: {mem_usage_percent:.1f}% ({mem_used} KB / {mem_total} KB)")
        
        except Exception as e:
            print(f"无法读取内存信息: {e}")
        
        print()
    
    def analyze_cpu_info(self):
        """分析CPU信息"""
        print(self.color_text("=== CPU 信息 ===", 'CYAN'))
        
        try:
            with open(self.proc_path / "cpuinfo", 'r') as f:
                cpuinfo = f.read()
            
            # 统计CPU核心数
            cpu_cores = cpuinfo.count('processor\t:')
            print(f"  CPU核心数: {cpu_cores}")
            
            # 提取CPU型号
            model_match = re.search(r'model name\s*:\s*(.+)', cpuinfo)
            if model_match:
                print(f"  CPU型号: {model_match.group(1)}")
            
            # 提取CPU频率
            freq_match = re.search(r'cpu MHz\s*:\s*([\d.]+)', cpuinfo)
            if freq_match:
                print(f"  CPU频率: {freq_match.group(1)} MHz")
        
        except Exception as e:
            print(f"无法读取CPU信息: {e}")
        
        print()
    
    def get_process_statistics(self):
        """获取进程统计信息"""
        print(self.color_text("=== 进程统计 ===", 'CYAN'))
        
        try:
            # 获取所有进程目录
            process_dirs = [d for d in self.proc_path.iterdir() if d.name.isdigit()]
            total_processes = len(process_dirs)
            
            print(f"  总进程数: {total_processes}")
            
            # 统计进程状态
            state_count = {'R': 0, 'S': 0, 'D': 0, 'Z': 0, 'T': 0, 'X': 0}
            user_processes = 0
            kernel_processes = 0
            
            for proc_dir in process_dirs[:1000]:  # 限制检查数量以避免性能问题
                try:
                    status_file = proc_dir / "status"
                    if status_file.exists():
                        with open(status_file, 'r') as f:
                            content = f.read()
                            
                            # 检查进程状态
                            state_match = re.search(r'State:\s*(\w)', content)
                            if state_match:
                                state = state_match.group(1)
                                state_count[state] = state_count.get(state, 0) + 1
                            
                            # 检查用户ID
                            uid_match = re.search(r'Uid:\s*\d+\s+(\d+)', content)
                            if uid_match:
                                uid = int(uid_match.group(1))
                                if uid == 0:
                                    kernel_processes += 1
                                else:
                                    user_processes += 1
                
                except (PermissionError, FileNotFoundError):
                    continue
            
            print(f"  运行状态分布:")
            for state, count in state_count.items():
                if count > 0:
                    state_names = {'R': '运行', 'S': '睡眠', 'D': '磁盘睡眠', 
                                 'T': '停止', 'Z': '僵尸', 'X': '死亡'}
                    print(f"    {state_names.get(state, state)}: {count}")
            
            print(f"  用户进程: {user_processes}")
            print(f"  内核进程: {kernel_processes}")
        
        except Exception as e:
            print(f"无法统计进程信息: {e}")
        
        print()
    
    def analyze_process_details(self, pid=None):
        """分析特定进程的详细信息"""
        if pid is None:
            # 分析当前进程
            pid = "self"
        
        proc_dir = self.proc_path / str(pid)
        
        if not proc_dir.exists():
            print(self.color_text(f"错误: 进程 {pid} 不存在", 'RED'))
            return
        
        print(self.color_text(f"=== 进程 {pid} 详细信息 ===", 'CYAN'))
        
        try:
            # 读取status文件
            status_file = proc_dir / "status"
            if status_file.exists():
                print(self.color_text("状态信息:", 'YELLOW'))
                with open(status_file, 'r') as f:
                    for line in f:
                        if any(key in line for key in ['Name', 'State', 'Pid', 'PPid', 'Uid', 'Gid', 'VmSize', 'VmRSS', 'Threads']):
                            print(f"  {line.strip()}")
            
            # 读取stat文件
            stat_file = proc_dir / "stat"
            if stat_file.exists():
                print(self.color_text("\n统计信息:", 'YELLOW'))
                with open(stat_file, 'r') as f:
                    stat_data = f.read().split()
                    if len(stat_data) > 20:
                        print(f"  状态: {stat_data[2]}")
                        print(f"  父进程PID: {stat_data[3]}")
                        print(f"  进程组ID: {stat_data[4]}")
                        print(f"  用户态CPU时间: {stat_data[13]} 时钟滴答")
                        print(f"  内核态CPU时间: {stat_data[14]} 时钟滴答")
            
            # 读取maps文件（内存映射）
            maps_file = proc_dir / "maps"
            if maps_file.exists():
                print(self.color_text("\n内存映射统计:", 'YELLOW'))
                with open(maps_file, 'r') as f:
                    maps_lines = f.readlines()
                    print(f"  内存区域数量: {len(maps_lines)}")
                    
                    # 统计不同类型的映射
                    mapping_types = {}
                    for line in maps_lines:
                        parts = line.split()
                        if len(parts) > 5:
                            mapping = parts[5] if parts[5] != '' else 'anonymous'
                            mapping_types[mapping] = mapping_types.get(mapping, 0) + 1
                    
                    for mtype, count in mapping_types.items():
                        print(f"    {mtype}: {count}")
            
            # 读取fd目录（文件描述符）
            fd_dir = proc_dir / "fd"
            if fd_dir.exists():
                print(self.color_text("\n文件描述符:", 'YELLOW'))
                try:
                    fds = list(fd_dir.iterdir())
                    print(f"  打开文件数: {len(fds)}")
                    
                    # 显示前几个文件描述符
                    for fd in fds[:5]:
                        try:
                            target = fd.resolve()
                            print(f"    {fd.name} -> {target}")
                        except:
                            print(f"    {fd.name} -> [无法解析]")
                    
                    if len(fds) > 5:
                        print(f"    ... 还有 {len(fds) - 5} 个文件描述符")
                
                except PermissionError:
                    print("  无权限读取文件描述符")
        
        except Exception as e:
            print(f"分析进程时出错: {e}")
        
        print()
    
    def analyze_io_info(self):
        """分析系统I/O信息"""
        print(self.color_text("=== I/O 统计 ===", 'CYAN'))
        
        try:
            # 磁盘I/O统计
            diskstats_file = self.proc_path / "diskstats"
            if diskstats_file.exists():
                with open(diskstats_file, 'r') as f:
                    disk_lines = f.readlines()
                
                print("  磁盘设备统计:")
                for line in disk_lines[:5]:  # 显示前5个设备
                    parts = line.strip().split()
                    if len(parts) >= 14:
                        device = parts[2]
                        reads = parts[3]
                        writes = parts[7]
                        print(f"    {device}: 读 {reads} 次, 写 {writes} 次")
            
            # 系统级I/O统计
            vmstat_file = self.proc_path / "vmstat"
            if vmstat_file.exists():
                with open(vmstat_file, 'r') as f:
                    vmstat_lines = f.readlines()
                
                print("  系统I/O统计:")
                io_stats = {}
                for line in vmstat_lines:
                    if any(key in line for key in ['pgpgin', 'pgpgout', 'pswpin', 'pswpout']):
                        key, value = line.strip().split()
                        io_stats[key] = value
                
                for key, value in io_stats.items():
                    print(f"    {key}: {value}")
        
        except Exception as e:
            print(f"无法读取I/O信息: {e}")
        
        print()
    
    def find_large_processes(self, top_n=10):
        """查找内存使用量最大的进程"""
        print(self.color_text(f"=== 内存使用TOP {top_n} ===", 'CYAN'))
        
        process_memory = []
        
        for proc_dir in self.proc_path.iterdir():
            if proc_dir.name.isdigit():
                try:
                    status_file = proc_dir / "status"
                    if status_file.exists():
                        with open(status_file, 'r') as f:
                            content = f.read()
                            
                            # 提取进程名和内存使用
                            name_match = re.search(r'Name:\s*(.+)', content)
                            vmrss_match = re.search(r'VmRSS:\s*(\d+)', content)
                            
                            if name_match and vmrss_match:
                                name = name_match.group(1).strip()
                                memory_kb = int(vmrss_match.group(1))
                                
                                if memory_kb > 0:  # 只记录使用内存的进程
                                    process_memory.append((name, memory_kb, proc_dir.name))
                
                except (PermissionError, FileNotFoundError, ValueError):
                    continue
        
        # 按内存使用排序
        process_memory.sort(key=lambda x: x[1], reverse=True)
        
        print(f"{'进程名':<20} {'PID':<8} {'内存使用':<12} {'内存(MB)':<10}")
        print("-" * 55)
        
        for name, memory_kb, pid in process_memory[:top_n]:
            memory_mb = memory_kb / 1024
            print(f"{name:<20} {pid:<8} {memory_kb:<12} KB {memory_mb:<8.1f} MB")
        
        print()
    
    def monitor_process_changes(self, interval=5):
        """监视进程变化"""
        print(self.color_text(f"=== 进程变化监视 (每{interval}秒更新) ===", 'CYAN'))
        print("按 Ctrl+C 停止监视")
        
        previous_processes = set()
        
        try:
            while True:
                current_processes = set()
                
                for proc_dir in self.proc_path.iterdir():
                    if proc_dir.name.isdigit():
                        current_processes.add(proc_dir.name)
                
                if previous_processes:
                    new_processes = current_processes - previous_processes
                    dead_processes = previous_processes - current_processes
                    
                    if new_processes:
                        print(f"\n[{datetime.now().strftime('%H:%M:%S')}] 新进程: {len(new_processes)} 个")
                    
                    if dead_processes:
                        print(f"[{datetime.now().strftime('%H:%M:%S')}] 终止进程: {len(dead_processes)} 个")
                
                previous_processes = current_processes
                import time
                time.sleep(interval)
        
        except KeyboardInterrupt:
            print(self.color_text("\n监视已停止", 'YELLOW'))
    
    def generate_report(self, output_file=None):
        """生成分析报告"""
        print(self.color_text("=== 生成分析报告 ===", 'CYAN'))
        
        report = {
            "timestamp": datetime.now().isoformat(),
            "system_overview": {},
            "memory_info": {},
            "process_statistics": {},
            "top_processes": []
        }
        
        try:
            # 系统概览
            try:
                with open(self.proc_path / "version", 'r') as f:
                    report["system_overview"]["kernel_version"] = f.read().strip()
            except:
                pass
            
            try:
                with open(self.proc_path / "uptime", 'r') as f:
                    report["system_overview"]["uptime_seconds"] = float(f.read().split()[0])
            except:
                pass
            
            # 内存信息
            try:
                with open(self.proc_path / "meminfo", 'r') as f:
                    for line in f:
                        key = line.split(':')[0]
                        value = line.split(':')[1].strip()
                        report["memory_info"][key] = value
            except:
                pass
            
            # 进程统计
            process_dirs = [d for d in self.proc_path.iterdir() if d.name.isdigit()]
            report["process_statistics"]["total_processes"] = len(process_dirs)
            
            print(f"报告已生成，包含 {len(process_dirs)} 个进程的信息")
            
            if output_file:
                with open(output_file, 'w') as f:
                    json.dump(report, f, indent=2)
                print(f"报告已保存到: {output_file}")
            else:
                print("报告内容:")
                print(json.dumps(report, indent=2))
        
        except Exception as e:
            print(f"生成报告时出错: {e}")

def main():
    parser = argparse.ArgumentParser(description='/proc 文件系统分析工具')
    parser.add_argument('--system', action='store_true', help='显示系统概览')
    parser.add_argument('--memory', action='store_true', help='分析内存信息')
    parser.add_argument('--cpu', action='store_true', help='分析CPU信息')
    parser.add_argument('--process-stats', action='store_true', help='显示进程统计')
    parser.add_argument('--process-detail', type=int, help='分析指定PID的详细信息')
    parser.add_argument('--io', action='store_true', help='分析I/O信息')
    parser.add_argument('--top-memory', type=int, default=10, help='显示内存使用TOP N进程')
    parser.add_argument('--monitor', type=int, help='监视进程变化，指定间隔秒数')
    parser.add_argument('--report', help='生成JSON报告到指定文件')
    parser.add_argument('--all', action='store_true', help='执行所有分析')
    
    args = parser.parse_args()
    
    analyzer = ProcAnalyzer()
    
    try:
        if args.all or not any(vars(args).values()):
            # 默认显示所有基本信息
            analyzer.get_system_overview()
            analyzer.analyze_memory_info()
            analyzer.analyze_cpu_info()
            analyzer.get_process_statistics()
            analyzer.find_large_processes()
        
        if args.system:
            analyzer.get_system_overview()
        
        if args.memory:
            analyzer.analyze_memory_info()
        
        if args.cpu:
            analyzer.analyze_cpu_info()
        
        if args.process_stats:
            analyzer.get_process_statistics()
        
        if args.process_detail:
            analyzer.analyze_process_details(args.process_detail)
        
        if args.io:
            analyzer.analyze_io_info()
        
        if args.top_memory:
            analyzer.find_large_processes(args.top_memory)
        
        if args.monitor:
            analyzer.monitor_process_changes(args.monitor)
        
        if args.report:
            analyzer.generate_report(args.report)
    
    except KeyboardInterrupt:
        print(analyzer.color_text("\n程序被用户中断", 'YELLOW'))
    except Exception as e:
        print(analyzer.color_text(f"错误: {e}", 'RED'))

if __name__ == "__main__":
    # 检查是否在Linux系统上
    if not os.path.exists("/proc"):
        print("错误: 此工具只能在Linux系统上运行")
        sys.exit(1)
    
    main()