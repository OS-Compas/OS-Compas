markdown
# eBPF跟踪实验故障排除指南

## 常见问题及解决方案

### 1. 权限问题

**问题**: `bpftrace: error: bpftrace currently only works as root`
```bash
# 解决方法1: 使用sudo运行
sudo bpftrace -e 'BEGIN { printf("Hello\\n"); }'

# 解决方法2: 授予当前用户权限（生产环境不推荐）
sudo setcap cap_bpf,cap_perfmon,cap_sys_ptrace,cap_sys_admin+eip $(which bpftrace)
问题: Operation not permitted

bash
# 检查内核配置
grep CONFIG_BPF=y /boot/config-$(uname -r)
grep CONFIG_BPF_SYSCALL=y /boot/config-$(uname -r)
2. 缺少内核支持
问题: bpftrace: info: This tool needs root privileges to run.
实际原因: 内核版本太旧或未启用eBPF

检查内核版本:

bash
uname -r
# 需要 ≥ 4.1 版本
检查eBPF支持:

bash
# 方法1: 检查/sys/kernel/debug/tracing
ls /sys/kernel/debug/tracing/available_events

# 方法2: 检查内核配置
zcat /proc/config.gz | grep -E "BPF|DEBUG_FS"

# 方法3: 加载简单eBPF程序测试
sudo bpftool prog load /dev/null /sys/fs/bpf/test
解决方法:

bash
# Ubuntu/Debian: 安装新内核
sudo apt install linux-image-generic-hwe-20.04

# CentOS/RHEL:
sudo yum install kernel kernel-devel

# 编译内核时启用:
# CONFIG_BPF=y
# CONFIG_BPF_SYSCALL=y
# CONFIG_DEBUG_INFO=y
# CONFIG_DEBUG_INFO_BTF=y
3. 缺少调试符号
问题: kprobe:__kmalloc not found

bash
# 安装调试符号
# Ubuntu:
sudo apt install linux-image-$(uname -r)-dbgsym

# 或者使用调试符号仓库
echo "deb http://ddebs.ubuntu.com $(lsb_release -cs) main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list.d/ddebs.list
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F2EDC64DC5AEE1F6B9CD5295F8F7E6A5A6A6A6A6
sudo apt update
sudo apt install linux-image-$(uname -r)-dbgsym

# CentOS/RHEL:
sudo yum install kernel-debuginfo kernel-debuginfo-common
4. bpftrace安装问题
Ubuntu安装失败:

bash
# 方法1: 使用Snap
sudo snap install bpftrace

# 方法2: 从源码编译
git clone https://github.com/iovisor/bpftrace
cd bpftrace
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
sudo make install
CentOS安装失败:

bash
# 启用EPEL和Iovisor仓库
sudo yum install epel-release
sudo yum install https://repo.iovisor.org/yum/nightly/8/x86_64/iovisor-release-1.0-1.el8.noarch.rpm
sudo yum install bpftrace
5. 验证器拒绝程序
问题: bpf: Permission denied 或验证器错误

常见原因及解决:

循环未展开:

bash
# 错误: 包含无法证明会终止的循环
bpftrace -e 'kprobe:vfs_read { for(i=0;i<arg0;i++) { @++ } }'

# 正确: 使用展开的循环或有限循环
bpftrace -e 'kprobe:vfs_read { $limit = arg0 < 10 ? arg0 : 10; for(i=0;i<$limit;i++) { @++ } }'
未检查指针边界:

bash
# 添加边界检查
bpftrace -e 'kprobe:vfs_read { if (arg1 && arg2 < 4096) { printf("%s\\n", str(arg1, arg2)); } }'
程序太复杂:

bash
# 简化程序，减少指令数
# eBPF程序有100万条指令的限制，实际建议 < 4096条
6. 性能问题
系统变慢或卡顿:

减少事件频率:

bash
# 使用采样
bpftrace -e 'tracepoint:syscalls:sys_enter_open /pid % 100 == 0/ { @++ }'

# 使用频率限制
bpftrace -e 'tracepoint:syscalls:sys_enter_open { if (@++ % 100 == 0) { printf(...) } }'
减少输出:

bash
# 聚合数据，减少printf
bpftrace -e 'tracepoint:syscalls:sys_enter_open { @[comm] = count() } END { print(@) }'
使用更高效的映射:

bash
# 使用hist()而不是数组
bpftrace -e 'kretprobe:vfs_read { @latency = hist(arg0); }'
7. 特定功能问题
kprobe找不到函数:

bash
# 列出所有可用的kprobe
sudo bpftrace -l 'kprobe:*' | grep -i kmalloc

# 查找函数名
sudo cat /proc/kallsyms | grep kmalloc

# 使用正确的函数名
sudo bpftrace -e 'kprobe:__kmalloc { ... }'
tracepoint格式问题:

bash
# 查看tracepoint格式
sudo cat /sys/kernel/debug/tracing/events/syscalls/sys_enter_open/format

# 使用正确的参数名
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { printf("%s\\n", str(args->filename)); }'
8. 内存和资源限制
BPF映射内存不足:

bash
# 检查当前限制
sysctl kernel.bpf_stats_enabled
sysctl kernel.bpf_jit_harden

# 增加限制（临时）
sudo sysctl -w kernel.perf_event_mlock_kb=20480
sudo sysctl -w kernel.bpf_jit_limit=1000000000
Too many open files:

bash
# 增加文件描述符限制
ulimit -n 8192
sudo prlimit --pid $$ --nofile=8192
9. 特定发行版问题
Arch Linux:

bash
# 安装所有依赖
sudo pacman -S bpftrace linux-headers clang llvm
sudo mount -t debugfs none /sys/kernel/debug
Fedora:

bash
# 可能需要禁用SELinux或设置权限
sudo setsebool -P deny_ptrace 0
WSL2:

bash
# WSL2支持有限，建议使用完整Linux环境
# 检查WSL版本
wsl --version

# 可能需要自定义内核
10. 调试技巧
启用调试输出:

bash
# 显示详细错误信息
sudo bpftrace -v -e '...'

# 显示BPF字节码
sudo bpftrace -d -e '...'

# 使用bpftool调试
sudo bpftool prog list
sudo bpftool prog dump xlated id <prog_id>
查看内核日志:

bash
# 查看详细的BPF相关错误
sudo dmesg | grep -i bpf
sudo dmesg | tail -50

# 实时查看日志
sudo journalctl -f -k
使用strace跟踪:

bash
# 跟踪bpftrace的系统调用
strace -f sudo bpftrace -e 'BEGIN { exit() }'
11. 网络相关问题
无法跟踪网络事件:

bash
# 检查网络tracepoint
sudo bpftrace -l 'tracepoint:net:*'

# 可能需要特定网络配置
sudo sysctl -w net.core.bpf_jit_enable=1
12. 容器环境问题
在Docker容器中运行:

bash
# 需要特权模式
docker run --privileged --pid=host -it ubuntu bash

# 在容器内安装
apt update && apt install -y bpftrace linux-tools-$(uname -r)

# 挂载调试文件系统
mount -t debugfs none /sys/kernel/debug
Kubernetes中运行:

yaml
# Pod配置需要特权
securityContext:
  privileged: true
  capabilities:
    add: ["BPF", "PERFMON", "SYS_ADMIN", "SYS_RESOURCE"]
快速诊断脚本
创建一个诊断脚本 diagnose.sh:

bash
#!/bin/bash
echo "=== eBPF环境诊断 ==="
echo "1. 内核版本: $(uname -r)"
echo "2. BPF支持: $(grep -c CONFIG_BPF=y /boot/config-$(uname -r) 2>/dev/null || echo '未知')"
echo "3. 调试文件系统: $(mount | grep -c debugfs)"
echo "4. bpftrace版本: $(bpftrace --version 2>/dev/null || echo '未安装')"
echo "5. 可用tracepoint: $(bpftrace -l 'tracepoint:syscalls:*' 2>/dev/null | wc -l)"
echo "6. 当前用户: $(whoami)"
echo "7. 权限测试:"
sudo bpftrace -e 'BEGIN { printf("测试通过\\n"); exit(); }' 2>&1 | grep -q "测试通过" && echo "✓ 权限正常" || echo "✗ 权限异常"
获取帮助
官方文档: https://github.com/iovisor/bpftrace/blob/master/docs/reference_guide.md

GitHub Issues: https://github.com/iovisor/bpftrace/issues

Stack Overflow: 使用标签 [bpftrace]

IRC: #bpftrace on OFTC

紧急恢复
如果eBPF程序导致系统问题:

bash
# 1. 卸载所有BPF程序
sudo bpftool prog list | grep -o 'id [0-9]*' | cut -d' ' -f2 | xargs -I{} sudo bpftool prog unload id {}

# 2. 清理BPF映射
sudo rm -rf /sys/fs/bpf/*

# 3. 重启BPF文件系统
sudo umount /sys/fs/bpf
sudo mount -t bpf none /sys/fs/bpf

# 4. 禁用BPF JIT（如有问题）
sudo sysctl -w net.core.bpf_jit_enable=0
记住：当遇到问题时，从简单测试开始，逐步增加复杂度！

text

## 🎯 示例文件

### 1. 实用一行命令（完整版）

**examples/one_liners.md**

```markdown
# bpftrace 实用一行命令大全

