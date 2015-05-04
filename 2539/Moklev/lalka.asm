section .text

global lalka
lalka:

    
    mov rax, 0xFFFFFFFFFFFFFFFF
    cmp rdi, rax

    jb .less
    mov rax, 1
    ret

.less:
    mov rax, 21
    ret
