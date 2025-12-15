#!/bin/bash

# 按钮输入测试脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../scripts"
BUILD_DIR="$SCRIPT_DIR/../build"

echo "=== Button Input Test ==="

# 检查硬件连接提示
echo "IMPORTANT: Make sure button is connected to GPIO27"
echo "Button: GPIO27 -> Button -> 3.3V"
echo "       GPIO27 -> 10kΩ resistor -> GND"
read -p "Is button connected? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Test skipped - button not connected"
    exit 0
fi

# 清理环境
echo "Step 1: Cleaning up..."
"$SCRIPTS_DIR/unload_driver.sh" 2>/dev/null || true

# 构建驱动
echo "Step 2: Building driver..."
"$SCRIPTS_DIR/build.sh"

# 加载驱动（带按钮支持）
echo -e "\nStep 3: Loading driver with button support..."
"$SCRIPTS_DIR/load_driver.sh" 1 17

sleep 1

# 测试1: 检查设备文件可读
echo -e "\nTest 1: Checking device readability..."
if [ -r "/dev/gpio_led" ]; then
    echo "✓ Test 1 PASSED: Device file is readable"
else
    echo "✗ Test 1 FAILED: Cannot read device file"
    exit 1
fi

# 测试2: 读取按钮状态（初始状态）
echo -e "\nTest 2: Reading initial button state..."
INITIAL_STATE=$(sudo cat /dev/gpio_led 2>/dev/null || echo "ERROR")

if [[ "$INITIAL_STATE" =~ ^[01]$ ]]; then
    echo "✓ Test 2 PASSED: Initial state is $INITIAL_STATE"
    echo "  (0=released, 1=pressed)"
else
    echo "✗ Test 2 FAILED: Could not read initial state"
    echo "  Got: $INITIAL_STATE"
    exit 1
fi

# 测试3: 使用测试程序读取
echo -e "\nTest 3: Using test program to read..."
if [ -f "$BUILD_DIR/gpio_led_test" ]; then
    echo "Current button state:"
    "$BUILD_DIR/gpio_led_test" read
    echo "✓ Test 3 PASSED: Test program can read button"
else
    echo "⚠ Test 3 SKIPPED: Test program not found"
fi

# 测试4: 交互式测试
echo -e "\nTest 4: Interactive button test"
echo "Press and release the button several times"
echo "Checking for state changes..."
echo "Press Ctrl+C when done"

COUNT=0
LAST_STATE="$INITIAL_STATE"
TIMEOUT=30  # 30秒超时
START_TIME=$(date +%s)

while true; do
    CURRENT_STATE=$(sudo cat /dev/gpio_led 2>/dev/null)
    
    if [[ "$CURRENT_STATE" != "$LAST_STATE" ]]; then
        COUNT=$((COUNT + 1))
        echo "  Change $COUNT: $LAST_STATE -> $CURRENT_STATE"
        LAST_STATE="$CURRENT_STATE"
    fi
    
    # 检查超时
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "Timeout reached after $TIMEOUT seconds"
        break
    fi
    
    sleep 0.1
done

if [ $COUNT -ge 2 ]; then
    echo "✓ Test 4 PASSED: Detected $COUNT button state changes"
else
    echo "⚠ Test 4: Only detected $COUNT changes (expected at least 2)"
fi

# 测试5: LED和按钮同时工作
echo -e "\nTest 5: Simultaneous LED and button test..."
echo "Turning LED ON while reading button..."
echo '1' | sudo tee /dev/gpio_led > /dev/null
sleep 0.5
BUTTON_WHILE_ON=$(sudo cat /dev/gpio_led 2>/dev/null)
echo "Button state while LED ON: $BUTTON_WHILE_ON"

echo '0' | sudo tee /dev/gpio_led > /dev/null
sleep 0.5
BUTTON_WHILE_OFF=$(sudo cat /dev/gpio_led 2>/dev/null)
echo "Button state while LED OFF: $BUTTON_WHILE_OFF"

if [[ "$BUTTON_WHILE_ON" =~ ^[01]$ ]] && [[ "$BUTTON_WHILE_OFF" =~ ^[01]$ ]]; then
    echo "✓ Test 5 PASSED: Button reading works while controlling LED"
else
    echo "⚠ Test 5: Button reading may be affected by LED control"
fi

# 清理
echo -e "\nStep 4: Cleaning up..."
"$SCRIPTS_DIR/unload_driver.sh"

echo -e "\n=== Button tests completed! ==="
echo "Summary:"
echo "- Device file: /dev/gpio_led"
echo "- Button GPIO: 27"
echo "- LED GPIO: 17"
echo "- Button reads return '0' (released) or '1' (pressed)"