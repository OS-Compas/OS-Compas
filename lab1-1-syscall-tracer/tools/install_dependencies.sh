#!/bin/bash

# install_dependencies.sh - 依赖安装脚本
# 为实验1.1：系统调用追踪与可视化分析安装所需依赖

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="/tmp/syscall_lab_install.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# 初始化日志文件
init_log() {
    echo "=== 实验1.1 依赖安装日志 ===" > "$LOG_FILE"
    echo "开始时间: $(date)" >> "$LOG_FILE"
    echo "项目路径: $PROJECT_ROOT" >> "$LOG_FILE"
    echo "用户: $(whoami)" >> "$LOG_FILE"
    echo "系统: $(uname -a)" >> "$LOG_FILE"
    echo "=================================" >> "$LOG_FILE"
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        OS_VERSION=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        OS_VERSION=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        OS_VERSION=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS=Debian
        OS_VERSION=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | awk '{print $1}')
        OS_VERSION=$(cat /etc/redhat-release | awk '{print $3}')
    else
        OS=$(uname -s)
        OS_VERSION=$(uname -r)
    fi
    
    log_info "检测到操作系统: $OS $OS_VERSION"
    echo "$OS" | tr '[:upper:]' '[:lower:]'
}

# 检查权限
check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        log_warning "当前不是root用户，部分安装可能需要sudo权限"
        return 1
    else
        log_success "当前是root用户，具有完整安装权限"
        return 0
    fi
}

# 检查网络连接
check_network() {
    log_step "检查网络连接..."
    
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        log_success "网络连接正常"
        return 0
    else
        log_error "网络连接失败，请检查网络设置"
        return 1
    fi
}

# Ubuntu/Debian 系统安装
install_ubuntu_debian() {
    log_step "更新软件包列表..."
    apt-get update >> "$LOG_FILE" 2>&1
    
    log_step "安装系统工具..."
    apt-get install -y \
        strace \
        build-essential \
        gcc \
        g++ \
        make \
        gdb \
        git \
        wget \
        curl \
        python3 \
        python3-pip \
        python3-venv \
        pkg-config \
        >> "$LOG_FILE" 2>&1
    
    # 安装开发库
    log_step "安装开发库..."
    apt-get install -y \
        libc6-dev \
        linux-headers-$(uname -r) \
        >> "$LOG_FILE" 2>&1
}

# CentOS/RHEL/Fedora 系统安装
install_centos_redhat() {
    local os_type=$1
    
    log_step "更新软件包列表..."
    if command -v dnf >/dev/null 2>&1; then
        dnf update -y >> "$LOG_FILE" 2>&1
        PKG_MGR="dnf"
    else
        yum update -y >> "$LOG_FILE" 2>&1
        PKG_MGR="yum"
    fi
    
    log_step "安装系统工具..."
    $PKG_MGR install -y \
        strace \
        gcc \
        gcc-c++ \
        make \
        gdb \
        git \
        wget \
        curl \
        python3 \
        python3-pip \
        >> "$LOG_FILE" 2>&1
    
    # 安装开发工具组
    log_step "安装开发工具组..."
    if [ "$PKG_MGR" = "dnf" ]; then
        dnf groupinstall -y "Development Tools" >> "$LOG_FILE" 2>&1
        dnf install -y kernel-devel-$(uname -r) >> "$LOG_FILE" 2>&1
    else
        yum groupinstall -y "Development Tools" >> "$LOG_FILE" 2>&1
        yum install -y kernel-devel-$(uname -r) >> "$LOG_FILE" 2>&1
    fi
}

# Arch Linux 系统安装
install_arch() {
    log_step "更新系统..."
    pacman -Syu --noconfirm >> "$LOG_FILE" 2>&1
    
    log_step "安装系统工具..."
    pacman -S --noconfirm \
        strace \
        base-devel \
        gcc \
        gdb \
        git \
        wget \
        curl \
        python \
        python-pip \
        >> "$LOG_FILE" 2>&1
}

