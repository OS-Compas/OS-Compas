markdown
# 🚀 bpftrace 实用一行命令大全

## 📊 系统概览与监控

### CPU相关
```bash
# 实时显示CPU使用率最高的进程（每秒更新）
sudo bpftrace -e 'tracepoint:sched:sched_stat_runtime { @[comm] = sum(args->runtime); } interval:s:1 { printf("\nCPU Usage (ms):\n"); print(@); clear(@); }'

# 跟踪上下文切换最多的进程
sudo bpftrace -e 'tracepoint:sched:sched_switch { @[comm] = count(); } END { print(@, 10); }'

# 显示CPU迁移情况
sudo bpftrace -e 'tracepoint:sched:sched_migrate_task { printf("%s migrated from CPU%d to CPU%d\n", args->comm, args->orig_cpu, args->dest_cpu); }'

# 跟踪CPU频率变化
sudo bpftrace -e 'tracepoint:power:cpu_frequency { printf("CPU%d: %d -> %d MHz\n", args->cpu, args->old_state, args->new_state); }'
内存相关
bash
# 跟踪页错误（按进程）
sudo bpftrace -e 'tracepoint:exceptions:page_fault_user { @[comm] = count(); } interval:s:5 { printf("\nPage Faults (last 5s):\n"); print(@); clear(@); }'

# 跟踪内核内存分配（按大小直方图）
sudo bpftrace -e 'kprobe:__kmalloc { @sizes = hist(arg0); } interval:s:10 { printf("\nMemory Allocation Sizes:\n"); print(@sizes); clear(@sizes); }'

# 监控OOM Killer事件
sudo bpftrace -e 'tracepoint:oom:oom_kill_process { printf("[OOM] Killed %s (pid %d), score %d\n", args->comm, args->pid, args->totalpages); }'

# 跟踪slab分配器
sudo bpftrace -e 'kprobe:kmem_cache_alloc { @[comm] = count(); } interval:s:5 { printf("\nSlab Allocations:\n"); print(@, 10); clear(@); }'
磁盘I/O相关
bash
# 按进程统计磁盘I/O操作
sudo bpftrace -e 'tracepoint:block:block_rq_issue { @io[comm] = count(); @bytes[comm] = sum(args->bytes); } END { printf("\nI/O Statistics:\n"); print(@io); printf("\nI/O Bytes:\n"); print(@bytes); }'

# 磁盘I/O延迟直方图（微秒）
sudo bpftrace -e 'tracepoint:block:block_rq_issue { @start[args->sector] = nsecs; } tracepoint:block:block_rq_complete /@start[args->sector]/ { @latency = hist((nsecs - @start[args->sector])/1000); delete(@start[args->sector]); } interval:s:5 { printf("\nI/O Latency (μs):\n"); print(@latency); clear(@latency); }'

# 按设备统计I/O
sudo bpftrace -e 'tracepoint:block:block_rq_issue { @[args->dev] = count(); } interval:s:3 { time("%H:%M:%S "); print(@); clear(@); }'

# 跟踪文件系统操作
sudo bpftrace -e 'tracepoint:ext4:ext4_request_inode { printf("%s creating inode\n", comm); } tracepoint:ext4:ext4_delete_inode { printf("%s deleting inode\n", comm); }'
网络相关
bash
# TCP连接建立跟踪
sudo bpftrace -e 'tracepoint:tcp:tcp_connect { printf("TCP Connect: %s -> %s:%d (pid: %d)\n", ntop(args->saddr), ntop(args->daddr), args->dport, pid); }'

# 网络丢包原因分析
sudo bpftrace -e 'kprobe:__kfree_skb { @[kstack] = count(); } END { printf("\nPacket Drops by stack:\n"); print(@, 5); }'

# 按进程统计网络流量（每秒）
sudo bpftrace -e 'tracepoint:net:net_dev_queue { @tx[comm] = sum(args->len); } tracepoint:net:netif_receive_skb { @rx[comm] = sum(args->len); } interval:s:2 { printf("\nNetwork Traffic (bytes/s):\n"); printf("TX: "); print(@tx); printf("RX: "); print(@rx); clear(@tx); clear(@rx); }'

# 跟踪DNS查询
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_sendto /comm == "systemd-resolve"/ { printf("DNS query by %s\n", comm); }'
🔍 进程与系统调用分析
进程生命周期
bash
# 跟踪进程fork/exec/exit完整生命周期
sudo bpftrace -e 'tracepoint:sched:sched_process_fork { printf("[FORK] %s(%d) -> %d\n", args->parent_comm, args->parent_pid, args->child_pid); } tracepoint:sched:sched_process_exec { printf("[EXEC] %d -> %s\n", pid, comm); } tracepoint:sched:sched_process_exit { printf("[EXIT] %s(%d) code %d\n", args->comm, args->pid, args->exit_code); }'

# 跟踪execve系统调用（新程序执行）
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_execve { printf("%d execve: %s\n", pid, str(args->filename)); }'

# 跟踪权限变更（setuid/setgid）
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_setuid { printf("%s setuid to %d\n", comm, args->uid); } tracepoint:syscalls:sys_enter_setgid { printf("%s setgid to %d\n", comm, args->gid); }'
进程间通信
bash
# 跟踪信号发送
sudo bpftrace -e 'tracepoint:signal:signal_generate { printf("%s(%d) sent signal %d to %s(%d)\n", comm, pid, args->sig, args->comm, args->pid); }'

# 跟踪管道创建和使用
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_pipe { printf("%s created pipe\n", comm); } tracepoint:syscalls:sys_enter_pipe2 { printf("%s created pipe2 with flags %d\n", comm, args->flags); }'

# 跟踪共享内存操作
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_shmat { printf("%s attaching shared memory\n", comm); } tracepoint:syscalls:sys_enter_shmdt { printf("%s detaching shared memory\n", comm); }'
系统调用统计分析
bash
# 按类型统计所有系统调用（最常用的20个）
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_* { @[probe] = count(); } END { print(@, 20); }'

# 按进程统计系统调用（实时更新）
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_* { @[comm] = count(); } interval:s:5 { printf("\nSyscalls by process (last 5s):\n"); print(@, 10); clear(@); }'

# 统计系统调用错误（返回负值）
sudo bpftrace -e 'tracepoint:syscalls:sys_exit_* /args->ret < 0/ { @[probe] = count(); } END { printf("\nSyscall Errors:\n"); print(@, 10); }'

# 跟踪特定系统调用延迟
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { @start[pid] = nsecs; } tracepoint:syscalls:sys_exit_open /@start[pid]/ { @latency = hist(nsecs - @start[pid]); delete(@start[pid]); } END { printf("\nOpen syscall latency (ns):\n"); print(@latency); }'
文件系统操作
bash
# 跟踪所有文件打开操作
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open, tracepoint:syscalls:sys_enter_openat { printf("%s open: %s (flags: 0x%x)\n", comm, str(args->filename), args->flags); }'

# 跟踪文件读写操作（带大小）
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_read { @read[comm] = sum(args->count); } tracepoint:syscalls:sys_enter_write { @write[comm] = sum(args->count); } interval:s:5 { printf("\nFile I/O (bytes):\n"); printf("Read: "); print(@read); printf("Write: "); print(@write); clear(@read); clear(@write); }'

# 跟踪文件删除操作
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_unlink, tracepoint:syscalls:sys_enter_unlinkat { printf("[DELETE] %s: %s\n", comm, str(args->filename)); }'

# 跟踪目录操作
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_mkdir, tracepoint:syscalls:sys_enter_mkdirat { printf("%s mkdir: %s\n", comm, str(args->filename)); } tracepoint:syscalls:sys_enter_rmdir { printf("%s rmdir: %s\n", comm, str(args->filename)); }'
🔧 内核内部跟踪
调度器跟踪
bash
# 跟踪进程唤醒和调度
sudo bpftrace -e 'tracepoint:sched:sched_wakeup { printf("Wakeup: %s(%d) -> %s(%d)\n", args->curr_comm, args->curr_pid, args->comm, args->pid); } tracepoint:sched:sched_switch { printf("Switch: %s(%d) -> %s(%d)\n", args->prev_comm, args->prev_pid, args->next_comm, args->next_pid); }'

# 跟踪CPU负载（运行队列长度）
sudo bpftrace -e 'kprobe:enqueue_task_fair { @runq[cpu] = count(); } interval:s:1 { printf("\nRun queue length per CPU:\n"); print(@runq); clear(@runq); }'
内存管理跟踪
bash
# 跟踪页面分配器
sudo bpftrace -e 'kprobe:alloc_pages { @allocations[comm] = count(); } interval:s:5 { printf("\nPage Allocations:\n"); print(@allocations, 10); clear(@allocations); }'

# 跟踪内存回收（kswapd）
sudo bpftrace -e 'kprobe:shrink_slab { printf("Memory shrink by %s: scanned %d objects\n", comm, arg0); }'

# 跟踪缺页异常
sudo bpftrace -e 'tracepoint:exceptions:page_fault_kernel { printf("Kernel page fault at 0x%x by %s\n", args->address, comm); } tracepoint:exceptions:page_fault_user { printf("User page fault at 0x%x by %s\n", args->address, comm); }'
网络协议栈跟踪
bash
# 跟踪IP层数据包接收
sudo bpftrace -e 'kprobe:ip_rcv { @packets[comm] = count(); } interval:s:2 { printf("\nIP Packets Received:\n"); print(@packets); clear(@packets); }'

# 跟踪TCP状态变化
sudo bpftrace -e 'tracepoint:tcp:tcp_set_state { printf("TCP %s:%d -> %s:%d state %d->%d\n", ntop(args->saddr), args->sport, ntop(args->daddr), args->dport, args->oldstate, args->newstate); }'

# 跟踪UDP数据包
sudo bpftrace -e 'kprobe:udp_recvmsg { @udp[comm] = count(); } interval:s:5 { printf("\nUDP packets received:\n"); print(@udp, 10); clear(@udp); }'
文件系统内部跟踪
bash
# 跟踪VFS层操作
sudo bpftrace -e 'kprobe:vfs_read { @reads[comm] = count(); } kprobe:vfs_write { @writes[comm] = count(); } interval:s:5 { printf("\nVFS Operations:\n"); printf("Reads: "); print(@reads); printf("Writes: "); print(@writes); clear(@reads); clear(@writes); }'

# 跟踪inode操作
sudo bpftrace -e 'kprobe:iput { printf("%s releasing inode\n", comm); } kprobe:iget_locked { printf("%s getting inode\n", comm); }'
📈 性能分析与调优
延迟分析
bash
# 系统调用延迟直方图（多个系统调用）
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { @start[pid] = nsecs; } tracepoint:syscalls:sys_exit_open /@start[pid]/ { @open_latency = hist(nsecs - @start[pid]); delete(@start[pid]); } tracepoint:syscalls:sys_enter_read { @start[pid] = nsecs; } tracepoint:syscalls:sys_exit_read /@start[pid]/ { @read_latency = hist(nsecs - @start[pid]); delete(@start[pid]); } END { printf("\nOpen latency (ns):\n"); print(@open_latency); printf("\nRead latency (ns):\n"); print(@read_latency); }'

# 调度延迟分析（从唤醒到运行）
sudo bpftrace -e 'tracepoint:sched:sched_wakeup { @wakeup[args->pid] = nsecs; } tracepoint:sched:sched_switch /@wakeup[args->next_pid]/ { @delay = hist(nsecs - @wakeup[args->next_pid]); delete(@wakeup[args->next_pid]); } END { printf("\nScheduling delay (ns):\n"); print(@delay); }'

# I/O完成延迟
sudo bpftrace -e 'tracepoint:block:block_rq_issue { @start[args->sector] = nsecs; } tracepoint:block:block_rq_complete /@start[args->sector]/ { @io_latency = hist((nsecs - @start[args->sector])/1000); delete(@start[args->sector]); } interval:s:10 { printf("\nI/O Completion Latency (μs):\n"); print(@io_latency); }'
热点分析
bash
# 内核函数调用热点（Top 20）
sudo bpftrace -e 'kprobe:* { @[func] = count(); } interval:s:5 { printf("\nKernel function calls (top 20):\n"); print(@, 20); clear(@); }'

# 用户空间库函数热点（需要调试符号）
sudo bpftrace -e 'uprobe:/lib/x86_64-linux-gnu/libc.so.6:* { @[func] = count(); } interval:s:5 { printf("\nLibc function calls (top 10):\n"); print(@, 10); clear(@); }'

# 堆栈跟踪热点
sudo bpftrace -e 'kprobe:vfs_read { @[kstack] = count(); } END { printf("\nVFS read call stacks:\n"); print(@, 5); }'
资源使用分析
bash
# CPU时间按进程统计
sudo bpftrace -e 'tracepoint:sched:sched_stat_runtime { @cpu_time[comm] = sum(args->runtime); } interval:s:10 { printf("\nCPU Time (ms, last 10s):\n"); print(@cpu_time); clear(@cpu_time); }'

# 内存使用趋势
sudo bpftrace -e 'tracepoint:kmem:mm_page_alloc { @alloc[comm] = count(); } tracepoint:kmem:mm_page_free { @free[comm] = count(); } interval:s:5 { printf("\nPage allocation/free delta:\n"); foreach ([$comm, $alloc_count] in @alloc) { $free_count = @free[$comm]; printf("%s: +%d -%d = %d\n", $comm, $alloc_count, $free_count, $alloc_count - $free_count); } clear(@alloc); clear(@free); }'
🎯 安全监控与审计
权限变更监控
bash
# 跟踪特权操作
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_capset { printf("%s capset: effective=0x%x, permitted=0x%x, inheritable=0x%x\n", comm, args->effective, args->permitted, args->inheritable); }'

# 跟踪内核模块加载/卸载
sudo bpftrace -e 'tracepoint:module:module_load { printf("Module loaded: %s\n", str(args->name)); } tracepoint:module:module_free { printf("Module unloaded: %s\n", str(args->name)); }'

# 跟踪ptrace操作（进程调试）
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_ptrace { printf("%s ptrace: request=%d, pid=%d\n", comm, args->request, args->pid); }'
可疑活动检测
bash
# 检测/proc文件系统扫描（可能的隐藏进程检测）
sudo bpftrace -e 'kprobe:proc_pid_readdir { @scans[comm] = count(); } interval:s:10 { printf("\n/proc scans (possible hiding detection):\n"); print(@scans); clear(@scans); }'

# 检测代码注入尝试（mprotect with execute permission）
sudo bpftrace -e 'kprobe:do_mprotect_pkey { if (arg2 & 0x4) { printf("WARNING: %s mprotect with PROT_EXEC: addr=0x%x, len=%d\n", comm, arg0, arg1); } }'

# 检测reverse shell连接尝试
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_connect { if (args->uservaddr->sin_port == htons(4444) || args->uservaddr->sin_port == htons(5555)) { printf("SUSPICIOUS: %s connecting to port %d\n", comm, ntohs(args->uservaddr->sin_port)); } }'
文件监控
bash
# 监控敏感文件访问（如/etc/shadow）
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_openat { $filename = str(args->filename); if (str($filename) == "/etc/shadow" || strstr($filename, ".ssh/id_rsa") != 0) { printf("ALERT: %s accessing sensitive file: %s\n", comm, $filename); } }'

# 监控文件创建在敏感目录
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_openat { $filename = str(args->filename); if (strstr($filename, "/tmp/") != 0 && (args->flags & O_CREAT)) { printf("File created in /tmp: %s by %s\n", $filename, comm); } }'
🐳 容器与虚拟化环境
Docker/Kubernetes监控
bash
# 跟踪cgroup操作
sudo bpftrace -e 'tracepoint:cgroup:* { printf("%s: %s\n", probe, str(args->path)); }'

# 跟踪命名空间操作
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_unshare { printf("%s unshare: flags=0x%x\n", comm, args->flags); } tracepoint:syscalls:sys_enter_setns { printf("%s setns: fd=%d, nstype=%d\n", comm, args->fd, args->nstype); }'

# 跟踪容器运行时操作
sudo bpftrace -e 'uprobe:/usr/bin/docker:* { @docker[func] = count(); } interval:s:5 { printf("\nDocker operations:\n"); print(@docker, 10); clear(@docker); }'
虚拟化跟踪
bash
# 跟踪KVM虚拟机退出
sudo bpftrace -e 'tracepoint:kvm:kvm_exit { printf("VM exit: reason %d, rip 0x%llx\n", args->exit_reason, args->guest_rip); }'

# 跟踪虚拟机I/O
sudo bpftrace -e 'tracepoint:kvm:kvm_io { printf("VM I/O: port 0x%x, size %d, direction %d\n", args->port, args->size, args->direction); }'
🎮 交互式监控面板
实时系统监控
bash
# 系统资源实时监控面板
sudo bpftrace -e '
BEGIN {
    printf("\033[2J\033[H"); // 清屏
    printf("%-10s %-8s %-8s %-8s %-8s %-8s\n", 
           "TIME", "CPU%", "MEM", "DISK", "NET_RX", "NET_TX");
    printf("%s\n", "=" repeat(60));
}

// CPU使用率
tracepoint:sched:sched_stat_runtime {
    @cpu_time[comm] = sum(args->runtime);
}

// 内存分配
tracepoint:kmem:mm_page_alloc {
    @mem_alloc = count();
}

// 磁盘I/O
tracepoint:block:block_rq_issue {
    @disk_io = sum(args->bytes);
}

// 网络
tracepoint:net:net_dev_queue {
    @net_tx = sum(args->len);
}
tracepoint:net:netif_receive_skb {
    @net_rx = sum(args->len);
}

interval:s:1 {
    $time = strftime("%H:%M:%S", nsecs);
    
    // 计算CPU使用率
    $total_cpu = 0;
    foreach ($comm in @cpu_time) {
        $total_cpu += @cpu_time[$comm];
    }
    $cpu_percent = $total_cpu / 10000000; // 转换为百分比近似值
    
    // 内存使用（页数）
    $mem_pages = @mem_alloc * 4; // 每页4KB
    
    // 磁盘I/O（KB/s）
    $disk_kb = @disk_io / 1024;
    
    // 网络（KB/s）
    $net_rx_kb = @net_rx / 1024;
    $net_tx_kb = @net_tx / 1024;
    
    // 更新显示
    printf("\033[2;0H"); // 移动到第2行
    printf("%-10s %-8.1f %-8d %-8.0f %-8.0f %-8.0f\n",
           $time,
           $cpu_percent,
           $mem_pages,
           $disk_kb,
           $net_rx_kb,
           $net_tx_kb);
    
    // 显示top进程
    printf("\033[4;0H");
    printf("Top CPU processes:\n");
    $i = 0;
    foreach ([$comm, $time] in @cpu_time limit 3) {
        printf("  %s: %.1f ms\n", $comm, $time / 1000000);
        $i++;
    }
    
    // 清理数据
    clear(@cpu_time);
    clear(@mem_alloc);
    clear(@disk_io);
    clear(@net_rx);
    clear(@net_tx);
}

END {
    printf("\033[10;0H"); // 移动到屏幕底部
    printf("Monitoring stopped.\n");
}
'

# 进程树实时监控
sudo bpftrace -e '
BEGIN {
    printf("Process Tree Monitor - Press Ctrl+C to exit\n");
    printf("PID\tPPID\tCOMM\t\tSTATE\n");
    printf("========================================\n");
}

tracepoint:sched:sched_process_fork {
    @parent[$1] = pid;
    @children[pid] = $1;
}

tracepoint:sched:sched_process_exec {
    printf("%d\t%d\t%s\t\texec\n", pid, @parent[pid], comm);
}

tracepoint:sched:sched_process_exit {
    printf("%d\t%d\t%s\t\texit\n", pid, @parent[pid], comm);
    delete(@parent[pid]);
    delete(@children[pid]);
}

interval:s:2 {
    printf("\n--- Active processes (refreshed every 2s) ---\n");
}
'
💡 实用技巧与模式
过滤器使用技巧
bash
# 只跟踪特定进程
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open /comm == "nginx"/ { printf("nginx open: %s\n", str(args->filename)); }'

# 排除系统进程
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open /comm != "systemd" && comm != "kworker"/ { @[comm] = count(); }'

# 基于PID过滤
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open /pid == 1234 || pid == 5678/ { printf("PID %d open: %s\n", pid, str(args->filename)); }'

# 基于返回值过滤（错误处理）
sudo bpftrace -e 'tracepoint:syscalls:sys_exit_open /args->ret < 0/ { printf("%s open failed: %s, errno=%d\n", comm, str(args->filename), -args->ret); }'

# 基于参数值过滤
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_openat /args->dfd == AT_FDCWD/ { printf("%s openat with AT_FDCWD\n", comm); }'
条件触发与告警
bash
# 阈值触发告警
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { @count++; if (@count > 1000) { printf("ALERT: High open rate: %d opens/s\n", @count); @count = 0; } } interval:s:1 { @count = 0; }'

# 异常检测（大内存分配）
sudo bpftrace -e 'kprobe:__kmalloc { $size = arg0; if ($size > 1048576) { printf("WARNING: Large allocation: %s allocated %d bytes\n", comm, $size); } }'

# 错误率监控
sudo bpftrace -e 'tracepoint:syscalls:sys_exit_open { @total++; if (args->ret < 0) { @errors++; } } interval:s:10 { $error_rate = @errors * 100.0 / @total; if ($error_rate > 10.0) { printf("ALERT: High open error rate: %.1f%%\n", $error_rate); } clear(@total); clear(@errors); }'
数据持久化与导出
bash
# 将输出保存到文件（带时间戳）
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { printf("%d %s %s\n", nsecs, comm, str(args->filename)); }' > file_access_$(date +%Y%m%d_%H%M%S).log

# 使用外部命令处理输出
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { printf("%s\n", str(args->filename)); }' | sort | uniq -c | sort -rn | head -20

# JSON格式输出
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { printf("{\"timestamp\":%d,\"process\":\"%s\",\"file\":\"%s\"}\n", nsecs, comm, str(args->filename)); }' > access.json

# CSV格式输出
sudo bpftrace -e 'BEGIN { printf("timestamp,pid,comm,filename\n"); } tracepoint:syscalls:sys_enter_open { printf("%d,%d,%s,%s\n", nsecs, pid, comm, str(args->filename)); }' > access.csv
性能优化技巧
bash
# 使用采样减少开销
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open /pid % 100 == 0/ { @[comm] = count(); } END { printf("Sampled open calls:\n"); print(@); }'

# 聚合数据减少输出
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { @[comm] = count() } interval:s:5 { printf("\nOpen calls (last 5s):\n"); print(@); clear(@); }'

# 使用直方图而不是详细日志
sudo bpftrace -e 'kretprobe:vfs_read { @latency = hist(arg0); } END { printf("\nRead latency distribution:\n"); print(@latency); }'

# 限制跟踪范围
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open /pid > 1000 && pid < 2000/ { @[comm] = count(); }'
🚀 高级组合示例
分布式跟踪模式
bash
# 跟踪跨进程的调用链
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

// 跟踪进程间通信
tracepoint:syscalls:sys_enter_write /fd == 1 || fd == 2/ {  // stdout/stderr
    printf("Process output: %s -> %s\n", comm, str(buf));
}
'

# 服务依赖分析
sudo bpftrace -e '
tracepoint:syscalls:sys_enter_connect {
    @connections[comm] = str(args->uservaddr);
}

tracepoint:syscalls:sys_exit_connect /args->ret == 0/ {
    printf("Service dependency: %s -> %s\n", comm, @connections[comm]);
    delete(@connections[comm]);
}
'
性能回归检测
bash
# 检测性能退化
sudo bpftrace -e '
tracepoint:syscalls:sys_enter_open {
    @start[pid] = nsecs;
}

tracepoint:syscalls:sys_exit_open {
    if (@start[pid]) {
        $latency = nsecs - @start[pid];
        @avg_latency = avg($latency);
        @max_latency = max($latency);
        @min_latency = min($latency);
        
        // 检测异常
        if ($latency > 100000000) {  // 100ms阈值
            printf("PERFORMANCE ALERT: %s open took %d ms\n", 
                   comm, $latency / 1000000);
        }
        
        delete(@start[pid]);
    }
}

interval:s:10 {
    printf("Performance stats (last 10s):\n");
    printf("  Avg: %d ns, Min: %d ns, Max: %d ns\n", 
           @avg_latency, @min_latency, @max_latency);
    
    // 基线比较
    if (@avg_latency > @baseline * 1.5) {
        printf("  WARNING: 50%% degradation from baseline!\n");
    }
    
    clear(@avg_latency);
    clear(@max_latency);
    clear(@min_latency);
}

BEGIN {
    // 设置基线（需要校准）
    @baseline = 1000000; // 1ms基线
}
'
容量规划分析
bash
# 系统资源使用趋势
sudo bpftrace -e '
BEGIN {
    printf("System Capacity Planning Monitor\n");
    printf("Tracking resource usage trends...\n\n");
}

// 跟踪各种资源
tracepoint:sched:sched_stat_runtime {
    @cpu_usage = sum(args->runtime);
}

tracepoint:kmem:mm_page_alloc {
    @mem_usage = count();
}

tracepoint:block:block_rq_issue {
    @io_ops = count();
    @io_bytes = sum(args->bytes);
}

tracepoint:net:net_dev_queue {
    @net_tx = sum(args->len);
}

interval:s:60 {  // 每分钟记录一次
    $time = strftime("%H:%M", nsecs);
    
    // 计算每分钟的使用率
    $cpu_ms = @cpu_usage / 1000000;  // 转换为毫秒
    $mem_mb = @mem_usage * 4 / 1024; // 转换为MB（4KB每页）
    $io_mb = @io_bytes / 1024 / 1024;
    $net_mb = @net_tx / 1024 / 1024;
    
    printf("%s: CPU=%.1fms, Mem=%.1fMB, I/O=%.1fMB, Net=%.1fMB\n",
           $time, $cpu_ms, $mem_mb, $io_mb, $net_mb);
    
    // 存储历史数据（最后60分钟）
    @cpu_history[$time] = $cpu_ms;
    @mem_history[$time] = $mem_mb;
    
    // 清理旧数据
    delete(@cpu_history[$time - 3600]);
    delete(@mem_history[$time - 3600]);
    
    // 重置计数器
    clear(@cpu_usage);
    clear(@mem_usage);
    clear(@io_ops);
    clear(@io_bytes);
    clear(@net_tx);
}

END {
    printf("\n\nHourly Summary:\n");
    printf("===============\n");
    
    // 计算每小时的平均值
    foreach ([$hour, $cpu] in @cpu_history) {
        @hourly_cpu[$hour] = avg($cpu);
    }
    
    foreach ([$hour, $mem] in @mem_history) {
        @hourly_mem[$hour] = avg($mem);
    }
    
    printf("CPU Usage (ms/min):\n");
    print(@hourly_cpu);
    printf("\nMemory Usage (MB/min):\n");
    print(@hourly_mem);
}
'
📚 学习与调试
学习工具
bash
# 查看所有可用的tracepoint
sudo bpftrace -l | head -20
sudo bpftrace -l 'tracepoint:syscalls:*'
sudo bpftrace -l 'tracepoint:sched:*'

# 查看kprobe列表
sudo bpftrace -l 'kprobe:*' | grep -i vfs | head -10

# 查看tracepoint格式
sudo cat /sys/kernel/debug/tracing/events/syscalls/sys_enter_open/format

# 测试单个探针
sudo bpftrace -v -e 'tracepoint:syscalls:sys_enter_open { printf("Test\n"); }'
调试技巧
bash
# 显示BPF字节码
sudo bpftrace -d -e 'tracepoint:syscalls:sys_enter_open { printf("Open\n"); }'

# 显示详细执行信息
sudo bpftrace -v -e 'tracepoint:syscalls:sys_enter_open { printf("Open\n"); }'

# 使用bpftool检查加载的程序
sudo bpftool prog list
sudo bpftool prog dump xlated id <prog_id>

# 检查验证器错误
sudo dmesg | grep -i bpf
sudo dmesg | tail -20
🎯 快速参考表
类别	常用探针	示例用途
系统调用	tracepoint:syscalls:sys_enter_*	跟踪所有系统调用
系统调用	tracepoint:syscalls:sys_exit_*	跟踪系统调用返回
调度	tracepoint:sched:sched_switch	进程上下文切换
调度	tracepoint:sched:sched_wakeup	进程唤醒
内存	tracepoint:kmem:mm_page_alloc	页面分配
内存	kprobe:__kmalloc	内核内存分配
磁盘	tracepoint:block:block_rq_issue	磁盘I/O请求
网络	tracepoint:net:net_dev_queue	网络发送
网络	tracepoint:net:netif_receive_skb	网络接收
文件系统	kprobe:vfs_read	VFS读操作
文件系统	kprobe:vfs_write	VFS写操作
💎 最佳实践
从简单开始: 先测试单个探针，再逐渐增加复杂性

使用过滤器: 减少事件数量，降低开销

聚合数据: 在eBPF程序内聚合，减少用户空间传输

设置超时: 使用timeout命令限制运行时间

监控开销: 注意eBPF程序对系统性能的影响

错误处理: 检查返回值，处理错误情况

清理资源: 确保程序退出时清理所有映射

🔗 相关资源
bpftrace官方指南

BPF和XDP参考指南

Linux内核跟踪文档

BCC工具包

eBPF.io - eBPF官方网站