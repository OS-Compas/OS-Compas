
### 15. 编译脚本

**scripts/build.sh**

```bash
#!/bin/bash

# RT-Thread IoT传感器项目编译脚本
# 适用于STM32F103C8T6 + RT-Thread

set -e  # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
BUILD_DIR="$PROJECT_DIR/build"
SRC_DIR="$PROJECT_DIR/src"

echo "========================================"
echo "IoT Sensor Project Build Script"
echo "RT-Thread + STM32F103C8T6"
echo "========================================"

# 检查环境变量
if [ -z "$RTT_ROOT" ]; then
    echo "Error: RTT_ROOT environment variable not set"
    echo "Please set RTT_ROOT to your RT-Thread root directory"
    echo "Example: export RTT_ROOT=/path/to/rt-thread"
    exit 1
fi

echo "RT-Thread root: $RTT_ROOT"
echo "Project directory: $PROJECT_DIR"

# 检查必要工具
echo -e "\nChecking tools..."
command -v arm-none-eabi-gcc >/dev/null 2>&1 || {
    echo "Error: arm-none-eabi-gcc not found"
    echo "Please install ARM GCC toolchain"
    exit 1
}

command -v scons >/dev/null 2>&1 || {
    echo "Error: scons not found"
    echo "Please install scons: pip install scons"
    exit 1
}

# 创建构建目录
mkdir -p "$BUILD_DIR"

# 进入项目目录
cd "$PROJECT_DIR"

# 清理之前的构建
echo -e "\nCleaning previous build..."
scons -c 2>/dev/null || true
rm -rf "$BUILD_DIR"/* 2>/dev/null || true

# 配置工程
echo -e "\nConfiguring project..."
if [ ! -f "rtconfig.h" ]; then
    cp "$SRC_DIR/rtconfig.h" .
fi

# 检查配置文件
if [ ! -f "$PROJECT_DIR/config/wifi_config.h" ]; then
    echo "Warning: wifi_config.h not found, creating default..."
    cp "$PROJECT_DIR/config/wifi_config.h.example" \
       "$PROJECT_DIR/config/wifi_config.h" 2>/dev/null || true
fi

# 构建项目
echo -e "\nBuilding project..."
if scons -j4; then
    echo -e "\nBuild successful!"
    
    # 复制生成的文件
    cp rtthread.bin "$BUILD_DIR/"
    cp rtthread.elf "$BUILD_DIR/"
    cp rtthread.map "$BUILD_DIR/" 2>/dev/null || true
    
    # 显示文件信息
    echo -e "\nGenerated files:"
    ls -lh "$BUILD_DIR"/
    
    # 显示固件大小
    echo -e "\nFirmware size:"
    arm-none-eabi-size rtthread.elf
    
    # 生成Hex文件（可选）
    echo -e "\nGenerating HEX file..."
    arm-none-eabi-objcopy -O ihex rtthread.elf "$BUILD_DIR/rtthread.hex"
    
    echo -e "\nBuild completed at: $(date)"
else
    echo -e "\nBuild failed!"
    exit 1
fi

# 生成烧录脚本
cat > "$BUILD_DIR/flash_openocd.sh" << 'EOF'
#!/bin/bash
# OpenOCD烧录脚本
openocd -f interface/stlink.cfg \
        -f target/stm32f1x.cfg \
        -c "program rtthread.bin 0x08000000 verify reset exit"
EOF

chmod +x "$BUILD_DIR/flash_openocd.sh"

echo -e "\nTo flash the firmware, run:"
echo "  cd $BUILD_DIR"
echo "  ./flash_openocd.sh"
echo "Or use STM32CubeProgrammer/ST-Link Utility"