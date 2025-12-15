#!/bin/bash

# SparrowOS内存碎片化测试
# 测试内存分配器在碎片化场景下的表现

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
TEST_LOG="$BUILD_DIR/test_fragmentation_$(date +%Y%m%d_%H%M%S).log"

echo -e "${BLUE}=== SparrowOS Memory Fragmentation Test ===${NC}" | tee "$TEST_LOG"
echo -e "Timestamp: $(date)" | tee -a "$TEST_LOG"

# 构建修改后的测试内核
echo -e "\n${YELLOW}[1/4] Building test kernel...${NC}" | tee -a "$TEST_LOG"

# 创建专门的碎片化测试文件
FRAG_TEST_SRC="$BUILD_DIR/fragmentation_test.c"
cat > "$FRAG_TEST_SRC" << 'EOF'
/**
 * fragmentation_test.c - 内存碎片化测试
 * 专门测试分配器在碎片化场景下的表现
 */

#include <os/memory.h>
#include <os/print.h>
#include <string.h>

// 碎片化测试模式
void fragmentation_test(void) {
    printk("\n=== Memory Fragmentation Test ===\n");
    
    #define NUM_BLOCKS 20
    #define PATTERN_SIZE 100
    
    void *blocks[NUM_BLOCKS];
    size_t sizes[NUM_BLOCKS];
    
    // 记录初始状态
    uint64_t initial_free = get_free_memory();
    printk("Initial free memory: %llu bytes\n", initial_free);
    
    // 阶段1: 创建碎片化模式
    printk("\n[Phase 1] Creating fragmentation pattern...\n");
    
    // 交替分配不同大小的块
    for (int i = 0; i < NUM_BLOCKS; i++) {
        sizes[i] = 32 + (i * 16);  // 32, 48, 64, ..., 336
        blocks[i] = kmalloc(sizes[i]);
        
        if (!blocks[i]) {
            printk("Allocation failed at block %d (size=%zu)\n", i, sizes[i]);
            printk("Free memory: %llu\n", get_free_memory());
            memory_stats();
            return;
        }
        
        // 填充模式数据
        memset(blocks[i], 0xA0 + (i % 16), sizes[i]);
        
        if (i % 5 == 0) {
            printk("  Allocated block %2d: %4zu bytes @ 0x%llx\n", 
                   i, sizes[i], (uint64_t)blocks[i]);
        }
    }
    
    // 显示中间状态
    printk("\nAfter allocation:\n");
    memory_stats();
    
    // 阶段2: 创建碎片（每隔一个释放）
    printk("\n[Phase 2] Creating holes (releasing every other block)...\n");
    
    int holes_created = 0;
    for (int i = 0; i < NUM_BLOCKS; i += 2) {
        kfree(blocks[i]);
        blocks[i] = NULL;
        holes_created++;
        
        if (i % 6 == 0) {
            printk("  Freed block %2d (size=%zu)\n", i, sizes[i]);
        }
    }
    
    printk("Created %d holes in the heap\n", holes_created);
    printk("Current state:\n");
    memory_stats();
    
    // 阶段3: 尝试分配大块（测试碎片合并）
    printk("\n[Phase 3] Testing large allocation in fragmented heap...\n");
    
    // 计算最大连续空闲空间
    void *large1 = kmalloc(1024);  // 1KB
    if (large1) {
        printk("✓ Allocated 1KB block in fragmented heap @ 0x%llx\n", 
               (uint64_t)large1);
        
        void *large2 = kmalloc(2048);  // 2KB
        if (large2) {
            printk("✓ Allocated 2KB block in fragmented heap @ 0x%llx\n", 
                   (uint64_t)large2);
            kfree(large2);
        } else {
            printk("✗ Failed to allocate 2KB block (fragmentation issue)\n");
        }
        
        kfree(large1);
    } else {
        printk("✗ Failed to allocate 1KB block - severe fragmentation\n");
    }
    
    // 阶段4: 分配许多小对象（测试外部碎片）
    printk("\n[Phase 4] Testing small allocations...\n");
    
    #define NUM_SMALL 50
    void *small_blocks[NUM_SMALL];
    int small_success = 0;
    
    for (int i = 0; i < NUM_SMALL; i++) {
        small_blocks[i] = kmalloc(16 + (i % 8) * 4);  // 16-44字节
        if (small_blocks[i]) {
            small_success++;
            memset(small_blocks[i], i % 256, 16 + (i % 8) * 4);
        }
    }
    
    printk("Small allocations: %d/%d successful\n", small_success, NUM_SMALL);
    
    // 释放所有小对象
    for (int i = 0; i < NUM_SMALL; i++) {
        if (small_blocks[i]) {
            kfree(small_blocks[i]);
        }
    }
    
    // 阶段5: 清理和验证
    printk("\n[Phase 5] Cleaning up and verifying...\n");
    
    // 释放剩余块
    for (int i = 0; i < NUM_BLOCKS; i++) {
        if (blocks[i]) {
            kfree(blocks[i]);
        }
    }
    
    // 最终验证
    uint64_t final_free = get_free_memory();
    uint64_t memory_leak = initial_free - final_free;
    
    printk("\n=== Fragmentation Test Results ===\n");
    printk("Initial free memory: %llu bytes\n", initial_free);
    printk("Final free memory:   %llu bytes\n", final_free);
    
    if (memory_leak == 0) {
        printk("✓ No memory leak detected\n");
    } else {
        printk("✗ Memory leak detected: %llu bytes\n", memory_leak);
    }
    
    // 显示碎片化程度
    memory_stats();
    memory_integrity_check();
    
    printk("\n=== Fragmentation Test Complete ===\n");
}
EOF

