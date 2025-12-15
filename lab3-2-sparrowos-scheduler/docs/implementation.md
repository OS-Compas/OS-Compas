```markdown
# 调度器实现细节

## 1. 总体架构设计

### 1.1 模块划分
调度器系统
├── 核心调度模块 (scheduler.c)
├── 进程管理模块 (pcb.h)
├── 中断处理模块 (interrupt.c)
├── 上下文切换模块 (context_switch.S)
└── 配置和统计模块

text

### 1.2 数据流设计
定时器中断 → 中断处理 → 调度器tick → 调度决策 → 上下文切换

text

## 2. 进程控制块实现

### 2.1 PCB数据结构
```c
typedef struct process_control_block {
    // 标识信息
    uint32_t pid;
    char name[32];
    
    // 状态信息
    process_state_t state;
    uint8_t priority;
    uint32_t priority_original;
    
    // 时间统计
    uint32_t time_created;
    uint32_t time_started;
    uint32_t time_used;
    uint32_t time_slice;
    uint32_t time_slice_used;
    uint32_t vruntime;
    
    // CPU上下文
    uint32_t reg_esp;
    uint32_t reg_eip;
    uint32_t reg_eax;
    uint32_t reg_ebx;
    // ... 其他寄存器
    
    // 内存信息
    uint32_t stack_base;
    uint32_t stack_size;
    
    // 链表指针
    struct process_control_block *next;
    struct process_control_block *prev;
    
    // MLFQ特定字段
    uint32_t time_in_queue;
    uint8_t demotions;
    uint8_t promotions;
} pcb_t;
2.2 PCB管理策略
静态分配: 预分配固定数量的PCB，避免动态内存分配

位图管理: 快速查找空闲PCB

缓存友好: 合理安排字段顺序，提高缓存命中率

3. 就绪队列实现
3.1 队列设计
c
typedef struct {
    pcb_t *head;
    pcb_t *tail;
    uint32_t count;
    uint32_t time_slice;  // 该队列的时间片长度
} ready_queue_t;
3.2 队列操作
入队: O(1) 时间复杂度，添加到尾部

出队: O(1) 时间复杂度，从头部移除

查找: O(n) 时间复杂度，需要遍历

移除中间节点: O(n) 时间复杂度

3.3 多级队列实现
c
typedef struct {
    ready_queue_t queues[MAX_PRIORITY_LEVELS];
    uint32_t time_slices[MAX_PRIORITY_LEVELS];
    uint32_t boost_interval;
    uint32_t last_boost_time;
} mlfq_t;
4. 上下文切换实现
4.1 汇编实现 (x86)
assembly
context_switch:
    pusha                    ; 保存通用寄存器
    pushf                    ; 保存标志寄存器
    
    ; 保存当前进程上下文
    mov 44(%esp), %eax       ; eax = current PCB
    test %eax, %eax
    jz .skip_save
    mov %esp, (%eax)         ; 保存栈指针
    ; ... 保存其他寄存器
    
.skip_save:
    ; 恢复下一个进程上下文
    mov 48(%esp), %ebx       ; ebx = next PCB
    mov (%ebx), %esp         ; 恢复栈指针
    ; ... 恢复其他寄存器
    
    popf
    popa
    ret
4.2 切换优化
惰性保存: 只保存必要的寄存器

浮点状态: 延迟保存浮点寄存器

TLB优化: 避免不必要的TLB刷新

