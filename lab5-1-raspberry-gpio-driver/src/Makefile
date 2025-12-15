# Linux内核模块Makefile
# 用于构建树莓派GPIO LED驱动模块

obj-m += gpio_led.o

# 树莓派内核构建目录
KDIR ?= /lib/modules/$(shell uname -r)/build

# 当前模块目录
PWD := $(shell pwd)

# 默认构建目标
default:
	@echo "Building GPIO LED kernel module..."
	@echo "Kernel directory: $(KDIR)"
	@echo "Current directory: $(PWD)"
	$(MAKE) -C $(KDIR) M=$(PWD) modules

# 清理构建产物
clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	@echo "Clean completed"

# 安装驱动（自动创建设备节点）
install: default
	sudo insmod gpio_led.ko
	@echo "Use: sudo chmod 666 /dev/gpio_led"

# 卸载驱动
uninstall:
	sudo rmmod gpio_led

# 重新加载驱动
reload: uninstall install

# 显示模块信息
info:
	modinfo gpio_led.ko

# 检查模块状态
status:
	@lsmod | grep gpio_led || echo "Module not loaded"

# 查看内核日志
logs:
	dmesg | tail -20

# 创建设备节点（手动）
mknod:
	sudo mknod /dev/gpio_led c $(shell awk '/gpio_led/ {print $$1}' /proc/devices) 0
	sudo chmod 666 /dev/gpio_led

# 删除设备节点
rmnod:
	sudo rm /dev/gpio_led

# 构建并测试
test: default install mknod
	sleep 1
	@echo "=== Module status ==="
	@make status
	@echo "=== Device node ==="
	@ls -la /dev/gpio_led
	@echo "=== Recent kernel messages ==="
	@dmesg | tail -10

.PHONY: default clean install uninstall reload info status logs mknod rmnod test