# 创建临时Makefile用于碎片化测试
cat > "$BUILD_DIR/Makefile.fragtest" << EOF
# 碎片化测试专用Makefile
CC = riscv64-unknown-elf-gcc
LD = riscv64-unknown-elf-ld
OBJCOPY = riscv64-unknown-elf-objcopy

CFLAGS = -Wall -Werror -O2 -mabi=lp64 -march=rv64gc -ffreestanding -nostdlib -fno-builtin -I$PROJECT_ROOT/include

OBJS = $PROJECT_ROOT/kernel/entry.o \\
       $PROJECT_ROOT/kernel/main.o \\
       $PROJECT_ROOT/kernel/print.o \\
       $PROJECT_ROOT/src/memory.o \\
       $BUILD_DIR/fragmentation_test.o

# 修改main.c以调用碎片化测试
$BUILD_DIR/main_fragtest.c: $PROJECT_ROOT/kernel/main.c
	sed 's/run_all_tests();/fragmentation_test();/g' \$< > \$@

$BUILD_DIR/main_fragtest.o: $BUILD_DIR/main_fragtest.c
	\$(CC) \$(CFLAGS) -c \$< -o \$@

$BUILD_DIR/fragmentation_test.o: $BUILD_DIR/fragmentation_test.c
	\$(CC) \$(CFLAGS) -c \$< -o \$@

fragtest.bin: fragtest.elf
	\$(OBJCOPY) -O binary \$< \$@

fragtest.elf: \$(OBJS) $BUILD_DIR/main_fragtest.o
	\$(LD) -T $PROJECT_ROOT/src/link.ld -o \$@ \$^
	
