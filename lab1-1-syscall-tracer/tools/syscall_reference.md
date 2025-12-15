系统调用参考手册

概述

本参考手册为实验1.1：系统调用追踪与可视化分析提供完整的系统调用参考资料，涵盖Linux系统中最常用的系统调用及其使用模式。

系统调用分类

1. 进程控制

#### fork
```c
pid_t fork(void);
功能: 创建子进程
返回值: 子进程返回0，父进程返回子进程PID，错误返回-1
追踪特征: 在strace中显示进程复制，子进程继承父进程的系统调用序列

execve
c
int execve(const char *pathname, char *const argv[], char *const envp[]);
功能: 执行新程序
参数:

pathname: 程序路径

argv: 参数数组

envp: 环境变量数组
追踪特征: 程序替换，后续系统调用属于新程序

exit
c
void _exit(int status);
功能: 终止进程
参数: status: 退出状态
追踪特征: 进程结束，通常与wait系列调用配合

waitpid
c
pid_t waitpid(pid_t pid, int *wstatus, int options);
功能: 等待子进程状态改变
追踪特征: 父进程阻塞等待子进程结束

2. 文件操作
open / openat
c
int open(const char *pathname, int flags, mode_t mode);
int openat(int dirfd, const char *pathname, int flags, mode_t mode);
常用flags:

O_RDONLY: 只读

O_WRONLY: 只写

O_RDWR: 读写

O_CREAT: 文件不存在时创建

O_TRUNC: 截断文件

O_APPEND: 追加模式

追踪特征: 文件描述符分配，后续read/write操作的基础

read
c
ssize_t read(int fd, void *buf, size_t count);
功能: 从文件描述符读取数据
返回值: 成功返回读取字节数，0表示EOF，-1表示错误
追踪特征: 数据读取操作，可能多次调用直到读取完成

write
c
ssize_t write(int fd, const void *buf, size_t count);
功能: 向文件描述符写入数据
追踪特征: 数据写入操作，可能多次调用

close
c
int close(int fd);
功能: 关闭文件描述符
追踪特征: 资源释放，文件描述符回收

stat / fstat
c
int stat(const char *pathname, struct stat *statbuf);
int fstat(int fd, struct stat *statbuf);
功能: 获取文件状态信息
stat结构重要字段:

st_mode: 文件类型和权限

st_size: 文件大小

st_uid: 用户ID

st_gid: 组ID

st_mtime: 修改时间

追踪特征: 文件元数据查询，ls命令大量使用

3. 内存管理
brk / sbrk
c
int brk(void *addr);
void *sbrk(intptr_t increment);
功能: 调整程序数据段结束位置
追踪特征: 堆内存管理，malloc/free的底层实现

mmap / munmap
c
void *mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);
int munmap(void *addr, size_t length);
常用flags:

MAP_SHARED: 共享映射

MAP_PRIVATE: 私有映射

MAP_ANONYMOUS: 匿名映射

追踪特征: 大内存分配，文件内存映射

4. 网络通信
socket
c
int socket(int domain, int type, int protocol);
常用参数:

domain: AF_INET(IPv4), AF_INET6(IPv6), AF_UNIX(本地)

type: SOCK_STREAM(TCP), SOCK_DGRAM(UDP)

protocol: 通常为0

追踪特征: 网络通信起点

bind
c
int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
功能: 绑定socket到地址
追踪特征: 服务器端设置监听地址

listen
c
int listen(int sockfd, int backlog);
功能: 监听连接请求
追踪特征: TCP服务器准备接受连接

accept
c
int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
功能: 接受连接
追踪特征: TCP服务器接受客户端连接

connect
c
int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
功能: 建立连接
追踪特征: TCP客户端连接服务器

send / recv
c
ssize_t send(int sockfd, const void *buf, size_t len, int flags);
ssize_t recv(int sockfd, void *buf, size_t len, int flags);
功能: TCP数据发送/接收
追踪特征: 面向连接的数据传输

sendto / recvfrom
c
ssize_t sendto(int sockfd, const void *buf, size_t len, int flags,
               const struct sockaddr *dest_addr, socklen_t addrlen);
ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags,
                 struct sockaddr *src_addr, socklen_t *addrlen);
功能: UDP数据发送/接收
追踪特征: 无连接的数据传输

5. 目录操作
mkdir
c
int mkdir(const char *pathname, mode_t mode);
功能: 创建目录
追踪特征: 目录创建操作

opendir / readdir / closedir
c
DIR *opendir(const char *name);
struct dirent *readdir(DIR *dirp);
int closedir(DIR *dirp);
功能: 目录流操作
追踪特征: 目录遍历，ls命令核心操作

getdents
c
int getdents(unsigned int fd, struct linux_dirent *dirp, unsigned int count);
功能: 读取目录条目（系统调用层面）
追踪特征: readdir的底层实现

6. 信号处理
kill
c
int kill(pid_t pid, int sig);
功能: 向进程发送信号
常用信号:

SIGTERM: 终止信号

SIGKILL: 强制终止

SIGSTOP: 停止进程

signal / sigaction
c
void (*signal(int sig, void (*handler)(int)))(int);
int sigaction(int sig, const struct sigaction *act, struct sigaction *oldact);
功能: 信号处理设置
追踪特征: 信号处理器注册

7. 时间相关
time / gettimeofday
c
time_t time(time_t *tloc);
int gettimeofday(struct timeval *tv, struct timezone *tz);
功能: 获取时间
追踪特征: 时间查询操作

nanosleep
c
int nanosleep(const struct timespec *req, struct timespec *rem);
功能: 高精度睡眠
追踪特征: 进程暂停执行

常见程序系统调用模式
命令行工具模式
ls命令典型序列
text
execve()      # 程序加载
brk()         # 内存管理
access()      # 文件检查
openat()      # 打开目录
getdents64()  # 读取目录内容
stat()        # 获取文件信息（每个文件）
write()       # 输出结果
close()       # 清理资源
cp命令典型序列
text
open()        # 打开源文件
open()        # 创建目标文件
read()        # 读取数据块
write()       # 写入数据块
（重复read/write直到文件结束）
close()       # 关闭文件
网络服务器模式
TCP服务器典型序列
text
socket()      # 创建socket
bind()        # 绑定地址
listen()      # 开始监听
accept()      # 接受连接（阻塞）
fork()        # 创建子进程处理（可选）
read()/write()# 数据交换
close()       # 关闭连接
TCP客户端典型序列
text
socket()      # 创建socket  
connect()     # 连接服务器
write()       # 发送请求
read()        # 接收响应
close()       # 关闭连接
动态内存程序模式
内存密集型程序
text
brk()         # 小内存分配
mmap()        # 大内存分配
munmap()      # 释放映射内存
mprotect()    # 内存保护设置
错误处理模式
常见错误返回值
错误码	含义	常见场景
ENOENT	文件不存在	open不存在的文件
EACCES	权限不足	访问受限文件
EEXIST	文件已存在	创建已存在文件
EINTR	系统调用被中断	信号处理
EAGAIN	资源暂时不可用	非阻塞I/O
ECONNREFUSED	连接被拒绝	连接无服务端口
错误处理示例
c
int fd = open("file.txt", O_RDONLY);
if (fd == -1) {
    // 检查具体错误
    if (errno == ENOENT) {
        printf("文件不存在\n");
    } else if (errno == EACCES) {
        printf("权限不足\n");
    }
}
性能分析要点
高频系统调用识别
文件操作: 频繁的open/close可能表明文件打开策略需要优化

内存操作: 大量的brk调用可能表明内存分配碎片化

上下文切换: 频繁的read/write小数据可能表明缓冲区大小不合适

耗时系统调用
统计方法: 使用strace -T显示每个系统调用的耗时

优化重点: 关注执行时间长的系统调用

常见瓶颈: 磁盘I/O、网络延迟、进程创建

strace 使用技巧
基本追踪
bash
strace ls                  # 追踪简单命令
strace -o trace.log ls     # 输出到文件
strace -f command         # 追踪子进程
过滤和统计
bash
strace -e trace=open,read,write ls    # 只追踪特定调用
strace -c ls                          # 统计模式
strace -p PID                         # 追踪运行中进程
详细输出
bash
strace -tt ls             # 微秒级时间戳
strace -T ls              # 显示调用耗时
strace -v ls              # 显示完整环境信息
系统调用与库函数关系
封装关系
text
库函数        → 系统调用
----------    → ----------
fopen()       → open()
fread()       → read() 
fwrite()      → write()
fclose()      → close()
malloc()      → brk()/mmap()
free()        → brk()/munmap()
缓冲区影响
库函数通常有缓冲区，减少系统调用次数

直接系统调用更底层，控制更精确

strace显示的是实际发生的系统调用

实验1.1 相关分析
文件操作分析要点
打开模式: 注意O_CREAT、O_TRUNC、O_APPEND的使用

读写模式: 顺序读写 vs 随机访问

错误处理: 如何处理文件不存在、权限问题

网络操作分析要点
协议选择: TCP vs UDP 调用模式差异

连接管理: 短连接 vs 长连接

错误处理: 连接失败、超时处理

内存操作分析要点
分配策略: brk vs mmap 的使用场景

释放模式: 及时释放 vs 延迟释放

碎片问题: 大量小分配的影响

扩展资源
官方文档
Linux man-pages

Linux System Call Reference

调试工具
strace: 系统调用追踪

ltrace: 库调用追踪

perf: 性能分析

gdb: 调试器

学习资源
《Linux/Unix系统编程手册》

《深入理解Linux内核》

Linux内核源码