5. 定时器中断实现
5.1 8254定时器编程
c
void timer_init(uint32_t frequency) {
    uint32_t divisor = 1193180 / frequency;
    
    // 设置8254工作模式
    outb(0x36, TIMER_CMD_PORT);  // 模式3，方波发生器
    
    // 设置计数值
    outb(divisor & 0xFF, TIMER_DATA_PORT);
    outb((divisor >> 8) & 0xFF, TIMER_DATA_PORT);
}
5.2 中断处理链
text
硬件中断 → 中断控制器 → 中断描述符表 → 中断服务例程 → 调度器
6. 调度算法实现细节
6.1 FIFO调度器
c
pcb_t* scheduler_fifo_schedule(void) {
    if (ready_queue.count == 0) {
        return NULL;
    }
    
    pcb_t* next = ready_queue.head;
    ready_queue.head = next->next;
    if (ready_queue.head) {
        ready_queue.head->prev = NULL;
    } else {
        ready_queue.tail = NULL;
    }
    ready_queue.count--;
    
    return next;
}
6.2 RR调度器
c
void scheduler_rr_schedule(void) {
    pcb_t* current = scheduler_get_current_process();
    
    if (current && current->time_slice_used >= current->time_slice) {
        // 时间片用完，重新加入队列
        current->state = PROCESS_READY;
        add_to_ready_queue(current);
        current->time_slice_used = 0;
    }
    
    // 从队列头部选择下一个进程
    pcb_t* next = scheduler_fifo_schedule();
    if (next) {
        next->state = PROCESS_RUNNING;
        next->time_started = system_ticks;
    }
}
6.3 MLFQ调度器
c
pcb_t* scheduler_mlfq_schedule(void) {
    // 从高优先级到低优先级查找
    for (int i = 0; i < MAX_PRIORITY_LEVELS; i++) {
        if (mlfq.queues[i].count > 0) {
            pcb_t* next = mlfq.queues[i].head;
            
            // 从队列移除
            mlfq.queues[i].head = next->next;
            if (mlfq.queues[i].head) {
                mlfq.queues[i].head->prev = NULL;
            } else {
                mlfq.queues[i].tail = NULL;
            }
            mlfq.queues[i].count--;
            
            // 设置时间片
            next->time_slice = mlfq.time_slices[i];
            next->time_in_queue = 0;
            
            return next;
        }
    }
    return NULL;
}
7. 性能优化技术
7.1 缓存优化
c
// 热点数据集中存储
typedef struct {
    pcb_t* current_process;      // 频繁访问
    uint32_t system_ticks;       // 频繁更新
    scheduler_stats_t stats;     // 统计信息
} scheduler_hot_data_t;
7.2 分支预测优化
c
// 使用likely/unlikely提示编译器
#define likely(x)   __builtin_expect(!!(x), 1)
#define unlikely(x) __builtin_expect(!!(x), 0)

if (likely(ready_queue.count > 0)) {
    // 常见情况
} else {
    // 少见情况
}
7.3 内存预取
c
// 预取下一个可能运行的进程
void prefetch_next_process(void) {
    if (ready_queue.head && ready_queue.head->next) {
        __builtin_prefetch(ready_queue.head->next, 0, 3);
    }
}
8. 调试和测试框架
8.1 单元测试框架
c
void test_scheduler_basic(void) {
    scheduler_config_t config = {SCHED_FIFO, 0, 1, 4, 100};
    scheduler_init(config);
    
    // 创建测试进程
    pcb_t* p1 = scheduler_create_process("Test1", 0);
    assert(p1 != NULL);
    assert(p1->state == PROCESS_READY);
    
    // 测试调度
    scheduler_schedule();
    assert(scheduler_get_current_process() == p1);
    
    printf("Basic test passed\n");
}
8.2 性能测试框架
c
void benchmark_scheduler(void) {
    struct timespec start, end;
    
    clock_gettime(CLOCK_MONOTONIC, &start);
    
    // 执行调度操作
    for (int i = 0; i < 1000000; i++) {
        scheduler_tick();
        if (i % 1000 == 0) {
            scheduler_schedule();
        }
    }
    
    clock_gettime(CLOCK_MONOTONIC, &end);
    
    double elapsed = (end.tv_sec - start.tv_sec) + 
                    (end.tv_nsec - start.tv_nsec) / 1e9;
    
    printf("Performance: %.2f operations/second\n", 
           1000000 / elapsed);
}
9. 可配置参数
9.1 调度器配置
c
typedef struct {
    scheduler_type_t type;        // 调度算法类型
    uint32_t time_quantum;        // 基本时间片长度
    uint8_t enable_preemption;    // 是否启用抢占
    uint8_t mlfq_levels;          // MLFQ队列级数
    uint32_t boost_interval;      // 优先级提升间隔
} scheduler_config_t;
9.2 运行时调整
c
void scheduler_reconfigure(scheduler_config_t new_config) {
    // 保存当前状态
    scheduler_suspend();
    
    // 应用新配置
    scheduler_config = new_config;
    
    // 重新初始化
    switch (new_config.type) {
        case SCHED_FIFO:
            scheduler_fifo_init();
            break;
        case SCHED_RR:
            scheduler_rr_init(new_config.time_quantum);
            break;
        case SCHED_MLFQ:
            scheduler_mlfq_init(new_config.mlfq_levels, 
                               new_config.boost_interval);
            break;
    }
    
    // 恢复运行
    scheduler_resume();
}
10. 扩展接口设计
10.1 插件式调度算法
c
typedef struct {
    const char* name;
    void (*init)(void* config);
    pcb_t* (*schedule)(void);
    void (*tick)(void);
    void (*cleanup)(void);
} scheduler_plugin_t;

