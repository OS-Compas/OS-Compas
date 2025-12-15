/**
 * context_switch.S - x86架构上下文切换汇编实现
 * 位于: kernel/arch/x86/context_switch.S
 */

/* 全局符号声明 */
.global context_save
.global context_restore  
.global context_switch
.global interrupt_context_save
.global interrupt_context_restore

/* 定义常量 */
.set PCB_CONTEXT_OFFSET, 0
.set PCB_ESP_OFFSET, PCB_CONTEXT_OFFSET
.set PCB_EIP_OFFSET, PCB_CONTEXT_OFFSET + 4
.set PCB_EFLAGS_OFFSET, PCB_CONTEXT_OFFSET + 8
.set PCB_EAX_OFFSET, PCB_CONTEXT_OFFSET + 12
.set PCB_EBX_OFFSET, PCB_CONTEXT_OFFSET + 16
.set PCB_ECX_OFFSET, PCB_CONTEXT_OFFSET + 20
.set PCB_EDX_OFFSET, PCB_CONTEXT_OFFSET + 24
.set PCB_ESI_OFFSET, PCB_CONTEXT_OFFSET + 28
.set PCB_EDI_OFFSET, PCB_CONTEXT_OFFSET + 32
.set PCB_EBP_OFFSET, PCB_CONTEXT_OFFSET + 36

/**
 * context_save - 保存当前CPU上下文到PCB
 * 参数: pcb_t *pcb (通过eax传递)
 */
context_save:
    /* 保存通用寄存器到栈 */
    pusha           /* 保存EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI */
    pushf           /* 保存标志寄存器 */
    
    /* 获取PCB指针 */
    movl 44(%esp), %eax     /* eax = pcb指针 (跳过pusha和pushf) */
    
    /* 保存栈指针 */
    movl %esp, PCB_ESP_OFFSET(%eax)
    
    /* 保存指令指针 */
    movl 4(%esp), %ebx      /* 获取返回地址 */
    movl %ebx, PCB_EIP_OFFSET(%eax)
    
    /* 保存标志寄存器 */
    movl (%esp), %ebx
    movl %ebx, PCB_EFLAGS_OFFSET(%eax)
    
    /* 保存通用寄存器到PCB结构 */
    movl 8(%esp), %ebx      /* eax */
    movl %ebx, PCB_EAX_OFFSET(%eax)
    movl 12(%esp), %ebx     /* ecx */
    movl %ebx, PCB_ECX_OFFSET(%eax)
    movl 16(%esp), %ebx     /* edx */
    movl %ebx, PCB_EDX_OFFSET(%eax)
    movl 20(%esp), %ebx     /* ebx */
    movl %ebx, PCB_EBX_OFFSET(%eax)
    movl 28(%esp), %ebx     /* esi */
    movl %ebx, PCB_ESI_OFFSET(%eax)
    movl 32(%esp), %ebx     /* edi */
    movl %ebx, PCB_EDI_OFFSET(%eax)
    movl 36(%esp), %ebx     /* ebp */
    movl %ebx, PCB_EBP_OFFSET(%eax)
    
    /* 恢复栈 */
    addl $4, %esp           /* 跳过eflags */
    popa                    /* 恢复通用寄存器 */
    
    ret

/**
 * context_restore - 从PCB恢复CPU上下文
 * 参数: pcb_t *pcb (通过eax传递)
 */
