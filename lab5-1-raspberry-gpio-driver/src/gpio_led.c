/**
 * gpio_led.c - 树莓派GPIO LED驱动
 *
 * 实现一个字符设备驱动，控制GPIO引脚点亮LED
 * 支持通过write命令控制亮灭
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/gpio.h>
#include <linux/uaccess.h>
#include <linux/slab.h>

/* 模块信息 */
MODULE_LICENSE("GPL");
MODULE_AUTHOR("OS-Lab-Team");
MODULE_DESCRIPTION("Raspberry Pi GPIO LED Driver");
MODULE_VERSION("1.0");

/* GPIO引脚配置 - 树莓派默认使用BCM编号 */
#define GPIO_LED_PIN 17      /* GPIO17 - 物理引脚11 */
#define GPIO_BUTTON_PIN 27   /* GPIO27 - 物理引脚13 (扩展挑战) */

/* 设备参数 */
#define DEVICE_NAME "gpio_led"
#define CLASS_NAME "gpio_class"
#define DEVICE_MINOR 0

/* 全局变量 */
static dev_t dev_num;
static struct class *gpio_class = NULL;
static struct device *gpio_device = NULL;
static struct cdev gpio_cdev;

/* 模块参数 */
static int gpio_pin = GPIO_LED_PIN;
module_param(gpio_pin, int, 0644);
MODULE_PARM_DESC(gpio_pin, "GPIO pin number for LED (default: 17)");

/* 扩展挑战：输入引脚支持 */
static int use_button = 0;  /* 是否启用按钮输入功能 */
module_param(use_button, int, 0644);
MODULE_PARM_DESC(use_button, "Enable button input (default: 0)");

/**
 * 设备打开函数
 */
static int gpio_open(struct inode *inode, struct file *file)
{
    printk(KERN_INFO "GPIO_LED: Device opened\n");
    return 0;
}

/**
 * 设备关闭函数
 */
static int gpio_release(struct inode *inode, struct file *file)
{
    printk(KERN_INFO "GPIO_LED: Device closed\n");
    return 0;
}

/**
 * 设备写入函数 - 控制LED亮灭
 */
static ssize_t gpio_write(struct file *file, const char __user *buf,
                         size_t len, loff_t *offset)
{
    char value;
    
    if (copy_from_user(&value, buf, 1)) {
        return -EFAULT;
    }
    
    if (value == '1') {
        gpio_set_value(gpio_pin, 1);
        printk(KERN_INFO "GPIO_LED: LED ON (GPIO%d = HIGH)\n", gpio_pin);
    } else if (value == '0') {
        gpio_set_value(gpio_pin, 0);
        printk(KERN_INFO "GPIO_LED: LED OFF (GPIO%d = LOW)\n", gpio_pin);
    } else {
        printk(KERN_WARNING "GPIO_LED: Invalid command '%c'\n", value);
        return -EINVAL;
    }
    
    return 1;
}

/**
 * 设备读取函数 - 读取按钮状态（扩展挑战）
 */
static ssize_t gpio_read(struct file *file, char __user *buf,
                        size_t len, loff_t *offset)
{
    char state;
    int button_state = 0;
    
    if (use_button) {
        button_state = gpio_get_value(GPIO_BUTTON_PIN);
        state = button_state ? '1' : '0';
        
        if (copy_to_user(buf, &state, 1)) {
            return -EFAULT;
        }
        
        printk(KERN_DEBUG "GPIO_LED: Button state: %d\n", button_state);
        return 1;
    }
    
    return 0;
}

/* 文件操作结构体 */
static struct file_operations gpio_fops = {
    .owner = THIS_MODULE,
    .open = gpio_open,
    .release = gpio_release,
    .write = gpio_write,
    .read = gpio_read,
};

/**
 * 模块初始化函数
 */
