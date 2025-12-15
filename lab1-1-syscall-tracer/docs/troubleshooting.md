实验1.1 故障排除指南
🚨 快速问题诊断
问题1：strace命令未找到
症状：

bash
strace: command not found
解决方案：

bash
# Ubuntu/Debian
sudo apt update && sudo apt install strace

# CentOS/RHEL
sudo yum install strace

# Arch Linux
sudo pacman -S strace

# 验证安装
strace --version
问题2：权限不足
症状：

bash
strace: ptrace(PTRACE_TRACEME, ...): Operation not permitted
解决方案：

bash
# 使用sudo权限
sudo strace ls

# 或者将用户添加到调试组
sudo usermod -a -G debug $USER
# 需要重新登录生效
问题3：进程无法附加
症状：

bash
strace: attach: ptrace(PTRACE_ATTACH, ...): No such process
解决方案：

bash
# 确认进程存在
ps aux | grep <进程名>

# 使用正确的PID
strace -p <正确的PID>

# 检查进程状态
cat /proc/<PID>/status
🔧 工具特定问题
Python工具问题
问题：Python依赖缺失

bash
ModuleNotFoundError: No module named 'matplotlib'
解决方案：

bash
# 安装所有依赖
pip install matplotlib seaborn pandas numpy

# 或者使用系统包管理器
sudo apt install python3-matplotlib python3-seaborn python3-pandas

# 创建虚拟环境（推荐）
python3 -m venv syscall-env
source syscall-env/bin/activate
pip install -r requirements.txt
问题：编码错误

bash
UnicodeDecodeError: 'utf-8' codec can't decode byte...
解决方案：

bash
# 使用错误处理选项
python3 src/syscall_tracer.py -f trace.log --encoding latin1

# 或者清理追踪文件
iconv -f ISO-8859-1 -t UTF-8 trace.log > trace_utf8.log
监控脚本问题
问题：颜色显示异常

bash
# 终端不支持颜色
echo -e "\033[31mTest\033[0m"
解决方案：

bash
# 检查终端支持
echo $TERM

# 强制启用颜色
TERM=xterm-256color ./src/syscall_monitor.sh -n firefox

# 或者禁用颜色
sed -i 's/\\033\[[0-9;]*m//g' src/syscall_monitor.sh
问题：进程名匹配多个PID

bash
找到多个匹配的PID: 1234, 5678
解决方案：

bash
# 指定具体PID
./src/syscall_monitor.sh -p 1234

# 或者使用进程全名
./src/syscall_monitor.sh -n '/usr/bin/firefox'

# 选择第一个匹配的进程
./src/syscall_monitor.sh -n firefox --first
📊 数据分析问题
追踪文件解析错误
问题：空的追踪文件

bash
解析完成: 共处理 0 行
原因和解决方案：

bash
# 1. 程序执行太快
strace -o trace.log sleep 1

# 2. 输出被缓冲
strace -ff -o trace.log command  # 跟踪子进程

# 3. 权限问题
sudo strace -o trace.log command
问题：无效的追踪格式

bash
Error: 无法解析追踪文件格式
解决方案：

bash
# 检查文件格式
head -5 trace.log

# 使用正确的解析选项
python3 src/syscall_tracer.py -f trace.log --format raw

# 手动清理文件
grep -E '^[0-9]+:' trace.log > trace_clean.log
可视化问题
问题：图表显示空白

bash
# 没有显示窗口或图片为空
解决方案：

bash
# 1. 设置matplotlib后端
export MPLBACKEND=Agg
python3 src/syscall_tracer.py -f trace.log --visualize

# 2. 安装图形界面支持
sudo apt install python3-tk

# 3. 保存到文件查看
python3 src/syscall_tracer.py -f trace.log --visualize --output plot.png
问题：中文显示乱码

bash
# 图表中的中文显示为方块
解决方案：

bash
# 安装中文字体
sudo apt install fonts-wqy-microhei

# 或者在代码中设置字体
plt.rcParams['font.sans-serif'] = ['DejaVu Sans', 'SimHei', 'Arial']
🖥 系统环境问题
容器环境问题
问题：在Docker中ptrace受限

bash
strace: ptrace(PTRACE_TRACEME, ...): Operation not permitted
解决方案：

bash
# 运行容器时添加权限
docker run --cap-add=SYS_PTRACE --security-opt seccomp=unconfined ...

# 或者使用特权模式
docker run --privileged ...
安全策略限制
问题：SELinux阻止追踪

bash
strace: ptrace(PTRACE_ATTACH, ...): Permission denied
解决方案：

