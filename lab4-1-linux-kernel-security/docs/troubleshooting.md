```markdown
# 故障排除指南

## 目录

1. [编译相关问题](#1-编译相关问题)
2. [启动相关问题](#2-启动相关问题)
3. [SELinux相关问题](#3-selinux相关问题)
4. [KASAN相关问题](#4-kasan相关问题)
5. [性能问题](#5-性能问题)
6. [通用问题](#6-通用问题)
7. [紧急恢复](#7-紧急恢复)

## 1. 编译相关问题

### 问题1.1：缺少头文件或依赖

**症状**：
fatal error: linux/module.h: No such file or directory
make[1]: *** No rule to make target 'modules'. Stop.

text

**原因**：缺少内核头文件或开发工具链。

**解决方案**：

```bash
# 安装内核头文件
sudo apt install linux-headers-$(uname -r)

# 安装完整开发工具链
sudo apt install build-essential

# 对于内核编译，还需要：
sudo apt install libncurses-dev libssl-dev bc flex bison libelf-dev dwarves
问题1.2：内核配置错误
症状：

text
.config:1234:warning: override: reassigning to symbol CONFIG_XXX
.config:5678:warning: override: reassigning to symbol CONFIG_YYY
原因：配置文件中有冲突或过时的选项。

解决方案：

bash
# 清理配置
make mrproper

# 使用当前内核配置作为基础
cp /boot/config-$(uname -r) .config
make olddefconfig

# 或者使用默认配置
make defconfig
问题1.3：编译过程中内存不足
症状：

text
Killed process 12345 (cc1)
dmesg显示: Out of memory: Kill process ...
原因：系统内存不足，OOM killer终止了编译进程。

解决方案：

bash
# 增加交换空间
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 验证交换空间
free -h

# 减少编译并发数
# 编辑编译脚本，将 make -j$(nproc) 改为 make -j2 或 make -j4
问题1.4：磁盘空间不足
症状：

text
No space left on device
write error: No space left on device
原因：编译需要大量临时空间。

解决方案：

bash
# 检查磁盘使用
df -h

# 清理临时文件
make clean
sudo apt clean
sudo apt autoremove

# 清理旧内核（谨慎操作）
sudo apt purge linux-image-*旧版本*
sudo update-grub

# 使用tmpfs（如果内存足够）
# 在编译时指定临时目录
make O=/dev/shm/build
问题1.5：网络问题导致下载失败
症状：

text
wget: unable to resolve host address 'cdn.kernel.org'
Failed to download kernel source
原因：网络连接问题或镜像不可用。

解决方案：

bash
# 测试网络连接
ping -c 3 cdn.kernel.org

# 使用备用镜像
# 编辑脚本，修改下载URL
# 原始：https://cdn.kernel.org/pub/linux/kernel/...
# 备用：https://mirrors.edge.kernel.org/pub/linux/kernel/...

# 或手动下载
wget https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.15.tar.xz
tar -xf linux-5.15.tar.xz -C /usr/src/
2. 启动相关问题
问题2.1：系统无法启动新内核
症状：重启后卡在GRUB、黑屏或进入紧急模式。

解决方案：

重启到旧内核：

在GRUB菜单选择旧内核版本

按e编辑启动参数，删除可能的问题参数

检查引导日志：

bash
journalctl -xb -p err
dmesg | tail -100
常见原因和修复：

缺少initramfs：

bash
sudo update-initramfs -u -k 新内核版本
sudo update-grub
驱动缺失：

bash
# 重新配置内核，启用更多驱动
make menuconfig
# 在 Device Drivers 中启用必要驱动
文件系统错误：

bash
sudo fsck -y /dev/sda1
问题2.2：内核恐慌 (Kernel Panic)
症状：

text
Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
原因：根文件系统无法挂载。

解决方案：

bash
# 检查内核配置中的文件系统支持
# 确保启用了正确的文件系统驱动

# 检查GRUB配置中的root参数
# 在GRUB编辑模式中，确保root=参数正确

# 重新生成initramfs
sudo update-initramfs -c -k 新内核版本
问题2.3：模块无法加载
症状：

text
insmod: ERROR: could not insert module module.ko: Invalid module format
原因：模块与当前运行内核版本不匹配。

解决方案：

bash
# 检查内核版本
uname -r

# 检查模块版本
modinfo module.ko | grep vermagic

# 重新编译模块
make clean
make
3. SELinux相关问题
问题3.1：SELinux无法启用
症状：

text
SELinux:  Initializing.
SELinux:  Disabled at boot.
原因：内核启动参数或配置文件问题。