static int __init gpio_led_init(void)
{
    int ret;
    
    printk(KERN_INFO "GPIO_LED: Initializing driver...\n");
    
    /* 1. 分配设备号 */
    ret = alloc_chrdev_region(&dev_num, DEVICE_MINOR, 1, DEVICE_NAME);
    if (ret < 0) {
        printk(KERN_ERR "GPIO_LED: Failed to allocate device number\n");
        return ret;
    }
    
    printk(KERN_INFO "GPIO_LED: Major number = %d\n", MAJOR(dev_num));
    
    /* 2. 创建设备类 */
    gpio_class = class_create(THIS_MODULE, CLASS_NAME);
    if (IS_ERR(gpio_class)) {
        unregister_chrdev_region(dev_num, 1);
        printk(KERN_ERR "GPIO_LED: Failed to create class\n");
        return PTR_ERR(gpio_class);
    }
    
    /* 3. 创建设备文件 */
    gpio_device = device_create(gpio_class, NULL, dev_num, NULL, DEVICE_NAME);
    if (IS_ERR(gpio_device)) {
        class_destroy(gpio_class);
        unregister_chrdev_region(dev_num, 1);
        printk(KERN_ERR "GPIO_LED: Failed to create device\n");
        return PTR_ERR(gpio_device);
    }
    
    /* 4. 初始化字符设备 */
    cdev_init(&gpio_cdev, &gpio_fops);
    gpio_cdev.owner = THIS_MODULE;
    
    /* 5. 添加字符设备到系统 */
    ret = cdev_add(&gpio_cdev, dev_num, 1);
    if (ret < 0) {
        device_destroy(gpio_class, dev_num);
        class_destroy(gpio_class);
        unregister_chrdev_region(dev_num, 1);
        printk(KERN_ERR "GPIO_LED: Failed to add cdev\n");
        return ret;
    }
    
    /* 6. 初始化GPIO引脚 */
    if (!gpio_is_valid(gpio_pin)) {
        printk(KERN_ERR "GPIO_LED: Invalid GPIO pin %d\n", gpio_pin);
        ret = -EINVAL;
        goto error;
    }
    
    ret = gpio_request(gpio_pin, "gpio_led");
    if (ret) {
        printk(KERN_ERR "GPIO_LED: Failed to request GPIO%d\n", gpio_pin);
        goto error;
    }
    
    ret = gpio_direction_output(gpio_pin, 0);
    if (ret) {
        printk(KERN_ERR "GPIO_LED: Failed to set GPIO%d as output\n", gpio_pin);
        gpio_free(gpio_pin);
        goto error;
    }
    
    /* 7. 初始化按钮GPIO（扩展挑战） */
    if (use_button) {
        if (!gpio_is_valid(GPIO_BUTTON_PIN)) {
            printk(KERN_ERR "GPIO_LED: Invalid button GPIO pin %d\n", GPIO_BUTTON_PIN);
        } else {
            ret = gpio_request(GPIO_BUTTON_PIN, "gpio_button");
            if (ret) {
                printk(KERN_WARNING "GPIO_LED: Failed to request button GPIO%d\n", GPIO_BUTTON_PIN);
            } else {
                ret = gpio_direction_input(GPIO_BUTTON_PIN);
                if (ret) {
                    printk(KERN_WARNING "GPIO_LED: Failed to set button GPIO%d as input\n", GPIO_BUTTON_PIN);
                    gpio_free(GPIO_BUTTON_PIN);
                } else {
                    printk(KERN_INFO "GPIO_LED: Button input enabled on GPIO%d\n", GPIO_BUTTON_PIN);
                }
            }
        }
    }
    
    printk(KERN_INFO "GPIO_LED: Driver initialized successfully\n");
    printk(KERN_INFO "GPIO_LED: Use: echo '1' > /dev/gpio_led  # Turn LED ON\n");
    printk(KERN_INFO "GPIO_LED: Use: echo '0' > /dev/gpio_led  # Turn LED OFF\n");
    
    if (use_button) {
        printk(KERN_INFO "GPIO_LED: Use: cat /dev/gpio_led     # Read button state\n");
    }
    
    return 0;

error:
    cdev_del(&gpio_cdev);
    device_destroy(gpio_class, dev_num);
    class_destroy(gpio_class);
    unregister_chrdev_region(dev_num, 1);
    return ret;
}

/**
 * 模块清理函数
 */
static void __exit gpio_led_exit(void)
{
    printk(KERN_INFO "GPIO_LED: Cleaning up driver...\n");
    
    /* 关闭LED */
    gpio_set_value(gpio_pin, 0);
    
    /* 释放GPIO资源 */
    gpio_free(gpio_pin);
    
    if (use_button) {
        gpio_free(GPIO_BUTTON_PIN);
    }
    
    /* 删除字符设备 */
    cdev_del(&gpio_cdev);
    
    /* 销毁设备文件 */
    device_destroy(gpio_class, dev_num);
    
    /* 销毁设备类 */
    class_destroy(gpio_class);
    
    /* 释放设备号 */
    unregister_chrdev_region(dev_num, 1);
    
    printk(KERN_INFO "GPIO_LED: Driver unloaded\n");
}

module_init(gpio_led_init);
module_exit(gpio_led_exit);