# macOS 系统安装
install_macos() {
    # 检查是否安装了Homebrew
    if ! command -v brew >/dev/null 2>&1; then
        log_step "安装Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >> "$LOG_FILE" 2>&1
    fi
    
    log_step "更新Homebrew..."
    brew update >> "$LOG_FILE" 2>&1
    
    log_step "安装系统工具..."
    brew install \
        strace \
        gcc \
        make \
        git \
        wget \
        curl \
        python3 \
        >> "$LOG_FILE" 2>&1
}

# 安装系统依赖
install_system_dependencies() {
    local os_type=$1
    
    log_step "开始安装系统依赖..."
    
    case $os_type in
        *ubuntu*|*debian*)
            install_ubuntu_debian
            ;;
        *centos*|*red*hat*|*fedora*)
            install_centos_redhat "$os_type"
            ;;
        *arch*)
            install_arch
            ;;
        *darwin*|*macos*)
            install_macos
            ;;
        *)
            log_error "不支持的操作系统: $os_type"
            log_info "请手动安装以下工具:"
            log_info "  - strace"
            log_info "  - gcc"
            log_info "  - make"
            log_info "  - python3"
            log_info "  - python3-pip"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log_success "系统依赖安装完成"
        return 0
    else
        log_error "系统依赖安装失败"
        return 1
    fi
}

# 安装Python依赖
install_python_dependencies() {
    log_step "安装Python依赖..."
    
    # 检查Python3是否可用
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "Python3 未安装"
        return 1
    fi
    
    # 检查pip是否可用
    if ! command -v pip3 >/dev/null 2>&1; then
        log_error "pip3 未安装"
        return 1
    fi
    
    # 升级pip
    log_step "升级pip..."
    pip3 install --upgrade pip >> "$LOG_FILE" 2>&1
    
    # 基础Python包
    log_step "安装基础Python包..."
    local base_packages=(
        "setuptools"
        "wheel"
    )
    
    for package in "${base_packages[@]}"; do
        pip3 install "$package" >> "$LOG_FILE" 2>&1
    done
    
    # 必要的数据分析包
    log_step "安装数据分析包..."
    local required_packages=(
        "numpy"
        "pandas"
        "matplotlib"
        "seaborn"
        "Jinja2"
    )
    
    for package in "${required_packages[@]}"; do
        log_info "安装 $package..."
        if pip3 install "$package" >> "$LOG_FILE" 2>&1; then
            log_success "$package 安装成功"
        else
            log_error "$package 安装失败"
            return 1
        fi
    done
    
    # 可选的可视化增强包
    log_step "安装可选的可视化增强包..."
    local optional_packages=(
        "plotly"
        "bokeh"
        "ipywidgets"
    )
    
    for package in "${optional_packages[@]}"; do
        log_info "尝试安装 $package..."
        if pip3 install "$package" >> "$LOG_FILE" 2>&1; then
            log_success "$package 安装成功"
        else
            log_warning "$package 安装失败 (可选包)"
        fi
    done
    
    log_success "Python依赖安装完成"
    return 0
}

# 创建虚拟环境（可选）
create_virtualenv() {
    local create_venv=$1
    
    if [ "$create_venv" = "true" ]; then
        log_step "创建Python虚拟环境..."
        
        local venv_path="$PROJECT_ROOT/venv"
        
        if [ -d "$venv_path" ]; then
            log_warning "虚拟环境已存在，跳过创建"
            return 0
        fi
        
        if python3 -m venv "$venv_path" >> "$LOG_FILE" 2>&1; then
            log_success "虚拟环境创建成功: $venv_path"
            
            # 激活虚拟环境安装包
            log_step "在虚拟环境中安装依赖..."
            source "$venv_path/bin/activate"
            install_python_dependencies
            deactivate
            
            log_info "虚拟环境使用说明:"
            log_info "  激活: source $venv_path/bin/activate"
            log_info "  退出: deactivate"
        else
            log_error "虚拟环境创建失败"
            return 1
        fi
    else
        log_info "跳过虚拟环境创建"
    fi
}

