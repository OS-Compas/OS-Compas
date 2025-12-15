#!/bin/bash

# 实验4.1环境准备脚本
# 安装所有必要的依赖和工具

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_ROOT/logs"
CONFIGS_DIR="$PROJECT_ROOT/configs"

# 创建必要的目录
mkdir -p "$LOGS_DIR"
mkdir -p "$CONFIGS_DIR"

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

print_header "Linux Kernel Security Lab - Environment Setup"
echo "Project Root: $PROJECT_ROOT"
echo "Logs Directory: $LOGS_DIR"
echo ""

# 步骤1：系统信息检查
print_header "Step 1: System Information Check"

echo "System Information:"
uname -a
echo ""

echo "Distribution:"
if [ -f /etc/os-release ]; then
    source /etc/os-release
    echo "$PRETTY_NAME"
elif [ -f /etc/lsb-release ]; then
    cat /etc/lsb-release
elif [ -f /etc/redhat-release ]; then
    cat /etc/redhat-release
fi
echo ""

echo "Disk Space:"
df -h /
echo ""

echo "Memory:"
free -h
echo ""

# 步骤2：更新系统
print_header "Step 2: System Update"

print_info "Updating package lists..."
apt update 2>&1 | tee "$LOGS_DIR/apt_update.log"

print_info "Upgrading existing packages..."
apt upgrade -y 2>&1 | tee "$LOGS_DIR/apt_upgrade.log"

print_success "System updated"

# 步骤3：安装内核编译依赖
print_header "Step 3: Kernel Build Dependencies"

print_info "Installing kernel build tools..."
apt install -y \
    build-essential \
    libncurses-dev \
    libssl-dev \
    bc \
    flex \
    bison \
    libelf-dev \
    rsync \
    kmod \
    cpio \
    wget \
    xz-utils \
    git \
    curl \
    dwarves \
    2>&1 | tee "$LOGS_DIR/kernel_deps_install.log"

print_success "Kernel build dependencies installed"

# 步骤4：安装SELinux工具
print_header "Step 4: SELinux Tools"

if [ "$ID" = "ubuntu" ] || [ "$ID" = "debian" ]; then
    print_info "Installing SELinux tools for Debian/Ubuntu..."
    apt install -y \
        selinux-basics \
        selinux-policy-default \
        selinux-policy-dev \
        policycoreutils \
        setools \
        setools-gui \
        setroubleshoot \
        auditd \
        audispd-plugins \
        2>&1 | tee "$LOGS_DIR/selinux_install.log"
    
    print_info "Configuring SELinux..."
    selinux-activate 2>&1 | tee "$LOGS_DIR/selinux_activate.log"
    
elif [ "$ID" = "centos" ] || [ "$ID" = "rhel" ] || [ "$ID" = "fedora" ]; then
    print_info "Installing SELinux tools for RHEL/CentOS/Fedora..."
    dnf install -y \
        selinux-policy-targeted \
        selinux-policy-devel \
        policycoreutils \
        policycoreutils-python-utils \
        setools \
        setools-console \
        setroubleshoot \
        setroubleshoot-server \
        audit \
        audit-libs \
        2>&1 | tee "$LOGS_DIR/selinux_install.log"
else
    print_error "Unsupported distribution for SELinux setup"
    print_info "Please manually install SELinux tools for your distribution"
fi

print_success "SELinux tools installed"

# 步骤5：安装开发工具
print_header "Step 5: Development Tools"

print_info "Installing development tools..."
apt install -y \
    gcc \
    g++ \
    make \
    cmake \
    autoconf \
    automake \
    libtool \
    pkg-config \
    gdb \
    valgrind \
    strace \
    ltrace \
    2>&1 | tee "$LOGS_DIR/dev_tools_install.log"

print_info "Installing code analysis tools..."
apt install -y \
    cppcheck \
    flawfinder \
    sparse \
    2>&1 | tee "$LOGS_DIR/analysis_tools_install.log"

print_success "Development tools installed"

# 步骤6：安装文档工具
print_header "Step 6: Documentation Tools"

print_info "Installing documentation tools..."
apt install -y \
    doxygen \
    graphviz \
    texlive \
    texinfo \
    pandoc \
    2>&1 | tee "$LOGS_DIR/doc_tools_install.log"

print_success "Documentation tools installed"

# 步骤7：配置审计系统
print_header "Step 7: Audit System Configuration"

print_info "Configuring audit system..."
systemctl enable auditd 2>&1 | tee "$LOGS_DIR/audit_enable.log"
systemctl start auditd 2>&1 | tee "$LOGS_DIR/audit_start.log"

# 创建审计规则
cat > /etc/audit/rules.d/kernel-lab.rules << 'EOF'
# Kernel lab audit rules
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k sudoers
-w /etc/selinux/ -p wa -k selinux
-w /usr/src/ -p wa -k kernel_source
-w /boot/ -p wa -k boot_files
-a always,exit -F arch=b64 -S init_module -S delete_module -k kernel_modules
EOF

auditctl -R /etc/audit/rules.d/kernel-lab.rules 2>&1 | tee "$LOGS_DIR/audit_rules.log"

print_success "Audit system configured"

# 步骤8：创建测试用户
print_header "Step 8: Test User Creation"

print_info "Creating test user 'kernellab'..."
if ! id kernellab > /dev/null 2>&1; then
    useradd -m -s /bin/bash kernellab
    echo "kernellab:kernel123" | chpasswd
    usermod -aG sudo kernellab
    print_success "Test user created: kernellab / kernel123"
else
    print_info "Test user already exists"
