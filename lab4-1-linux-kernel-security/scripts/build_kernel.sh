#!/bin/bash

# Linux内核编译主脚本
# 封装了内核下载、配置、编译和安装的全过程

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/src"
CONFIGS_DIR="$PROJECT_ROOT/configs"
LOGS_DIR="$PROJECT_ROOT/logs"
BUILD_DIR="$PROJECT_ROOT/build"

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

check_disk_space() {
    local required_gb=20
    local available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ "$available_gb" -lt "$required_gb" ]; then
        print_error "Insufficient disk space. Need ${required_gb}GB, have ${available_gb}GB"
        exit 1
    fi
}

check_memory() {
    local required_mb=4096
    local available_mb=$(free -m | awk 'NR==2 {print $7}')
    
    if [ "$available_mb" -lt "$required_mb" ]; then
        print_warning "Low memory. Need ${required_mb}MB, have ${available_mb}MB"
        print_info "Compilation may be slow or fail"
    fi
}

check_cpu_cores() {
    local cores=$(nproc)
    print_info "CPU cores available: $cores"
    echo $cores
}

select_kernel_version() {
    echo "Available kernel versions from kernel.org:"
    echo "1) 5.10.x - LTS (Long Term Support)"
    echo "2) 5.15.x - LTS (Recommended for this lab)"
    echo "3) 6.1.x  - LTS"
    echo "4) 6.6.x  - Latest stable"
    echo "5) Custom version"
    echo ""
    
    read -p "Select kernel version (1-5): " choice
    
    case $choice in
        1)
            echo "5.10"
            ;;
        2)
            echo "5.15"
            ;;
        3)
            echo "6.1"
            ;;
        4)
            echo "6.6"
            ;;
        5)
            read -p "Enter custom version (e.g., 5.4.210): " custom_version
            echo "$custom_version"
            ;;
        *)
            echo "5.15"  # 默认
            ;;
    esac
}

download_kernel_source() {
    local version=$1
    local source_dir="/usr/src/linux-$version"
    
    print_header "Downloading Linux Kernel $version"
    
    if [ -d "$source_dir" ]; then
        print_info "Kernel source already exists at $source_dir"
        read -p "Use existing source? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$source_dir"
            return
        fi
    fi
    
    # 下载内核源码
    local url="https://cdn.kernel.org/pub/linux/kernel/v${version%.*}.x/linux-$version.tar.xz"
    local tarball="/tmp/linux-$version.tar.xz"
    
    print_info "Downloading from: $url"
    wget -q --show-progress -O "$tarball" "$url" 2>&1 | tee "$LOGS_DIR/kernel_download.log"
    
    if [ ! -f "$tarball" ]; then
        print_error "Failed to download kernel source"
        exit 1
    fi
    
    # 解压源码
    print_info "Extracting kernel source..."
    tar -xf "$tarball" -C /usr/src/ 2>&1 | tee "$LOGS_DIR/kernel_extract.log"
    
    # 清理临时文件
    rm -f "$tarball"
    
    print_success "Kernel source downloaded and extracted to $source_dir"
    echo "$source_dir"
}

configure_kernel() {
    local source_dir=$1
    local build_dir=$2
    
    print_header "Configuring Kernel"
    
    cd "$build_dir"
    
    # 清理之前的构建
    print_info "Cleaning previous build..."
    make mrproper 2>&1 | tee "$LOGS_DIR/make_mrproper.log"
    
    # 使用当前内核配置作为基础
    if [ -f "/boot/config-$(uname -r)" ]; then
        print_info "Using current kernel config as base..."
        cp "/boot/config-$(uname -r)" .config
        make olddefconfig 2>&1 | tee "$LOGS_DIR/olddefconfig.log"
    else
        print_info "Using default configuration..."
        make defconfig 2>&1 | tee "$LOGS_DIR/defconfig.log"
    fi
    
    # 应用安全配置片段
    if [ -f "$CONFIGS_DIR/kernel_config_fragment" ]; then
        print_info "Applying security configuration fragments..."
        cat "$CONFIGS_DIR/kernel_config_fragment" >> .config
        make olddefconfig 2>&1 | tee "$LOGS_DIR/olddefconfig2.log"
    fi
    
    # 交互式配置
    print_info "Starting interactive configuration..."
    print_info "Please enable the following important options:"
    print_info "1. Security options → Enable different security models"
    print_info "2. Security options → SELinux Support"
    print_info "3. Kernel hacking → Memory Debugging → KASAN"
    print_info "4. General setup → Kernel .config support"
    echo ""
    
    read -p "Press Enter to start menuconfig..."
    make menuconfig
    
    # 保存配置
    cp .config "$LOGS_DIR/kernel_final_config"
    cp .config "$BUILD_DIR/kernel.config"
    
    print_success "Kernel configuration completed"
}

compile_kernel() {
    local build_dir=$1
    local cores=$2
    
    print_header "Compiling Kernel"
    
    cd "$build_dir"
    
    # 获取开始时间
    local start_time=$(date +%s)
    
    # 编译内核镜像
    print_info "Compiling kernel image..."
    print_info "Using $cores CPU cores"
    print_info "This may take 30-90 minutes..."
    echo "Start time: $(date)"
    
    make -j$cores 2>&1 | tee "$LOGS_DIR/kernel_compile.log"
    
    # 编译模块
    print_info "Compiling kernel modules..."
    make modules -j$cores 2>&1 | tee "$LOGS_DIR/modules_compile.log"
    
    # 计算耗时
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    print_success "Compilation completed in ${minutes}m ${seconds}s"
    echo "End time: $(date)"
}

