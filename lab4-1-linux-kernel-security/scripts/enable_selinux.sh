#!/bin/bash

# SELinux启用和配置脚本
# 用于实验4.1：SELinux安全特性配置

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_ROOT/logs"
CONFIGS_DIR="$PROJECT_ROOT/configs"

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

check_selinux_support() {
    print_header "Checking SELinux Support"
    
    # 检查内核是否支持SELinux
    if ! grep -q "CONFIG_SECURITY_SELINUX=y" /boot/config-$(uname -r) 2>/dev/null; then
        if [ -f /proc/config.gz ]; then
            if ! zcat /proc/config.gz | grep -q "CONFIG_SECURITY_SELINUX=y"; then
                print_error "SELinux not supported in current kernel"
                print_info "You need to compile kernel with SELinux support first"
                exit 1
            fi
        else
            print_error "Cannot check kernel configuration"
            print_info "Assuming SELinux is supported..."
        fi
    fi
    
    print_success "Kernel supports SELinux"
    
    # 检查SELinux文件系统
    if [ ! -d /sys/fs/selinux ]; then
        print_error "SELinux filesystem not mounted"
        print_info "SELinux may not be enabled in kernel"
    else
        print_success "SELinux filesystem found"
    fi
}

check_current_status() {
    print_header "Current SELinux Status"
    
    # 检查SELinux命令是否可用
    if ! command -v sestatus &> /dev/null; then
        print_error "sestatus command not found"
        print_info "Installing SELinux utilities..."
        
        if command -v apt &> /dev/null; then
            apt install -y selinux-utils policycoreutils 2>&1 | tee "$LOGS_DIR/selinux_install.log"
        elif command -v dnf &> /dev/null; then
            dnf install -y selinux-utils policycoreutils 2>&1 | tee "$LOGS_DIR/selinux_install.log"
        elif command -v yum &> /dev/null; then
            yum install -y selinux-utils policycoreutils 2>&1 | tee "$LOGS_DIR/selinux_install.log"
        else
            print_error "Cannot install SELinux utilities automatically"
            exit 1
        fi
    fi
    
    # 显示当前状态
    echo "Current SELinux status:"
    sestatus 2>&1 | tee "$LOGS_DIR/selinux_status_before.log"
    echo ""
    
    # 检查getenforce输出
    local enforce_mode=$(getenforce 2>/dev/null || echo "Disabled")
    echo "Enforcement mode: $enforce_mode"
}

install_selinux_packages() {
    print_header "Installing SELinux Packages"
    
    local distribution=""
    
    # 检测发行版
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        distribution="$ID"
    fi
    
    case $distribution in
        ubuntu|debian)
            print_info "Detected Debian/Ubuntu system"
            
            # 安装SELinux基础包
            apt update 2>&1 | tee "$LOGS_DIR/apt_update.log"
            
            print_info "Installing SELinux packages..."
            apt install -y \
                selinux-basics \
                selinux-policy-default \
                auditd \
                setools \
                policycoreutils \
                selinux-utils \
                2>&1 | tee "$LOGS_DIR/selinux_packages_install.log"
            
            print_success "SELinux packages installed"
            ;;
            
        centos|rhel|fedora)
            print_info "Detected RHEL/CentOS/Fedora system"
            
            # RHEL/CentOS/Fedora通常默认安装SELinux
            print_info "Checking SELinux installation..."
            
            if ! rpm -q selinux-policy > /dev/null 2>&1; then
                print_info "Installing SELinux policy..."
                dnf install -y selinux-policy-targeted 2>&1 | tee "$LOGS_DIR/selinux_policy_install.log"
            fi
            
            print_success "SELinux is available"
            ;;
            
        *)
            print_error "Unsupported distribution: $distribution"
            print_info "Please install SELinux packages manually"
            exit 1
            ;;
    esac
}

enable_selinux() {
    print_header "Enabling SELinux"
    
    # 检查是否已经启用
    if [ -f /sys/fs/selinux/enforce ]; then
        print_info "SELinux is already enabled in kernel"
    else
        print_error "SELinux not enabled in kernel"
        print_info "You may need to:"
        print_info "1. Reboot with selinux=1 in kernel parameters"
        print_info "2. Or compile kernel with SELinux support"
        exit 1
    fi
    
    # 对于Debian/Ubuntu，运行selinux-activate
    if command -v selinux-activate &> /dev/null; then
        print_info "Activating SELinux (Debian/Ubuntu)..."
        selinux-activate 2>&1 | tee "$LOGS_DIR/selinux_activate.log"
    fi
    
    # 设置为Permissive模式（仅记录，不拒绝）
    print_info "Setting SELinux to permissive mode..."
    setenforce 0 2>&1 | tee "$LOGS_DIR/setenforce_permissive.log"
    
    # 永久启用SELinux
    print_info "Configuring SELinux to be enabled on boot..."
    sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || \
    sed -i 's/^SELINUX=disabled/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || \
    echo "SELINUX=permissive" > /etc/selinux/config
    
    print_success "SELinux enabled in permissive mode"
}