fi

# 步骤9：配置环境变量
print_header "Step 9: Environment Configuration"

# 创建环境配置文件
cat > /etc/profile.d/kernel-lab.sh << 'EOF'
# Kernel Lab Environment Variables
export KERNEL_LAB_ROOT="$HOME/kernel-security-lab"
export PATH="$KERNEL_LAB_ROOT/scripts:$PATH"
export C_INCLUDE_PATH="/usr/src/linux-headers-$(uname -r)/include:$C_INCLUDE_PATH"
alias kgrep="grep -r --include='*.c' --include='*.h'"
alias klog="dmesg -wH"
alias ktest="cd $KERNEL_LAB_ROOT && ./scripts/test_all.sh"
EOF

# 创建项目目录结构
mkdir -p "$PROJECT_ROOT/build"
mkdir -p "$PROJECT_ROOT/modules"
mkdir -p "$PROJECT_ROOT/tests"

print_success "Environment configured"

# 步骤10：安装内核头文件
print_header "Step 10: Kernel Headers Installation"

print_info "Installing kernel headers..."
apt install -y \
    linux-headers-$(uname -r) \
    linux-source \
    2>&1 | tee "$LOGS_DIR/kernel_headers_install.log"

print_success "Kernel headers installed"

# 步骤11：验证安装
print_header "Step 11: Installation Verification"

echo "Verifying installations..."
echo ""

# 检查关键工具
declare -A tools=(
    ["gcc"]="gcc --version | head -1"
    ["make"]="make --version | head -1"
    ["flex"]="flex --version | head -1"
    ["bison"]="bison --version | head -1"
    ["git"]="git --version | head -1"
    ["gdb"]="gdb --version | head -1"
)

for tool in "${!tools[@]}"; do
    if command -v $tool > /dev/null 2>&1; then
        echo -n "$tool: "
        eval "${tools[$tool]}"
    else
        print_error "$tool not found"
    fi
done

echo ""
echo "Kernel version: $(uname -r)"
echo "Kernel headers: $(ls -d /usr/src/linux-headers-* 2>/dev/null | head -1)"

# 检查SELinux
echo ""
print_info "SELinux Status:"
if command -v sestatus > /dev/null 2>&1; then
    sestatus | head -5
else
    print_error "sestatus not found"
fi

# 步骤12：创建测试脚本
print_header "Step 12: Creating Test Scripts"

# 创建编译测试脚本
cat > "$PROJECT_ROOT/scripts/test_compile.sh" << 'EOF'
#!/bin/bash
echo "Testing C compiler..."
cat > /tmp/test_compile.c << 'EOC'
#include <stdio.h>
int main() {
    printf("Kernel Lab Compiler Test: PASS\n");
    return 0;
}
EOC

gcc /tmp/test_compile.c -o /tmp/test_compile
/tmp/test_compile
rm -f /tmp/test_compile.c /tmp/test_compile
EOF

chmod +x "$PROJECT_ROOT/scripts/test_compile.sh"

# 创建内核模块测试脚本
cat > "$PROJECT_ROOT/scripts/test_module.sh" << 'EOF'
#!/bin/bash
echo "Testing kernel module compilation..."
cat > /tmp/test_module.c << 'EOM'
#include <linux/init.h>
#include <linux/module.h>
MODULE_LICENSE("GPL");
static int __init test_init(void) { printk(KERN_INFO "Test module loaded\n"); return 0; }
static void __exit test_exit(void) { printk(KERN_INFO "Test module unloaded\n"); }
module_init(test_init);
module_exit(test_exit);
EOM

cat > /tmp/Makefile << 'EOM'
obj-m += test_module.o
all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules
clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
EOM

cd /tmp && make > /dev/null 2>&1
if [ -f test_module.ko ]; then
    echo "Kernel module compilation: PASS"
    rm -rf /tmp/test_module.* /tmp/Makefile
else
    echo "Kernel module compilation: FAIL"
fi
EOF

chmod +x "$PROJECT_ROOT/scripts/test_module.sh"

# 创建综合测试脚本
cat > "$PROJECT_ROOT/scripts/test_all.sh" << 'EOF'
#!/bin/bash
echo "=== Kernel Lab Environment Test ==="
echo ""
./scripts/test_compile.sh
echo ""
./scripts/test_module.sh
echo ""
echo "System Information:"
uname -a
echo ""
echo "Disk space:"
df -h / | tail -1
EOF

chmod +x "$PROJECT_ROOT/scripts/test_all.sh"

print_success "Test scripts created"

# 步骤13：完成信息
print_header "Step 13: Setup Complete"

print_success "Environment setup completed successfully!"
echo ""
echo "Summary:"
echo "1. System updated and upgraded"
echo "2. Kernel build dependencies installed"
echo "3. SELinux tools configured"
echo "4. Development tools installed"
echo "5. Audit system configured"
echo "6. Test user created: kernellab"
echo "7. Environment variables set"
echo "8. Test scripts created"
echo ""
echo "Next steps:"
echo "1. Reboot the system: sudo reboot"
echo "2. Run tests: cd $PROJECT_ROOT && ./scripts/test_all.sh"
echo "3. Build kernel: ./src/kernel_build.sh"
echo ""
echo "Log files are available in: $LOGS_DIR/"
echo ""

# 创建完成标记
date > "$PROJECT_ROOT/.setup_complete"
echo "Setup completed on: $(date)" >> "$LOGS_DIR/setup_summary.log"

print_info "Please reboot to apply all changes"
read -p "Reboot now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    reboot
fi