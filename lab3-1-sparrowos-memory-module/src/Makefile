# SparrowOS 内存管理实验 Makefile
# RISC-V 64位，裸机环境

# 工具链配置
TOOLCHAIN_PREFIX = riscv64-unknown-elf-
CC = $(TOOLCHAIN_PREFIX)gcc
LD = $(TOOLCHAIN_PREFIX)ld
OBJCOPY = $(TOOLCHAIN_PREFIX)objcopy
OBJDUMP = $(TOOLPHONY: all clean run debug

all: sparrowos.bin

sparrowos.bin: sparrowos.elf
	$(OBJCOPY) -O binary $< $@

sparrowos.elf: kernel/entry.o kernel/main.o kernel/print.o src/memory.o src/memory_test.o
	$(LD) -T src/link.ld -o $@ $^

kernel/entry.o: kernel/entry.S
	$(CC) $(CFLAGS) -c $< -o $@

kernel/main.o: kernel/main.c
	$(CC) $(CFLAGS) -Iinclude -c $< -o $@

kernel/print.o: kernel/print.c
	$(CC) $(CFLAGS) -Iinclude -c $< -o $@

src/memory.o: src/memory.c
	$(CC) $(CFLAGS) -Iinclude -c $< -o $@

src/memory_test.o: src/memory_test.c
	$(CC) $(CFLAGS) -Iinclude -c $< -o $@

# 编译标志
CFLAGS = -Wall -Werror -O2 -mabi=lp64 -march=rv64gc -ffreestanding -nostdlib -fno-builtin

# 清理
clean:
	rm -f *.o *.elf *.bin kernel/*.o src/*.o

# 运行 QEMU
run: sparrowos.bin
	qemu-system-riscv64 -machine virt -nographic -bios none -kernel sparrowos.bin

# 调试模式
debug: sparrowos.elf
	qemu-system-riscv64 -machine virt -nographic -bios none -kernel sparrowos.elf -s -S

# 反汇编查看
disasm: sparrowos.elf
	$(OBJDUMP) -d sparrowos.elf

# 内存布局查看
layout: sparrowos.elf
	$(OBJDUMP) -h sparrowos.elf

.PHONY: all clean run debug disasm layout