clean:
	rm -f fragtest.* $BUILD_DIR/*_fragtest.*
EOF

# 编译测试内核
cd "$BUILD_DIR"
if make -f Makefile.fragtest fragtest.bin 2>&1 | tee -a "$TEST_LOG"; then
    echo -e "${GREEN}✓ Test kernel built successfully${NC}" | tee -a "$TEST_LOG"
else
    echo -e "${RED}✗ Failed to build test kernel${NC}" | tee -a "$TEST_LOG"
    exit 1
fi

# 运行碎片化测试
echo -e "\n${YELLOW}[2/4] Running fragmentation test...${NC}" | tee -a "$TEST_LOG"

QEMU_OUTPUT_FILE="$BUILD_DIR/fragtest_output.log"
timeout 15s qemu-system-riscv64 \
    -machine virt \
    -nographic \
    -bios none \
    -kernel "$BUILD_DIR/fragtest.bin" \
    -m 128M \
    2>&1 | tee "$QEMU_OUTPUT_FILE" | tee -a "$TEST_LOG" || true

# 分析结果
echo -e "\n${YELLOW}[3/4] Analyzing results...${NC}" | tee -a "$TEST_LOG"

# 检查关键指标
FRAGMENTATION_PASS=1

# 1. 检查是否成功完成测试
if ! grep -q "Fragmentation Test Complete" "$QEMU_OUTPUT_FILE"; then
    echo -e "${RED}✗ Test did not complete successfully${NC}" | tee -a "$TEST_LOG"
    FRAGMENTATION_PASS=0
fi

# 2. 检查内存泄漏
if grep -q "Memory leak detected" "$QEMU_OUTPUT_FILE"; then
    LEAK_SIZE=$(grep "Memory leak detected" "$QEMU_OUTPUT_FILE" | grep -o '[0-9]\+ bytes')
    echo -e "${RED}✗ Memory leak detected: $LEAK_SIZE${NC}" | tee -a "$TEST_LOG"
    FRAGMENTATION_PASS=0
else
    echo -e "${GREEN}✓ No memory leak detected${NC}" | tee -a "$TEST_LOG"
fi

# 3. 检查大块分配是否成功
if grep -q "Failed to allocate.*block.*fragmentation" "$QEMU_OUTPUT_FILE"; then
    echo -e "${YELLOW}⚠ Some large allocations failed due to fragmentation${NC}" | tee -a "$TEST_LOG"
    # 这不一定是失败，只是显示碎片化效果
fi

# 4. 检查小对象分配成功率
SMALL_SUCCESS=$(grep "Small allocations:" "$QEMU_OUTPUT_FILE" | grep -o '[0-9]\+/[0-9]\+')
if [ -n "$SMALL_SUCCESS" ]; then
    SUCCESS_RATE=$(echo "$SMALL_SUCCESS" | cut -d'/' -f1)
    TOTAL=$(echo "$SMALL_SUCCESS" | cut -d'/' -f2)
    if [ "$SUCCESS_RATE" -eq "$TOTAL" ]; then
        echo -e "${GREEN}✓ All small allocations succeeded${NC}" | tee -a "$TEST_LOG"
    elif [ $((SUCCESS_RATE * 100 / TOTAL)) -gt 80 ]; then
        echo -e "${GREEN}✓ Good small allocation success: $SMALL_SUCCESS${NC}" | tee -a "$TEST_LOG"
    else
        echo -e "${YELLOW}⚠ Low small allocation success: $SMALL_SUCCESS${NC}" | tee -a "$TEST_LOG"
    fi
fi

# 5. 提取碎片化统计
echo -e "\n${YELLOW}[4/4] Fragmentation Statistics:${NC}" | tee -a "$TEST_LOG"
grep -A5 "=== Memory Statistics ===" "$QEMU_OUTPUT_FILE" | tail -6 | tee -a "$TEST_LOG"

# 计算碎片化程度
FRAGMENTATION_LINE=$(grep "Fragmentation:" "$QEMU_OUTPUT_FILE" | tail -1)
if [ -n "$FRAGMENTATION_LINE" ]; then
    FRAG_PERCENT=$(echo "$FRAGMENTATION_LINE" | grep -o '[0-9.]\+%')
    echo -e "\nFinal fragmentation level: $FRAG_PERCENT" | tee -a "$TEST_LOG"
    
    # 评估碎片化程度
    FRAG_VALUE=$(echo "$FRAG_PERCENT" | sed 's/%//')
    if (( $(echo "$FRAG_VALUE < 10" | bc -l) )); then
        echo -e "${GREEN}✓ Low fragmentation (good)${NC}" | tee -a "$TEST_LOG"
    elif (( $(echo "$FRAG_VALUE < 30" | bc -l) )); then
        echo -e "${YELLOW}⚠ Moderate fragmentation${NC}" | tee -a "$TEST_LOG"
    else
        echo -e "${RED}✗ High fragmentation (needs improvement)${NC}" | tee -a "$TEST_LOG"
        FRAGMENTATION_PASS=0
    fi
fi

# 保存详细输出
echo -e "\n${BLUE}=== Test Output Summary ===${NC}" | tee -a "$TEST_LOG"
tail -50 "$QEMU_OUTPUT_FILE" | tee -a "$TEST_LOG"

# 生成测试报告
TEST_REPORT="$BUILD_DIR/fragmentation_report.md"
cat > "$TEST_REPORT" << EOF
# 内存碎片化测试报告

## 测试信息
- **测试时间**: $(date)
- **内核版本**: SparrowOS Memory Manager
- **测试类型**: 碎片化压力测试
- **内存大小**: 128MB
- **堆大小**: 64KB

## 测试结果
$(if [ $FRAGMENTATION_PASS -eq 1 ]; then
    echo "- ✅ **测试通过**"
else
    echo "- ❌ **测试失败**"
fi)

## 关键指标
$(grep -E "(Initial free|Final free|Fragmentation:|Small allocations:)" "$QEMU_OUTPUT_FILE" | head -5)

## 详细统计
\`\`\`
$(grep -A10 "=== Memory Statistics ===" "$QEMU_OUTPUT_FILE")
\`\`\`

## 分析
$(if [ $FRAGMENTATION_PASS -eq 1 ]; then
    echo "分配器在碎片化场景下表现良好，能够有效管理内存碎片。"
else
    echo "分配器在碎片化场景下存在问题，需要进一步优化。"
fi)

## 建议
1. 考虑实现块合并优化
2. 添加碎片整理机制
3. 对于频繁分配的小对象，考虑使用内存池

## 原始输出
完整输出见: $QEMU_OUTPUT_FILE
EOF

echo -e "\n${GREEN}Test report saved to: $TEST_REPORT${NC}" | tee -a "$TEST_LOG"

# 最终判断
if [ $FRAGMENTATION_PASS -eq 1 ]; then
    echo -e "\n${GREEN}✅ Fragmentation test PASSED${NC}" | tee -a "$TEST_LOG"
    exit 0
else
    echo -e "\n${RED}❌ Fragmentation test FAILED${NC}" | tee -a "$TEST_LOG"
    exit 1
fi