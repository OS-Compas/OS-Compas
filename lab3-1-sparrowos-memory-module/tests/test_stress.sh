#!/bin/bash

# SparrowOS内存管理压力测试
# 高强度测试内存分配器的稳定性和性能

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
TEST_LOG="$BUILD_DIR/test_stress_$(date +%Y%m%d_%H%M%S).log"

echo -e "${BLUE}=== SparrowOS Memory Stress Test ===${NC}" | tee "$TEST_LOG"
echo -e "Timestamp: $(date)" | tee -a "$TEST_LOG"

# 创建压力测试源文件
STRESS_TEST_SRC="$BUILD_DIR/stress_test.c"
cat > "$STRESS_TEST_SRC" << 'EOF'
/**
 * stress_test.c - 内存管理压力测试
 * 高强度测试分配器的稳定性和性能
 */

#include <os/memory.h>
#include <os/print.h>
#include <string.h>

// 性能计数器
struct perf_counters {
    uint64_t total_allocations;
    uint64_t total_frees;
    uint64_t total_bytes_allocated;
    uint64_t max_concurrent_allocations;
    uint64_t start_time;
    uint64_t end_time;
};

static struct perf_counters perf = {0};

// 获取时间（简化的实现）
static uint64_t get_time(void) {
    uint64_t time;
    asm volatile("rdtime %0" : "=r"(time));
    return time;
}

// 随机数生成器（简单的线性同余）
static uint32_t random_state = 12345;
static uint32_t random_next(void) {
    random_state = random_state * 1103515245 + 12345;
    return (random_state >> 16) & 0x7FFF;
}

// 压力测试1: 随机分配释放
void stress_test_random(void) {
    printk("\n=== Stress Test 1: Random Allocation ===\n");
    
    #define MAX_ALLOCS 1000
    #define MAX_SIZE 2048
    
    void *allocations[MAX_ALLOCS] = {0};
    size_t sizes[MAX_ALLOCS] = {0};
    
    perf.start_time = get_time();
    
    // 进行多次分配/释放操作
    for (int cycle = 0; cycle < 5000; cycle++) {
        int index = random_next() % MAX_ALLOCS;
        
        if (allocations[index] == NULL) {
            // 分配新块
            sizes[index] = (random_next() % MAX_SIZE) + 1;
            allocations[index] = kmalloc(sizes[index]);
            
            if (allocations[index]) {
                perf.total_allocations++;
                perf.total_bytes_allocated += sizes[index];
                
                // 填充数据
                memset(allocations[index], cycle % 256, sizes[index]);
                
                // 更新最大并发分配数
                uint64_t concurrent = 0;
                for (int i = 0; i < MAX_ALLOCS; i++) {
                    if (allocations[i] != NULL) concurrent++;
                }
                if (concurrent > perf.max_concurrent_allocations) {
                    perf.max_concurrent_allocations = concurrent;
                }
            }
        } else {
            // 释放块
            // 验证数据（可选）
            kfree(allocations[index]);
            allocations[index] = NULL;
            perf.total_frees++;
        }
        
        // 每1000次操作显示进度
        if (cycle % 1000 == 0) {
            printk("  Cycle %5d: allocs=%llu, frees=%llu\n", 
                   cycle, perf.total_allocations, perf.total_frees);
        }
    }
    
    // 清理所有分配
    for (int i = 0; i < MAX_ALLOCS; i++) {
        if (allocations[i]) {
            kfree(allocations[i]);
            perf.total_frees++;
        }
    }
    
    perf.end_time = get_time();
}

