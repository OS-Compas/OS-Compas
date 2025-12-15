#!/bin/bash

# 进程监视器 - 环境依赖安装脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        OS_TYPE=$ID
    else
        OS=$(uname -s)
        OS_TYPE=$OS
    fi
    echo "$OS_TYPE"
}

# 安装Debian/Ubuntu依赖
install_debian_deps() {
    log_info "检测到 Debian/Ubuntu 系统，安装依赖..."
    
    sudo apt update
    sudo apt install -y \
        bc \
        procps \
        psmisc \
        tree \
        htop \
        iotop \
        python3 \
        python3-pip \
        gcc \
        make \
        build-essential
    
    # 安装Python依赖
    if command_exists pip3; then
        pip3 install psutil
    fi
}

# 安装RedHat/CentOS依赖
install_redhat_deps() {
    log_info "检测到 RedHat/CentOS 系统，安装依赖..."
    
    sudo yum update -y
    sudo yum install -y \
        bc \
        procps-ng \
        psmisc \
        tree \
        htop \
        python3 \
        python3-pip \
        gcc \
        make
    
    # 安装Python依赖
    if command_exists pip3; then
        pip3 install psutil
    fi
}

# 安装Arch Linux依赖
install_arch_deps() {
    log_info "检测到 Arch Linux 系统，安装依赖..."
    
    sudo pacman -Sy --noconfirm \
        bc \
        procps-ng \
        psmisc \
        tree \
        htop \
        python \
        python-pip \
        gcc \
        make
    
    # 安装Python依赖
    if command_exists pip; then
        pip install psutil
    fi
}

# 安装macOS依赖
install_macos_deps() {
    log_info "检测到 macOS 系统，安装依赖..."
    
    # 检查是否安装了Homebrew
    if ! command_exists brew; then
        log_error "请先安装Homebrew: https://brew.sh/"
        exit 1
    fi
    
    brew update
    brew install \
        bc \
        procps \
        pstree \
        tree \
        htop \
        python3
    
    # 安装Python依赖
    pip3 install psutil
}

# 验证安装
verify_installation() {
    log_info "验证工具安装..."
    
    local missing_tools=()
    
    # 检查必需工具
    for tool in bc ps pgrep awk grep; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    # 检查Python和psutil
    if ! python3 -c "import psutil" 2>/dev/null; then
        missing_tools+=("psutil(python)")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "以下工具安装失败: ${missing_tools[*]}"
        return 1
    fi
    
    log_success "所有依赖工具安装成功！"
    return 0
}

# 设置执行权限
setup_permissions() {
    log_info "设置脚本执行权限..."
    
    chmod +x "$PROJECT_ROOT/src/"*.sh
    chmod +x "$PROJECT_ROOT/src/"*.py
    chmod +x "$PROJECT_ROOT/tests/"*.sh
    chmod +x "$PROJECT_ROOT/tools/"*.sh
    chmod +x "$PROJECT_ROOT/examples/sample_scripts/"*.sh
    
    log_success "权限设置完成"
}

# 编译示例程序
compile_examples() {
    log_info "编译示例程序..."
    
    local example_dir="$PROJECT_ROOT/examples/sample_scripts"
    
    if command_exists gcc; then
        for c_file in "$example_dir"/*.c; do
            if [ -f "$c_file" ]; then
                local base_name=$(basename "$c_file" .c)
                gcc -o "$example_dir/$base_name" "$c_file"
                if [ $? -eq 0 ]; then
                    log_success "编译成功: $base_name"
                else
                    log_warning "编译失败: $base_name"
                fi
            fi
        done
    else
        log_warning "未找到gcc，跳过示例程序编译"
    fi
}

# 显示系统信息
show_system_info() {
    log_info "系统信息:"
    echo "  OS: $(uname -s)"
    echo "  架构: $(uname -m)"
    echo "  内核: $(uname -r)"
    
    if [ -f /etc/os-release ]; then
        echo "  发行版: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
    fi
    
    echo "  Python: $(python3 --version 2>/dev/null || echo '未安装')"
    echo "  GCC: $(gcc --version 2>/dev/null | head -1 || echo '未安装')"
}

# 主安装函数
main() {
    log_info "开始安装进程监视器依赖..."
    echo "=========================================="
    
    show_system_info
    echo
    
    local os_type=$(detect_os)
    
    case $os_type in
        ubuntu|debian)
            install_debian_deps
            ;;
        rhel|centos|fedora)
            install_redhat_deps
            ;;
        arch|manjaro)
            install_arch_deps
            ;;
        darwin)
            install_macos_deps
            ;;
        *)
            log_error "不支持的操作系统: $os_type"
            log_info "请手动安装以下依赖:"
            echo "  - bc, procps, psmisc, tree, htop"
            echo "  - python3, python3-pip, gcc"
            echo "  - psutil (pip包)"
            exit 1
            ;;
    esac
    
    echo
    setup_permissions
    echo
    compile_examples
    echo
    verify_installation
    
    echo
    log_success "环境配置完成！"
    log_info "现在可以运行进程监视器了:"
    echo "  cd $PROJECT_ROOT"
    echo "  ./src/process_monitor.sh --help"
}

# 显示帮助信息
show_help() {
    echo "进程监视器 - 环境依赖安装脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help    显示此帮助信息"
    echo "  -v, --verify  仅验证安装，不进行安装"
    echo ""
    echo "示例:"
    echo "  $0            # 完整安装"
    echo "  $0 --verify   # 仅验证当前环境"
}

# 参数解析
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--verify)
        verify_installation
        exit $?
        ;;
    *)
        main
        ;;
esac