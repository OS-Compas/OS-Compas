
---

## 🛠️ **scripts/ 目录内容**

### 1. **scripts/build.sh** - 构建脚本

```bash
#!/bin/bash

# 树莓派GPIO驱动构建脚本

set -e  # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/../src"
BUILD_DIR="$SCRIPT_DIR/../build"

echo "=== Raspberry Pi GPIO Driver Build Script ==="

# 检查是否在正确的目录
if [ ! -f "$SRC_DIR/gpio_led.c" ]; then
    echo "Error: gpio_led.c not found in $SRC_DIR"
    exit 1
fi

# 创建构建目录
mkdir -p "$BUILD_DIR"

# 检查是否在树莓派上
if ! uname -r | grep -q raspberrypi; then
    echo "Warning: Not running on Raspberry Pi"
    echo "This driver is designed for Raspberry Pi"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 检查内核头文件
echo "Checking kernel headers..."
if [ ! -d "/lib/modules/$(uname -r)/build" ]; then
    echo "Error: Kernel headers not found."
    echo "Please install kernel headers:"
    echo "  sudo apt update"
    echo "  sudo apt install raspberrypi-kernel-headers"
    exit 1
fi

# 进入源码目录
cd "$SRC_DIR"

# 清理之前的构建
echo "Cleaning previous build..."
make clean > /dev/null 2>&1 || true

# 构建模块
echo "Building kernel module..."
if make; then
    # 复制生成的文件到构建目录
    cp gpio_led.ko "$BUILD_DIR/"
    
    # 编译测试程序
    echo "Building test program..."
    if gcc -o gpio_led_test gpio_led_test.c; then
        cp gpio_led_test "$BUILD_DIR/"
    else
        echo "Warning: Failed to build test program"
    fi
    
    echo "Build successful!"
    echo -e "\nGenerated files in $BUILD_DIR/:"
    ls -la "$BUILD_DIR"/
    
    # 显示模块信息
    echo -e "\nModule information:"
    modinfo "$BUILD_DIR/gpio_led.ko"
    
    # 显示硬件连接提示
    echo -e "\nHardware connection reminder:"
    echo "  LED: GPIO17 (pin 11) -> 220Ω resistor -> LED+"
    echo "       LED- -> GND (pin 6)"
    echo "  Button (optional): GPIO27 (pin 13) -> Button -> 3.3V (pin 1)"
    echo "                     GPIO27 (pin 13) -> 10kΩ resistor -> GND"
    
else
    echo "Build failed!"
    exit 1
fi