context_restore:
    /* 获取PCB指针 */
    movl 4(%esp), %eax      /* eax = pcb指针 */
    
    /* 恢复栈指针 */
    movl PCB_ESP_OFFSET(%eax), %esp
    
    /* 设置返回地址 */
    movl PCB_EIP_OFFSET(%eax), %ebx
    movl %ebx, 4(%esp)
    
    /* 恢复标志寄存器 */
    movl PCB_EFLAGS_OFFSET(%eax), %ebx
    movl %ebx, (%esp)
    
    /* 恢复通用寄存器到栈 */
    movl PCB_EAX_OFFSET(%eax), %ebx
    movl %ebx, 8(%esp)
    movl PCB_ECX_OFFSET(%eax), %ebx
    movl %ebx, 12(%esp)
    movl PCB_EDX_OFFSET(%eax), %ebx
    movl %ebx, 16(%esp)
    movl PCB_EBX_OFFSET(%eax), %ebx
    movl %ebx, 20(%esp)
    movl PCB_ESI_OFFSET(%eax), %ebx
    movl %ebx, 28(%esp)
    movl PCB_EDI_OFFSET(%eax), %ebx
    movl %ebx, 32(%esp)
    movl PCB_EBP_OFFSET(%eax), %ebx
    movl %ebx, 36(%esp)
    
    ret

/**
 * context_switch - 执行完整的上下文切换
 * 参数: pcb_t *current (第一个参数)
 *       pcb_t *next    (第二个参数)
 */
context_switch:
    /* 保存当前进程上下文 */
    pusha                   /* 保存通用寄存器 */
    pushf                   /* 保存标志寄存器 */
    
    /* 获取参数 */
    movl 44(%esp), %eax     /* eax = current PCB (跳过pusha+pushf) */
    movl 48(%esp), %ebx     /* ebx = next PCB */
    
    /* 检查current是否为NULL */
    testl %eax, %eax
    jz .skip_current_save
    
    /* 保存当前进程上下文 */
    movl %esp, PCB_ESP_OFFSET(%eax)
    
    /* 保存指令指针 */
    movl 4(%esp), %ecx      /* 获取返回地址 */
    movl %ecx, PCB_EIP_OFFSET(%eax)
    
    /* 保存标志寄存器 */
    movl (%esp), %ecx
    movl %ecx, PCB_EFLAGS_OFFSET(%eax)
    
    /* 保存通用寄存器 */
    movl 8(%esp), %ecx      /* eax */
    movl %ecx, PCB_EAX_OFFSET(%eax)
    movl 12(%esp), %ecx     /* ecx */
    movl %ecx, PCB_ECX_OFFSET(%eax)
    movl 16(%esp), %ecx     /* edx */
    movl %ecx, PCB_EDX_OFFSET(%eax)
    movl 20(%esp), %ecx     /* ebx */
    movl %ecx, PCB_EBX_OFFSET(%eax)
    movl 28(%esp), %ecx     /* esi */
    movl %ecx, PCB_ESI_OFFSET(%eax)
    movl 32(%esp), %ecx     /* edi */
    movl %ecx, PCB_EDI_OFFSET(%eax)
    movl 36(%esp), %ecx     /* ebp */
    movl %ecx, PCB_EBP_OFFSET(%eax)
    
.skip_current_save:
    /* 切换到新进程的栈 */
    movl PCB_ESP_OFFSET(%ebx), %esp
    
    /* 设置返回地址 */
    movl PCB_EIP_OFFSET(%ebx), %ecx
    movl %ecx, 4(%esp)
    
    /* 恢复标志寄存器 */
    movl PCB_EFLAGS_OFFSET(%ebx), %ecx
    movl %ecx, (%esp)
    
    /* 恢复通用寄存器 */
    movl PCB_EAX_OFFSET(%ebx), %eax
    movl %eax, 8(%esp)
    movl PCB_ECX_OFFSET(%ebx), %ecx
    movl %ecx, 12(%esp)
    movl PCB_EDX_OFFSET(%ebx), %edx
    movl %edx, 16(%esp)
    movl PCB_EBX_OFFSET(%ebx), %ebx
    movl %ebx, 20(%esp)
    movl PCB_ESI_OFFSET(%ebx), %esi
    movl %esi, 28(%esp)
    movl PCB_EDI_OFFSET(%ebx), %edi
    movl %edi, 32(%esp)
    movl PCB_EBP_OFFSET(%ebx), %ebp
    movl %ebp, 36(%esp)
    
    /* 恢复执行 */
    popf
    popa
    ret

