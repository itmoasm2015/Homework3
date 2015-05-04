default rel
global __regchk
extern fprintf
extern exit
extern stderr

section .text

__regchk:
    ; rsp = 8
    mov r11, rdi ; function address
    mov rdi, rsi ; p1
    mov rsi, rdx ; p2
    mov rdx, rcx ; p3
    mov rcx, r8  ; p4
    mov r8, r9   ; p5
                 ; p6-... not supported
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbp, [crbp]
    mov rbx, [crbx]
    mov r12, [cr12]
    mov r13, [cr13]
    mov r14, [cr14]
    mov r15, [cr15]
    call r11
    cmp rbp, [crbp]
    jne .nrbp
    cmp rbx, [crbx]
    jne .nrbx
    cmp r12, [cr12]
    jne .nr12
    cmp r13, [cr13]
    jne .nr13
    cmp r14, [cr14]
    jne .nr14
    cmp r15, [cr15]
    jne .nr15

    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.nrbp:
    mov rsi, msgRbp
    jmp .msg
.nrbx:
    mov rsi, msgRbx
    jmp .msg
.nr12:
    mov rsi, msgR12
    jmp .msg
.nr13:
    mov rsi, msgR13
    jmp .msg
.nr14:
    mov rsi, msgR14
    jmp .msg
.nr15:
    mov rsi, msgR15
    jmp .msg
.msg:
    mov rdi, [stderr]
    call fprintf
    mov rdi, 1
    call exit
    ; unreachable

section .data
msgRbp: db "RBP is not saved", 10, 0
msgRbx: db "RBX is not saved", 10, 0
msgR12: db "R12 is not saved", 10, 0
msgR13: db "R13 is not saved", 10, 0
msgR14: db "R14 is not saved", 10, 0
msgR15: db "R15 is not saved", 10, 0
crbp db "rbprbp33"
crbx db "checkrbx"
cr12 db "CheckR12"
cr13 db "cHecKR13"
cr14 db "cHECKR14"
cr15 db "TEST R15"