解决方案：

bash
# 检查启动参数
cat /proc/cmdline
# 确保没有 selinux=0

# 检查配置文件
cat /etc/selinux/config
# 应该包含：SELINUX=permissive 或 SELINUX=enforcing

# 检查内核配置
zcat /proc/config.gz | grep SELINUX
# 应该显示：CONFIG_SECURITY_SELINUX=y

# 重新标记文件系统
touch /.autorelabel
reboot
问题3.2：SELinux阻止正常操作
症状：正常程序无法运行，日志中显示AVC拒绝。

解决方案：

bash
# 临时设置为permissive模式
sudo setenforce 0

# 查看拒绝信息
sudo ausearch -m avc -ts recent

# 使用sealert分析
sudo sealert -a /var/log/audit/audit.log

# 生成允许规则
sudo audit2allow -a -M mypolicy
sudo semodule -i mypolicy.pp

# 或者直接允许特定操作
sudo semanage boolean --list | grep 相关布尔值
sudo setsebool -P 布尔值 on
问题3.3：审计服务不工作
症状：ausearch返回空结果，/var/log/audit/audit.log为空。

解决方案：

bash
# 检查审计服务状态
sudo systemctl status auditd

# 启动审计服务
sudo systemctl start auditd
sudo systemctl enable auditd

# 检查审计规则
sudo auditctl -l

# 添加基本规则
sudo auditctl -w /etc/passwd -p wa -k identity
sudo auditctl -a always,exit -F arch=b64 -S open -k file_access

# 检查磁盘空间
df -h /var/log
问题3.4：文件上下文错误
症状：文件的安全上下文不正确。

解决方案：

bash
# 查看文件上下文
ls -lZ /path/to/file

# 恢复默认上下文
sudo restorecon -v /path/to/file
sudo restorecon -Rv /path/to/directory

# 设置自定义上下文
sudo chcon -t httpd_sys_content_t /var/www/html/index.html
sudo semanage fcontext -a -t httpd_sys_content_t "/var/www/html(/.*)?"

# 重新标记整个文件系统
sudo fixfiles -F onboot
touch /.autorelabel
4. KASAN相关问题
问题4.1：KASAN未生效
症状：内存错误未被检测，dmesg中没有KASAN报告。

解决方案：

bash
# 验证KASAN是否编译进内核
zcat /proc/config.gz | grep CONFIG_KASAN
# 应该显示：CONFIG_KASAN=y

# 检查启动参数
cat /proc/cmdline
# 可以添加：kasan_multi_shot（允许多次错误）

# 检查dmesg中的KASAN初始化
dmesg | grep -i kasan

# 确保测试模块正确触发错误
# 检查test_mode参数是否正确设置
问题4.2：KASAN误报或漏报
症状：报告不应存在的错误，或未报告明显错误。

解决方案：

bash
# 检查KASAN模式
zcat /proc/config.gz | grep "CONFIG_KASAN_"
# Generic模式更精确但更慢

# 检查影子内存状态
# KASAN使用影子内存跟踪内存状态
# 错误的影子内存设置可能导致误报

# 更新测试代码
# 确保测试准确触发目标错误类型
问题4.3：KASAN导致系统崩溃
症状：加载测试模块后系统死机或重启。

解决方案：

bash
# 使用panic_on_error=0参数
sudo insmod kasan_module.ko panic_on_error=0

# 减少测试强度
sudo insmod kasan_module.ko test_mode=0 iterations=1

# 检查系统日志
journalctl -xb

# 如果系统崩溃，重启后检查：
dmesg | tail -50
5. 性能问题
问题5.1：系统响应缓慢
症状：启用安全特性后系统明显变慢。

解决方案：

bash
# 检查系统负载
top
htop

# 识别性能瓶颈
sudo perf top

# 调整安全特性
# KASAN会显著影响性能，仅用于测试
# SELinux影响较小，可保持启用

# 考虑禁用部分调试特性
# 如：CONFIG_DEBUG_INFO, CONFIG_PROVE_LOCKING
问题5.2：内存使用过高
症状：系统内存不足，频繁使用交换空间。

解决方案：

bash
# 检查内存使用
free -h

# KASAN会加倍内存使用
# 考虑在测试后禁用KASAN

# 调整虚拟内存参数
sudo sysctl -w vm.swappiness=10
sudo sysctl -w vm.vfs_cache_pressure=50
问题5.3：编译时间过长
症状：内核编译耗时数小时。

解决方案：

bash
# 增加并发编译数（如果CPU核心多）
make -j$(nproc)

