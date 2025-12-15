# 用户态中断实验Makefile
# 用于构建UINTR和Pipe测试程序

CC = gcc
CFLAGS = -Wall -O2 -pthread
TARGETS = uintr_server uintr_client pipe_server pipe_client

# 默认构建所有目标
all: $(TARGETS)

# UINTR服务器
uintr_server: uintr_server.c uintr_common.h
	$(CC) $(CFLAGS) -o uintr_server uintr_server.c

# UINTR客户端
uintr_client: uintr_client.c uintr_common.h
	$(CC) $(CFLAGS) -o uintr_client uintr_client.c

# 管道服务器
pipe_server: pipe_server.c uintr_common.h
	$(CC) $(CFLAGS) -o pipe_server pipe_server.c

# 管道客户端
pipe_client: pipe_client.c uintr_common.h
	$(CC) $(CFLAGS) -o pipe_client pipe_client.c

# 清理构建产物
clean:
	rm -f $(TARGETS) *.o

# 安装到系统路径
install: all
	@echo "Installing binaries to /usr/local/bin/"
	@sudo cp $(TARGETS) /usr/local/bin/ 2>/dev/null || echo "Installation may require sudo privileges"

# 运行基本测试
test: all
	@echo "=== Starting basic test ==="
	@./scripts/test_basic.sh

# 运行性能测试
perf: all
	@echo "=== Starting performance test ==="
	@./scripts/benchmark.sh

.PHONY: all clean install test perf