// 压力测试2: 突发分配
void stress_test_burst(void) {
    printk("\n=== Stress Test 2: Burst Allocation ===\n");
    
    #define BURST_SIZE 200
    #define NUM_BURSTS 10
    
    for (int burst = 0; burst < NUM_BURSTS; burst++) {
        void *burst_allocs[BURST_SIZE];
        
        printk("  Burst %d: Allocating %d blocks...\n", burst + 1, BURST_SIZE);
        
        // 突发分配
        for (int i = 0; i < BURST_SIZE; i++) {
            size_t size = 64 + (random_next() % 192);  // 64-256字节
            burst_allocs[i] = kmalloc(size);
            
            if (burst_allocs[i]) {
                perf.total_allocations++;
                perf.total_bytes_allocated += size;
                memset(burst_allocs[i], burst % 256, size);
            } else {
                printk("    Allocation failed at burst %d, index %d\n", burst, i);
                memory_stats();
            }
        }
        
        // 随机释放一部分
        printk("    Randomly freeing half...\n");
        for (int i = 0; i < BURST_SIZE / 2; i++) {
            int idx = random_next() % BURST_SIZE;
            if (burst_allocs[idx]) {
                kfree(burst_allocs[idx]);
                perf.total_frees++;
                burst_allocs[idx] = NULL;
            }
        }
        
        // 再分配一些
        printk("    Allocating more...\n");
        for (int i = 0; i < BURST_SIZE / 4; i++) {
            int idx = random_next() % BURST_SIZE;
            if (burst_allocs[idx] == NULL) {
                size_t size = 128 + (random_next() % 128);
                burst_allocs[idx] = kmalloc(size);
                if (burst_allocs[idx]) {
                    perf.total_allocations++;
                    perf.total_bytes_allocated += size;
                }
            }
        }
        
        // 清理这个突发的所有分配
        for (int i = 0; i < BURST_SIZE; i++) {
            if (burst_allocs[i]) {
                kfree(burst_allocs[i]);
                perf.total_frees++;
            }
        }
    }
}

// 压力测试3: 长时间运行
void stress_test_long_running(void) {
    printk("\n=== Stress Test 3: Long Running ===\n");
    
    #define LONG_TEST_DURATION 10000  // 操作次数
    
    void *long_term_allocs[100] = {0};
    
    for (int i = 0; i < LONG_TEST_DURATION; i++) {
        // 定期分配和释放
        if (i % 100 == 0) {
            // 分配一些长期存在的块
            for (int j = 0; j < 10; j++) {
                if (long_term_allocs[j] == NULL) {
                    long_term_allocs[j] = kmalloc(512);
                    if (long_term_allocs[j]) {
                        perf.total_allocations++;
                        memset(long_term_allocs[j], j % 256, 512);
                    }
                }
            }
        }
        
        if (i % 137 == 0) {  // 质数，创造随机模式
            // 释放一些长期块
            for (int j = 0; j < 10; j++) {
                if (long_term_allocs[j] && (random_next() % 3 == 0)) {
                    kfree(long_term_allocs[j]);
                    perf.total_frees++;
                    long_term_allocs[j] = NULL;
                }
            }
        }
        
        // 短期分配/释放
        void *temp = kmalloc(64 + (i % 128));
        if (temp) {
            perf.total_allocations++;
            perf.total_bytes_allocated += 64 + (i % 128);
            // 使用内存
            memset(temp, i % 256, 64 + (i % 128));
            kfree(temp);
            perf.total_frees++;
        }
        
        // 显示进度
        if (i % 1000 == 0) {
            printk("  Progress: %d/%d operations\n", i, LONG_TEST_DURATION);
            if (i % 3000 == 0) {
                memory_stats();
            }
        }
    }
    
    // 清理长期块
    for (int j = 0; j < 100; j++) {
        if (long_term_allocs[j]) {
            kfree(long_term_allocs[j]);
            perf.total_frees++;
        }
    }
}

// 显示性能结果
void show_performance_results(void) {
    uint64_t duration = perf.end_time - perf.start_time;
    uint64_t ops_per_second = (perf.total_allocations + perf.total_frees) * 1000000 / 
                             (duration > 0 ? duration : 1);
    
    printk("\n=== Performance Results ===\n");
    printk("Total allocations:    %llu\n", perf.total_allocations);
    printk("Total frees:          %llu\n", perf.total_frees);
    printk("Total bytes allocated: %llu\n", perf.total_bytes_allocated);
    printk("Max concurrent allocs: %llu\n", perf.max_concurrent_allocations);
    printk("Test duration:        %llu cycles\n", duration);
    printk("Operations/sec:       %llu\n", ops_per_second);
    
    // 检查平衡
    if (perf.total_allocations == perf.total_frees) {
        printk("Allocation balance:   ✓ Perfect (no leaks)\n");
    } else {
        printk("Allocation balance:   ✗ Imbalance: %lld\n", 
               (int64_t)(perf.total_allocations - perf.total_frees));
    }
}

