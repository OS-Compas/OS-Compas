/**
 * network_test.c - 网络操作示例程序
 * 
 * 用于演示网络相关的系统调用模式
 * 可以通过strace观察socket、connect、bind等系统调用
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/select.h>
#include <fcntl.h>
#include <signal.h>

#define BUFFER_SIZE 1024
#define TEST_PORT 8888
#define BACKLOG 5
#define MAX_CLIENTS 10

// 显示系统调用错误
void show_error(const char *operation) {
    fprintf(stderr, "错误: %s - %s\n", operation, strerror(errno));
}

// 1. 基础TCP客户端
void test_tcp_client() {
    printf("=== 测试TCP客户端 ===\n");
    
    int sockfd;
    struct sockaddr_in server_addr;
    char buffer[BUFFER_SIZE];
    
    // 创建TCP socket
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd == -1) {
        show_error("socket");
        return;
    }
    printf("TCP socket创建成功: fd=%d\n", sockfd);
    
    // 设置服务器地址
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(TEST_PORT);
    server_addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    
    printf("尝试连接到 127.0.0.1:%d...\n", TEST_PORT);
    
    // 连接到服务器（预期会失败，因为没有服务器在监听）
    if (connect(sockfd, (struct sockaddr*)&server_addr, sizeof(server_addr)) == -1) {
        printf("连接失败 (预期): %s\n", strerror(errno));
        // 这是正常的，因为我们没有启动服务器
    } else {
        printf("连接成功\n");
        
        // 发送测试数据
        const char *message = "Hello TCP Server!";
        ssize_t sent = send(sockfd, message, strlen(message), 0);
        if (sent == -1) {
            show_error("send");
        } else {
            printf("发送 %zd 字节数据\n", sent);
        }
        
        // 尝试接收数据
        ssize_t received = recv(sockfd, buffer, BUFFER_SIZE - 1, 0);
        if (received == -1) {
            show_error("recv");
        } else if (received > 0) {
            buffer[received] = '\0';
            printf("接收数据: %s\n", buffer);
        }
    }
    
    close(sockfd);
    printf("TCP客户端测试完成\n\n");
}

// 2. 基础TCP服务器
void test_tcp_server() {
    printf("=== 测试TCP服务器 ===\n");
    
    int server_fd, client_fd;
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_len;
    char buffer[BUFFER_SIZE];
    
    // 创建TCP socket
    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd == -1) {
        show_error("socket");
        return;
    }
    printf("服务器socket创建成功: fd=%d\n", server_fd);
    
    // 设置socket选项（地址重用）
    int opt = 1;
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) == -1) {
        show_error("setsockopt");
    }
    
    // 绑定地址
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(TEST_PORT);
    
    if (bind(server_fd, (struct sockaddr*)&server_addr, sizeof(server_addr)) == -1) {
        show_error("bind");
        close(server_fd);
        return;
    }
    printf("绑定到端口 %d 成功\n", TEST_PORT);
    
    // 开始监听
    if (listen(server_fd, BACKLOG) == -1) {
        show_error("listen");
        close(server_fd);
        return;
    }
    printf("开始监听连接...\n");
    
    // 设置非阻塞模式，避免accept阻塞
    int flags = fcntl(server_fd, F_GETFL, 0);
    fcntl(server_fd, F_SETFL, flags | O_NONBLOCK);
    
    // 尝试接受连接（应该立即返回，因为没有客户端连接）
    client_len = sizeof(client_addr);
    client_fd = accept(server_fd, (struct sockaddr*)&client_addr, &client_len);
    
    if (client_fd == -1) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            printf("没有客户端连接 (预期)\n");
        } else {
            show_error("accept");
        }
    } else {
        printf("接受客户端连接: fd=%d\n", client_fd);
        
        // 处理客户端数据
        ssize_t received = recv(client_fd, buffer, BUFFER_SIZE - 1, 0);
        if (received > 0) {
            buffer[received] = '\0';
            printf("接收客户端数据: %s\n", buffer);
            
            // 发送响应
            const char *response = "Hello from server!";
            send(client_fd, response, strlen(response), 0);
        }
        
        close(client_fd);
    }
    
    close(server_fd);
    printf("TCP服务器测试完成\n\n");
}

// 3. UDP客户端测试
void test_udp_client() {
    printf("=== 测试UDP客户端 ===\n");
    
    int sockfd;
    struct sockaddr_in server_addr;
    char buffer[BUFFER_SIZE];
    
    // 创建UDP socket
    sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd == -1) {
        show_error("socket");
        return;
    }
    printf("UDP socket创建成功: fd=%d\n", sockfd);
    
    // 设置服务器地址
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(TEST_PORT);
    server_addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    
    // 发送UDP数据报
    const char *message = "Hello UDP!";
    ssize_t sent = sendto(sockfd, message, strlen(message), 0,
                         (struct sockaddr*)&server_addr, sizeof(server_addr));
    if (sent == -1) {
        show_error("sendto");
    } else {
        printf("发送UDP数据报: %zd 字节\n", sent);
    }
    
    // 设置接收超时
    struct timeval timeout;
    timeout.tv_sec = 1;
    timeout.tv_usec = 0;
    setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    
    // 尝试接收响应（应该超时）
    socklen_t addr_len = sizeof(server_addr);
    ssize_t received = recvfrom(sockfd, buffer, BUFFER_SIZE - 1, 0,
                               (struct sockaddr*)&server_addr, &addr_len);
    if (received == -1) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            printf("接收超时 (预期，没有UDP服务器)\n");
        } else {
            show_error("recvfrom");
        }
    } else {
        buffer[received] = '\0';
        printf("接收UDP响应: %s\n", buffer);
    }
    
    close(sockfd);
    printf("UDP客户端测试完成\n\n");
}

// 4. UDP服务器测试
void test_udp_server() {
    printf("=== 测试UDP服务器 ===\n");
    
    int sockfd;
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_len;
    char buffer[BUFFER_SIZE];
    
    // 创建UDP socket
    sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd == -1) {
        show_error("socket");
        return;
    }
    printf("UDP服务器socket创建成功: fd=%d\n", sockfd);
    
    // 绑定地址
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(TEST_PORT + 1);  // 使用不同端口避免冲突
    
    if (bind(sockfd, (struct sockaddr*)&server_addr, sizeof(server_addr)) == -1) {
        show_error("bind");
        close(sockfd);
        return;
    }
    printf("UDP服务器绑定到端口 %d\n", TEST_PORT + 1);
    
    // 设置非阻塞和超时
    int flags = fcntl(sockfd, F_GETFL, 0);
    fcntl(sockfd, F_SETFL, flags | O_NONBLOCK);
    
    struct timeval timeout = {1, 0};  // 1秒超时
    setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    
    // 尝试接收数据（应该立即返回）
    client_len = sizeof(client_addr);
    ssize_t received = recvfrom(sockfd, buffer, BUFFER_SIZE - 1, 0,
                               (struct sockaddr*)&client_addr, &client_len);
    if (received == -1) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            printf("没有收到UDP数据 (预期)\n");
        } else {
            show_error("recvfrom");
        }
    } else {
        buffer[received] = '\0';
        printf("接收UDP数据: %s\n", buffer);
        
        // 发送响应
        const char *response = "UDP Server Response";
        sendto(sockfd, response, strlen(response), 0,
              (struct sockaddr*)&client_addr, client_len);
    }
    
    close(sockfd);
    printf("UDP服务器测试完成\n\n");
}

// 5. 域名解析测试
void test_dns_resolution() {
    printf("=== 测试DNS域名解析 ===\n");
    
    struct hostent *host_info;
    struct in_addr **addr_list;
    
    // 解析localhost
    host_info = gethostbyname("localhost");
    if (host_info == NULL) {
        show_error("gethostbyname");
        return;
    }
    
    printf("localhost 解析结果:\n");
    printf("  正式主机名: %s\n", host_info->h_name);
    printf("  地址类型: %s\n", 
           (host_info->h_addrtype == AF_INET) ? "IPv4" : "IPv6");
    
    addr_list = (struct in_addr **)host_info->h_addr_list;
    for (int i = 0; addr_list[i] != NULL; i++) {
        printf("  地址 %d: %s\n", i + 1, inet_ntoa(*addr_list[i]));
    }
    
    // 解析不存在的域名（测试错误处理）
    printf("\n测试错误域名解析...\n");
    host_info = gethostbyname("nonexistent-domain-that-should-not-exist.local");
    if (host_info == NULL) {
        printf("域名解析失败 (预期): %s\n", hstrerror(h_errno));
    }
    
    printf("DNS解析测试完成\n\n");
}

// 6. 网络地址转换测试
void test_address_conversion() {
    printf("=== 测试网络地址转换 ===\n");
    
    struct in_addr ip_addr;
    struct in6_addr ip6_addr;
    char ip_str[INET6_ADDRSTRLEN];
    
    // IPv4地址转换
    printf("IPv4地址转换:\n");
    if (inet_pton(AF_INET, "192.168.1.1", &ip_addr) == 1) {
        printf("  字符串 -> 二进制: 192.168.1.1 -> 0x%x\n", ip_addr.s_addr);
    }
    
    if (inet_ntop(AF_INET, &ip_addr, ip_str, INET_ADDRSTRLEN)) {
        printf("  二进制 -> 字符串: 0x%x -> %s\n", ip_addr.s_addr, ip_str);
    }
    
    // IPv6地址转换
    printf("IPv6地址转换:\n");
    if (inet_pton(AF_INET6, "::1", &ip6_addr) == 1) {
        printf("  字符串 -> 二进制: ::1 -> 成功\n");
    }
    
    if (inet_ntop(AF_INET6, &ip6_addr, ip_str, INET6_ADDRSTRLEN)) {
        printf("  二进制 -> 字符串: -> %s\n", ip_str);
    }
    
    // 测试无效地址
    printf("测试无效地址处理:\n");
    if (inet_pton(AF_INET, "invalid.ip.address", &ip_addr) == 0) {
        printf("  无效地址检测: 正确拒绝无效地址\n");
    }
    
    printf("地址转换测试完成\n\n");
}

// 7. 多路复用I/O测试（select）
void test_select_io() {
    printf("=== 测试select多路复用 ===\n");
    
    fd_set read_fds, write_fds, except_fds;
    struct timeval timeout;
    int max_fd = 0;
    
    // 初始化文件描述符集合
    FD_ZERO(&read_fds);
    FD_ZERO(&write_fds);
    FD_ZERO(&except_fds);
    
    // 添加标准输入到读集合
    FD_SET(STDIN_FILENO, &read_fds);
    max_fd = STDIN_FILENO;
    
    // 创建一个TCP socket添加到写集合（测试可写条件）
    int test_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (test_socket != -1) {
        FD_SET(test_socket, &write_fds);
        if (test_socket > max_fd) max_fd = test_socket;
        
        // 设置非阻塞
        int flags = fcntl(test_socket, F_GETFL, 0);
        fcntl(test_socket, F_SETFL, flags | O_NONBLOCK);
        
        // 尝试连接（会立即返回）
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_port = htons(TEST_PORT);
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr);
        connect(test_socket, (struct sockaddr*)&addr, sizeof(addr));
    }
    
    // 设置超时
    timeout.tv_sec = 1;
    timeout.tv_usec = 0;
    
    printf("调用select (1秒超时)...\n");
    int ready = select(max_fd + 1, &read_fds, &write_fds, &except_fds, &timeout);
    
    if (ready == -1) {
        show_error("select");
    } else if (ready == 0) {
        printf("select超时 (预期)\n");
    } else {
        printf("select返回 %d 个就绪描述符\n", ready);
        
        if (FD_ISSET(STDIN_FILENO, &read_fds)) {
            printf("  标准输入可读\n");
        }
        
        if (test_socket != -1 && FD_ISSET(test_socket, &write_fds)) {
            printf("  socket可写\n");
        }
    }
    
    if (test_socket != -1) {
        close(test_socket);
    }
    
    printf("select测试完成\n\n");
}

// 8. Socket选项测试
void test_socket_options() {
    printf("=== 测试Socket选项 ===\n");
    
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd == -1) {
        show_error("socket");
        return;
    }
    
    // 测试各种socket选项
    int optval;
    socklen_t optlen = sizeof(optval);
    
    // 获取发送缓冲区大小
    if (getsockopt(sockfd, SOL_SOCKET, SO_SNDBUF, &optval, &optlen) == 0) {
        printf("发送缓冲区大小: %d 字节\n", optval);
    }
    
    // 获取接收缓冲区大小
    if (getsockopt(sockfd, SOL_SOCKET, SO_RCVBUF, &optval, &optlen) == 0) {
        printf("接收缓冲区大小: %d 字节\n", optval);
    }
    
    // 设置和获取超时选项
    struct timeval timeout;
    timeout.tv_sec = 5;
    timeout.tv_usec = 0;
    
    if (setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) == 0) {
        printf("设置接收超时: %ld 秒\n", timeout.tv_sec);
    }
    
    // 测试错误socket选项（应该失败）
    if (setsockopt(sockfd, SOL_SOCKET, 0xFFFF, &optval, sizeof(optval)) == -1) {
        printf("无效选项设置失败 (预期): %s\n", strerror(errno));
    }
    
    close(sockfd);
    printf("Socket选项测试完成\n\n");
}

// 9. 网络接口信息测试
void test_network_interfaces() {
    printf("=== 测试网络接口信息 ===\n");
    
    // 获取主机名
    char hostname[256];
    if (gethostname(hostname, sizeof(hostname)) == 0) {
        printf("主机名: %s\n", hostname);
    } else {
        show_error("gethostname");
    }
    
    // 简单的网络测试 - 尝试创建多个socket
    printf("创建多个socket测试:\n");
    int sockets[5];
    int created = 0;
    
    for (int i = 0; i < 5; i++) {
        sockets[i] = socket(AF_INET, SOCK_STREAM, 0);
        if (sockets[i] != -1) {
            created++;
            printf("  创建socket %d: fd=%d\n", i + 1, sockets[i]);
        }
    }
    
    printf("成功创建 %d 个socket\n", created);
    
    // 关闭所有socket
    for (int i = 0; i < 5; i++) {
        if (sockets[i] != -1) {
            close(sockets[i]);
        }
    }
    
    printf("网络接口测试完成\n\n");
}

// 10. 错误处理测试
void test_network_errors() {
    printf("=== 测试网络错误处理 ===\n");
    
    // 测试各种错误条件
    
    // 1. 无效地址族
    int sockfd = socket(999, SOCK_STREAM, 0);
    if (sockfd == -1) {
        printf("无效地址族错误 (预期): %s\n", strerror(errno));
    }
    
    // 2. 无效协议
    sockfd = socket(AF_INET, 999, 0);
    if (sockfd == -1) {
        printf("无效协议错误 (预期): %s\n", strerror(errno));
    }
    
    // 3. 绑定到特权端口
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd != -1) {
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_port = htons(80);  // HTTP端口，需要特权
        addr.sin_addr.s_addr = INADDR_ANY;
        
        if (bind(sockfd, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
            printf("绑定特权端口错误 (预期): %s\n", strerror(errno));
        }
        close(sockfd);
    }
    
    // 4. 连接被拒绝
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd != -1) {
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_port = htons(1);  // 不太可能有服务在这个端口
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr);
        
        if (connect(sockfd, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
            printf("连接被拒绝错误 (预期): %s\n", strerror(errno));
        }
        close(sockfd);
    }
    
    printf("网络错误处理测试完成\n\n");
}

// 清理函数
void cleanup() {
    printf("=== 网络测试清理 ===\n");
    // 这里可以添加任何必要的清理代码
    printf("网络测试清理完成\n");
}

// 显示使用说明
void show_usage(const char *program_name) {
    printf("用法: %s [选项]\n", program_name);
    printf("选项:\n");
    printf("  all       运行所有测试（默认）\n");
    printf("  tcp       只运行TCP客户端测试\n");
    printf("  tcpsrv    只运行TCP服务器测试\n");
    printf("  udp       只运行UDP客户端测试\n");
    printf("  udpsrv    只运行UDP服务器测试\n");
    printf("  dns       只运行DNS解析测试\n");
    printf("  addr      只运行地址转换测试\n");
    printf("  select    只运行select测试\n");
    printf("  opts      只运行socket选项测试\n");
    printf("  iface     只运行网络接口测试\n");
    printf("  errors    只运行错误处理测试\n");
    printf("  clean     清理\n");
    printf("\n示例:\n");
    printf("  %s all              # 运行所有测试\n", program_name);
    printf("  %s tcp udp dns      # 运行TCP、UDP和DNS测试\n", program_name);
}

int main(int argc, char *argv[]) {
    printf("网络操作示例程序 - 系统调用追踪演示\n");
    printf("====================================\n\n");
    
    // 如果没有参数，运行所有测试
    if (argc == 1) {
        test_tcp_client();
        test_tcp_server();
        test_udp_client();
        test_udp_server();
        test_dns_resolution();
        test_address_conversion();
        test_select_io();
        test_socket_options();
        test_network_interfaces();
        test_network_errors();
    } else {
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "all") == 0) {
                test_tcp_client();
                test_tcp_server();
                test_udp_client();
                test_udp_server();
                test_dns_resolution();
                test_address_conversion();
                test_select_io();
                test_socket_options();
                test_network_interfaces();
                test_network_errors();
            } else if (strcmp(argv[i], "tcp") == 0) {
                test_tcp_client();
            } else if (strcmp(argv[i], "tcpsrv") == 0) {
                test_tcp_server();
            } else if (strcmp(argv[i], "udp") == 0) {
                test_udp_client();
            } else if (strcmp(argv[i], "udpsrv") == 0) {
                test_udp_server();
            } else if (strcmp(argv[i], "dns") == 0) {
                test_dns_resolution();
            } else if (strcmp(argv[i], "addr") == 0) {
                test_address_conversion();
            } else if (strcmp(argv[i], "select") == 0) {
                test_select_io();
            } else if (strcmp(argv[i], "opts") == 0) {
                test_socket_options();
            } else if (strcmp(argv[i], "iface") == 0) {
                test_network_interfaces();
            } else if (strcmp(argv[i], "errors") == 0) {
                test_network_errors();
            } else if (strcmp(argv[i], "clean") == 0) {
                cleanup();
                return 0;
            } else if (strcmp(argv[i], "help") == 0 || strcmp(argv[i], "-h") == 0) {
                show_usage(argv[0]);
                return 0;
            } else {
                printf("未知选项: %s\n", argv[i]);
                show_usage(argv[0]);
                return 1;
            }
        }
    }
    
    printf("所有网络操作测试完成！\n");
    printf("可以使用以下命令观察系统调用:\n");
    printf("  strace -o network_test_trace.log ./network_test\n");
    printf("  python3 ../src/syscall_tracer.py -f network_test_trace.log --visualize\n");
    
    return 0;
}