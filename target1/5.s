movq %rsp, %rax
ret

movl %ecx, %esi
cmpb %al,%al
ret

movl %edx, %ecx
cmpb %cl,%cl
ret

movl %eax, %edx
nop
ret