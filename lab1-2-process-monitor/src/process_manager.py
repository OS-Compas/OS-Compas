#!/usr/bin/env python3
"""
进阶进程管理器
实验1.2扩展挑战：进程树显示和进程管理
"""

import os
import sys
import psutil
import signal
import argparse
from datetime import datetime

class ProcessManager:
    def __init__(self):
        self.colors = {
            'RED': '\033[91m',
            'GREEN': '\033[92m',
            'YELLOW': '\033[93m',
            'BLUE': '\033[94m',
            'CYAN': '\033[96m',
            'END': '\033[0m'
        }
    
    def color_text(self, text, color):
        return f"{self.colors.get(color, '')}{text}{self.colors['END']}"
    
    def get_process_tree(self, pid=None, max_depth=5):
        """获取完整的进程树"""
        if pid is None:
            # 找到所有没有父进程的进程（通常是init进程）
            root_processes = []
            for proc in psutil.process_iter(['pid', 'ppid', 'name']):
                if proc.info['ppid'] == 0:  # 没有父进程
                    root_processes.append(proc)
            return root_processes
        else:
            try:
                return [psutil.Process(pid)]
            except psutil.NoSuchProcess:
                return []
    
    def display_process_tree(self, pid=None, show_cmdline=False):
        """显示进程树"""
        print(self.color_text("系统进程树:", 'CYAN'))
        print("=" * 60)
        
        roots = self.get_process_tree(pid)
        
        for root in roots:
            self._display_tree_node(root, "", "", show_cmdline, set())
    
    def _display_tree_node(self, process, prefix, children_prefix, show_cmdline, visited):
        """递归显示进程树节点"""
        try:
            pid = process.pid
            if pid in visited:
                return
            visited.add(pid)
            
            # 获取进程信息
            with process.oneshot():
                name = process.name()
                status = process.status()
                memory_percent = process.memory_percent()
                cpu_percent = process.cpu_percent()
                
                if show_cmdline:
                    cmdline = ' '.join(process.cmdline()[:3]) + ("..." if len(process.cmdline()) > 3 else "")
                    display_name = f"{name} {cmdline}"
                else:
                    display_name = name
            
            # 显示进程信息
            status_color = 'GREEN' if status == 'running' else 'YELLOW'
            process_info = f"{prefix}{pid} {self.color_text(display_name, status_color)} "
            process_info += f"[CPU: {cpu_percent:.1f}%, MEM: {memory_percent:.1f}%]"
            print(process_info)
            
            # 处理子进程
            try:
                children = process.children()
                for i, child in enumerate(children):
                    if i == len(children) - 1:
                        self._display_tree_node(child, children_prefix + "└── ", 
                                              children_prefix + "    ", show_cmdline, visited)
                    else:
                        self._display_tree_node(child, children_prefix + "├── ", 
                                              children_prefix + "│   ", show_cmdline, visited)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
                
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    
    def kill_process(self, pid, signal_type=signal.SIGTERM):
        """终止进程"""
        try:
            process = psutil.Process(pid)
            process_name = process.name()
            
            if signal_type == signal.SIGTERM:
                print(f"正在终止进程 {pid} ({process_name})...")
                process.terminate()
            elif signal_type == signal.SIGKILL:
                print(f"强制杀死进程 {pid} ({process_name})...")
                process.kill()
            
            print(self.color_text(f"成功发送信号到进程 {pid}", 'GREEN'))
            
        except psutil.NoSuchProcess:
            print(self.color_text(f"错误: 进程 {pid} 不存在", 'RED'))
        except psutil.AccessDenied:
            print(self.color_text(f"错误: 没有权限终止进程 {pid}", 'RED'))
    
    def find_processes_by_name(self, name):
        """根据名称查找进程"""
        matching = []
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                if (name.lower() in proc.info['name'].lower() or 
                    (proc.info['cmdline'] and name.lower() in ' '.join(proc.info['cmdline']).lower())):
                    matching.append(proc)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        
        return matching
    
    def interactive_mode(self):
        """交互式模式"""
        print(self.color_text("进程管理器 - 交互模式", 'CYAN'))
        print("=" * 50)
        print("命令:")
        print("  list     - 显示进程列表")
        print("  tree     - 显示进程树")
        print("  find     - 查找进程")
        print("  kill     - 终止进程")
        print("  monitor  - 监视进程")
        print("  quit     - 退出")
        print()
        
        while True:
            try:
                command = input(self.color_text("pm> ", 'GREEN')).strip().split()
                if not command:
                    continue
                
                cmd = command[0].lower()
                
                if cmd == 'quit' or cmd == 'exit':
                    break
                elif cmd == 'list':
                    self.display_process_list()
                elif cmd == 'tree':
                    show_cmdline = len(command) > 1 and command[1] == '-c'
                    self.display_process_tree(show_cmdline=show_cmdline)
                elif cmd == 'find':
                    if len(command) > 1:
                        self.search_and_display(command[1])
                    else:
                        print("用法: find <进程名>")
                elif cmd == 'kill':
                    if len