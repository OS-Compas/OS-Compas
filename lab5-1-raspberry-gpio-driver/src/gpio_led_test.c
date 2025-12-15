/**
 * gpio_led_test.c - 用户空间测试程序
 * 用于测试GPIO LED驱动功能
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

#define DEVICE_PATH "/dev/gpio_led"
#define BUFFER_SIZE 2

void print_usage(const char *program_name)
{
    printf("GPIO LED Test Program\n");
    printf("Usage: %s [options]\n", program_name);
    printf("Options:\n");
    printf("  on               Turn LED ON\n");
    printf("  off              Turn LED OFF\n");
    printf("  blink [count]    Blink LED specified times (default: 5)\n");
    printf("  read             Read button state (if enabled)\n");
    printf("  status           Show device information\n");
    printf("  help             Show this help message\n");
}

int turn_led(const char *state)
{
    int fd;
    char buf[2] = {0};
    
    if (strcmp(state, "on") == 0) {
        buf[0] = '1';
    } else if (strcmp(state, "off") == 0) {
        buf[0] = '0';
    } else {
        printf("Invalid state: %s\n", state);
        return -1;
    }
    
    fd = open(DEVICE_PATH, O_WRONLY);
    if (fd < 0) {
        printf("Failed to open %s: %s\n", DEVICE_PATH, strerror(errno));
        return -1;
    }
    
    if (write(fd, buf, 1) != 1) {
        printf("Failed to write to device: %s\n", strerror(errno));
        close(fd);
        return -1;
    }
    
    printf("LED turned %s\n", state);
    close(fd);
    return 0;
}

int blink_led(int count)
{
    int fd, i;
    
    fd = open(DEVICE_PATH, O_WRONLY);
    if (fd < 0) {
        printf("Failed to open %s: %s\n", DEVICE_PATH, strerror(errno));
        return -1;
    }
    
    printf("Blinking LED %d times...\n", count);
    
    for (i = 0; i < count; i++) {
        write(fd, "1", 1);
        usleep(200000);  /* 200ms */
        write(fd, "0", 1);
        if (i < count - 1) {
            usleep(200000);
        }
    }
    
    printf("Blink complete\n");
    close(fd);
    return 0;
}

int read_button_state(void)
{
    int fd;
    char buf[2];
    
    fd = open(DEVICE_PATH, O_RDONLY);
    if (fd < 0) {
        printf("Failed to open %s: %s\n", DEVICE_PATH, strerror(errno));
        return -1;
    }
    
    if (read(fd, buf, 1) != 1) {
        printf("Failed to read from device: %s\n", strerror(errno));
        close(fd);
        return -1;
    }
    
    printf("Button state: %s\n", buf[0] == '1' ? "PRESSED" : "RELEASED");
    close(fd);
    return 0;
}

void show_device_status(void)
{
    printf("Device Status:\n");
    printf("  Device path: %s\n", DEVICE_PATH);
    
    /* 检查设备文件是否存在 */
    if (access(DEVICE_PATH, F_OK) == 0) {
        printf("  Device file: EXISTS\n");
        
        /* 检查权限 */
        if (access(DEVICE_PATH, W_OK) == 0) {
            printf("  Permissions: WRITABLE\n");
        } else {
            printf("  Permissions: NOT WRITABLE (may need sudo)\n");
        }
    } else {
        printf("  Device file: NOT FOUND\n");
        printf("  Run: sudo mknod /dev/gpio_led c [major] 0\n");
    }
}

int main(int argc, char *argv[])
{
    if (argc < 2) {
        print_usage(argv[0]);
        return 0;
    }
    
    if (strcmp(argv[1], "on") == 0) {
        return turn_led("on");
    } else if (strcmp(argv[1], "off") == 0) {
        return turn_led("off");
    } else if (strcmp(argv[1], "blink") == 0) {
        int count = 5;
        if (argc > 2) {
            count = atoi(argv[2]);
            if (count <= 0) count = 5;
        }
        return blink_led(count);
    } else if (strcmp(argv[1], "read") == 0) {
        return read_button_state();
    } else if (strcmp(argv[1], "status") == 0) {
        show_device_status();
        return 0;
    } else if (strcmp(argv[1], "help") == 0) {
        print_usage(argv[0]);
        return 0;
    } else {
        printf("Unknown command: %s\n", argv[1]);
        print_usage(argv[0]);
        return 1;
    }
    
    return 0;
}