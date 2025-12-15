#!/usr/bin/env python3
"""
进程资源监视器 - Python版本
实验1.2：进程资源监视与分析
"""

import os
import sys
import time
import psutil
import argparse
from datetime import datetime

class ProcessMonitor:
    def __init__(self):
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
    
    def find_process_by_name(self, name):
        """通过进程名查找PID"""
        matching_processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                if (name.lower() in proc.info['name'].lower() or 
                    (proc.info['cmdline'] and name.lower() in ' '.join(proc.info['cmdline']).lower())):
                    matching_processes.append(proc)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        
        return matching_processes
    
    def get_detailed_proc_info(self, pid):
        """从/proc文件系统获取详细信息"""
        proc_path = f"/proc/{pid}"
        info = {}
        
        try:
            # 读取status文件
            if os.path.exists(f"{proc_path}/status"):
                with open(f"{proc_path}/status", 'r') as f:
                    for line in f:
                        if any(field in line for field in ['Name', 'Pid', 'PPid', 'State', 'VmSize', 'VmRSS', 'VmPeak', 'Threads']):
                            key, value = line.strip().split(':\t', 1)
                            info[key] = value
            
            # 读取命令行
            if os.path.exists(f"{proc_path}/cmdline"):
                with open(f"{proc_path}/cmdline", 'r') as f:
                    cmdline = f.read().replace('\x00', ' ')
                    if cmdline.strip():
                        info['Cmdline'] = cmdline.strip()
            
            # 读取IO统计
            if os.path.exists(f"{proc_path}/io"):
                with open(f"{proc_path}/io", 'r') as f:
                    io_data = f.read()
                    info['IO'] = io_data
            
        except (FileNotFoundError, PermissionError):
            pass
        
        return info
    
    def monitor_single_process(self, pid, interval=2, count=0):
        """监视单个进程"""
        try:
            process = psutil.Process(pid)
        except psutil.NoSuchProcess:
            print(self.color_text(f"错误: 进程 {pid} 不存在", 'RED'))
            return
        
        print(self.color_text(f"开始监视进程 PID: {pid} ({process.name()})", 'CYAN'))
        print(self.color_text(f"更新间隔: {interval}秒", 'CYAN'))
        print("=" * 70)
        
        # 显示列标题
        header = f"{'时间':<20} | {'PID':<8} | {'CPU%':<8} | {'内存RSS':<12} | {'内存VMS':<12} | {'线程数':<8} | {'状态':<10}"
        print(self.color_text(header, 'PURPLE'))
        print("-" * 90)
        
        current_count = 0
        
        try:
            while True:
                if not process.is_running():
                    print(self.color_text(f"进程 {pid} 已终止", 'RED'))
                    break
                
                # 获取进程信息
                with process.oneshot():
                    cpu_percent = process.cpu_percent(interval=0.1)
                    memory_info = process.memory_info()
                    num_threads = process.num_threads()
                    status = process.status()
                
                current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                
                # 输出监控信息
                row = f"{current_time:<20} | {pid:<8} | {cpu_percent:<8.2f} | "
                row += f"{memory_info.rss//1024:<12} | {memory_info.vms//1024:<12} | "
                row += f"{num_threads:<8} | {status:<10}"
                
                print(row)
                
                current_count += 1
                
                # 检查监视次数
                if count > 0 and current_count >= count:
                    print(self.color_text(f"监视完成，共 {current_count} 次采样", 'GREEN'))
                    break
                
                time.sleep(interval)
                
        except psutil.NoSuchProcess:
            print(self.color_text(f"进程 {pid} 已终止", 'RED'))
        except KeyboardInterrupt:
            print(self.color_text("\n监视被用户中断", 'YELLOW'))
    
    def show_cpu_top(self, top_n=10):
        """显示CPU使用率最高的进程"""
        print(self.color_text(f"CPU使用率最高的 {top_n} 个进程:", 'CYAN'))
        print("=" * 70)
        
        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent', 'memory_info']):
            try:
                processes.append(proc)
            except psutil.NoSuchProcess:
                continue
        
        # 按CPU使用率排序
        processes.sort(key=lambda x: x.info['cpu_percent'], reverse=True)
        
        header = f"{'PID':<8} {'名称':<20} {'CPU%':<8} {'内存%':<8} {'内存RSS':<12}"
        print(self.color_text(header, 'PURPLE'))
        print("-" * 70)
        
        for i, proc in enumerate(processes[:top_n]):
            info = proc.info
            memory_rss = info['memory_info'].rss // 1024 // 1024  # 转换为MB
            row = f"{info['pid']:<8} {info['name']:<20} {info['cpu_percent']:<8.1f} "
            row += f"{info['memory_percent']:<8.1f} {memory_rss:<12}MB"
            print(row)
    
    def show_process_tree(self, pid=None):
        """显示进程树"""
        if pid is None:
            pid = 1  # 从init进程开始
        
        print(self.color_text(f"进程树 (从PID {pid} 开始):", 'CYAN'))
        print("=" * 50)
        
        try:
            root_process = psutil.Process(pid)
            self._print_tree(root_process)
        except psutil.NoSuchProcess:
            print(self.color_text(f"错误: 进程 {pid} 不存在", 'RED'))
    
    def _print_tree(self, process, indent=""):
        """递归打印进程树"""
        try:
            name = process.name()
            pid = process.pid
            print(f"{indent}├─ {name} ({pid})")
            
            children = process.children()
            for i, child in enumerate(children):
                if i == len(children) - 1:
                    self._print_tree(child, indent + "    ")
                else:
                    self._print_tree(child, indent + "│   ")
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    
    def analyze_proc_filesystem(self):
        """分析/proc文件系统"""
        print(self.color_text("/proc 文件系统分析", 'CYAN'))
        print("=" * 50)
        
        # 基本统计
        proc_path = "/proc"
        if not os.path.exists(proc_path):
            print(self.color_text("错误: /proc 目录不存在", 'RED'))
            return
        
        # 进程数量
        process_dirs = [d for d in os.listdir(proc_path) if d.isdigit()]
        print(f"1. 进程数量: {len(process_dirs)}")
        
        # 系统信息文件
        system_files = ['version', 'uptime', 'meminfo', 'cpuinfo', 'loadavg']
        print("\n2. 系统信息文件:")
        for file in system_files:
            file_path = os.path.join(proc_path, file)
            if os.path.exists(file_path):
                print(f"   ✓ /proc/{file}")
        
        # 自我进程信息
        print("\n3. 当前进程信息 (/proc/self):")
        try:
            self_info = self.get_detailed_proc_info('self')
            for key in ['Name', 'Pid', 'VmSize', 'VmRSS']:
                if key in self_info:
                    print(f"   {key}: {self_info[key]}")
        except:
            print("   无法读取自我进程信息")
        
        # 内存信息
        print("\n4. 系统内存信息:")
        try:
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if any(x in line for x in ['MemTotal', 'MemFree', 'MemAvailable']):
                        print(f"   {line.strip()}")
        except FileNotFoundError:
            print("   无法读取内存信息")

def main():
    parser = argparse.ArgumentParser(description='进程资源监视器 - Python版本')
    parser.add_argument('-p', '--pid', type=int, help='要监视的进程PID')
    parser.add_argument('-n', '--name', help='要监视的进程名称')
    parser.add_argument('-i', '--interval', type=float, default=2, help='更新间隔(秒)')
    parser.add_argument('-c', '--count', type=int, default=0, help='监视次数(0表示无限)')
    parser.add_argument('--cpu-top', action='store_true', help='显示CPU使用率TOP进程')
    parser.add_argument('--tree', action='store_true', help='显示进程树')
    parser.add_argument('--analyze-proc', action='store_true', help='分析/proc文件系统')
    
    args = parser.parse_args()
    
    monitor = ProcessMonitor()
    
    try:
        if args.cpu_top:
            monitor.show_cpu_top()
        elif args.tree:
            monitor.show_process_tree(args.pid)
        elif args.analyze_proc:
            monitor.analyze_proc_filesystem()
        else:
            if args.name:
                processes = monitor.find_process_by_name(args.name)
                if not processes:
                    print(monitor.color_text(f"错误: 未找到进程 '{args.name}'", 'RED'))
                    return
                target_pid = processes[0].pid
                print(monitor.color_text(f"找到进程: {args.name} (PID: {target_pid})", 'GREEN'))
            elif args.pid:
                target_pid = args.pid
            else:
                print(monitor.color_text("错误: 必须指定要监视的进程 (使用 -p 或 -n)", 'RED'))
                parser.print_help()
                return
            
            monitor.monitor_single_process(target_pid, args.interval, args.count)
    
    except KeyboardInterrupt:
        print(monitor.color_text("\n程序被用户中断", 'YELLOW'))
    except Exception as e:
        print(monitor.color_text(f"错误: {e}", 'RED'))

if __name__ == "__main__":
    # 检查psutil是否安装
    try:
        import psutil
    except ImportError:
        print("错误: 需要安装 psutil 库")
        print("请运行: pip install psutil")
        sys.exit(1)
    
    main()