# 编译示例程序
compile_example_programs() {
    log_step "编译示例程序..."
    
    local example_dir="$PROJECT_ROOT/examples/example_programs"
    local compiled_count=0
    local total_examples=0
    
    if [ ! -d "$example_dir" ]; then
        log_warning "示例程序目录不存在: $example_dir"
        return 0
    fi
    
    # 查找所有的C示例程序
    for c_file in "$example_dir"/*.c; do
        if [ -f "$c_file" ]; then
            total_examples=$((total_examples + 1))
            local base_name=$(basename "$c_file" .c)
            local output_file="$example_dir/$base_name"
            
            log_info "编译 $c_file ..."
            if gcc -o "$output_file" "$c_file" >> "$LOG_FILE" 2>&1; then
                log_success "编译成功: $base_name"
                compiled_count=$((compiled_count + 1))
                
                # 设置执行权限
                chmod +x "$output_file"
            else
                log_error "编译失败: $base_name"
            fi
        fi
    done
    
    if [ $compiled_count -eq $total_examples ] && [ $total_examples -gt 0 ]; then
        log_success "示例程序编译完成 ($compiled_count/$total_examples)"
        return 0
    elif [ $compiled_count -gt 0 ]; then
        log_warning "部分示例程序编译完成 ($compiled_count/$total_examples)"
        return 1
    else
        log_error "示例程序编译全部失败"
        return 1
    fi
}

# 验证安装
verify_installation() {
    log_step "验证安装结果..."
    
    local verification_passed=0
    local verification_total=0
    
    # 验证系统工具
    local system_tools=("strace" "gcc" "make" "python3" "pip3")
    for tool in "${system_tools[@]}"; do
        ((verification_total++))
        if command -v "$tool" >/dev/null 2>&1; then
            local version=$("$tool" --version 2>/dev/null | head -1 || echo "版本未知")
            log_success "$tool 可用 ($version)"
            ((verification_passed++))
        else
            log_error "$tool 不可用"
        fi
    done
    
    # 验证Python包
    local python_packages=("numpy" "pandas" "matplotlib" "seaborn")
    for package in "${python_packages[@]}"; do
        ((verification_total++))
        if python3 -c "import $package" 2>/dev/null; then
            local version=$(python3 -c "import $package; print($package.__version__)" 2>/dev/null || echo "版本未知")
            log_success "Python包 $package 可用 ($version)"
            ((verification_passed++))
        else
            log_error "Python包 $package 不可用"
        fi
    done
    
    # 验证示例程序
    local example_dir="$PROJECT_ROOT/examples/example_programs"
    if [ -d "$example_dir" ]; then
        local example_programs=("file_ops" "memory_ops" "network_test")
        for program in "${example_programs[@]}"; do
            ((verification_total++))
            local program_path="$example_dir/$program"
            if [ -f "$program_path" ] && [ -x "$program_path" ]; then
                log_success "示例程序 $program 可用"
                ((verification_passed++))
            else
                log_warning "示例程序 $program 不可用"
            fi
        done
    fi
    
    # 显示验证结果
    echo
    log_info "验证结果: $verification_passed/$verification_total 项通过"
    
    if [ $verification_passed -eq $verification_total ]; then
        log_success "所有依赖安装验证通过！"
        return 0
    else
        log_warning "部分依赖安装验证失败"
        return 1
    fi
}

# 显示使用说明
show_usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "为实验1.1：系统调用追踪与可视化分析安装依赖"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -v, --verbose       显示详细输出"
    echo "  --no-venv           不创建虚拟环境"
    echo "  --venv              创建虚拟环境（默认）"
    echo "  --skip-compile      跳过示例程序编译"
    echo "  --only-verify       只验证安装，不进行安装"
    echo "  --log-file FILE     指定日志文件路径"
    echo ""
    echo "示例:"
    echo "  $0                  默认安装（推荐）"
    echo "  $0 --no-venv        不在虚拟环境中安装"
    echo "  $0 --only-verify    只验证当前安装状态"
    echo "  $0 --skip-compile   跳过示例程序编译"
}

# 显示安装摘要
show_summary() {
    echo
    echo -e "${CYAN}"
    echo "=========================================="
    echo "   实验1.1 依赖安装完成"
    echo "=========================================="
    echo -e "${NC}"
    
    log_info "安装日志: $LOG_FILE"
    log_info "项目路径: $PROJECT_ROOT"
    
    echo
    log_info "下一步操作:"
    echo "  1. 运行测试: ./tests/test_basic.sh"
    echo "  2. 查看示例: cd examples/example_programs && ./file_ops"
    echo "  3. 开始实验: 阅读 docs/README.md"
    
    echo
    log_info "常用命令:"
    echo "  strace -o trace.log ls          # 追踪命令"
    echo "  python3 src/syscall_tracer.py   # 分析追踪文件"
    echo "  ./src/syscall_monitor.sh -h     # 查看监控帮助"
    
    echo
    log_success "实验环境准备完成！开始探索系统调用的奥秘吧！"
}

# 主安装函数
main_install() {
    local create_venv=${1:-true}
    local skip_compile=${2:-false}
    
    log_step "开始安装实验1.1依赖..."
    
    # 检测操作系统
    local os_type=$(detect_os)
    
    # 检查网络
    if ! check_network; then
        log_error "网络连接失败，无法继续安装"
        return 1
    fi
    
    # 安装系统依赖
    if ! install_system_dependencies "$os_type"; then
        log_error "系统依赖安装失败"
        return 1
    fi
    
    # 安装Python依赖
    if [ "$create_venv" = "true" ]; then
        create_virtualenv "true"
    else
        if ! install_python_dependencies; then
            log_error "Python依赖安装失败"
            return 1
        fi
    fi
    
    # 编译示例程序
    if [ "$skip_compile" = "false" ]; then
        if ! compile_example_programs; then
            log_warning "示例程序编译存在问题，但主要功能应仍可用"
        fi
    else
        log_info "跳过示例程序编译"
    fi
    
    # 验证安装
    if verify_installation; then
        show_summary
        return 0
    else
        log_error "安装验证失败，请检查日志: $LOG_FILE"
        return 1
    fi
}

# 主函数
main() {
    local create_venv="true"
    local skip_compile="false"
    local only_verify="false"
    local verbose="false"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            --no-venv)
                create_venv="false"
                shift
                ;;
            --venv)
                create_venv="true"
                shift
                ;;
            --skip-compile)
                skip_compile="true"
                shift
                ;;
            --only-verify)
                only_verify="true"
                shift
                ;;
            --log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            *)
                log_error "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 初始化日志
    init_log
    
    # 显示欢迎信息
    echo -e "${CYAN}"
    echo "=========================================="
    echo "   实验1.1 系统调用追踪与可视化分析"
    echo "           依赖安装脚本"
    echo "=========================================="
    echo -e "${NC}"
    
    log_info "开始时间: $(date)"
    log_info "项目路径: $PROJECT_ROOT"
    
    # 检查权限
    check_privileges
    
    if [ "$only_verify" = "true" ]; then
        verify_installation
        exit $?
    fi
    
    # 执行安装
    if main_install "$create_venv" "$skip_compile"; then
        log_success "依赖安装完成！"
        exit 0
    else
        log_error "依赖安装失败！"
        log_info "请查看日志文件: $LOG_FILE"
        log_info "或尝试手动安装缺失的依赖"
        exit 1
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi