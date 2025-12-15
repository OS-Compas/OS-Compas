实验1.1：系统调用追踪与可视化分析
📖 实验简介
本实验是《OS多维度教学与实践体系》中维度一：观察与应用的第一个实验，旨在通过实际操作让学生直观理解应用程序如何通过系统调用与操作系统内核交互。通过使用专业的追踪工具和可视化分析，学生将深入观察系统调用的执行过程和行为特征。

🎯 实验目标
理解系统调用机制：掌握用户态与内核态的交互原理

熟练使用strace工具：学会追踪和分析程序系统调用

掌握可视化分析方法：将原始追踪数据转化为直观的图表

培养系统思维：通过观察理解操作系统的工作机制

🛠 环境要求
基础环境
Linux操作系统 (Ubuntu 20.04+ / CentOS 8+ 推荐)

Python 3.6+

Bash shell

依赖工具
bash
# 安装系统工具
sudo apt update
sudo apt install strace build-essential

# 安装Python依赖
pip install matplotlib seaborn pandas
或使用我们提供的一键安装脚本：

bash
chmod +x tools/install_dependencies.sh
./tools/install_dependencies.sh
📁 项目结构
text
lab1-1-syscall-tracer/
├── src/                    # 源代码目录
│   ├── syscall_tracer.py     # 主分析工具
│   ├── trace_visualizer.py   # 可视化工具
│   └── syscall_monitor.sh    # 实时监控脚本
├── docs/                   # 文档目录
│   ├── theory.md            # 系统调用理论基础
│   └── troubleshooting.md   # 故障排除指南
├── examples/               # 示例文件
│   ├── example_programs/    # 测试程序源码
│   └── sample_traces/       # 示例追踪结果
├── tests/                  # 测试套件
│   ├── test_basic.sh        # 基础功能测试
│   ├── test_advanced.sh     # 高级功能测试
│   └── test_visualization.sh # 可视化测试
└── tools/                  # 工具脚本
    └── install_dependencies.sh # 环境配置脚本
🚀 快速开始
方法一：使用集成工具（推荐）
bash
# 1. 追踪ls命令并生成分析报告
python3 src/syscall_tracer.py ls -d 5 --visualize

# 2. 实时监控Firefox的系统调用
./src/syscall_monitor.sh -n firefox -t 30 -s

# 3. 分析已有的追踪文件
python3 src/syscall_tracer.py -f examples/sample_traces/ls_trace.log --visualize
方法二：手动执行实验步骤
bash
# 步骤1: 安装strace
sudo apt install strace

# 步骤2: 追踪ls命令
strace ls

# 步骤3: 保存追踪结果
strace -o my_trace.log ls

# 步骤4: 统计分析
cat my_trace.log | grep -oP '^[a-z_]+' | sort | uniq -c | sort -nr

# 步骤5: 使用我们的工具进行高级分析
python3 src/syscall_tracer.py -f my_trace.log
🔧 工具详解
1. 主分析工具 (syscall_tracer.py)
功能特性：

支持实时追踪和文件分析

自动分类统计系统调用

错误率和耗时分析

多种输出格式（文本/JSON）

使用示例：

bash
# 追踪新程序
python3 src/syscall_tracer.py ls -l /usr/bin -d 10

# 分析现有文件
python3 src/syscall_tracer.py -f trace.log --report json

# 生成可视化报告
python3 src/syscall_tracer.py -f trace.log --visualize
2. 实时监控工具 (syscall_monitor.sh)
功能特性：

彩色高亮显示不同类型的系统调用

进程名和PID监控

实时统计摘要

调用过滤功能

使用示例：

bash
# 监控Firefox进程
./src/syscall_monitor.sh -n firefox -t 60 -s

# 监控特定PID，只显示文件操作
./src/syscall_monitor.sh -p 1234 -f open,read,write

# 保存监控结果
./src/syscall_monitor.sh -n bash -o bash_trace.log -s
3. 可视化工具 (trace_visualizer.py)
生成的图表：

最频繁系统调用柱状图

系统调用分类饼图

错误统计图表

耗时分析图表

📊 实验内容
基础实验
系统调用观察：追踪简单命令（ls, pwd, echo）

调用模式分析：识别不同程序的调用特征

错误处理观察：分析系统调用失败的情况

进阶实验
图形程序分析：比较CLI和GUI程序的调用差异

网络操作追踪：分析网络应用的系统调用模式

性能分析：识别耗时最长的系统调用

🤔 思考问题
通过本实验，请思考以下问题：

ls命令执行过程中，哪个系统调用被使用的次数最多？为什么？

如果追踪一个图形界面程序（如firefox），输出会有什么不同？这说明了什么？

系统调用错误通常由什么原因引起？如何从追踪结果中识别？

不同类别的程序（计算密集型 vs I/O密集型）在系统调用模式上有何区别？

🧪 测试验证
运行测试套件确保所有功能正常：

bash
# 运行基础测试
./tests/test_basic.sh

# 运行高级功能测试
./tests/test_advanced.sh

# 运行可视化测试
./tests/test_visualization.sh
🐛 故障排除
常见问题请参考 docs/troubleshooting.md，或：

strace命令未找到：运行安装脚本或手动安装

权限不足：使用sudo执行监控命令

Python依赖缺失：运行pip安装所需包

进程不存在：确认目标进程正在运行

📈 预期学习成果
完成本实验后，学生将能够：

✅ 理解系统调用在操作系统中的核心作用

✅ 熟练使用strace进行系统调用分析

✅ 解读复杂的系统调用追踪结果

✅ 使用可视化工具分析调用模式

✅ 诊断程序与操作系统交互的问题

🔗 扩展挑战
比较分析：编写脚本比较cp命令在复制大文件和小文件时的系统调用差异

性能优化：基于系统调用分析结果提出程序优化建议

安全分析：通过系统调用模式识别可疑程序行为

自定义工具：扩展现有工具支持新的分析功能

📚 参考资料
Linux strace 手册页

系统调用参考

Linux编程接口

🆘 获取帮助
如果遇到问题：

查看 docs/troubleshooting.md

检查测试用例 tests/

查阅示例文件 examples/

在项目Issue中提问