configure_selinux_policy() {
    print_header "Configuring SELinux Policy"
    
    # 检查策略文件
    if [ ! -f /etc/selinux/config ]; then
        print_error "SELinux configuration file not found"
        return 1
    fi
    
    # 设置策略类型为targeted（默认）
    print_info "Setting SELinux policy type to 'targeted'..."
    sed -i 's/^SELINUXTYPE=.*/SELINUXTYPE=targeted/' /etc/selinux/config
    
    # 重新加载策略（如果需要）
    if command -v load_policy &> /dev/null; then
        print_info "Reloading SELinux policy..."
        load_policy 2>&1 | tee "$LOGS_DIR/load_policy.log"
    fi
    
    # 生成策略模块（如果需要）
    if [ -f "$CONFIGS_DIR/selinux_test_policy.te" ]; then
        print_info "Compiling test SELinux policy..."
        
        if [ -d /usr/share/selinux/devel ]; then
            cp "$CONFIGS_DIR/selinux_test_policy.te" /tmp/
            cd /tmp
            
            make -f /usr/share/selinux/devel/Makefile selinux_test_policy.pp 2>&1 | \
                tee "$LOGS_DIR/policy_compile.log"
            
            if [ -f selinux_test_policy.pp ]; then
                print_info "Installing test policy module..."
                semodule -i selinux_test_policy.pp 2>&1 | tee "$LOGS_DIR/policy_install.log"
                print_success "Test policy module installed"
            fi
        else
            print_info "SELinux development tools not installed, skipping policy compilation"
        fi
    fi
    
    print_success "SELinux policy configured"
}

configure_audit_system() {
    print_header "Configuring Audit System"
    
    # 确保审计服务运行
    print_info "Starting audit service..."
    systemctl enable auditd 2>&1 | tee "$LOGS_DIR/audit_enable.log"
    systemctl start auditd 2>&1 | tee "$LOGS_DIR/audit_start.log"
    
    # 配置审计规则
    print_info "Configuring audit rules for SELinux..."
    cat > /etc/audit/rules.d/30-selinux.rules << 'EOF'
# SELinux audit rules
-w /etc/selinux/ -p wa -k selinux
-w /usr/share/selinux/ -p wa -k selinux
-w /etc/sestatus.conf -p wa -k selinux
-a always,exit -F arch=b64 -S setxattr -F key=selinux
-a always,exit -F arch=b64 -S lsetxattr -F key=selinux
-a always,exit -F arch=b64 -S fsetxattr -F key=selinux
-a always,exit -F arch=b64 -S removexattr -F key=selinux
-a always,exit -F arch=b64 -S lremovexattr -F key=selinux
-a always,exit -F arch=b64 -S fremovexattr -F key=selinux
EOF
    
    # 重新加载审计规则
    print_info "Reloading audit rules..."
    auditctl -R /etc/audit/rules.d/30-selinux.rules 2>&1 | tee "$LOGS_DIR/audit_rules_reload.log"
    
    print_success "Audit system configured for SELinux"
}

create_test_environment() {
    print_header "Creating SELinux Test Environment"
    
    # 创建测试目录
    local test_dir="/selinux_test"
    print_info "Creating test directory: $test_dir"
    mkdir -p "$test_dir"
    
    # 创建测试文件
    cat > "$test_dir/test_file.txt" << 'EOF'
SELinux Test File
=================
This file is used to test SELinux security context
and access control functionality.

File created: $(date)
Test purpose: Experiment 4.1 - Kernel Security
EOF
    
    # 设置测试文件权限
    chmod 644 "$test_dir/test_file.txt"
    
    # 创建违反策略的测试脚本
    cat > "$test_dir/violation_test.sh" << 'EOF'
#!/bin/bash
echo "SELinux Violation Test Script"
echo "Attempting operations that might be denied by SELinux..."
echo ""

# 尝试访问敏感文件
echo "1. Attempting to read /etc/shadow:"
sudo head -c 50 /etc/shadow 2>&1 | head -1
echo ""

# 尝试修改系统文件
echo "2. Attempting to create file in /etc:"
sudo touch /etc/test_selinux_file 2>&1
sudo rm -f /etc/test_selinux_file 2>&1
echo ""

# 检查审计日志
echo "3. Checking audit logs for denials:"
sudo ausearch -m avc -ts today 2>&1 | head -5
EOF
    
    chmod +x "$test_dir/violation_test.sh"
    
    # 创建修复脚本
    cat > "$test_dir/fix_contexts.sh" << 'EOF'
#!/bin/bash
echo "SELinux Context Fix Script"
echo ""

# 修复文件上下文
echo "1. Restoring default SELinux contexts..."
restorecon -R /selinux_test/

# 查看上下文
echo "2. Current SELinux contexts:"
ls -laZ /selinux_test/

# 设置自定义上下文（如果需要）
echo "3. Setting custom context for test file..."
chcon -t user_home_t /selinux_test/test_file.txt 2>/dev/null || \
echo "Cannot set custom context (may need policy adjustment)"

echo ""
echo "Fix completed"
EOF
    
    chmod +x "$test_dir/fix_contexts.sh"
    
    print_success "Test environment created at $test_dir"
}