/**
 * interrupt_context_save - 中断上下文保存
 * 用于中断处理程序保存被中断进程的上下文
 * 参数: pcb_t *pcb (通过eax传递)
 *       中断错误码和中断号在栈上
 */
interrupt_context_save:
    /* 此时栈布局:
     * [esp]     = 返回地址
     * [esp+4]   = 错误码 (如果有)
     * [esp+8]   = 中断号
     * [esp+12]  = 旧的ESP
     * [esp+16]  = 旧的SS
     * [esp+20]  = 旧的EFLAGS
     * [esp+24]  = 旧的CS
     * [esp+28]  = 旧的EIP
     */
    
    /* 获取PCB指针 */
    movl 4(%esp), %eax      /* 跳过返回地址 */
    
    /* 保存通用寄存器 */
    movl %ebx, PCB_EBX_OFFSET(%eax)
    movl %ecx, PCB_ECX_OFFSET(%eax)
    movl %edx, PCB_EDX_OFFSET(%eax)
    movl %esi, PCB_ESI_OFFSET(%eax)
    movl %edi, PCB_EDI_OFFSET(%eax)
    movl %ebp, PCB_EBP_OFFSET(%eax)
    
    /* 保存栈指针 */
    movl 12(%esp), %ebx     /* 旧的ESP */
    movl %ebx, PCB_ESP_OFFSET(%eax)
    
    /* 保存指令指针 */
    movl 28(%esp), %ebx     /* 旧的EIP */
    movl %ebx, PCB_EIP_OFFSET(%eax)
    
    /* 保存标志寄存器 */
    movl 20(%esp), %ebx     /* 旧的EFLAGS */
    movl %ebx, PCB_EFLAGS_OFFSET(%eax)
    
    /* 保存EAX（最后保存，因为需要用到它） */
    movl %eax, PCB_EAX_OFFSET(%eax)
    
    ret

/**
 * interrupt_context_restore - 中断上下文恢复
 * 用于从中断返回时恢复进程上下文
 * 参数: pcb_t *pcb (通过eax传递)
 */
interrupt_context_restore:
    /* 获取PCB指针 */
    movl 4(%esp), %eax
    
    /* 恢复通用寄存器（除了EAX） */
    movl PCB_EBX_OFFSET(%eax), %ebx
    movl PCB_ECX_OFFSET(%eax), %ecx
    movl PCB_EDX_OFFSET(%eax), %edx
    movl PCB_ESI_OFFSET(%eax), %esi
    movl PCB_EDI_OFFSET(%eax), %edi
    movl PCB_EBP_OFFSET(%eax), %ebp
    
    /* 准备IRET的栈帧 */
    pushl $0x10             /* 用户数据段选择子 */
    pushl PCB_ESP_OFFSET(%eax)  /* 栈指针 */
    pushl PCB_EFLAGS_OFFSET(%eax) /* 标志寄存器 */
    pushl $0x08             /* 用户代码段选择子 */
    pushl PCB_EIP_OFFSET(%eax)  /* 指令指针 */
    
    /* 恢复EAX */
    movl PCB_EAX_OFFSET(%eax), %eax
    
    /* 执行中断返回 */
    iret

/**
 * switch_to_user_mode - 切换到用户模式
 * 用于从内核模式切换到用户模式执行
 * 参数: void (*entry)(void) - 用户程序入口点
 *       void *stack_top     - 用户栈顶
 */
switch_to_user_mode:
    /* 设置用户模式段选择子 */
    movw $0x23, %ax      /* 用户数据段选择子 (0x23) */
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    
    /* 设置IRET的栈帧 */
    movl 8(%esp), %eax   /* 用户栈顶 */
    movl 4(%esp), %ebx   /* 用户程序入口点 */
    
    pushl $0x23          /* 用户数据段选择子 */
    pushl %eax           /* 用户栈指针 */
    pushf                /* 标志寄存器 */
    pushl $0x1B          /* 用户代码段选择子 (0x1B) */
    pushl %ebx           /* 用户程序入口点 */
    
    /* 清除不需要的寄存器 */
    xorl %eax, %eax
    xorl %ebx, %ebx
    xorl %ecx, %ecx
    xorl %edx, %edx
    xorl %esi, %esi
    xorl %edi, %edi
    xorl %ebp, %ebp
    
    /* 切换到用户模式 */
    iret

