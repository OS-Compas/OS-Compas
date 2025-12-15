/**
 * file_ops.c - 文件操作示例程序
 * 
 * 用于演示不同类型的文件系统调用模式
 * 可以通过strace观察各种文件操作的系统调用
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <errno.h>

#define BUFFER_SIZE 1024
#define TEST_DIR "test_directory"
#define TEST_FILE1 "test_file1.txt"
#define TEST_FILE2 "test_file2.txt"
#define LARGE_FILE "large_file.dat"

// 显示系统调用错误
void show_error(const char *operation) {
    fprintf(stderr, "错误: %s - %s\n", operation, strerror(errno));
}

// 1. 基础文件创建和写入
void test_basic_file_operations() {
    printf("=== 测试基础文件操作 ===\n");
    
    int fd;
    ssize_t bytes_written;
    const char *text = "Hello, File System!\nThis is a test file.\n";
    
    // 创建并打开文件 (O_CREAT | O_WRONLY | O_TRUNC)
    fd = open(TEST_FILE1, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd == -1) {
        show_error("open");
        return;
    }
    printf("文件创建成功: %s\n", TEST_FILE1);
    
    // 写入数据
    bytes_written = write(fd, text, strlen(text));
    if (bytes_written == -1) {
        show_error("write");
        close(fd);
        return;
    }
    printf("写入 %zd 字节数据\n", bytes_written);
    
    // 关闭文件
    if (close(fd) == -1) {
        show_error("close");
        return;
    }
    printf("文件关闭成功\n\n");
}

// 2. 文件读取和追加
void test_file_read_append() {
    printf("=== 测试文件读取和追加 ===\n");
    
    int fd;
    ssize_t bytes_read, bytes_written;
    char buffer[BUFFER_SIZE];
    
    // 打开文件读取 (O_RDONLY)
    fd = open(TEST_FILE1, O_RDONLY);
    if (fd == -1) {
        show_error("open for reading");
        return;
    }
    
    // 读取文件内容
    bytes_read = read(fd, buffer, BUFFER_SIZE - 1);
    if (bytes_read == -1) {
        show_error("read");
        close(fd);
        return;
    }
    buffer[bytes_read] = '\0';
    printf("读取 %zd 字节数据:\n%s\n", bytes_read, buffer);
    
    close(fd);
    
    // 重新打开文件追加 (O_WRONLY | O_APPEND)
    fd = open(TEST_FILE1, O_WRONLY | O_APPEND);
    if (fd == -1) {
        show_error("open for append");
        return;
    }
    
    // 追加数据
    const char *append_text = "--- 追加的内容 ---\n";
    bytes_written = write(fd, append_text, strlen(append_text));
    if (bytes_written == -1) {
        show_error("write append");
        close(fd);
        return;
    }
    printf("追加 %zd 字节数据\n", bytes_written);
    
    close(fd);
    printf("文件追加完成\n\n");
}

// 3. 文件信息查询
void test_file_metadata() {
    printf("=== 测试文件元数据查询 ===\n");
    
    struct stat file_stat;
    
    // 获取文件状态信息
    if (stat(TEST_FILE1, &file_stat) == -1) {
        show_error("stat");
        return;
    }
    
    printf("文件信息: %s\n", TEST_FILE1);
    printf("  文件大小: %ld 字节\n", file_stat.st_size);
    printf("  索引节点: %ld\n", file_stat.st_ino);
    printf("  硬链接数: %ld\n", file_stat.st_nlink);
    printf("  权限: %o\n", file_stat.st_mode & 0777);
    printf("  用户ID: %d\n", file_stat.st_uid);
    printf("  组ID: %d\n", file_stat.st_gid);
    printf("  最后修改: %ld\n", file_stat.st_mtime);
    
    // 测试文件访问权限
    if (access(TEST_FILE1, R_OK | W_OK) == 0) {
        printf("  文件可读可写\n");
    } else {
        printf("  文件访问受限\n");
    }
    
    printf("\n");
}

// 4. 目录操作
void test_directory_operations() {
    printf("=== 测试目录操作 ===\n");
    
    DIR *dir;
    struct dirent *entry;
    
    // 创建测试目录
    if (mkdir(TEST_DIR, 0755) == -1) {
        if (errno != EEXIST) {
            show_error("mkdir");
            return;
        }
        printf("目录已存在: %s\n", TEST_DIR);
    } else {
        printf("目录创建成功: %s\n", TEST_DIR);
    }
    
    // 在目录中创建文件
    char filepath[256];
    snprintf(filepath, sizeof(filepath), "%s/%s", TEST_DIR, TEST_FILE2);
    
    int fd = open(filepath, O_CREAT | O_WRONLY, 0644);
    if (fd != -1) {
        write(fd, "Directory test file\n", 20);
        close(fd);
        printf("在目录中创建文件: %s\n", filepath);
    }
    
    // 读取目录内容
    dir = opendir(TEST_DIR);
    if (dir == NULL) {
        show_error("opendir");
        return;
    }
    
    printf("目录内容:\n");
    while ((entry = readdir(dir)) != NULL) {
        printf("  %s\n", entry->d_name);
    }
    
    closedir(dir);
    printf("目录操作完成\n\n");
}

// 5. 大文件操作（测试多次read/write）
void test_large_file_operations() {
    printf("=== 测试大文件操作 ===\n");
    
    int fd;
    ssize_t bytes_written, total_written = 0;
    char buffer[BUFFER_SIZE];
    
    // 准备测试数据
    for (int i = 0; i < BUFFER_SIZE; i++) {
        buffer[i] = 'A' + (i % 26);
    }
    
    // 创建大文件
    fd = open(LARGE_FILE, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd == -1) {
        show_error("open large file");
        return;
    }
    
    // 多次写入，模拟大文件操作
    int chunks = 50;  // 写入50个块
    for (int i = 0; i < chunks; i++) {
        bytes_written = write(fd, buffer, BUFFER_SIZE);
        if (bytes_written == -1) {
            show_error("write chunk");
            close(fd);
            return;
        }
        total_written += bytes_written;
        
        // 每10个块显示进度
        if ((i + 1) % 10 == 0) {
            printf("  已写入: %d KB\n", (i + 1) * BUFFER_SIZE / 1024);
        }
    }
    
    close(fd);
    printf("大文件创建完成: %s, 总大小: %zd 字节\n", LARGE_FILE, total_written);
    
    // 验证文件大小
    struct stat file_stat;
    if (stat(LARGE_FILE, &file_stat) == 0) {
        printf("实际文件大小: %ld 字节\n", file_stat.st_size);
    }
    
    printf("\n");
}

// 6. 文件移动和删除
void test_file_move_delete() {
    printf("=== 测试文件移动和删除 ===\n");
    
    char old_path[256], new_path[256];
    
    // 移动文件
    snprintf(old_path, sizeof(old_path), "%s/%s", TEST_DIR, TEST_FILE2);
    snprintf(new_path, sizeof(new_path), "%s/moved_%s", TEST_DIR, TEST_FILE2);
    
    if (rename(old_path, new_path) == -1) {
        show_error("rename");
    } else {
        printf("文件移动成功: %s -> %s\n", old_path, new_path);
    }
    
    // 删除文件
    if (unlink(new_path) == -1) {
        show_error("unlink");
    } else {
        printf("文件删除成功: %s\n", new_path);
    }
    
    // 删除大文件
    if (unlink(LARGE_FILE) == -1) {
        show_error("unlink large file");
    } else {
        printf("文件删除成功: %s\n", LARGE_FILE);
    }
    
    printf("文件清理完成\n\n");
}

// 7. 错误处理测试（故意制造错误）
void test_error_conditions() {
    printf("=== 测试错误条件 ===\n");
    
    // 尝试打开不存在的文件
    int fd = open("non_existent_file.txt", O_RDONLY);
    if (fd == -1) {
        printf("预期错误 - 打开不存在的文件: %s\n", strerror(errno));
    } else {
        close(fd);
    }
    
    // 尝试在无权限的目录创建文件
    fd = open("/root/test_permission.txt", O_CREAT | O_WRONLY, 0644);
    if (fd == -1) {
        printf("预期错误 - 权限拒绝: %s\n", strerror(errno));
    } else {
        close(fd);
    }
    
    // 尝试读取目录作为文件
    fd = open(".", O_RDONLY);
    if (fd == -1) {
        printf("预期错误 - 读取目录: %s\n", strerror(errno));
    } else {
        char buffer[100];
        ssize_t result = read(fd, buffer, sizeof(buffer));
        if (result == -1) {
            printf("预期错误 - 从目录读取: %s\n", strerror(errno));
        }
        close(fd);
    }
    
    printf("错误条件测试完成\n\n");
}

// 8. 综合测试：文件拷贝功能
void test_file_copy() {
    printf("=== 测试文件拷贝功能 ===\n");
    
    int src_fd, dst_fd;
    ssize_t bytes_read, bytes_written;
    char buffer[BUFFER_SIZE];
    const char *copy_file = "copy_of_test_file.txt";
    
    // 打开源文件
    src_fd = open(TEST_FILE1, O_RDONLY);
    if (src_fd == -1) {
        show_error("open source file");
        return;
    }
    
    // 创建目标文件
    dst_fd = open(copy_file, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (dst_fd == -1) {
        show_error("open destination file");
        close(src_fd);
        return;
    }
    
    // 拷贝数据
    total_bytes_copied = 0;
    while ((bytes_read = read(src_fd, buffer, BUFFER_SIZE)) > 0) {
        bytes_written = write(dst_fd, buffer, bytes_read);
        if (bytes_written != bytes_read) {
            show_error("write during copy");
            break;
        }
        total_bytes_copied += bytes_written;
    }
    
    if (bytes_read == -1) {
        show_error("read during copy");
    }
    
    close(src_fd);
    close(dst_fd);
    
    printf("文件拷贝完成: %s -> %s\n", TEST_FILE1, copy_file);
    printf("拷贝数据量: %zd 字节\n", total_bytes_copied);
    
    // 验证拷贝结果
    struct stat src_stat, dst_stat;
    if (stat(TEST_FILE1, &src_stat) == 0 && stat(copy_file, &dst_stat) == 0) {
        if (src_stat.st_size == dst_stat.st_size) {
            printf("拷贝验证成功: 文件大小一致\n");
        } else {
            printf("拷贝验证失败: 大小不一致 (%ld vs %ld)\n", 
                   src_stat.st_size, dst_stat.st_size);
        }
    }
    
    // 清理拷贝的文件
    unlink(copy_file);
    printf("临时拷贝文件已清理\n\n");
}

// 显示使用说明
void show_usage(const char *program_name) {
    printf("用法: %s [选项]\n", program_name);
    printf("选项:\n");
    printf("  all     运行所有测试（默认）\n");
    printf("  basic   只运行基础文件操作测试\n");
    printf("  read    只运行文件读取测试\n");
    printf("  meta    只运行元数据测试\n");
    printf("  dir     只运行目录操作测试\n");
    printf("  large   只运行大文件测试\n");
    printf("  error   只运行错误条件测试\n");
    printf("  copy    只运行文件拷贝测试\n");
    printf("  clean   清理测试文件\n");
    printf("\n示例:\n");
    printf("  %s all          # 运行所有测试\n", program_name);
    printf("  %s basic read   # 运行基础和读取测试\n", program_name);
    printf("  %s clean        # 清理测试文件\n", program_name);
}

// 清理测试文件
void cleanup_test_files() {
    printf("=== 清理测试文件 ===\n");
    
    int removed = 0;
    
    if (unlink(TEST_FILE1) == 0) {
        printf("删除文件: %s\n", TEST_FILE1);
        removed++;
    }
    
    if (unlink(LARGE_FILE) == 0) {
        printf("删除文件: %s\n", LARGE_FILE);
        removed++;
    }
    
    // 清理目录中的文件
    char filepath[256];
    snprintf(filepath, sizeof(filepath), "%s/moved_%s", TEST_DIR, TEST_FILE2);
    unlink(filepath);  // 忽略错误，文件可能不存在
    
    // 删除目录
    if (rmdir(TEST_DIR) == 0) {
        printf("删除目录: %s\n", TEST_DIR);
        removed++;
    }
    
    printf("清理完成，删除了 %d 个文件/目录\n", removed);
}

int main(int argc, char *argv[]) {
    printf("文件操作示例程序 - 系统调用追踪演示\n");
    printf("====================================\n\n");
    
    // 如果没有参数，运行所有测试
    if (argc == 1) {
        test_basic_file_operations();
        test_file_read_append();
        test_file_metadata();
        test_directory_operations();
        test_large_file_operations();
        test_file_copy();
        test_file_move_delete();
        test_error_conditions();
    } else {
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "all") == 0) {
                test_basic_file_operations();
                test_file_read_append();
                test_file_metadata();
                test_directory_operations();
                test_large_file_operations();
                test_file_copy();
                test_file_move_delete();
                test_error_conditions();
            } else if (strcmp(argv[i], "basic") == 0) {
                test_basic_file_operations();
            } else if (strcmp(argv[i], "read") == 0) {
                test_file_read_append();
            } else if (strcmp(argv[i], "meta") == 0) {
                test_file_metadata();
            } else if (strcmp(argv[i], "dir") == 0) {
                test_directory_operations();
            } else if (strcmp(argv[i], "large") == 0) {
                test_large_file_operations();
            } else if (strcmp(argv[i], "error") == 0) {
                test_error_conditions();
            } else if (strcmp(argv[i], "copy") == 0) {
                test_file_copy();
            } else if (strcmp(argv[i], "clean") == 0) {
                cleanup_test_files();
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
    
    printf("所有测试完成！\n");
    printf("可以使用以下命令观察系统调用:\n");
    printf("  strace -o file_ops_trace.log ./file_ops\n");
    printf("  python3 ../src/syscall_tracer.py -f file_ops_trace.log --visualize\n");
    
    return 0;
}