void register_scheduler_plugin(scheduler_plugin_t* plugin) {
    // 注册新调度算法
}
10.2 统计信息接口
c
typedef struct {
    uint32_t context_switches;
    uint32_t processes_completed;
    uint32_t total_runtime;
    uint32_t avg_response_time;
    uint32_t avg_turnaround_time;
    // 详细的各算法统计
    fifo_stats_t fifo_stats;
    rr_stats_t rr_stats;
    mlfq_stats_t mlfq_stats;
} detailed_stats_t;

void scheduler_collect_stats(detailed_stats_t* stats) {
    // 收集详细统计信息
}
11. 安全考虑
11.1 输入验证
c
pcb_t* scheduler_create_process(const char* name, uint8_t priority) {
    // 验证输入参数
    if (!name || strlen(name) == 0) {
        return NULL;
    }
    
    if (priority >= MAX_PRIORITY_LEVELS) {
        priority = MAX_PRIORITY_LEVELS - 1;
    }
    
    // 继续创建进程...
}
11.2 边界检查
c
void add_to_ready_queue(pcb_t* pcb) {
    if (!pcb || pcb->state != PROCESS_READY) {
        return;
    }
    
    if (ready_queue.count >= MAX_PROCESSES) {
        // 队列已满，采取适当措施
        handle_queue_overflow();
        return;
    }
    
    // 正常入队操作...
}
12. 移植指南
12.1 平台相关代码隔离
text
src/platform/
├── x86/
│   ├── context_switch.S
│   └── interrupt.c
├── arm/
│   ├── context_switch.S
│   └── interrupt.c
└── riscv/
    ├── context_switch.S
    └── interrupt.c
12.2 抽象层设计
c
// 平台抽象接口
typedef struct {
    void (*context_switch)(pcb_t* from, pcb_t* to);
    void (*timer_init)(uint32_t frequency);
    uint32_t (*get_ticks)(void);
    void (*interrupt_enable)(void);
    void (*interrupt_disable)(void);
} platform_ops_t;

// 注册平台相关操作
void register_platform_ops(platform_ops_t* ops) {
    platform = ops;
}
13. 性能调优建议
13.1 性能分析步骤
基准测试: 建立性能基准

性能分析: 使用perf、gprof等工具

热点识别: 找到性能瓶颈

优化实现: 应用优化技术

验证测试: 确保优化有效且正确

13.2 常见优化点
调度算法选择: 根据工作负载选择合适的算法

时间片大小: 优化时间片长度平衡响应时间和吞吐量

队列管理: 优化队列操作的数据结构和算法

缓存利用: 改善数据局部性

分支预测: 优化条件判断

14. 故障排除指南
14.1 常见问题
调度死锁: 进程永远得不到调度

优先级反转: 低优先级进程阻塞高优先级进程

饥饿问题: 某些进程长期得不到CPU时间

响应时间差: 交互式体验不佳

14.2 调试工具
bash
# 启用详细日志
#define SCHEDULER_DEBUG 1

# 运行时调试
void scheduler_debug_dump(void) {
    printf("=== Scheduler Debug Info ===\n");
    printf("Current process: %s (PID: %d)\n",
           current_process ? current_process->name : "None",
           current_process ? current_process->pid : 0);
    printf("Ready queue count: %d\n", ready_queue.count);
    // 更多调试信息...
}
15. 未来扩展方向
15.1 算法扩展
实现CFS完全公平调度器

添加实时调度支持

实现能耗感知调度

15.2 功能扩展
多处理器支持

容器/虚拟机调度

动态工作负载适应

15.3 监控和管理
实时监控界面

动态配置调整

智能告警系统

text

## 第十三步：完整的Makefile

