实验1.2：进程资源监视器

## 📋 实验简介

本实验旨在通过构建进程资源监视器，深入理解Linux进程管理机制、资源监控原理以及/proc虚拟文件系统。通过实践掌握进程监控、资源分析和系统调优的核心技能。

## 🎯 实验目标

### 基础目标
- [x] 理解Linux进程管理机制
- [x] 掌握/proc文件系统的结构与访问方法
- [x] 实现进程资源监控功能
- [x] 学习进程间通信和资源调度原理

### 进阶目标
- [ ] 实现进程树可视化显示
- [ ] 开发进程生命周期管理功能
- [ ] 构建资源使用趋势分析
- [ ] 创建系统性能告警机制

## 🛠 环境要求

### 系统要求
- **操作系统**: Linux内核2.6及以上
- **Shell**: Bash 4.0+
- **Python**: 3.6+ (可选，用于Python版本)

### 依赖工具
```bash
# 必需工具
ps, top, pgrep, bc, awk, grep

# Python版本额外依赖
pip install psutil
环境配置
bash
# 运行自动配置脚本
cd tools/
./install_dependencies.sh
📁 项目结构详解
text
lab1-2-process-monitor/
├── src/                          # 源代码目录
│   ├── process_monitor.sh        # Bash主监视器(核心)：使用Bash脚本实现进程监控，依赖/proc文件系统
│   ├── process_monitor.py        # Python版本监视器：使用psutil库实现跨平台进程监控
│   ├── process_manager.py        # 进阶进程管理器：提供进程树显示、进程终止等高级功能
│   └── proc_analyzer.py          # /proc深度分析工具：解析/proc文件系统，提供详细进程信息
├── docs/                         # 文档目录
│   ├── theory.md                 # 进程理论基础：Linux进程管理、调度、/proc文件系统详解
│   └── troubleshooting.md        # 故障排除指南：常见问题及解决方案
├── examples/                     # 示例和测试
│   ├── sample_scripts/           # 测试程序源码
│   │   ├── cpu_intensive.c       # CPU密集型测试程序：用于生成高CPU负载
│   │   ├── memory_intensive.c    # 内存密集型测试程序：用于测试内存监控
│   │   └── process_tree.c        # 进程树测试程序：创建多个进程以形成进程树
│   └── sample_output/            # 预期输出示例
│       ├── proc_analysis.txt     # /proc分析示例输出
│       └── monitor_screenshot.txt # 监控输出截图
├── tests/                        # 测试套件
│   ├── test_basic.sh             # 基础功能测试：测试进程监控基本功能
│   ├── test_advanced.sh          # 高级功能测试：测试进程树、资源监控等高级功能
│   └── test_proc_fs.sh           # /proc文件系统测试：测试/proc分析功能
└── tools/                        # 实用工具脚本
    ├── install_dependencies.sh   # 环境配置脚本：安装所需依赖包
    └── performance_test.sh       # 性能测试脚本：测试监控工具的性能影响
🚀 快速开始
方法一：使用Bash版本(推荐)
bash
# 1. 赋予执行权限
chmod +x src/process_monitor.sh

# 2. 监视特定进程
./src/process_monitor.sh -p 1234

# 3. 按名称监视进程
./src/process_monitor.sh -n firefox -i 5

# 4. 查看CPU使用TOP 10
./src/process_monitor.sh --cpu-top
方法二：使用Python版本
bash
# 1. 安装Python依赖
pip install psutil

# 2. 运行Python监视器
python3 src/process_monitor.py -p 1234

# 3. 显示进程树
python3 src/process_monitor.py --tree
📖 详细使用指南
1. 基本进程监视
监视指定PID
bash
./src/process_monitor.sh -p 1234 -i 2 -c 10
输出示例:

text
开始监视进程 PID: 1234
更新间隔: 2秒
==========================================
时间                 | PID     | CPU使用率%   | VmSize(KB)   | VmRSS(KB)    
------------------------------------------------------------
2024-01-15 10:30:01 | 1234    | 2.50         | 245768       | 123456
2024-01-15 10:30:03 | 1234    | 1.80         | 245768       | 123458
监视进程名称
bash
./src/process_monitor.sh -n "chromium" -i 3
2. 系统资源分析
CPU使用率排行
bash
./src/process_monitor.sh --cpu-top
输出示例:

text
CPU使用率最高的10个进程:
==========================================
USER     PID     %CPU   %MEM  VSZ         COMMAND
user1    4567    45.2   12.3  245768      /usr/bin/chromium
user1    1234    23.1   8.5   123456      /usr/lib/firefox
内存使用率排行
bash
./src/process_monitor.sh --mem-top
3. 进程树分析
bash
./src/process_monitor.sh --tree
./src/process_monitor.sh --tree -p 1    # 从init进程开始
4. /proc文件系统分析
bash
./src/process_monitor.sh --analyze-proc
输出示例:

text
/proc 文件系统分析
==========================================
1. /proc 目录主要内容:
总用量 0
dr-xr-xr-x  9 root root 0 1月 15 10:30 .
dr-xr-xr-x 19 root root 0 1月 15 10:30 ..

2. 系统信息文件:
   /proc/version: 存在
   /proc/uptime: 存在

3. 进程数量统计:
   当前进程数: 245
5. 系统概要监视
bash
./src/process_monitor.sh --monitor-all -i 10
🔧 进阶功能
进程管理器(交互模式)
bash
python3 src/process_manager.py

pm> help
命令:
  list     - 显示进程列表
  tree     - 显示进程树  
  find     - 查找进程
  kill     - 终止进程
  monitor  - 监视进程
  quit     - 退出
/proc深度分析
bash
python3 src/proc_analyzer.py --pid 1234 --detail
🧪 实验任务
任务1：基础进程监视
使用process_monitor.sh监视一个运行中的进程

记录其CPU和内存使用情况变化

分析进程状态转换

任务2：/proc文件系统探索
查看/proc/self目录内容

分析进程状态文件格式

理解虚拟内存统计信息

任务3：资源使用分析
识别系统中最消耗资源的进程

分析进程资源使用模式

提出优化建议

任务4：进程树研究
绘制系统进程树结构

理解进程间父子关系

分析进程创建机制

📊 输出解读指南
关键指标说明
指标	说明	正常范围	异常处理
CPU使用率	进程占用CPU时间比例	<80%	检查是否CPU密集型任务
VmSize	虚拟内存大小	视应用而定	检查内存泄漏
VmRSS	物理内存使用	<可用内存	优化内存使用
线程数	进程线程数量	视应用而定	检查线程泄漏
性能分析要点
CPU瓶颈: 持续高CPU使用率可能表示计算密集型任务或无限循环

内存泄漏: VmRSS持续增长可能表示内存泄漏

IO等待: 高IO等待时间可能表示磁盘或网络瓶颈

上下文切换: 频繁的上下文切换可能表示进程过多或调度问题

🐛 故障排除
常见问题及解决方案
1. 权限问题
bash
# 错误: 无法访问/proc/pid目录
sudo ./src/process_monitor.sh -p 1

# 或使用当前用户进程
./src/process_monitor.sh -p $$
2. 进程不存在
bash
# 确保进程正在运行
ps aux | grep 进程名

# 使用进程名而不是完整路径
./src/process_monitor.sh -n "chrome"  # 正确
./src/process_monitor.sh -n "/opt/google/chrome/chrome"  # 可能失败
3. 工具依赖缺失
bash
# 安装bc工具(Ubuntu/Debian)
sudo apt install bc

# 安装psutil(Python)
pip install psutil
调试模式
bash
# 启用详细输出
bash -x src/process_monitor.sh -p 1234

# 检查语法
bash -n src/process_monitor.sh
🔍 深入理解
/proc文件系统关键文件
文件	内容	用途
/proc/pid/status	进程状态信息	获取进程基本信息
/proc/pid/stat	进程统计信息	CPU时间、状态等
/proc/pid/cmdline	启动命令行	查看启动参数
/proc/pid/io	IO统计	磁盘和网络IO
/proc/pid/fd	文件描述符	打开的文件和套接字
进程状态说明
R (Running): 运行中或可运行

S (Sleeping): 可中断睡眠

D (Disk Sleep): 不可中断睡眠(通常IO)

Z (Zombie): 僵尸进程

T (Stopped): 暂停状态

📈 扩展实验
扩展1：性能基准测试
bash
cd tools/
./performance_test.sh
扩展2：自定义监控脚本
参考examples/sample_scripts/中的示例，编写自己的监控脚本。

扩展3：系统调优实验
基于监控结果，尝试调整进程优先级、CPU亲和性等参数。

🤝 贡献指南
欢迎提交Issue和Pull Request来改进本项目！

开发规范
遵循现有的代码风格

添加适当的注释

更新相关文档

通过基础测试

测试要求
bash
# 运行测试套件
cd tests/
./test_basic.sh
./test_advanced.sh
📄 许可证
本项目采用MIT许可证，详见LICENSE文件。

🙏 致谢
感谢Linux内核开发者和开源社区提供的强大工具和文档支持。