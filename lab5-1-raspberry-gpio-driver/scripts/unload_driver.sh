#!/bin/bash

# GPIO驱动卸载脚本

echo "=== Raspberry Pi GPIO Driver Unloader ==="

# 检查模块是否已加载
if ! lsmod | grep -q gpio_led; then
    echo "Module is not loaded"
else
    # 卸载模块
    echo "Unloading module..."
    if sudo rmmod gpio_led; then
        echo "Module unloaded successfully"
    else
        echo "Failed to unload module"
        exit 1
    fi
fi

# 删除设备文件
if [ -e "/dev/gpio_led" ]; then
    echo "Removing device file /dev/gpio_led..."
    sudo rm -f /dev/gpio_led
    echo "Device file removed"
fi

# 清理GPIO（如果通过sysfs导出）
if [ -d "/sys/class/gpio/gpio17" ]; then
    echo "Cleaning up GPIO17..."
    echo 17 | sudo tee /sys/class/gpio/unexport > /dev/null 2>&1 || true
fi

if [ -d "/sys/class/gpio/gpio27" ]; then
    echo "Cleaning up GPIO27..."
    echo 27 | sudo tee /sys/class/gpio/unexport > /dev/null 2>&1 || true
fi

echo -e "\nRecent kernel messages:"
dmesg | tail -5

echo -e "\nUnload complete!"