default rel

section .text

extern malloc
extern free

global newVetor
global pushBack
global popBack
global deleteVector

struc VectorInt
    sz:      resq 1
    alignSize: resq 1
    elem:      resq 1;элементы вектора
endstruc

newVector:
    mov rax, 1
    .loop
        shl rax, 1
        cmp rdi, rax
        jae .loop
    ret

    push rax
    push rdi
    mov rdi, VectorInt_size
    call malloc
    pop rdi
    mov [rax + sz], rdi
    mov rdx, rax
    pop rax
    mov [rdx + alignSize], rax
    push rdx
    mov rdi, rax
    call malloc
    pop rdx
    mov [rdx + elem], rax
    mov rax, rdx
    ;TODO write set_zero
    ret

copyElem:
    push rbp
    push rbx
    push rdi
    mov [rdi + alignSize], rsi
    mov rdi, rsi
    call malloc
    pop rdi
    mov rcx, [rdi + sz]
    mov rbp, [rdi + elem]
    .loop_copy
        mov rbx, [rbp + rcx - 1]
        mov [rax + rcx - 1], rbx
        loop .loop_copy
    push rdi
    push rax
    mov rdi, [rdi + elem]
    call free
    pop rax
    pop rdi
    mov [rdi + elem], rax
    pop rbx
    pop rbp
    ret

pushBack:
    mov rax, [rdi + alignSize]
    cmp [rdi + sz], rax
    jne .push_back
    ;align size
        push rsi
        mov rsi, [rdi + alignSize]
        shl rsi
        call copyElem
        pop rsi
    .push_back
    mov rax, [rdi + sz]
    mov rdx, [rdi + elem]
    mov [rdx + 4*rax], rsi
    inc qword [rdi + sz]
    ret

popBack:
    dec [rdi + sz]
    mov rax, [rdi + sz]
    shl rax, 2
    cmp rax, [rdi + alignSize]
    ja .not_copy
        mov rsi, [rdi + alignSize]
        shr rsi
        call copyElem
    .not_copy
    ret

deleteVector:
    push rdi
    mov rdi, [rdi + elem]
    call free
    pop rdi
    call free
    ret