test_selinux_functionality() {
    print_header "Testing SELinux Functionality"
    
    print_info "Running basic SELinux tests..."
    
    # 测试1: 检查SELinux状态
    echo "Test 1: SELinux Status"
    sestatus | head -10
    echo ""
    
    # 测试2: 检查强制模式
    echo "Test 2: Enforcement Mode"
    getenforce
    echo ""
    
    # 测试3: 检查布尔值
    echo "Test 3: SELinux Booleans (first 10)"
    getsebool -a | head -10
    echo ""
    
    # 测试4: 进程上下文
    echo "Test 4: Process Context"
    ps -eZ | head -5
    echo ""
    
    # 测试5: 文件上下文
    echo "Test 5: File Context in /selinux_test"
    ls -laZ /selinux_test/ 2>/dev/null || echo "Test directory not found"
    echo ""
    
    # 测试6: 审计日志
    echo "Test 6: Recent SELinux Audit Messages"
    ausearch -m avc -ts recent 2>/dev/null | head -5 || \
    echo "No recent AVC denials found"
    echo ""
    
    print_success "Basic SELinux tests completed"
}

set_enforcing_mode() {
    print_header "Setting SELinux to Enforcing Mode"
    
    print_info "WARNING: Setting SELinux to enforcing mode may break system functionality!"
    print_info "Make sure you understand the implications before proceeding."
    echo ""
    
    read -p "Do you want to set SELinux to enforcing mode? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "SELinux will remain in permissive mode"
        return
    fi
    
    print_info "Creating /.autorelabel for filesystem relabeling on next boot..."
    touch /.autorelabel
    
    print_info "Setting SELinux to enforcing mode..."
    setenforce 1 2>&1 | tee "$LOGS_DIR/setenforce_enforcing.log"
    
    # 永久设置为enforcing
    sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
    
    print_success "SELinux set to enforcing mode"
    print_info "System will relabel files on next boot"
}

generate_configuration_report() {
    print_header "SELinux Configuration Report"
    
    local report_file="$LOGS_DIR/selinux_config_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
SELinux Configuration Report
============================
Generated: $(date)
System: $(uname -a)

1. SELinux Status:
$(sestatus)

2. Enforcement Mode:
$(getenforce)

3. Configuration File (/etc/selinux/config):
$(cat /etc/selinux/config 2>/dev/null || echo "Not found")

4. Installed SELinux Packages:
$(dpkg -l | grep selinux 2>/dev/null || rpm -qa | grep selinux 2>/dev/null || echo "Unknown package manager")

5. Audit Service Status:
$(systemctl status auditd 2>/dev/null | head -5 || echo "Audit service not found")

6. Recent SELinux Denials (last 10):
$(ausearch -m avc -ts recent 2>/dev/null | head -10 || echo "No recent denials")

7. SELinux Booleans (relevant ones):
$(getsebool -a | grep -E "(httpd|ssh|ftp|samba)" 2>/dev/null || echo "No relevant booleans")

8. Test Environment:
$(ls -la /selinux_test/ 2>/dev/null || echo "Test environment not created")

Recommendations:
1. Review audit logs regularly: ausearch -m avc -ts recent
2. Fix SELinux denials: sealert -a /var/log/audit/audit.log
3. Test in permissive mode before switching to enforcing
4. Create custom policies for applications if needed

Configuration complete!
EOF
    
    cat "$report_file"
    print_success "Report saved to: $report_file"
}

# 主函数
main() {
    print_header "SELinux Configuration Tool"
    echo "This script will configure SELinux for the Kernel Security Lab"
    echo ""
    
    # 检查权限
    check_root
    
    # 创建日志目录
    mkdir -p "$LOGS_DIR"
    
    # 检查SELinux支持
    check_selinux_support
    
    # 检查当前状态
    check_current_status
    
    # 安装必要的包
    install_selinux_packages
    
    # 启用SELinux
    enable_selinux
    
    # 配置策略
    configure_selinux_policy
    
    # 配置审计系统
    configure_audit_system
    
    # 创建测试环境
    create_test_environment
    
    # 测试功能
    test_selinux_functionality
    
    # 询问是否设置为强制模式
    set_enforcing_mode
    
    # 生成报告
    generate_configuration_report
    
    # 最终提示
    print_header "Configuration Complete"
    print_success "SELinux has been configured successfully!"
    echo ""
    echo "Summary:"
    echo "1. SELinux is now enabled in $(getenforce) mode"
    echo "2. Audit system is configured and running"
    echo "3. Test environment created at /selinux_test"
    echo "4. Configuration report saved to logs directory"
    echo ""
    echo "Next steps:"
    echo "1. Reboot the system to apply all changes: sudo reboot"
    echo "2. After reboot, verify with: sestatus"
    echo "3. Test functionality with: cd /selinux_test && ./violation_test.sh"
    echo "4. Monitor logs: sudo tail -f /var/log/audit/audit.log"
    echo ""
    echo "Troubleshooting:"
    echo "- If system has issues, boot with: selinux=0"
    echo "- Check logs in: $LOGS_DIR/"
    echo "- Use sealert to analyze denials"
    echo ""
}

# 运行主函数
main