**Makefile**
```makefile
# SparrowOS Scheduler Makefile

# 配置
CC = gcc
AS = nasm
CFLAGS = -Wall -Wextra -O2 -g -I./include
ASFLAGS = -f elf32
LDFLAGS = -lm

# 目录
SRC_DIR = src
INCLUDE_DIR = include
BUILD_DIR = build
BIN_DIR = bin
TESTS_DIR = tests
EXAMPLES_DIR = examples

# 源文件
C_SOURCES = $(wildcard $(SRC_DIR)/*.c)
AS_SOURCES = $(wildcard $(SRC_DIR)/*.S)
TEST_SOURCES = $(wildcard $(TESTS_DIR)/*.c)
EXAMPLE_SOURCES = $(wildcard $(EXAMPLES_DIR)/*.c)

# 目标文件
C_OBJECTS = $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(C_SOURCES))
AS_OBJECTS = $(patsubst $(SRC_DIR)/%.S, $(BUILD_DIR)/%.o, $(AS_SOURCES))

# 主目标
TARGET = $(BIN_DIR)/scheduler_test
TEST_TARGETS = $(patsubst $(TESTS_DIR)/%.c, $(BIN_DIR)/test_%, $(TEST_SOURCES))
EXAMPLE_TARGETS = $(patsubst $(EXAMPLES_DIR)/%.c, $(BIN_DIR)/demo_%, $(EXAMPLE_SOURCES))

# 默认目标
all: $(TARGET) $(TEST_TARGETS) $(EXAMPLE_TARGETS)

# 主程序
$(TARGET): $(C_OBJECTS) $(AS_OBJECTS)
	@mkdir -p $(BIN_DIR)
	$(CC) $^ $(LDFLAGS) -o $@
	@echo "Built main program: $@"

# 测试程序规则
$(BIN_DIR)/test_%: $(TESTS_DIR)/%.c $(filter-out $(BUILD_DIR)/main.o, $(C_OBJECTS))
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@
	@echo "Built test: $@"

# 示例程序规则
$(BIN_DIR)/demo_%: $(EXAMPLES_DIR)/%.c $(filter-out $(BUILD_DIR)/main.o, $(C_OBJECTS))
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@
	@echo "Built demo: $@"

# C源文件编译规则
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# 汇编文件编译规则
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.S
	@mkdir -p $(BUILD_DIR)
	$(AS) $(ASFLAGS) $< -o $@

# 清理
clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR)
	@echo "Clean completed"

# 测试
test: all
	@echo "Running tests..."
	@for test in $(TEST_TARGETS); do \
		echo "Running $$test..."; \
		$$test || exit 1; \
	done
	@echo "All tests passed!"

# 调试版本
debug: CFLAGS += -DDEBUG -O0
debug: clean all

# 安装 (复制到系统目录)
install: all
	@echo "Installing to /usr/local/bin..."
	@sudo cp $(TARGET) /usr/local/bin/sparrow-scheduler
	@echo "Installed as sparrow-scheduler"

# 卸载
uninstall:
	@sudo rm -f /usr/local/bin/sparrow-scheduler
	@echo "Uninstalled"

# 文档
doc:
	@echo "Generating documentation..."
	@mkdir -p docs/html
	@doxygen Doxyfile 2>/dev/null || echo "Please install Doxygen to generate documentation"
	@echo "Documentation generated in docs/html/"

# 帮助
help:
	@echo "SparrowOS Scheduler Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all       - Build everything (default)"
	@echo "  clean     - Remove build files"
	@echo "  test      - Build and run tests"
	@echo "  debug     - Build with debug symbols"
	@echo "  install   - Install to system"
	@echo "  uninstall - Uninstall from system"
	@echo "  doc       - Generate documentation"
	@echo "  help      - Show this help"
	@echo ""
	@echo "Build directories:"
	@echo "  Source:      $(SRC_DIR)"
	@echo "  Build:       $(BUILD_DIR)"
	@echo "  Binaries:    $(BIN_DIR)"
	@echo "  Tests:       $(TESTS_DIR)"
	@echo "  Examples:    $(EXAMPLES_DIR)"

# 伪目标
.PHONY: all clean test debug install uninstall doc help
第十四步：项目配置文件
.gitignore

text
# 构建产物
/build/
/bin/
*.o
*.ko
*.so

# 可执行文件
*.exe
*.out
*.app

# 编辑器文件
.vscode/
.idea/
*.swp
*~

# 文档生成
/docs/html/
/docs/latex/

# 日志文件
*.log

# 临时文件
/tmp/
*.tmp

# 备份文件
*.bak
*.backup

# 系统文件
.DS_Store
Thumbs.db
Doxyfile

text
# Doxygen配置文件
PROJECT_NAME           = "SparrowOS Scheduler"
PROJECT_NUMBER         = 1.0
PROJECT_BRIEF          = "An educational process scheduler implementation"
PROJECT_LOGO           = 
OUTPUT_DIRECTORY       = docs
CREATE_SUBDIRS         = NO
ALLOW_UNICODE_NAMES    = NO
OUTPUT_LANGUAGE        = Chinese
BRIEF_MEMBER_DESC      = YES
REPEAT_BRIEF           = YES
ABBREVIATE_BRIEF       = "The $name class" \
                         "The $name widget" \
                         "The $name file" \
                         is \
                         provides \
                         specifies \
                         contains \
                         represents \
                         a \
                         an \
                         the
ALWAYS_DETAILED_SEC    = NO
INLINE_INHERITED_MEMB  = NO
FULL_PATH_NAMES        = YES
STRIP_FROM_PATH        = 
STRIP_FROM_INC_PATH    = 
SHORT_NAMES            = NO
JAVADOC_AUTOBRIEF      = NO
QT_AUTOBRIEF           = NO
MULTILINE_CPP_IS_BRIEF = NO
INHERIT_DOCS           = YES
SEPARATE_MEMBER_PAGES  = NO
TAB_SIZE               = 4
ALIASES                = 
OPTIMIZE_OUTPUT_FOR_C  = YES
OPTIMIZE_OUTPUT_JAVA   = NO
OPTIMIZE_FOR_FORTRAN   = NO
OPTIMIZE_OUTPUT_VHDL   = NO
EXTENSION_MAPPING      = 
MARKDOWN_SUPPORT       = YES
TOC_INCLUDE_HEADINGS   = 5
AUTOLINK_SUPPORT       = YES
BUILTIN_STL_SUPPORT    = NO
CPP_CLI_SUPPORT        = NO
SIP_SUPPORT            = NO
IDL_PROPERTY_SUPPORT   = YES
DISTRIBUTE_GROUP_DOC   = NO
GROUP_NESTED_COMPOUNDS = NO
SUBGROUPING            = YES
INLINE_GROUPED_CLASSES = NO
INLINE_SIMPLE_STRUCTS  = NO
TYPEDEF_HIDES_STRUCT   = NO
LOOKUP_CACHE_SIZE      = 0
EXTRACT_ALL            = YES
EXTRACT_PRIVATE        = NO
EXTRACT_PACKAGE        = NO
EXTRACT_STATIC         = NO
EXTRACT_LOCAL_CLASSES  = YES
EXTRACT_LOCAL_METHODS  = NO
EXTRACT_ANON_NSPACES   = NO
HIDE_UNDOC_MEMBERS     = NO
HIDE_UNDOC_CLASSES     = NO
HIDE_FRIEND_COMPOUNDS  = NO
HIDE_IN_BODY_DOCS      = NO
INTERNAL_DOCS          = NO
CASE_SENSE_NAMES       = NO
HIDE_SCOPE_NAMES       = NO
HIDE_COMPOUND_REFERENCE= NO
SHOW_INCLUDE_FILES     = YES
SHOW_GROUPED_MEMB_INC  = NO
FORCE_LOCAL_INCLUDES   = NO
INLINE_INFO            = YES
SORT_MEMBER_DOCS       = YES
SORT_BRIEF_DOCS        = NO
SORT_MEMBERS_CTORS_1ST = NO
SORT_GROUP_NAMES       = NO
SORT_BY_SCOPE_NAME     = NO
STRICT_PROTO_MATCHING  = NO
GENERATE_TODOLIST      = YES
GENERATE_TESTLIST      = YES
GENERATE_BUGLIST       = YES
GENERATE_DEPRECATEDLIST= YES
ENABLED_SECTIONS       = 
MAX_INITIALIZER_LINES  = 30
SHOW_USED_FILES        = YES
SHOW_FILES             = YES
SHOW_NAMESPACES        = YES
FILE_VERSION_FILTER    = 
LAYOUT_FILE            = 
CITE_BIB_FILES         = 
QUIET                  = NO
WARNINGS               = YES
WARN_IF_UNDOCUMENTED   = YES
WARN_IF_DOC_ERROR      = YES
WARN_NO_PARAMDOC       = NO
WARN_AS_ERROR          = NO
WARN_FORMAT            = "$file:$line: $text"
WARN_LOGFILE           = 
INPUT                  = include src
INPUT_ENCODING         = UTF-8
FILE_PATTERNS          = *.c \
                         *.cc \
                         *.cxx \
                         *.cpp \
                         *.c++ \
                         *.java \
                         *.ii \
                         *.ixx \
                         *.ipp \
                         *.i++ \
                         *.inl \
                         *.idl \
                         *.ddl \
                         *.odl \
                         *.h \
                         *.hh \
                         *.hxx \
                         *.hpp \
                         *.h++ \
                         *.l \
                         *.cs \
                         *.d \
                         *.php \
                         *.php4 \
                         *.php5 \
                         *.phtml \
                         *.inc \
                         *.m \
                         *.markdown \
                         *.md \
                         *.mm \
                         *.dox \
                         *.py \
                         *.f90 \
                         *.f \
                         *.for \
                         *.tcl \
                         *.vhd \
                         *.vhdl \
                         *.ucf \
                         *.qsf
RECURSIVE              = YES
EXCLUDE                = 
EXCLUDE_SYMLINKS       = NO
EXCLUDE_PATTERNS       = 
EXCLUDE_SYMBOLS        = 
EXAMPLE_PATH           = examples tests
EXAMPLE_PATTERNS       = *.c
EXAMPLE_RECURSIVE      = NO
IMAGE_PATH             = 
INPUT_FILTER           = 
FILTER_PATTERNS        = 
FILTER_SOURCE_FILES    = NO
FILTER_SOURCE_PATTERNS = 
USE_MDFILE_AS_MAINPAGE = 
SOURCE_BROWSER         = YES
INLINE_SOURCES         = NO
STRIP_CODE_COMMENTS    = YES
REFERENCED_BY_RELATION = YES
REFERENCES_RELATION    = YES
REFERENCES_LINK_SOURCE = YES
SOURCE_TOOLTIPS        = YES
USE_HTAGS              = NO
VERBATIM_HEADERS       = YES
CLANG_ASSISTED_PARSING = NO
CLANG_OPTIONS          = 
ALPHABETICAL_INDEX     = YES
COLS_IN_ALPHA_INDEX    = 5
IGNORE_PREFIX          = 
GENERATE_HTML          = YES
HTML_OUTPUT            = html
HTML_FILE_EXTENSION    = .html
HTML_HEADER            = 
HTML_FOOTER            = 
HTML_STYLESHEET        = 
HTML_EXTRA_STYLESHEET  = 
HTML_EXTRA_FILES       = 
HTML_COLORSTYLE_HUE    = 220
HTML_COLORSTYLE_SAT    = 100
HTML_COLORSTYLE_GAMMA  = 80
HTML_TIMESTAMP         = YES
HTML_DYNAMIC_SECTIONS  = NO
HTML_INDEX_NUM_ENTRIES = 100
GENERATE_DOCSET        = NO
DOCSET_FEEDNAME        = "Doxygen generated docs"
DOCSET_BUNDLE_ID       = org.doxygen.Project
DOCSET_PUBLISHER_ID    = org.doxygen.Publisher
DOCSET_PUBLISHER_NAME  = Publisher
GENERATE_HTMLHELP      = NO
CHM_FILE               = 
HHC_LOCATION           = 
GENERATE_CHI           = NO
CHM_INDEX_ENCODING     = 
BINARY_TOC             = NO
TOC_EXPAND             = NO
GENERATE_QHP           = NO
QCH_FILE               = 
QHP_NAMESPACE          = org.doxygen.Project
QHP_VIRTUAL_FOLDER     = doc
QHP_CUST_FILTER_NAME   = 
QHP_CUST_FILTER_ATTRS  = 
QHP_SECT_FILTER_ATTRS  = 
QHG_LOCATION           = 
GENERATE_ECLIPSEHELP   = NO
ECLIPSE_DOC_ID         = org.doxygen.Project
DISABLE_INDEX          = NO
GENERATE_TREEVIEW      = NO
ENUM_VALUES_PER_LINE   = 4
TREEVIEW_WIDTH         = 250
EXT_LINKS_IN_WINDOW    = NO
FORMULA_FONTSIZE       = 10
FORMULA_TRANSPARENT    = YES
USE_MATHJAX            = NO
MATHJAX_FORMAT         = HTML-CSS
MATHJAX_RELPATH        = 
MATHJAX_EXTENSIONS     = 
MATHJAX_CODEFILE       = 
SEARCHENGINE           = YES
SERVER_BASED_SEARCH    = NO
EXTERNAL_SEARCH        = NO
SEARCHENGINE_URL       = 
SEARCHDATA_FILE        = searchdata.xml
EXTERNAL_SEARCH_ID     = 
EXTRA_SEARCH_MAPPINGS  = 
GENERATE_LATEX         = NO
LATEX_OUTPUT           = latex
LATEX_CMD_NAME         = latex
MAKEINDEX_CMD_NAME     = makeindex
COMPACT_LATEX          = NO
PAPER_TYPE             = a4
EXTRA_PACKAGES         = 
LATEX_HEADER           = 
LATEX_FOOTER           = 
LATEX_EXTRA_STYLESHEET = 
LATEX_EXTRA_FILES      = 
PDF_HYPERLINKS         = YES
USE_PDFLATEX           = YES
LATEX_BATCHMODE        = NO
LATEX_HIDE_INDICES     = NO
LATEX_SOURCE_CODE      = NO
LATEX_BIB_STYLE        = plain
GENERATE_RTF           = NO
RTF_OUTPUT             = rtf
COMPACT_RTF            = NO
RTF_HYPERLINKS         = NO
RTF_STYLESHEET_FILE    = 
RTF_EXTENSIONS_FILE    = 
GENERATE_MAN           = NO
MAN_OUTPUT             = man
MAN_EXTENSION          = .3
MAN_LINKS              = NO
GENERATE_XML           = NO
XML_OUTPUT             = xml
XML_PROGRAMLISTING     = YES
GENERATE_DOCBOOK       = NO
DOCBOOK_OUTPUT         = docbook
GENERATE_AUTOGEN_DEF   = NO
GENERATE_PERLMOD       = NO
ENABLE_PREPROCESSING   = YES
MACRO_EXPANSION        = NO
EXPAND_ONLY_PREDEF     = NO
SEARCH_INCLUDES        = YES
INCLUDE_PATH           = 
INCLUDE_FILE_PATTERNS  = 
PREDEFINED             = 
EXPAND_AS_DEFINED      = 
SKIP_FUNCTION_MACROS   = YES
TAGFILES               = 
GENERATE_TAGFILE       = 
ALLEXTERNALS           = NO
EXTERNAL_GROUPS        = YES
EXTERNAL_PAGES         = YES
PERL_PATH              = /usr/bin/perl
CLASS_DIAGRAMS         = YES
HIDE_UNDOC_RELATIONS   = YES
HAVE_DOT               = NO
DOT_NUM_THREADS        = 0
DOT_FONTNAME           = Helvetica
DOT_FONTSIZE           = 10
DOT_FONTPATH           = 
CLASS_GRAPH            = YES
COLLABORATION_GRAPH    = YES
GROUP_GRAPHS           = YES
UML_LOOK               = NO
UML_LIMIT_NUM_FIELDS   = 10
TEMPLATE_RELATIONS     = NO
INCLUDE_GRAPH          = YES
INCLUDED_BY_GRAPH      = YES
CALL_GRAPH             = NO
CALLER_GRAPH           = NO
GRAPHICAL_HIERARCHY    = YES
DIRECTORY_GRAPH        = YES
DOT_IMAGE_FORMAT       = png
INTERACTIVE_SVG        = NO
DOT_PATH               = 
DOTFILE_DIRS           = 
MSCFILE_DIRS           = 
DIAFILE_DIRS           = 
PLANTUML_JAR_PATH      = 
PLANTUML_CFG           = 
PLANTUML_INCLUDE_PATH  = 
DOT_GRAPH_MAX_NODES    = 50
MAX_DOT_GRAPH_DEPTH    = 0
DOT_TRANSPARENT        = NO
DOT_MULTI_TARGETS      = NO
GENERATE_LEGEND        = YES
DOT_CLEANUP            = YES

