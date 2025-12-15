#!/bin/bash

# GPIO驱动加载脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../build"
MODULE_PATH="$BUILD_DIR/gpio_led.ko"

echo "=== Raspberry Pi GPIO Driver Loader ==="

# 检查模块文件
if [ ! -f "$MODULE_PATH" ]; then
    echo "Error: Module not found at $MODULE_PATH"
    echo "Please run build.sh first"
    exit 1
fi

# 检查是否已加载
if lsmod | grep -q gpio_led; then
    echo "Module is already loaded. Unloading first..."
    sudo rmmod gpio_led 2>/dev/null || true
    sleep 1
fi

# 删除旧的设备文件
if [ -e "/dev/gpio_led" ]; then
    echo "Removing old device file..."
    sudo rm -f /dev/gpio_led
fi

# 设置模块参数
BUTTON_ENABLE="${1:-0}"
GPIO_PIN="${2:-17}"

echo "Loading module with parameters:"
echo "  gpio_pin=$GPIO_PIN"
echo "  use_button=$BUTTON_ENABLE"

# 加载模块
if sudo insmod "$MODULE_PATH" gpio_pin=$GPIO_PIN use_button=$BUTTON_ENABLE; then
    echo "Module loaded successfully!"
    
    # 获取主设备号
    MAJOR=$(awk '/gpio_led/ {print $1}' /proc/devices)
    if [ -z "$MAJOR" ]; then
        echo "Error: Failed to get major number"
        exit 1
    fi
    
    # 创建设备文件
    echo "Creating device file /dev/gpio_led with major=$MAJOR..."
    sudo mknod /dev/gpio_led c $MAJOR 0
    sudo chmod 666 /dev/gpio_led
    
    # 显示加载信息
    echo -e "\n=== Load information ==="
    echo "Module status:"
    lsmod | grep gpio_led
    
    echo -e "\nDevice file:"
    ls -l /dev/gpio_led
    
    echo -e "\nRecent kernel messages:"
    dmesg | tail -8 | grep -E '(GPIO|gpio|LED|led)'
    
    echo -e "\n=== Usage examples ==="
    echo "Turn LED ON:  echo '1' > /dev/gpio_led"
    echo "Turn LED OFF: echo '0' > /dev/gpio_led"
    
    if [ "$BUTTON_ENABLE" = "1" ]; then
        echo "Read button:  cat /dev/gpio_led"
    fi
    
    # 如果有测试程序，提供使用提示
    if [ -f "$BUILD_DIR/gpio_led_test" ]; then
        echo -e "\nTest program:"
        echo "  $BUILD_DIR/gpio_led_test on"
        echo "  $BUILD_DIR/gpio_led_test off"
        echo "  $BUILD_DIR/gpio_led_test blink"
        if [ "$BUTTON_ENABLE" = "1" ]; then
            echo "  $BUILD_DIR/gpio_led_test read"
        fi
    fi
    
else
    echo "Failed to load module!"
    echo "Check dmesg for details:"
    dmesg | tail -10
    exit 1
fi