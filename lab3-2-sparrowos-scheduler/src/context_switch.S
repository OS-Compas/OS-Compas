/**
 * context_switch.S - 上下文切换汇编代码
 * x86架构的上下文保存与恢复
 */

.global context_save
.global context_restore
.global context_switch

/* 保存当前上下文到PCB */
context_save:
    pusha                    /* 保存通用寄存器 */
    pushf                    /* 保存标志寄存器 */
    
    /* 获取PCB指针（通过eax传递） */
    mov 40(%esp), %eax       /* eax = pcb指针 */
    
    /* 保存栈指针 */
    mov %esp, (%eax)         /* pcb->reg_esp = esp */
    
    /* 保存其他寄存器到PCB */
    mov 4(%esp), %ebx        /* 获取返回地址 */
    mov %ebx, 4(%eax)        /* pcb->reg_eip = 返回地址 */
    
    /* 保存段寄存器 */
    mov %cs, 44(%eax)
    mov %ds, 48(%eax)
    mov %es, 52(%eax)
    mov %fs, 56(%eax)
    mov %gs, 60(%eax)
    mov %ss, 64(%eax)
    
    /* 保存通用寄存器到PCB */
    mov 8(%esp), %ebx        /* eax */
    mov %ebx, 8(%eax)
    mov 12(%esp), %ebx       /* ecx */
    mov %ebx, 12(%eax)
    mov 16(%esp), %ebx       /* edx */
    mov %ebx, 16(%eax)
    mov 20(%esp), %ebx       /* ebx */
    mov %ebx, 20(%eax)
    mov 28(%esp), %ebx       /* esi */
    mov %ebx, 28(%eax)
    mov 32(%esp), %ebx       /* edi */
    mov %ebx, 32(%eax)
    mov 36(%esp), %ebx       /* ebp */
    mov %ebx, 36(%eax)
    
    /* 保存标志寄存器 */
    mov 40(%esp), %ebx       /* eflags */
    mov %ebx, 68(%eax)
    
    popf                    /* 恢复标志寄存器 */
    popa                    /* 恢复通用寄存器 */
    ret

/* 从PCB恢复上下文 */
context_restore:
    /* 获取PCB指针（通过eax传递） */
    mov 4(%esp), %eax       /* eax = pcb指针 */
    
    /* 恢复栈指针 */
    mov (%eax), %esp        /* esp = pcb->reg_esp */
    
    /* 设置返回地址 */
    mov 4(%eax), %ebx       /* ebx = pcb->reg_eip */
    mov %ebx, 4(%esp)
    
    /* 恢复段寄存器 */
    mov 44(%eax), %cs
    mov 48(%eax), %ds
    mov 52(%eax), %es
    mov 56(%eax), %fs
    mov 60(%eax), %gs
    mov 64(%eax), %ss
    
    /* 恢复通用寄存器到栈 */
    mov 8(%eax), %ebx       /* eax */
    mov %ebx, 8(%esp)
    mov 12(%eax), %ebx      /* ecx */
    mov %ebx, 12(%esp)
    mov 16(%eax), %ebx      /* edx */
    mov %ebx, 16(%esp)
    mov 20(%eax), %ebx      /* ebx */
    mov %ebx, 20(%esp)
    mov 28(%eax), %ebx      /* esi */
    mov %ebx, 28(%esp)
    mov 32(%eax), %ebx      /* edi */
    mov %ebx, 32(%esp)
    mov 36(%eax), %ebx      /* ebp */
    mov %ebx, 36(%esp)
    
    /* 恢复标志寄存器 */
    mov 68(%eax), %ebx      /* eflags */
    mov %ebx, 40(%esp)
    
    ret

/* 上下文切换函数
 * void context_switch(pcb_t* current, pcb_t* next)
 */
context_switch:
    pusha                    /* 保存当前进程的寄存器 */
    pushf
    
    /* 获取参数 */
    mov 44(%esp), %eax       /* eax = current PCB */
    mov 48(%esp), %ebx       /* ebx = next PCB */
    
    /* 保存当前上下文 */
    test %eax, %eax
    jz .skip_save           /* 如果current为NULL，跳过保存 */
    
    /* 保存栈指针 */
    mov %esp, (%eax)        /* current->reg_esp = esp */
    
    /* 保存返回地址 */
    mov 4(%esp), %ecx
    mov %ecx, 4(%eax)       /* current->reg_eip = 返回地址 */
    
    /* 保存段寄存器 */
    mov %cs, 44(%eax)
    mov %ds, 48(%eax)
    mov %es, 52(%eax)
    mov %fs, 56(%eax)
    mov %gs, 60(%eax)
    mov %ss, 64(%eax)
    
    /* 保存通用寄存器到PCB结构 */
    mov 8(%esp), %ecx       /* eax */
    mov %ecx, 8(%eax)
    mov 12(%esp), %ecx      /* ecx */
    mov %ecx, 12(%eax)
    mov 16(%esp), %ecx      /* edx */
    mov %ecx, 16(%eax)
    mov 20(%esp), %ecx      /* ebx */
    mov %ecx, 20(%eax)
    mov 28(%esp), %ecx      /* esi */
    mov %ecx, 28(%eax)
    mov 32(%esp), %ecx      /* edi */
    mov %ecx, 32(%eax)
    mov 36(%esp), %ecx      /* ebp */
    mov %ecx, 36(%eax)
    
    /* 保存标志寄存器 */
    mov 40(%esp), %ecx      /* eflags */
    mov %ecx, 68(%eax)
    
.skip_save:
    /* 切换到新进程的栈 */
    mov (%ebx), %esp        /* esp = next->reg_esp */
    
    /* 设置返回地址 */
    mov 4(%ebx), %ecx       /* ecx = next->reg_eip */
    mov %ecx, 4(%esp)
    
    /* 恢复段寄存器 */
    mov 44(%ebx), %cs
    mov 48(%ebx), %ds
    mov 52(%ebx), %es
    mov 56(%ebx), %fs
    mov 60(%ebx), %gs
    mov 64(%ebx), %ss
    
    /* 恢复通用寄存器 */
    mov 8(%ebx), %eax       /* eax */
    mov %eax, 8(%esp)
    mov 12(%ebx), %ecx      /* ecx */
    mov %ecx, 12(%esp)
    mov 16(%ebx), %edx      /* edx */
    mov %edx, 16(%esp)
    mov 20(%ebx), %ebx      /* ebx */
    mov %ebx, 20(%esp)
    mov 28(%ebx), %esi      /* esi */
    mov %esi, 28(%esp)
    mov 32(%ebx), %edi      /* edi */
    mov %edi, 32(%esp)
    mov 36(%ebx), %ebp      /* ebp */
    mov %ebp, 36(%esp)
    
    /* 恢复标志寄存器 */
    mov 68(%ebx), %ecx      /* eflags */
    mov %ecx, 40(%esp)
    
    popf
    popa
    ret