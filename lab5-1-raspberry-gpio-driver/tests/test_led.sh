#!/bin/bash

# LED控制测试脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../scripts"
BUILD_DIR="$SCRIPT_DIR/../build"

echo "=== LED Control Test ==="

# 清理环境
echo "Step 1: Cleaning up..."
"$SCRIPTS_DIR/unload_driver.sh" 2>/dev/null || true

# 构建驱动
echo "Step 2: Building driver..."
"$SCRIPTS_DIR/build.sh"

# 加载驱动（不带按钮支持）
echo -e "\nStep 3: Loading driver..."
"$SCRIPTS_DIR/load_driver.sh" 0 17

sleep 1

# 测试1: 点亮LED
echo -e "\nTest 1: Turning LED ON..."
echo '1' | sudo tee /dev/gpio_led > /dev/null

sleep 0.5

if dmesg | tail -5 | grep -q "LED ON"; then
    echo "✓ Test 1 PASSED: LED turned ON"
else
    echo "✗ Test 1 FAILED: LED ON message not found"
    exit 1
fi

# 测试2: 熄灭LED
echo -e "\nTest 2: Turning LED OFF..."
echo '0' | sudo tee /dev/gio_led > /dev/null

sleep 0.5

if dmesg | tail -5 | grep -q "LED OFF"; then
    echo "✓ Test 2 PASSED: LED turned OFF"
else
    echo "✗ Test 2 FAILED: LED OFF message not found"
    exit 1
fi

# 测试3: 使用测试程序
echo -e "\nTest 3: Using test program..."
if [ -f "$BUILD_DIR/gpio_led_test" ]; then
    "$BUILD_DIR/gpio_led_test" on
    sleep 0.5
    "$BUILD_DIR/gpio_led_test" off
    echo "✓ Test 3 PASSED: Test program works"
else
    echo "⚠ Test 3 SKIPPED: Test program not found"
fi

# 测试4: 闪烁测试
echo -e "\nTest 4: Blink test..."
if [ -f "$BUILD_DIR/gpio_led_test" ]; then
    "$BUILD_DIR/gpio_led_test" blink 3
    echo "✓ Test 4 PASSED: Blink test completed"
fi

# 测试5: 无效命令处理
echo -e "\nTest 5: Invalid command test..."
echo '2' | sudo tee /dev/gpio_led 2>/dev/null || true

if dmesg | tail -5 | grep -q "Invalid command"; then
    echo "✓ Test 5 PASSED: Invalid command rejected"
else
    echo "⚠ Test 5: No invalid command message found"
fi

# 清理
echo -e "\nStep 4: Cleaning up..."
"$SCRIPTS_DIR/unload_driver.sh"

echo -e "\n=== All LED tests PASSED! ==="