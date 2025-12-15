#!/bin/bash

# KASAN测试脚本
# 用于测试内核地址消毒剂(KASAN)的功能

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/src"
LOGS_DIR="$PROJECT_ROOT/logs"
MODULES_DIR="$PROJECT_ROOT/modules"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

print_info() {
    echo -e "${YELLOW}[*] $1${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root or use sudo"
        exit 1
    fi
}

check_kasan_support() {
    print_header "Checking KASAN Support"
    
    local kasan_enabled=false
    
    # 检查内核配置
    if [ -f "/boot/config-$(uname -r)" ]; then
        if grep -q "CONFIG_KASAN=y" "/boot/config-$(uname -r)"; then
            kasan_enabled=true
        fi
    elif [ -f "/proc/config.gz" ]; then
        if zcat /proc/config.gz | grep -q "CONFIG_KASAN=y"; then
            kasan_enabled=true
        fi
    fi
    
    if $kasan_enabled; then
        print_success "KASAN is enabled in kernel"
        
        # 检查KASAN类型
        if grep -q "CONFIG_KASAN_GENERIC=y" "/boot/config-$(uname -r)" 2>/dev/null || \
           (zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_KASAN_GENERIC=y"); then
            print_info "KASAN type: Generic (slow but precise)"
        elif grep -q "CONFIG_KASAN_SW_TAGS=y" "/boot/config-$(uname -r)" 2>/dev/null || \
             (zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_KASAN_SW_TAGS=y"); then
            print_info "KASAN type: Software Tag-Based (fast)"
        fi
    else
        print_error "KASAN is NOT enabled in kernel"
        print_info "You need to compile kernel with CONFIG_KASAN=y"
        print_info "Run ./scripts/build_kernel.sh first"
        exit 1
    fi
    
    # 检查启动参数
    local cmdline=$(cat /proc/cmdline 2>/dev/null)
    if echo "$cmdline" | grep -q "kasan_multi_shot"; then
        print_info "KASAN multi-shot mode enabled"
    fi
}

check_kernel_logs() {
    print_header "Checking Kernel Logs for KASAN"
    
    print_info "Checking recent kernel messages for KASAN..."
    local kasan_lines=$(dmesg | grep -i kasan | tail -10)
    
    if [ -n "$kasan_lines" ]; then
        echo "Recent KASAN-related messages:"
        echo "$kasan_lines"
        
        # 检查是否有错误报告
        if echo "$kasan_lines" | grep -q -i "bug\|error\|panic\|warn"; then
            print_error "KASAN has detected errors!"
        else
            print_info "KASAN is active but no errors reported yet"
        fi
    else
        print_info "No recent KASAN messages found"
        print_info "This could mean:"
        print_info "1. KASAN is not active"
        print_info "2. No memory errors have occurred"
        print_info "3. System was recently rebooted"
    fi
}

compile_test_module() {
    print_header "Compiling KASAN Test Module"
    
    # 创建模块目录
    mkdir -p "$MODULES_DIR"
    
    # 检查内核头文件
    if [ ! -d "/lib/modules/$(uname -r)/build" ]; then
        print_error "Kernel headers not found"
        print_info "Please install: sudo apt install linux-headers-$(uname -r)"
        exit 1
    fi
    
    # 编译模块
    cd "$SRC_DIR"
    
    print_info "Creating Makefile for test module..."
    cat > Makefile << 'EOF'
obj-m += kasan_module.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean

install:
	sudo insmod kasan_module.ko

uninstall:
	sudo rmmod kasan_module

test:
	sudo insmod kasan_module.ko test_mode=1 iterations=2 debug=1
	sleep 2
	dmesg | tail -20
	sudo rmmod kasan_module
EOF
    
    print_info "Compiling module..."
    make 2>&1 | tee "$LOGS_DIR/kasan_module_compile.log"
    
    if [ -f "kasan_module.ko" ]; then
        cp kasan_module.ko "$MODULES_DIR/"
        print_success "Module compiled: $MODULES_DIR/kasan_module.ko"
        
        # 显示模块信息
        print_info "Module information:"
        modinfo kasan_module.ko | head -10
    else
        print_error "Module compilation failed"
        exit 1
    fi
}

test_safe_operations() {
    print_header "Testing Safe Memory Operations"
    
    print_info "Loading module in safe mode (test_mode=0)..."
    
    # 清理之前的模块
    sudo rmmod kasan_module 2>/dev/null || true
    
    # 加载模块（安全模式）
    if sudo insmod "$MODULES_DIR/kasan_module.ko" test_mode=0 iterations=1 debug=1; then
        print_success "Module loaded in safe mode"
        
        # 检查日志
        print_info "Checking kernel logs..."
        local logs=$(dmesg | tail -20 | grep -i "kasan")
        
        if echo "$logs" | grep -q -i "error\|bug\|warning"; then
            print_error "Unexpected KASAN errors in safe mode!"
            echo "Logs:"
            echo "$logs"
        else
            print_success "No KASAN errors in safe mode (as expected)"
        fi
        
        # 卸载模块
        sudo rmmod kasan_module
        print_success "Module unloaded"
    else
        print_error "Failed to load module in safe mode"
    fi
}

test_out_of_bounds() {
    print_header "Testing Out-of-Bounds Detection"
    
    print_info "WARNING: This test will trigger intentional memory errors!"
    print_info "KASAN should detect and report these errors."
    echo ""
    
    read -p "Continue with out-of-bounds test? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Skipping out-of-bounds test"
        return
    fi
    
    # 清理之前的模块
    sudo rmmod kasan_module 2>/dev/null || true
    
    # 记录测试前的日志
    local before_logs=$(dmesg | tail -100)
    
    print_info "Loading module with out-of-bounds test (test_mode=1)..."
    
    # 加载模块（越界测试模式）
    if sudo insmod "$MODULES_DIR/kasan_module.ko" test_mode=1 iterations=2 debug=1 panic_on_error=0; then
        print_info "Module loaded (errors expected)"
        
        # 等待一下让错误发生
        sleep 2
        
        # 检查日志
        print_info "Checking for KASAN error reports..."
        local after_logs=$(dmesg | tail -100)
        local kasan_reports=$(echo "$after_logs" | grep -A5 -B5 -i "kasan")
        
        if echo "$kasan_reports" | grep -q -i "out-of-bounds\|slab-out-of-bounds"; then
            print_success "KASAN detected out-of-bounds access!"
            echo ""
            echo "Error report:"
            echo "$kasan_reports" | tail -20
        else
            print_error "KASAN did not report out-of-bounds error"
            print_info "This could mean:"
            print_info "1. KASAN is not working properly"
            print_info "2. Error was not triggered"
            print_info "3. Error was silently handled"
        fi
        
        # 卸载模块
        sudo rmmod kasan_module 2>/dev/null && print_success "Module unloaded" || \
        print_error "Module unload failed (may be expected with KASAN errors)"
    else
        print_error "Failed to load module for out-of-bounds test"
        print_info "This may be expected if KASAN caused panic"
    fi
}

test_use_after_free() {
    print_header "Testing Use-After-Free Detection"
    
    print_info "WARNING: This test will trigger use-after-free errors!"
    echo ""
    
    read -p "Continue with use-after-free test? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Skipping use-after-free test"
        return
    fi
    
    # 清理之前的模块
    sudo rmmod kasan_module 2>/dev/null || true
    
    # 清空内核日志缓冲区
    sudo dmesg -C
    
    print_info "Loading module with use-after-free test (test_mode=2)..."
    
    # 加载模块（释放后使用测试模式）
    if sudo insmod "$MODULES_DIR/kasan_module.ko" test_mode=2 iterations=1 debug=1 panic_on_error=0; then
        print_info "Module loaded (errors expected)"
        
        # 等待
        sleep 2
        
        # 检查日志
        print_info "Checking for use-after-free reports..."
        local kasan_reports=$(dmesg | grep -A5 -B5 -i "use-after-free\|uaf")
        
        if [ -n "$kasan_reports" ]; then
            print_success "KASAN detected use-after-free!"
            echo ""
            echo "Error report:"
            echo "$kasan_reports" | tail -20
        else
            print_error "KASAN did not report use-after-free"
            print_info "Checking for any KASAN reports..."
            dmesg | grep -i kasan | tail -10
        fi
        
        # 卸载模块
        sudo rmmod kasan_module 2>/dev/null && print_success "Module unloaded" || \
        print_error "Module unload failed"
    else
        print_error "Failed to load module for use-after-free test"
    fi
}

test_double_free() {
    print_header "Testing Double-Free Detection"
    
    print_info "Testing double-free detection..."
    
    # 清理之前的模块
    sudo rmmod kasan_module 2>/dev/null || true
    
    # 清空内核日志缓冲区
    sudo dmesg -C
    
    print_info "Loading module with double-free test (test_mode=3)..."
    
    # 加载模块（双重释放测试模式）
    if sudo insmod "$MODULES_DIR/kasan_module.ko" test_mode=3 iterations=1 debug=1 panic_on_error=0; then
        print_info "Module loaded (errors expected)"
        
        # 等待
        sleep 2
        
        # 检查日志
        print_info "Checking for double-free reports..."
        local kasan_reports=$(dmesg | grep -A5 -B5 -i "double-free\|invalid-free")
        
        if [ -n "$kasan_reports" ]; then
            print_success "KASAN detected double-free!"
            echo ""
            echo "Error report:"
            echo "$kasan_reports" | tail -20
        else
            print_error "KASAN did not report double-free"
        fi
        
        # 卸载模块
        sudo rmmod kasan_module 2>/dev/null && print_success "Module unloaded" || \
        print_error "Module unload failed"
    else
        print_error "Failed to load module for double-free test"
    fi
}

run_comprehensive_test() {
    print_header "Running Comprehensive KASAN Test"
    
    print_info "This will run all KASAN tests sequentially"
    print_info "Each test will load and unload the test module"
    echo ""
    
    read -p "Continue with comprehensive test? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Skipping comprehensive test"
        return
    fi
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 运行各个测试
    test_safe_operations
    sleep 2
    
    test_out_of_bounds
    sleep 2
    
    test_use_after_free
    sleep 2
    
    test_double_free
    
    # 计算耗时
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_success "Comprehensive test completed in ${duration} seconds"
}

create_kasan_test_program() {
    print_header "Creating User-space KASAN Test Program"
    
    # 创建用户空间测试程序
    local test_program="$SRC_DIR/kasan_user_test.c"
    
    cat > "$test_program" << 'EOF'
/**
 * kasan_user_test.c - 用户空间内存错误测试程序
 * 用于对比用户空间ASAN和内核空间KASAN
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifdef __SANITIZE_ADDRESS__
    #define ASAN_ENABLED 1
#else
    #define ASAN_ENABLED 0
#endif

void test_heap_buffer_overflow() {
    printf("Test 1: Heap buffer overflow\n");
    
    char *buffer = malloc(10);
    if (!buffer) {
        printf("  Failed to allocate memory\n");
        return;
    }
    
    printf("  Allocated 10 bytes at %p\n", buffer);
    
    // 故意越界写入
    printf("  Writing 20 bytes (10 bytes overflow)...\n");
    for (int i = 0; i < 20; i++) {
        buffer[i] = 'A' + (i % 26);
    }
    
    printf("  Buffer content: %.10s...\n", buffer);
    
    free(buffer);
    printf("  Memory freed\n");
}

void test_stack_buffer_overflow() {
    printf("\nTest 2: Stack buffer overflow\n");
    
    char stack_buffer[16];
    printf("  Stack buffer at %p (16 bytes)\n", stack_buffer);
    
    // 故意越界写入
    printf("  Writing 32 bytes (16 bytes overflow)...\n");
    for (int i = 0; i < 32; i++) {
        stack_buffer[i] = 'B' + (i % 26);
    }
    
    printf("  Buffer content: %.16s...\n", stack_buffer);
}

void test_use_after_free() {
    printf("\nTest 3: Use after free\n");
    
    int *ptr = malloc(sizeof(int) * 5);
    if (!ptr) {
        printf("  Failed to allocate memory\n");
        return;
    }
    
    printf("  Allocated 5 integers at %p\n", ptr);
    ptr[0] = 0xDEADBEEF;
    
    free(ptr);
    printf("  Memory freed\n");
    
    // 故意使用已释放的内存
    printf("  Using freed memory (should be detected)...\n");
    ptr[0] = 0xCAFEBABE;
    printf("  Value at freed memory: 0x%x\n", ptr[0]);
}

void test_double_free() {
    printf("\nTest 4: Double free\n");
    
    char *buffer = malloc(32);
    if (!buffer) {
        printf("  Failed to allocate memory\n");
        return;
    }
    
    printf("  Allocated 32 bytes at %p\n", buffer);
    
    free(buffer);
    printf("  First free completed\n");
    
    // 故意双重释放
    printf("  Attempting double free (should be detected)...\n");
    free(buffer);
    printf("  Second free completed\n");
}

void test_memory_leak() {
    printf("\nTest 5: Memory leak (intentional)\n");
    
    void *leak1 = malloc(1024);
    void *leak2 = malloc(2048);
    
    printf("  Allocated 1024 bytes at %p\n", leak1);
    printf("  Allocated 2048 bytes at %p\n", leak2);
    
    // 故意不释放 - 内存泄漏
    printf("  Intentionally not freeing memory\n");
    printf("  Total leaked: 3072 bytes\n");
}

int main() {
    printf("=== User-space Memory Error Test Program ===\n");
    printf("ASAN enabled: %s\n", ASAN_ENABLED ? "YES" : "NO");
    printf("Compile with: gcc -fsanitize=address -o kasan_user_test kasan_user_test.c\n");
    printf("\n");
    
    if (!ASAN_ENABLED) {
        printf("WARNING: AddressSanitizer (ASAN) is not enabled!\n");
        printf("Memory errors will NOT be detected in user space.\n");
        printf("This program may crash or behave unexpectedly.\n");
        printf("\n");
        
        printf("Do you want to continue without ASAN? (y/n): ");
        char response;
        scanf("%c", &response);
        if (response != 'y' && response != 'Y') {
            printf("Exiting...\n");
            return 0;
        }
    }
    
    printf("Starting tests...\n");
    printf("=============================================\n");
    
    test_heap_buffer_overflow();
    test_stack_buffer_overflow();
    test_use_after_free();
    test_double_free();
    test_memory_leak();
    
    printf("\n=============================================\n");
    printf("Tests completed.\n");
    
    if (ASAN_ENABLED) {
        printf("Check program output for ASAN error reports.\n");
    } else {
        printf("Without ASAN, errors may not be detected.\n");
        printf("The program may have crashed or continued with errors.\n");
    }
    
    return 0;
}
EOF
    
    print_info "Compiling user-space test program..."
    
    # 尝试用ASAN编译
    if gcc -fsanitize=address -o "$SRC_DIR/kasan_user_test" "$test_program" 2>&1 | tee "$LOGS_DIR/asan_compile.log"; then
        print_success "User-space test program compiled with ASAN"
        print_info "Run: $SRC_DIR/kasan_user_test"
    else
        print_info "Trying to compile without ASAN..."
        if gcc -o "$SRC_DIR/kasan_user_test" "$test_program" 2>&1 | tee "$LOGS_DIR/normal_compile.log"; then
            print_success "User-space test program compiled (without ASAN)"
            print_info "Note: Memory errors will not be detected without ASAN"
        else
            print_error "Failed to compile user-space test program"
        fi
    fi
}

generate_test_report() {
    print_header "Generating KASAN Test Report"
    
    local report_file="$LOGS_DIR/kasan_test_report_$(date +%Y%m%d_%H%M%S).txt"
    local kernel_version=$(uname -r)
    local kasan_config=""
    
    # 获取KASAN配置
    if [ -f "/boot/config-$kernel_version" ]; then
        kasan_config=$(grep -i "CONFIG_KASAN" "/boot/config-$kernel_version")
    elif [ -f "/proc/config.gz" ]; then
        kasan_config=$(zcat /proc/config.gz | grep -i "CONFIG_KASAN")
    fi
    
    cat > "$report_file" << EOF
KASAN Test Report
=================
Generated: $(date)
Kernel Version: $kernel_version

1. KASAN Configuration:
$kasan_config

2. System Information:
$(uname -a)

3. Recent KASAN Messages:
$(dmesg | grep -i kasan | tail -20)

4. Test Module Information:
$(modinfo "$MODULES_DIR/kasan_module.ko" 2>/dev/null || echo "Module not found")

5. Test Results Summary:
- Safe operations: $(if dmesg | grep -q "Safe Operations.*PASS"; then echo "PASS"; else echo "FAIL/Unknown"; fi)
- Out-of-bounds detection: $(if dmesg | grep -q "out-of-bounds"; then echo "DETECTED"; else echo "NOT DETECTED"; fi)
- Use-after-free detection: $(if dmesg | grep -q "use-after-free"; then echo "DETECTED"; else echo "NOT DETECTED"; fi)
- Double-free detection: $(if dmesg | grep -q "double-free"; then echo "DETECTED"; else echo "NOT DETECTED"; fi)

6. Recommendations:
$(if echo "$kasan_config" | grep -q "=y"; then
    echo "- KASAN is properly configured"
else
    echo "- KASAN is not enabled or misconfigured"
fi)

7. Log Files:
$(ls -la "$LOGS_DIR"/kasan_*.log 2>/dev/null | awk '{print $9 " (" $5 " bytes)"}' || echo "No log files found")

Test completed.
EOF
    
    cat "$report_file"
    print_success "Report saved to: $report_file"
}

# 主函数
main() {
    print_header "KASAN Memory Error Detection Test"
    echo "This script tests Kernel Address Sanitizer (KASAN) functionality"
    echo ""
    
    # 检查权限
    check_root
    
    # 创建必要的目录
    mkdir -p "$LOGS_DIR"
    mkdir -p "$MODULES_DIR"
    
    # 检查KASAN支持
    check_kasan_support
    
    # 检查内核日志
    check_kernel_logs
    
    # 编译测试模块
    compile_test_module
    
    # 运行测试
    run_comprehensive_test
    
    # 创建用户空间测试程序
    create_kasan_test_program
    
    # 生成测试报告
    generate_test_report
    
    # 最终提示
    print_header "KASAN Testing Complete"
    print_success "KASAN testing completed successfully!"
    echo ""
    echo "Summary:"
    echo "1. KASAN support verified"
    echo "2. Test module compiled and tested"
    echo "3. Error detection tested"
    echo "4. Test report generated"
    echo ""
    echo "Files created:"
    echo "  Test module: $MODULES_DIR/kasan_module.ko"
    echo "  User test: $SRC_DIR/kasan_user_test"
    echo "  Logs: $LOGS_DIR/kasan_*.log"
    echo "  Report: $LOGS_DIR/kasan_test_report_*.txt"
    echo ""
    echo "Next steps:"
    echo "1. Review the test report above"
    echo "2. Check kernel logs: dmesg | grep -i kasan"
    echo "3. Run user-space test: $SRC_DIR/kasan_user_test"
    echo "4. Experiment with different test_mode values"
    echo ""
    echo "Important: KASAN adds runtime overhead. Use only for development/testing."
}

# 运行主函数
main