// 主压力测试函数
void run_stress_tests(void) {
    printk("\n=== SparrowOS Memory Stress Test Suite ===\n");
    printk("Starting comprehensive stress testing...\n");
    
    // 记录初始内存状态
    printk("\nInitial memory state:\n");
    memory_stats();
    
    // 运行各个压力测试
    stress_test_random();
    stress_test_burst();
    stress_test_long_running();
    
    // 显示最终结果
    show_performance_results();
    
    // 完整性检查
    printk("\nFinal integrity check:\n");
    memory_integrity_check();
    memory_stats();
    
    printk("\n=== Stress Test Complete ===\n");
    printk("If you see this message, the memory manager survived! 🎉\n");
}
EOF

# 创建压力测试Makefile
cat > "$BUILD_DIR/Makefile.stresstest" << EOF
# 压力测试专用Makefile
CC = riscv64-unknown-elf-gcc
LD = riscv64-unknown-elf-ld
OBJCOPY = riscv64-unknown-elf-objcopy

CFLAGS = -Wall -Werror -O2 -mabi=lp64 -march=rv64gc -ffreestanding -nostdlib -fno-builtin -I$PROJECT_ROOT/include

OBJS = $PROJECT_ROOT/kernel/entry.o \\
       $PROJECT_ROOT/kernel/main.o \\
       $PROJECT_ROOT/kernel/print.o \\
       $PROJECT_ROOT/src/memory.o \\
       $BUILD_DIR/stress_test.o

# 修改main.c以调用压力测试
$BUILD_DIR/main_stresstest.c: $PROJECT_ROOT/kernel/main.c
	sed 's/run_all_tests();/run_stress_tests();/g' \$< > \$@

$BUILD_DIR/main_stresstest.o: $BUILD_DIR/main_stresstest.c
	\$(CC) \$(CFLAGS) -c \$< -o \$@

$BUILD_DIR/stress_test.o: $BUILD_DIR/stress_test.c
	\$(CC) \$(CFLAGS) -c \$< -o \$@

stresstest.bin: stresstest.elf
	\$(OBJCOPY) -O binary \$< \$@

stresstest.elf: \$(OBJS) $BUILD_DIR/main_stresstest.o
	\$(LD) -T $PROJECT_ROOT/src/link.ld -o \$@ \$^
	
