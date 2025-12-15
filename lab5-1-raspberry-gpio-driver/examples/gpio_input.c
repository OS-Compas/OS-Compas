/**
 * gpio_input.c - GPIO输入引脚支持扩展
 * 
 * 扩展gpio_led.c，添加完整的输入引脚支持
 */

#include <linux/interrupt.h>
#include <linux/wait.h>
#include <linux/sched.h>
#include <linux/poll.h>

/* 添加以下到全局变量 */
static int irq_number;
static DECLARE_WAIT_QUEUE_HEAD(button_wait_queue);
static atomic_t button_event_count = ATOMIC_INIT(0);

/* 添加模块参数 */
static int button_gpio = 27;
module_param(button_gpio, int, 0644);
MODULE_PARM_DESC(button_gpio, "GPIO pin for button input (default: 27)");

/* 中断处理函数 */
static irqreturn_t button_interrupt_handler(int irq, void *dev_id)
{
    atomic_inc(&button_event_count);
    wake_up_interruptible(&button_wait_queue);
    return IRQ_HANDLED;
}

/* 扩展的read函数 */
static ssize_t gpio_read_extended(struct file *file, char __user *buf,
                                 size_t len, loff_t *offset)
{
    char state;
    int button_state;
    unsigned int mask;
    
    /* 检查是否有数据可读 */
    if (atomic_read(&button_event_count) == 0) {
        if (file->f_flags & O_NONBLOCK)
            return -EAGAIN;
        
        /* 等待按钮事件 */
        wait_event_interruptible(button_wait_queue, 
                                atomic_read(&button_event_count) != 0);
    }
    
    button_state = gpio_get_value(button_gpio);
    state = button_state ? '1' : '0';
    
    if (copy_to_user(buf, &state, 1))
        return -EFAULT;
    
    atomic_dec(&button_event_count);
    
    return 1;
}

/* 添加poll函数支持 */
static unsigned int gpio_poll(struct file *file, poll_table *wait)
{
    unsigned int mask = 0;
    
    poll_wait(file, &button_wait_queue, wait);
    
    if (atomic_read(&button_event_count) > 0)
        mask |= POLLIN | POLLRDNORM;
    
    return mask;
}

/* 扩展的文件操作 */
static struct file_operations gpio_fops_extended = {
    .owner = THIS_MODULE,
    .open = gpio_open,
    .release = gpio_release,
    .write = gpio_write,
    .read = gpio_read_extended,
    .poll = gpio_poll,
};

/* 在init函数中添加按钮初始化 */
static int init_button(void)
{
    int ret;
    
    if (!gpio_is_valid(button_gpio)) {
        printk(KERN_ERR "Invalid button GPIO: %d\n", button_gpio);
        return -EINVAL;
    }
    
    ret = gpio_request(button_gpio, "gpio_button");
    if (ret) {
        printk(KERN_ERR "Failed to request GPIO%d for button\n", button_gpio);
        return ret;
    }
    
    ret = gpio_direction_input(button_gpio);
    if (ret) {
        printk(KERN_ERR "Failed to set GPIO%d as input\n", button_gpio);
        gpio_free(button_gpio);
        return ret;
    }
    
    /* 设置中断 */
    irq_number = gpio_to_irq(button_gpio);
    ret = request_irq(irq_number,
                     button_interrupt_handler,
                     IRQF_TRIGGER_RISING | IRQF_TRIGGER_FALLING,
                     "gpio_button",
                     NULL);
    
    if (ret) {
        printk(KERN_ERR "Failed to request IRQ for button\n");
        gpio_free(button_gpio);
        return ret;
    }
    
    printk(KERN_INFO "Button initialized on GPIO%d, IRQ %d\n", 
           button_gpio, irq_number);
    
    return 0;
}

/* 在exit函数中添加按钮清理 */
static void cleanup_button(void)
{
    free_irq(irq_number, NULL);
    gpio_free(button_gpio);
}