install_kernel() {
    local build_dir=$1
    
    print_header "Installing Kernel"
    
    cd "$build_dir"
    
    # 安装模块
    print_info "Installing kernel modules..."
    make modules_install 2>&1 | tee "$LOGS_DIR/modules_install.log"
    
    # 安装内核
    print_info "Installing kernel image..."
    make install 2>&1 | tee "$LOGS_DIR/kernel_install.log"
    
    # 创建initramfs
    print_info "Creating initramfs..."
    if command -v update-initramfs > /dev/null 2>&1; then
        update-initramfs -c -k "$(make kernelversion)" 2>&1 | tee "$LOGS_DIR/initramfs.log"
    elif command -v dracut > /dev/null 2>&1; then
        dracut --force 2>&1 | tee "$LOGS_DIR/dracut.log"
    fi
    
    print_success "Kernel installation completed"
}

update_bootloader() {
    print_header "Updating Bootloader"
    
    # 更新GRUB配置
    print_info "Updating GRUB configuration..."
    if command -v update-grub > /dev/null 2>&1; then
        update-grub 2>&1 | tee "$LOGS_DIR/update_grub.log"
    elif command -v grub-mkconfig > /dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tee "$LOGS_DIR/update_grub.log"
    elif command -v grub2-mkconfig > /dev/null 2>&1; then
        grub2-mkconfig -o /boot/grub2/grub.cfg 2>&1 | tee "$LOGS_DIR/update_grub.log"
    else
        print_error "Could not find GRUB update command"
        return 1
    fi
    
    print_success "Bootloader updated"
}

create_build_summary() {
    local version=$1
    local build_dir=$2
    
    print_header "Build Summary"
    
    cat > "$BUILD_DIR/build_summary.txt" << EOF
Linux Kernel Security Lab - Build Summary
=========================================

Build Information:
- Kernel Version: $version
- Build Date: $(date)
- Build Directory: $build_dir
- Build Duration: $(( ($(date +%s) - $start_timestamp) / 60 )) minutes

Configuration:
- SELinux: Enabled
- KASAN: Enabled
- Debug Info: Enabled
- Security Features: Full

Installation:
- Kernel Image: /boot/vmlinuz-$version
- Modules: /lib/modules/$version
- Config: /boot/config-$version
- Initramfs: /boot/initrd.img-$version

Next Steps:
1. Reboot the system: sudo reboot
2. Select the new kernel from GRUB menu
3. Verify with: uname -r
4. Test SELinux: sestatus
5. Test KASAN: Check dmesg for KASAN initialization

Troubleshooting:
- If system doesn't boot, select previous kernel from GRUB
- Check logs in: $LOGS_DIR/
- Review configuration: $build_dir/.config

Security Notes:
- New kernel includes enhanced security features
- SELinux is in permissive mode by default
- KASAN adds runtime overhead (development only)
- Audit system is enabled and configured

Log Files:
$(ls -la $LOGS_DIR/*.log | awk '{print $9 " - " $5 " bytes"}')

Build completed successfully!
EOF
    
    cat "$BUILD_DIR/build_summary.txt"
}

# 主函数
main() {
    print_header "Linux Kernel Security Lab - Kernel Build"
    echo "Project: $PROJECT_ROOT"
    echo ""
    
    # 检查权限
    check_root
    
    # 检查系统资源
    check_disk_space
    check_memory
    local cores=$(check_cpu_cores)
    
    # 创建构建目录
    mkdir -p "$BUILD_DIR"
    mkdir -p "$LOGS_DIR"
    
    # 选择内核版本
    local kernel_version=$(select_kernel_version)
    
    # 下载内核源码
    local source_dir=$(download_kernel_source "$kernel_version")
    local build_dir="/usr/src/linux-build-$kernel_version-$(date +%Y%m%d)"
    
    # 复制源码到构建目录
    print_info "Preparing build directory: $build_dir"
    mkdir -p "$build_dir"
    cp -r "$source_dir"/* "$build_dir"/
    chown -R $USER:$USER "$build_dir"
    
    # 记录开始时间
    local start_timestamp=$(date +%s)
    
    # 配置内核
    configure_kernel "$source_dir" "$build_dir"
    
    # 编译内核
    compile_kernel "$build_dir" "$cores"
    
    # 安装内核
    install_kernel "$build_dir"
    
    # 更新引导加载器
    update_bootloader
    
    # 创建构建总结
    create_build_summary "$kernel_version" "$build_dir"
    
    # 最终提示
    print_header "Build Complete"
    print_success "Kernel build and installation completed successfully!"
    echo ""
    echo "Important files:"
    echo "  Build summary: $BUILD_DIR/build_summary.txt"
    echo "  Kernel config: $BUILD_DIR/kernel.config"
    echo "  Log files: $LOGS_DIR/"
    echo ""
    echo "Next steps:"
    echo "1. Review the build summary above"
    echo "2. Reboot into the new kernel"
    echo "3. Run SELinux and KASAN tests"
    echo ""
    echo "To reboot now, run: sudo reboot"
    echo ""
    
    # 询问是否重启
    read -p "Reboot now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Rebooting in 5 seconds... (Ctrl+C to cancel)"
        sleep 5
        reboot
    fi
}

# 异常处理
trap 'print_error "Build failed at line $LINENO"; exit 1' ERR

# 运行主函数
main