## 📊 系统概览

### CPU相关
```bash
# 显示CPU使用率最高的进程（每秒更新）
sudo bpftrace -e 'tracepoint:sched:sched_stat_runtime { @[comm] = sum(args->runtime); } interval:s:1 { printf("\nCPU Usage (ms):\n"); print(@); clear(@); }'

# 跟踪上下文切换
sudo bpftrace -e 'tracepoint:sched:sched_switch { @[comm] = count(); } END { print(@, 10); }'

# 显示CPU迁移
sudo bpftrace -e 'tracepoint:sched:sched_migrate_task { printf("%s migrated from CPU%d to CPU%d\n", args->comm, args->orig_cpu, args->dest_cpu); }'
内存相关
bash
# 跟踪页错误
sudo bpftrace -e 'tracepoint:exceptions:page_fault_user { @[comm] = count(); } interval:s:5 { printf("\nPage Faults (last 5s):\n"); print(@); clear(@); }'

# 跟踪内存分配（按大小）
sudo bpftrace -e 'kprobe:__kmalloc { @sizes = hist(arg0); } interval:s:10 { printf("\nMemory Allocation Sizes:\n"); print(@sizes); clear(@sizes); }'

# OOM Killer事件
sudo bpftrace -e 'tracepoint:oom:oom_kill_process { printf("OOM: killed %s (pid %d), score %d\n", args->comm, args->pid, args->totalpages); }'
磁盘I/O相关
bash
# 按进程统计磁盘I/O
sudo bpftrace -e 'tracepoint:block:block_rq_issue { @io[comm] = count(); @bytes[comm] = sum(args->bytes); } END { printf("\nI/O Operations:\n"); print(@io); printf("\nI/O Bytes:\n"); print(@bytes); }'

# 磁盘I/O延迟直方图
sudo bpftrace -e 'tracepoint:block:block_rq_issue { @start[args->sector] = nsecs; } tracepoint:block:block_rq_complete /@start[args->sector]/ { @latency = hist(nsecs - @start[args->sector]); delete(@start[args->sector]); } interval:s:5 { printf("\nI/O Latency (us):\n"); print(@latency); clear(@latency); }'

# 按设备统计I/O
sudo bpftrace -e 'tracepoint:block:block_rq_issue { @[args->dev] = count(); } interval:s:3 { time("%H:%M:%S "); print(@); clear(@); }'
网络相关
bash
# TCP连接跟踪
sudo bpftrace -e 'tracepoint:tcp:tcp_connect { printf("TCP Connect: %s -> %s:%d\n", ntop(args->saddr), ntop(args->daddr), args->dport); }'

# 网络丢包统计
sudo bpftrace -e 'kprobe:__kfree_skb { @[kstack] = count(); } END { printf("\nPacket Drops by stack:\n"); print(@, 5); }'

# 按进程统计网络流量
sudo bpftrace -e 'tracepoint:net:net_dev_queue { @tx[comm] = sum(args->len); } tracepoint:net:netif_receive_skb { @rx[comm] = sum(args->len); } interval:s:2 { printf("\nNetwork Traffic (bytes):\n"); printf("TX: "); print(@tx); printf("RX: "); print(@rx); clear(@tx); clear(@rx); }'
🔍 进程分析
进程生命周期
bash
# 跟踪进程创建/退出
sudo bpftrace -e 'tracepoint:sched:sched_process_fork { printf("Fork: %s(%d) -> %d\n", args->parent_comm, args->parent_pid, args->child_pid); } tracepoint:sched:sched_process_exit { printf("Exit: %s(%d) code %d\n", args->comm, args->pid, args->exit_code); }'

# 跟踪exec系统调用
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_execve { printf("%d execve: %s\n", pid, str(args->filename)); }'

# 跟踪setuid/setgid
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_setuid { printf("%s setuid to %d\n", comm, args->uid); }'
进程间通信
bash
# 跟踪信号发送
sudo bpftrace -e 'tracepoint:signal:signal_generate { printf("%s(%d) sent %s to %s(%d)\n", comm, pid, args->sig, args->comm, args->pid); }'

# 跟踪管道使用
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_pipe { printf("%s created pipe\n", comm); } tracepoint:syscalls:sys_enter_pipe2 { printf("%s created pipe2 with flags %d\n", comm, args->flags); }'
📁 文件系统分析
文件操作
bash
# 跟踪所有文件打开
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open, tracepoint:syscalls:sys_enter_openat { printf("%s open: %s\n", comm, str(args->filename)); }'

# 跟踪文件读写（带大小）
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_read { @read[comm] = sum(args->count); } tracepoint:syscalls:sys_enter_write { @write[comm] = sum(args->count); } interval:s:5 { printf("\nFile I/O (bytes):\n"); printf("Read: "); print(@read); printf("Write: "); print(@write); clear(@read); clear(@write); }'

# 跟踪文件删除
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_unlink, tracepoint:syscalls:sys_enter_unlinkat { printf("%s deleted: %s\n", comm, str(args->filename)); }'
目录操作
bash
# 跟踪目录创建/删除
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_mkdir, tracepoint:syscalls:sys_enter_mkdirat { printf("%s mkdir: %s\n", comm, str(args->filename)); } tracepoint:syscalls:sys_enter_rmdir { printf("%s rmdir: %s\n", comm, str(args->filename)); }'
🛠️ 系统调用分析
系统调用统计
bash
# 按类型统计系统调用
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_* { @[probe] = count(); } END { print(@, 20); }'

# 按进程统计系统调用
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_* { @[comm] = count(); } interval:s:5 { printf("\nSyscalls by process:\n"); print(@, 10); clear(@); }'

# 系统调用错误统计
sudo bpftrace -e 'tracepoint:syscalls:sys_exit_* /args->ret < 0/ { @[probe] = count(); } END { printf("\nSyscall Errors:\n"); print(@, 10); }'
特定系统调用跟踪
bash
# 跟踪mmap/munmap
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_mmap { printf("%s mmap: size=%d, prot=%d, flags=%d\n", comm, args->len, args->prot, args->flags); }'

# 跟踪brk（堆内存管理）
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_brk { printf("%s brk: addr=0x%x\n", comm, args->brk); }'

# 跟踪clone/fork
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_clone { printf("%s clone: flags=0x%x\n", comm, args->flags); }'
🔧 内核函数跟踪
调度器
bash
# 跟踪进程唤醒
sudo bpftrace -e 'tracepoint:sched:sched_wakeup { printf("Wakeup: %s(%d) -> %s(%d)\n", args->curr_comm, args->curr_pid, args->comm, args->pid); }'

# 跟踪CPU空闲/忙碌
sudo bpftrace -e 'tracepoint:power:cpu_idle { @idle[args->state] = count(); } tracepoint:power:cpu_frequency { @freq[args->state] = count(); } END { printf("Idle states:\n"); print(@idle); printf("\nFrequency states:\n"); print(@freq); }'
内存管理
bash
# 跟踪页面分配
sudo bpftrace -e 'kprobe:alloc_pages { @allocations[comm] = count(); } interval:s:5 { printf("\nPage Allocations:\n"); print(@allocations, 10); clear(@allocations); }'

# 跟踪内存回收
sudo bpftrace -e 'kprobe:shrink_slab { printf("%s shrink_slab: scanned=%d\n", comm, arg0); }'
网络协议栈
bash
# 跟踪IP层处理
sudo bpftrace -e 'kprobe:ip_rcv { @packets[comm] = count(); } interval:s:2 { printf("\nIP Packets Received:\n"); print(@packets); clear(@packets); }'

# 跟踪TCP状态变化
sudo bpftrace -e 'tracepoint:tcp:tcp_set_state { printf("TCP %s:%d -> %s:%d state %d->%d\n", ntop(args->saddr), args->sport, ntop(args->daddr), args->dport, args->oldstate, args->newstate); }'
📈 性能分析
延迟分析
bash
# 系统调用延迟直方图
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { @start[pid] = nsecs; } tracepoint:syscalls:sys_exit_open /@start[pid]/ { @latency = hist(nsecs - @start[pid]); delete(@start[pid]); } END { printf("\nOpen syscall latency (ns):\n"); print(@latency); }'

# 调度延迟
sudo bpftrace -e 'tracepoint:sched:sched_wakeup { @wakeup[args->pid] = nsecs; } tracepoint:sched:sched_switch /@wakeup[args->next_pid]/ { @delay = hist(nsecs - @wakeup[args->next_pid]); delete(@wakeup[args->next_pid]); } END { printf("\nScheduling delay (ns):\n"); print(@delay); }'
热点分析
bash
# 函数调用热点（内核空间）
sudo bpftrace -e 'kprobe:* { @[func] = count(); } interval:s:5 { printf("\nKernel function calls (top 20):\n"); print(@, 20); clear(@); }'

# 用户空间函数热点（需要调试符号）
sudo bpftrace -e 'uprobe:/lib/x86_64-linux-gnu/libc.so.6:* { @[func] = count(); } interval:s:5 { printf("\nLibc function calls:\n"); print(@, 10); clear(@); }'
🎯 安全监控
权限变更
bash
# 跟踪特权操作
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_capset { printf("%s capset: effective=0x%x, permitted=0x%x, inheritable=0x%x\n", comm, args->effective, args->permitted, args->inheritable); }'

# 跟踪模块加载
sudo bpftrace -e 'tracepoint:module:module_load { printf("Module loaded: %s\n", str(args->name)); }'
可疑活动检测
bash
# 检测隐藏进程（通过/proc遍历）
sudo bpftrace -e 'kprobe:proc_pid_readdir { @scans[comm] = count(); } interval:s:10 { printf("\n/proc scans (possible hiding detection):\n"); print(@scans); clear(@scans); }'

# 检测代码注入
sudo bpftrace -e 'kprobe:do_mprotect_pkey { printf("%s mprotect: addr=0x%x, len=%d, prot=%d\n", comm, arg0, arg1, arg2); }'
🐳 容器监控
Docker/Kubernetes环境
bash
# 跟踪cgroup操作
sudo bpftrace -e 'tracepoint:cgroup:* { printf("%s: %s\n", probe, str(args->path)); }'

# 跟踪命名空间操作
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_unshare { printf("%s unshare: flags=0x%x\n", comm, args->flags); } tracepoint:syscalls:sys_enter_setns { printf("%s setns: fd=%d, nstype=%d\n", comm, args->fd, args->nstype); }'
🎮 交互式工具
实时监控面板
bash
# 系统资源实时监控
sudo bpftrace -e '
BEGIN {
    printf("%-10s %-6s %-6s %-6s %-8s %-8s\n", 
           "TIME", "CPU%", "MEM", "IO", "NET_RX", "NET_TX");
}

tracepoint:sched:sched_stat_runtime {
    @cpu_time[comm] = sum(args->runtime);
}

tracepoint:syscalls:sys_enter_read {
    @read_bytes[comm] = sum(args->count);
}

tracepoint:syscalls:sys_enter_write {
    @write_bytes[comm] = sum(args->count);
}

tracepoint:net:net_dev_queue {
    @tx_bytes[comm] = sum(args->len);
}

tracepoint:net:netif_receive_skb {
    @rx_bytes[comm] = sum(args->len);
}

interval:s:1 {
    $time = strftime("%H:%M:%S", nsecs);
    
    // 计算CPU使用率
    $total_cpu = 0;
    foreach ($comm in @cpu_time) {
        $total_cpu += @cpu_time[$comm];
    }
    
    // 计算内存（近似）
    $total_mem = count(@proc_maps) * 4096;
    
    // 计算I/O
    $total_io = 0;
    foreach ($comm in @read_bytes) {
        $total_io += @read_bytes[$comm];
    }
    foreach ($comm in @write_bytes) {
        $total_io += @write_bytes[$comm];
    }
    
    // 计算网络
    $total_rx = 0;
    $total_tx = 0;
    foreach ($comm in @rx_bytes) {
        $total_rx += @rx_bytes[$comm];
    }
    foreach ($comm in @tx_bytes) {
        $total_tx += @tx_bytes[$comm];
    }
    
    printf("%-10s %-6d %-6d %-6d %-8d %-8d\n",
           $time,
           $total_cpu / 10000000,  // 转换为百分比近似值
           $total_mem / 1024,      // KB
           $total_io / 1024,       // KB
           $total_rx / 1024,       // KB
           $total_tx / 1024);      // KB
    
    // 清理数据
    clear(@cpu_time);
    clear(@read_bytes);
    clear(@write_bytes);
    clear(@rx_bytes);
    clear(@tx_bytes);
}
'
💡 实用技巧
过滤器使用
bash
# 只跟踪特定进程
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open /comm == "nginx"/ { printf("nginx open: %s\n", str(args->filename)); }'

# 排除特定进程
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open /comm != "systemd"/ { @[comm] = count(); }'

# 基于PID过滤
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open /pid == 1234/ { printf("PID 1234 open: %s\n", str(args->filename)); }'

# 基于返回值过滤
sudo bpftrace -e 'tracepoint:syscalls:sys_exit_open /args->ret < 0/ { printf("%s open failed: %s, errno=%d\n", comm, str(args->filename), -args->ret); }'
条件触发
bash
# 阈值触发
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { @count++; if (@count > 1000) { printf("High open rate: %d opens/s\n", @count); @count = 0; } } interval:s:1 { @count = 0; }'

# 异常检测
sudo bpftrace -e 'kprobe:__kmalloc { $size = arg0; if ($size > 1048576) { printf("Large allocation: %s allocated %d bytes\n", comm, $size); } }'
数据持久化
bash
# 将输出保存到文件
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { printf("%d %s %s\n", nsecs, comm, str(args->filename)); }' > opens.log

# 使用外部命令处理
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { printf("%s\n", str(args->filename)); }' | sort | uniq -c | sort -rn | head -20
🚀 高级组合
分布式跟踪
bash
# 跟踪跨进程的系统调用链
sudo bpftrace -e '
tracepoint:syscalls:sys_enter_open {
    @chain[pid] = str(args->filename);
}

tracepoint:syscalls:sys_exit_open {
    if (@chain[pid]) {
        printf("Process chain: %s -> %s (result: %d)\n", 
               @chain[pid], comm, args->ret);
        delete(@chain[pid]);
    }
}
'
性能回归检测
bash
# 检测性能回归
sudo bpftrace -e '
tracepoint:syscalls:sys_enter_open {
    @start[pid] = nsecs;
}

tracepoint:syscalls:sys_exit_open {
    if (@start[pid]) {
        $latency = nsecs - @start[pid];
        @avg_latency = avg($latency);
        @max_latency = max($latency);
        
        // 如果延迟超过阈值，报警
        if ($latency > 100000000) {  // 100ms
            printf("PERF ALERT: %s open took %d ms\n", 
                   comm, $latency / 1000000);
        }
        
        delete(@start[pid]);
    }
}

interval:s:10 {
    printf("Stats: avg=%d ns, max=%d ns\n", 
           @avg_latency, @max_latency);
    clear(@avg_latency);
    clear(@max_latency);
}
'