# 使用ccache加速后续编译
sudo apt install ccache
export CC="ccache gcc"
export CXX="ccache g++"

# 选择较小的内核配置
# 禁用不需要的驱动和特性
6. 通用问题
问题6.1：权限问题
症状：Permission denied 错误。

解决方案：

bash
# 确保使用sudo执行需要特权的操作
sudo command

# 检查当前用户权限
id
groups

# 检查文件权限
ls -l /path/to/file

# 检查SELinux上下文（如果启用）
ls -lZ /path/to/file
问题6.2：命令找不到
症状：command not found 错误。

解决方案：

bash
# 检查命令是否存在
which command

# 更新PATH环境变量
export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin

# 安装缺少的软件包
sudo apt install package-name

# 检查软件包名称
apt search keyword
问题6.3：版本不兼容
症状：软件版本不匹配导致错误。

解决方案：

bash
# 检查版本
gcc --version
make --version
uname -r

# 安装特定版本
sudo apt install gcc-10 g++-10

# 使用版本管理
update-alternatives --config gcc
问题6.4：日志文件过大
症状：日志文件占用大量磁盘空间。

解决方案：

bash
# 检查日志文件大小
sudo du -sh /var/log/*

# 清理旧日志
sudo journalctl --vacuum-time=7d
sudo rm -f /var/log/*.log.*

# 配置日志轮转
sudo vim /etc/logrotate.conf
7. 紧急恢复
情况7.1：系统完全无法启动
恢复步骤：

使用Live USB/CD启动

挂载原系统分区

bash
sudo mount /dev/sda1 /mnt
sudo mount /dev/sda2 /mnt/boot  # 如果有单独boot分区
修复GRUB

bash
sudo chroot /mnt
grub-install /dev/sda
update-grub
exit
恢复内核配置

bash
# 从备份恢复内核
cp /mnt/boot/vmlinuz-旧版本 /mnt/boot/vmlinuz
cp /mnt/boot/initrd.img-旧版本 /mnt/boot/initrd.img
情况7.2：SELinux导致系统不可用
恢复步骤：

在GRUB中临时禁用SELinux

在启动时按e编辑GRUB条目

在linux行末尾添加 selinux=0

按Ctrl+X启动

永久禁用SELinux

bash
sudo setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
修复文件上下文

bash
touch /.autorelabel
reboot
情况7.3：编译环境损坏
恢复步骤：

清理编译环境

bash
make mrproper
make clean
重新安装工具链

bash
sudo apt purge build-essential linux-headers-*
sudo apt autoremove
sudo apt install build-essential linux-headers-$(uname -r)
从干净源码重新开始

bash
rm -rf linux-*
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.tar.xz
tar -xf linux-5.15.tar.xz
预防措施
定期备份
bash
# 备份重要配置文件
sudo cp /etc/selinux/config /etc/selinux/config.backup
sudo cp /boot/grub/grub.cfg /boot/grub/grub.cfg.backup

# 备份内核配置
cp .config config.backup

# 使用版本控制
git add .
git commit -m "Backup before changes"
测试环境
始终在虚拟机或测试机上实验

使用快照功能保存状态

准备系统恢复镜像

逐步验证
bash
# 每一步都验证
make olddefconfig
make -j4  # 先编译一部分测试
make modules  # 测试模块编译
make install  # 先不重启，检查安装文件
监控系统
bash
# 监控资源使用
watch -n 1 'free -h; df -h /'

# 监控编译进度
tail -f compile.log

# 监控系统日志
journalctl -f
获取帮助
在线资源
官方文档：

Kernel Documentation

SELinux Wiki

KASAN Documentation

社区支持：

Stack Overflow

Unix & Linux Stack Exchange

Kernel Newbies

邮件列表：

Linux Kernel Mailing List

SELinux Mailing List

诊断工具
bash
# 系统信息收集
sudo dmesg > dmesg.log
sudo journalctl -xb > journal.log
uname -a > system_info.txt
lsmod > modules.txt

# 性能分析
sudo perf record -g -- sleep 10
sudo perf report

# 内存分析
sudo slabtop
sudo cat /proc/meminfo
故障排除流程
text
遇到问题 → 检查症状 → 查看日志 → 搜索已知解决方案
    ↓          ↓          ↓            ↓
    ├──────────┴──────────┘            │
    │       分析根本原因               │
    ↓                                   ↓
制定解决方案 ←─── 参考文档和社区 ──── 实施解决方案
    ↓
验证解决效果
    ↓
记录问题和解决方案