/**
 * save_fpu_state - 保存FPU状态
 * 参数: uint8_t *buffer (512字节缓冲区)
 */
save_fpu_state:
    movl 4(%esp), %eax
    fxsave (%eax)
    ret

/**
 * restore_fpu_state - 恢复FPU状态
 * 参数: uint8_t *buffer (512字节缓冲区)
 */
restore_fpu_state:
    movl 4(%esp), %eax
    fxrstor (%eax)
    ret

/**
 * enable_sse - 启用SSE扩展
 */
enable_sse:
    movl %cr0, %eax
    andl $0xFFFB, %eax      /* 清除CR0.EM (仿真位) */
    orl $0x2, %eax          /* 设置CR0.MP (监视协处理器) */
    movl %eax, %cr0
    
    movl %cr4, %eax
    orl $0x600, %eax        /* 设置CR4.OSFXSR和CR4.OSXMMEXCPT */
    movl %eax, %cr4
    
    ret

/**
 * flush_tlb - 刷新TLB
 * 参数: void *addr - 要刷新的地址（如果为NULL则刷新整个TLB）
 */
flush_tlb:
    movl 4(%esp), %eax
    testl %eax, %eax
    jz .flush_all
    
    /* 刷新单个条目 */
    invlpg (%eax)
    jmp .flush_done
    
.flush_all:
    /* 刷新整个TLB */
    movl %cr3, %eax
    movl %eax, %cr3
    
.flush_done:
    ret

/**
 * get_esp - 获取当前栈指针
 * 返回: 当前ESP值
 */
get_esp:
    movl %esp, %eax
    addl $4, %eax      /* 跳过返回地址 */
    ret

/**
 * get_ebp - 获取当前基指针
 * 返回: 当前EBP值
 */
get_ebp:
    movl %ebp, %eax
    ret

/**
 * atomic_inc - 原子增加
 * 参数: int *value
 */
atomic_inc:
    movl 4(%esp), %eax
    lock incl (%eax)
    ret

/**
 * atomic_dec - 原子减少
 * 参数: int *value
 */
atomic_dec:
    movl 4(%esp), %eax
    lock decl (%eax)
    ret

/**
 * spin_lock - 自旋锁加锁
 * 参数: int *lock
 */
spin_lock:
    movl 4(%esp), %eax
.spin_loop:
    pause
    cmpl $0, (%eax)
    jne .spin_loop
    
    movl $1, %ebx
    lock cmpxchg %ebx, (%eax)
    jnz .spin_loop
    
    ret

/**
 * spin_unlock - 自旋锁解锁
 * 参数: int *lock
 */
spin_unlock:
    movl 4(%esp), %eax
    movl $0, (%eax)
    ret

/**
 * cli - 禁用中断
 */
cli:
    cli
    ret

/**
 * sti - 启用中断
 */
sti:
    sti
    ret

/**
 * halt - 停止CPU直到中断发生
 */
halt:
    hlt
    ret

/**
 * cpu_idle - CPU空闲循环
 */
cpu_idle:
    pushf
    sti               /* 允许中断 */
.idle_loop:
    hlt               /* 等待中断 */
    jmp .idle_loop
    popf
    ret

/* 数据段 */
.section .data

/* 全局上下文切换计数 */
.global context_switch_count
context_switch_count:
    .long 0

/* 最后一个切换时间戳 */
.global last_context_switch_time
last_context_switch_time:
    .long 0

/* 性能计数器 */
.global perf_counters
perf_counters:
    .space 64        /* 16个32位计数器 */

.section .text