clean:
	rm -f stresstest.* $BUILD_DIR/*_stresstest.*
EOF

echo -e "\n${YELLOW}[1/5] Building stress test kernel...${NC}" | tee -a "$TEST_LOG"

# 编译压力测试内核
cd "$BUILD_DIR"
if make -f Makefile.stresstest stresstest.bin 2>&1 | tee -a "$TEST_LOG"; then
    echo -e "${GREEN}✓ Stress test kernel built successfully${NC}" | tee -a "$TEST_LOG"
    KERNEL_SIZE=$(stat -c%s "stresstest.bin")
    echo -e "Kernel size: $KERNEL_SIZE bytes" | tee -a "$TEST_LOG"
else
    echo -e "${RED}✗ Failed to build stress test kernel${NC}" | tee -a "$TEST_LOG"
    exit 1
fi

echo -e "\n${YELLOW}[2/5] Running stress tests (this may take a minute)...${NC}" | tee -a "$TEST_LOG"

# 运行压力测试，设置较长的超时时间
QEMU_OUTPUT_FILE="$BUILD_DIR/stresstest_output.log"
STRESS_START_TIME=$(date +%s)

timeout 60s qemu-system-riscv64 \
    -machine virt \
    -nographic \
    -bios none \
    -kernel "$BUILD_DIR/stresstest.bin" \
    -m 128M \
    2>&1 | tee "$QEMU_OUTPUT_FILE" | tee -a "$TEST_LOG" || true

STRESS_END_TIME=$(date +%s)
STRESS_DURATION=$((STRESS_END_TIME - STRESS_START_TIME))

echo -e "\n${YELLOW}[3/5] Stress test completed in ${STRESS_DURATION} seconds${NC}" | tee -a "$TEST_LOG"

# 分析结果
echo -e "\n${YELLOW}[4/5] Analyzing stress test results...${NC}" | tee -a "$TEST_LOG"

STRESS_PASS=1
CRITICAL_ISSUES=0
WARNINGS=0

# 检查测试是否完成
if ! grep -q "Stress Test Complete" "$QEMU_OUTPUT_FILE"; then
    echo -e "${RED}✗ Stress test did not complete${NC}" | tee -a "$TEST_LOG"
    STRESS_PASS=0
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
else
    echo -e "${GREEN}✓ Stress test completed successfully${NC}" | tee -a "$TEST_LOG"
fi

# 检查内核恐慌或严重错误
if grep -q -i "panic\|exception\|fault\|error" "$QEMU_OUTPUT_FILE"; then
    ERROR_COUNT=$(grep -c -i "panic\|exception\|fault\|error" "$QEMU_OUTPUT_FILE")
    echo -e "${RED}✗ Found $ERROR_COUNT error(s) during stress test${NC}" | tee -a "$TEST_LOG"
    grep -i "panic\|exception\|fault\|error" "$QEMU_OUTPUT_FILE" | head -5 | tee -a "$TEST_LOG"
    STRESS_PASS=0
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + ERROR_COUNT))
else
    echo -e "${GREEN}✓ No critical errors detected${NC}" | tee -a "$TEST_LOG"
fi

# 检查内存泄漏
if grep -q "Allocation balance:.*✗" "$QEMU_OUTPUT_FILE"; then
    LEAK_INFO=$(grep "Allocation balance:.*✗" "$QEMU_OUTPUT_FILE")
    echo -e "${RED}✗ Memory leak detected: $LEAK_INFO${NC}" | tee -a "$TEST_LOG"
    STRESS_PASS=0
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
else
    echo -e "${GREEN}✓ No memory leaks detected${NC}" | tee -a "$TEST_LOG"
fi

# 检查性能指标
echo -e "\n${YELLOW}Performance Metrics:${NC}" | tee -a "$TEST_LOG"

# 提取性能数据
TOTAL_ALLOCS=$(grep "Total allocations:" "$QEMU_OUTPUT_FILE" | grep -o '[0-9]\+' || echo "0")
TOTAL_FREES=$(grep "Total frees:" "$QEMU_OUTPUT_FILE" | grep -o '[0-9]\+' || echo "0")
OPS_PER_SEC=$(grep "Operations/sec:" "$QEMU_OUTPUT_FILE" | grep -o '[0-9]\+' || echo "0")
MAX_CONCURRENT=$(grep "Max concurrent allocs:" "$QEMU_OUTPUT_FILE" | grep -o '[0-9]\+' || echo "0")

echo -e "Total allocations:    $TOTAL_ALLOCS" | tee -a "$TEST_LOG"
echo -e "Total frees:          $TOTAL_FREES" | tee -a "$TEST_LOG"
echo -e "Operations/second:    $OPS_PER_SEC" | tee -a "$TEST_LOG"
echo -e "Max concurrent:       $MAX_CONCURRENT" | tee -a "$TEST_LOG"

# 评估性能
if [ "$OPS_PER_SEC" -gt 1000 ]; then
    echo -e "${GREEN}✓ Good performance ($OPS_PER_SEC ops/sec)${NC}" | tee -a "$TEST_LOG"
elif [ "$OPS_PER_SEC" -gt 100 ]; then
    echo -e "${YELLOW}⚠ Moderate performance ($OPS_PER_SEC ops/sec)${NC}" | tee -a "$TEST_LOG"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${RED}✗ Poor performance ($OPS_PER_SEC ops/sec)${NC}" | tee -a "$TEST_LOG"
    STRESS_PASS=0
    WARNINGS=$((WARNINGS + 1))
fi

# 显示内存统计摘要
echo -e "\n${YELLOW}Final Memory State:${NC}" | tee -a "$TEST_LOG"
grep -A10 "=== Memory Statistics ===" "$QEMU_OUTPUT_FILE" | tail -10 | tee -a "$TEST_LOG"

# 检查碎片化
FRAGMENTATION=$(grep "Fragmentation:" "$QEMU_OUTPUT_FILE" | tail -1 || echo "")
if [ -n "$FRAGMENTATION" ]; then
    echo -e "\nFinal $FRAGMENTATION" | tee -a "$TEST_LOG"
    FRAG_VALUE=$(echo "$FRAGMENTATION" | grep -o '[0-9.]\+' | head -1)
    
    if (( $(echo "$FRAG_VALUE > 50" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "${RED}✗ High fragmentation after stress test${NC}" | tee -a "$TEST_LOG"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# 生成压力测试报告
echo -e "\n${YELLOW}[5/5] Generating stress test report...${NC}" | tee -a "$TEST_LOG"

STRESS_REPORT="$BUILD_DIR/stress_test_report.md"
cat > "$STRESS_REPORT" << EOF
# 内存压力测试报告

## 测试信息
- **测试时间**: $(date)
- **测试持续时间**: ${STRESS_DURATION}秒
- **内核版本**: SparrowOS Memory Manager
- **测试类型**: 高强度压力测试
- **内存配置**: 128MB RAM, 64KB堆

## 测试概要
- **状态**: $(if [ $STRESS_PASS -eq 1 ]; then echo "✅ 通过"; else echo "❌ 失败"; fi)
- **关键问题**: $CRITICAL_ISSUES 个
- **警告**: $WARNINGS 个

## 性能指标
| 指标 | 值 |
|------|-----|
| 总分配次数 | $TOTAL_ALLOCS |
| 总释放次数 | $TOTAL_FREES |
| 操作频率 | $OPS_PER_SEC 次/秒 |
| 最大并发分配 | $MAX_CONCURRENT |
| 测试时间 | ${STRESS_DURATION}秒 |

## 内存状态
\`\`\`
$(grep -A10 "=== Memory Statistics ===" "$QEMU_OUTPUT_FILE" | tail -10)
\`\`\`

## 问题摘要
$(if [ $CRITICAL_ISSUES -gt 0 ]; then
    grep -i "panic\|exception\|fault\|error\|leak" "$QEMU_OUTPUT_FILE" | head -5 | sed 's/^/- /'
else
    echo "- 无关键问题"
fi)

## 通过标准检查
- [$(if grep -q "Stress Test Complete" "$QEMU_OUTPUT_FILE"; then echo "x"; else echo " ")] 测试完整执行
- [$(if ! grep -q -i "panic\|exception\|fault" "$QEMU_OUTPUT_FILE"; then echo "x"; else echo " ")] 无系统崩溃
- [$(if ! grep -q "Allocation balance:.*✗" "$QEMU_OUTPUT_FILE"; then echo "x"; else echo " ")] 无内存泄漏
- [$(if [ "$OPS_PER_SEC" -gt 100 ]; then echo "x"; else echo " ")] 性能可接受 (>100 ops/sec)

## 建议
$(if [ $STRESS_PASS -eq 1 ]; then
    echo "内存分配器在高压力下表现稳定，可以投入生产使用。"
else
    echo "内存分配器在高压力下存在问题，需要进一步优化："
    echo "1. 检查错误处理逻辑"
    echo "2. 优化分配算法性能"
    echo "3. 加强内存完整性检查"
fi)

## 详细日志
完整测试输出见: $QEMU_OUTPUT_FILE
EOF

echo -e "${GREEN}Stress test report saved to: $STRESS_REPORT${NC}" | tee -a "$TEST_LOG"

# 保存摘要输出
echo -e "\n${BLUE}=== Stress Test Output Summary ===${NC}" | tee -a "$TEST_LOG"
tail -30 "$QEMU_OUTPUT_FILE" | tee -a "$TEST_LOG"

# 最终评估
echo -e "\n${BLUE}=== Final Assessment ===${NC}" | tee -a "$TEST_LOG"

if [ $STRESS_PASS -eq 1 ]; then
    if [ $CRITICAL_ISSUES -eq 0 ]; then
        echo -e "${GREEN}✅ EXCELLENT: Stress test passed with no critical issues!${NC}" | tee -a "$TEST_LOG"
        echo -e "${GREEN}The memory manager is production-ready! 🎉${NC}" | tee -a "$TEST_LOG"
    else
        echo -e "${YELLOW}⚠ ACCEPTABLE: Stress test passed but with some issues${NC}" | tee -a "$TEST_LOG"
        echo -e "${YELLOW}Consider addressing the critical issues before production use.${NC}" | tee -a "$TEST_LOG"
    fi
    exit 0
else
    echo -e "${RED}❌ UNACCEPTABLE: Stress test failed with $CRITICAL_ISSUES critical issue(s)${NC}" | tee -a "$TEST_LOG"
    echo -e "${RED}The memory manager needs significant improvements.${NC}" | tee -a "$TEST_LOG"
    exit 1
fi