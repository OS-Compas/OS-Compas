#!/bin/bash

# Linux内核编译脚本 - 用于实验4.1
# 启用SELinux和KASAN安全特性

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_ROOT/logs"
CONFIGS_DIR="$PROJECT_ROOT/configs"

# 内核版本配置
KERNEL_VERSION="5.15.0"  # 可根据需要修改
KERNEL_SOURCE_URL="https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.xz"
SOURCE_DIR="/usr/src/linux-$KERNEL_VERSION"
BUILD_DIR="/usr/src/linux-build-$KERNEL_VERSION-$(date +%Y%m%d)"
CONFIG_FILE="$BUILD_DIR/.config"

# 创建日志目录
mkdir -p "$LOGS_DIR"

echo "=== Linux Kernel Security Build Script ==="
echo "Target Kernel Version: $KERNEL_VERSION"
echo "Build Directory: $BUILD_DIR"
echo "Logs Directory: $LOGS_DIR"
echo ""

# 步骤1：安装依赖
echo "[1/8] Installing dependencies..."
sudo apt update 2>&1 | tee "$LOGS_DIR/apt_update.log"
sudo apt install -y \
    build-essential \
    libncurses-dev \
    libssl-dev \
    flex \
    bison \
    libelf-dev \
    bc \
    rsync \
    kmod \
    cpio \
    wget \
    xz-utils \
    git 2>&1 | tee "$LOGS_DIR/deps_install.log"

# 步骤2：下载内核源码
echo "[2/8] Downloading kernel source..."
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Downloading kernel source from $KERNEL_SOURCE_URL"
    wget "$KERNEL_SOURCE_URL" -O /tmp/linux-$KERNEL_VERSION.tar.xz 2>&1 | tee "$LOGS_DIR/kernel_download.log"
    
    if [ ! -f /tmp/linux-$KERNEL_VERSION.tar.xz ]; then
        echo "Error: Failed to download kernel source"
        exit 1
    fi
    
    echo "Extracting kernel source..."
    sudo mkdir -p /usr/src
    sudo tar -xf /tmp/linux-$KERNEL_VERSION.tar.xz -C /usr/src/ 2>&1 | tee "$LOGS_DIR/kernel_extract.log"
else
    echo "Kernel source already exists at $SOURCE_DIR"
fi

# 步骤3：准备构建目录
echo "[3/8] Preparing build directory..."
sudo mkdir -p "$BUILD_DIR"
sudo chown -R $USER:$USER "$BUILD_DIR"
cp -r "$SOURCE_DIR"/* "$BUILD_DIR"/

cd "$BUILD_DIR"

# 步骤4：应用配置片段
echo "[4/8] Applying security configuration fragments..."
if [ -f "$CONFIGS_DIR/kernel_config_fragment" ]; then
    echo "Using custom config fragment from $CONFIGS_DIR/kernel_config_fragment"
    cat "$CONFIGS_DIR/kernel_config_fragment" >> "$CONFIG_FILE" 2>/dev/null || true
fi

# 步骤5：配置内核
echo "[5/8] Configuring kernel with security features..."
make clean 2>&1 | tee "$LOGS_DIR/make_clean.log"

# 使用默认配置
make defconfig 2>&1 | tee "$LOGS_DIR/make_defconfig.log"

# 启用安全特性
echo "Enabling security features..."
./scripts/config --file "$CONFIG_FILE" \
    --enable CONFIG_IKCONFIG \
    --enable CONFIG_IKCONFIG_PROC \
    --enable CONFIG_SECURITY \
    --enable CONFIG_SECURITY_SELINUX \
    --enable CONFIG_SECURITY_SELINUX_BOOTPARAM \
    --enable CONFIG_SECURITY_SELINUX_DISABLE \
    --enable CONFIG_DEFAULT_SECURITY_SELINUX \
    --enable CONFIG_KASAN \
    --enable CONFIG_KASAN_GENERIC \
    --enable CONFIG_DEBUG_INFO \
    --enable CONFIG_DEBUG_KERNEL \
    --enable CONFIG_DEBUG_FS \
    --set-val CONFIG_DEBUG_INFO_DWARF5 y \
    --enable CONFIG_DEBUG_INFO_BTF 2>&1 | tee "$LOGS_DIR/kernel_config.log"

# 更新配置
make olddefconfig 2>&1 | tee "$LOGS_DIR/olddefconfig.log"

# 交互式配置界面
echo ""
echo "Launching menuconfig for final adjustments..."
echo "Please enable any additional security features you want"
read -p "Press Enter to continue to menuconfig or Ctrl+C to skip..."
make menuconfig

# 保存最终配置
cp .config "$LOGS_DIR/kernel_final_config"

# 步骤6：编译内核
echo "[6/8] Compiling kernel (this may take 30-90 minutes)..."
echo "Start time: $(date)"
nproc=$(nproc)
echo "Using $nproc CPU cores"

# 编译bzImage
make -j$((nproc + 1)) 2>&1 | tee "$LOGS_DIR/kernel_compile.log"

# 编译模块
make modules -j$((nproc + 1)) 2>&1 | tee "$LOGS_DIR/modules_compile.log"

echo "Compilation completed at: $(date)"

# 步骤7：安装内核
echo "[7/8] Installing new kernel..."
sudo make modules_install 2>&1 | tee "$LOGS_DIR/modules_install.log"
sudo make install 2>&1 | tee "$LOGS_DIR/kernel_install.log"

# 步骤8：更新引导配置
echo "[8/8] Updating boot configuration..."
if command -v update-grub &> /dev/null; then
    sudo update-grub 2>&1 | tee "$LOGS_DIR/update_grub.log"
elif command -v grub-mkconfig &> /dev/null; then
    sudo grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tee "$LOGS_DIR/update_grub.log"
elif command -v grub2-mkconfig &> /dev/null; then
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg 2>&1 | tee "$LOGS_DIR/update_grub.log"
else
    echo "Warning: Could not find GRUB update command"
fi

echo ""
echo "=== Build Summary ==="
echo "Kernel Version: $KERNEL_VERSION"
echo "Build Directory: $BUILD_DIR"
echo "Config File: $CONFIG_FILE"
echo "Logs saved to: $LOGS_DIR/"
echo ""
echo "=== Next Steps ==="
echo "1. Reboot your system"
echo "2. Select the new kernel from GRUB menu"
echo "3. Run 'uname -r' to verify new kernel"
echo "4. Run './scripts/enable_selinux.sh' to configure SELinux"
echo ""
echo "=== IMPORTANT NOTES ==="
echo "- Ensure you have at least 20GB free disk space"
echo "- The compilation may take 30-90 minutes"
echo "- Keep the system powered on and connected during compilation"
echo "- Backup important data before rebooting"

# 创建重启提醒
cat > "$PROJECT_ROOT/REBOOT_REMINDER.txt" << EOF
Kernel compilation completed successfully!

To use the new kernel with security features:
1. Reboot your computer: sudo reboot
2. In GRUB boot menu, select the new kernel (usually the first entry)
3. After boot, verify with: uname -r
4. Configure SELinux: ./scripts/enable_selinux.sh

New kernel details:
- Version: $KERNEL_VERSION
- Build date: $(date)
- Security features: SELinux, KASAN, DEBUG_INFO

Log files are available in: $LOGS_DIR/
EOF

echo ""
echo "Reboot reminder saved to: $PROJECT_ROOT/REBOOT_REMINDER.txt"
echo "=== Build Completed Successfully ==="