bash
# 临时禁用SELinux
sudo setenforce 0

# 或者设置SELinux策略
sudo setsebool -P allow_ptrace on

# 检查SELinux状态
sestatus
问题：AppArmor限制

bash
# 类似SELinux的权限错误
解决方案：

bash
# 检查AppArmor配置
aa-status

# 临时禁用配置文件
sudo apparmor_parser -R /etc/apparmor.d/usr.bin.strace

# 重新加载
sudo apparmor_parser -r /etc/apparmor.d/usr.bin.strace
🔍 性能问题
高系统负载
问题：strace导致程序变慢

bash
# 被追踪程序运行异常缓慢
解决方案：

bash
# 1. 使用过滤选项
strace -e trace=open,read,write command

# 2. 减少输出详细信息
strace -qq command  # 静默模式

# 3. 使用统计模式
strace -c command   # 只显示统计信息
问题：大量输出导致磁盘满

bash
# 追踪文件过大
解决方案：

bash
# 1. 限制输出大小
strace -o trace.log -s 100 command  # 限制字符串长度

# 2. 使用旋转日志
strace -o trace.log -ff -s 100 command

# 3. 实时分析，不保存文件
python3 src/syscall_tracer.py command --no-save
🧪 测试相关问题
测试脚本失败
问题：测试环境不完整

bash
./tests/test_basic.sh: line X: command not found
解决方案：

bash
# 安装测试依赖
sudo apt install bc time  # 常用的测试工具

# 设置执行权限
chmod +x tests/*.sh src/*.py src/*.sh

# 检查路径
echo $PATH
问题：测试超时

bash
Test timeout after 30 seconds
解决方案：

bash
# 增加超时时间
./tests/test_basic.sh --timeout 60

# 或者跳过耗时测试
./tests/test_basic.sh --skip slow_tests
📝 常见错误模式
初学者常见错误
错误：错误的命令顺序

bash
# 错误做法
strace ls -o trace.log  # -o 被传递给ls而不是strace

# 正确做法
strace -o trace.log ls
错误：忽略返回值检查

bash
# 总是检查strace返回值
if ! strace -o trace.log command; then
    echo "追踪失败"
    exit 1
fi
脚本使用错误
错误：参数顺序错误

bash
# 错误
python3 src/syscall_tracer.py --visualize -f trace.log

# 正确
python3 src/syscall_tracer.py -f trace.log --visualize
错误：文件路径问题

bash
# 使用相对路径
python3 src/syscall_tracer.py -f ../traces/mytrace.log

# 或者绝对路径
python3 src/syscall_tracer.py -f /home/user/traces/mytrace.log
🛠 调试技巧
基础调试
启用详细输出：

bash
# 显示详细执行信息
python3 src/syscall_tracer.py -v ls
./src/syscall_monitor.sh -v -n firefox

# 调试模式
export DEBUG=1
./tests/test_basic.sh
检查系统状态：

bash
# 检查可用资源
free -h
df -h /tmp

# 检查进程限制
ulimit -a

# 检查系统日志
sudo dmesg | tail -20
journalctl -xe --since "5 minutes ago"
高级调试
使用gdb调试strace：

bash
# 调试有问题的strace会话
gdb --args strace -o trace.log problematic_command

# 在gdb中运行
run
bt  # 查看堆栈跟踪
分析核心转储：

bash
# 启用核心转储
ulimit -c unlimited

# 分析转储文件
gdb strace core
bt full
📞 获取帮助
自助诊断
收集诊断信息：

bash
# 运行诊断脚本
./tools/diagnostics.sh

# 收集系统信息
./tools/system_info.sh > system_info.txt
检查工具版本：

bash
# 检查所有工具版本
strace --version
python3 --version
bash --version
uname -a
寻求外部帮助
当需要寻求帮助时，请提供以下信息：

系统信息：

bash
cat /etc/os-release
uname -a
错误信息：

bash
# 完整的错误输出
python3 src/syscall_tracer.py ls 2>&1 | tee error.log
环境信息：

bash
echo "Python path: $(which python3)"
echo "Strace path: $(which strace)"
echo "User: $USER"
已尝试的解决方案

✅ 健康检查
运行健康检查脚本验证环境：

bash
# 运行完整健康检查
./tools/health_check.sh

# 或者分步检查
./tools/check_dependencies.sh
./tools/check_permissions.sh
./tools/check_environment.sh
如果所有检查都通过，但问题仍然存在，请考虑：

查看项目Issue页面

在相关技术论坛提问

联系课程指导教师