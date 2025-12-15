/**
 * gpio_pwm.c - PWM控制扩展
 * 
 * 添加PWM支持，实现LED亮度调节
 */

#include <linux/timer.h>
#include <linux/jiffies.h>

/* 添加PWM相关全局变量 */
struct pwm_control {
    unsigned int period_ms;      /* PWM周期 */
    unsigned int duty_cycle;     /* 占空比 0-100 */
    unsigned int state;          /* 当前状态 */
    struct timer_list timer;     /* 定时器 */
    spinlock_t lock;             /* 自旋锁 */
};

static struct pwm_control led_pwm;

/* 添加模块参数 */
static unsigned int pwm_period = 100;  /* 默认100ms周期 */
module_param(pwm_period, uint, 0644);
MODULE_PARM_DESC(pwm_period, "PWM period in milliseconds (default: 100)");

static unsigned int pwm_duty = 50;     /* 默认50%占空比 */
module_param(pwm_duty, uint, 0644);
MODULE_PARM_DESC(pwm_duty, "PWM duty cycle 0-100 (default: 50)");

/* PWM定时器回调函数 */
static void pwm_timer_callback(struct timer_list *t)
{
    struct pwm_control *pwm = from_timer(pwm, t, timer);
    unsigned long flags;
    unsigned long delay_ms;
    
    spin_lock_irqsave(&pwm->lock, flags);
    
    if (pwm->state == 0) {
        /* 当前为低电平，切换到高电平 */
        gpio_set_value(gpio_pin, 1);
        pwm->state = 1;
        /* 高电平时间 = 周期 * 占空比 */
        delay_ms = pwm->period_ms * pwm->duty_cycle / 100;
    } else {
        /* 当前为高电平，切换到低电平 */
        gpio_set_value(gpio_pin, 0);
        pwm->state = 0;
        /* 低电平时间 = 周期 * (1 - 占空比) */
        delay_ms = pwm->period_ms * (100 - pwm->duty_cycle) / 100;
    }
    
    /* 重新设置定时器 */
    mod_timer(&pwm->timer, jiffies + msecs_to_jiffies(delay_ms));
    
    spin_unlock_irqrestore(&pwm->lock, flags);
}

/* 扩展的write函数支持PWM命令 */
static ssize_t gpio_write_with_pwm(struct file *file, const char __user *buf,
                                  size_t len, loff_t *offset)
{
    char cmd[16];
    unsigned int value;
    
    if (len == 0 || len > sizeof(cmd) - 1)
        return -EINVAL;
    
    if (copy_from_user(cmd, buf, len))
        return -EFAULT;
    
    cmd[len] = '\0';
    
    /* 处理PWM命令 */
    if (strncmp(cmd, "pwm ", 4) == 0) {
        if (sscanf(cmd + 4, "%u %u", &pwm_period, &pwm_duty) != 2) {
            printk(KERN_WARNING "Invalid PWM command format\n");
            return -EINVAL;
        }
        
        if (pwm_duty > 100) {
            printk(KERN_WARNING "Duty cycle must be 0-100\n");
            return -EINVAL;
        }
        
        /* 更新PWM参数 */
        spin_lock(&led_pwm.lock);
        led_pwm.period_ms = pwm_period;
        led_pwm.duty_cycle = pwm_duty;
        
        /* 如果PWM正在运行，重新配置 */
        if (timer_pending(&led_pwm.timer)) {
            del_timer(&led_pwm.timer);
            led_pwm.state = 0;
            gpio_set_value(gpio_pin, 0);
            mod_timer(&led_pwm.timer, jiffies);
        }
        
        spin_unlock(&led_pwm.lock);
        
        printk(KERN_INFO "PWM set: period=%ums, duty=%u%%\n", 
               pwm_period, pwm_duty);
        return len;
    }
    
    /* 启动PWM */
    if (strcmp(cmd, "pwm_start") == 0) {
        if (!timer_pending(&led_pwm.timer)) {
            led_pwm.state = 0;
            gpio_set_value(gpio_pin, 0);
            mod_timer(&led_pwm.timer, jiffies);
            printk(KERN_INFO "PWM started\n");
        }
        return len;
    }
    
    /* 停止PWM */
    if (strcmp(cmd, "pwm_stop") == 0) {
        if (timer_pending(&led_pwm.timer)) {
            del_timer(&led_pwm.timer);
            gpio_set_value(gpio_pin, 0);
            printk(KERN_INFO "PWM stopped\n");
        }
        return len;
    }
    
    /* 原有的'0'/'1'命令 */
    return gpio_write(file, buf, len, offset);
}

/* 在init函数中初始化PWM */
static int init_pwm(void)
{
    spin_lock_init(&led_pwm.lock);
    
    led_pwm.period_ms = pwm_period;
    led_pwm.duty_cycle = pwm_duty;
    led_pwm.state = 0;
    
    timer_setup(&led_pwm.timer, pwm_timer_callback, 0);
    
    printk(KERN_INFO "PWM initialized: period=%ums, duty=%u%%\n",
           pwm_period, pwm_duty);
    
    return 0;
}

/* 在exit函数中清理PWM */
static void cleanup_pwm(void)
{
    if (timer_pending(&led_pwm.timer)) {
        del_timer(&led_pwm.timer);
    }
}