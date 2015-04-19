default rel

section .text

extern malloc
extern free

global newVector
global pushBack
global popBack
global back
global deleteVector
global copyVector

struc VectorInt
    sz:        resq 1
    alignSize: resq 1
    elem:      resq 1;элементы вектора
endstruc

newVector:
    mov rax, 1
    .loop
        shl rax, 1
        cmp rdi, rax
        jae .loop
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
    shl rdi, 2
    call malloc
    pop rdx
    mov [rdx + elem], rax
    mov rax, rdx

    mov rcx, [rax + sz]
    shl rcx, 2
    cmp rcx, 0
    je .size_zero
    mov rdx, [rax + elem]
    .loop_set
        mov dword [rdx + rcx - 4], 0
        sub rcx, 4
        jnz .loop_set

    .size_zero
    ret

copyElem:
    push rdi
    mov [rdi + alignSize], rsi
    mov rdi, rsi
    shl rdi, 2
    call malloc
    pop rdi

    mov rcx, [rdi + sz]
    shl rcx, 2
    cmp rcx, 0
    je .size_zero
    mov rdx, [rdi + elem]
    .loop_copy
        mov esi, [rdx + rcx - 4]
        mov [rax + rcx - 4], esi
        sub rcx, 4
        jnz .loop_copy
    .size_zero

    push rdi
    push rax
    mov rdi, [rdi + elem]
    call free
    pop rax
    pop rdi
    mov [rdi + elem], rax
    ret

pushBack:
    mov rax, [rdi + alignSize]
    cmp [rdi + sz], rax
    jne .push_back
    ;align size
        push rsi
        mov rsi, [rdi + alignSize]
        shl rsi, 1
        call copyElem
        pop rsi
    .push_back
    mov rax, [rdi + sz]
    mov rdx, [rdi + elem]
    mov [rdx + 4*rax], esi
    inc qword [rdi + sz]
    ret

popBack:
    dec qword [rdi + sz]
    mov rax, [rdi + sz]
    shl rax, 2
    cmp rax, [rdi + alignSize]
    ja .not_copy
        mov rsi, [rdi + alignSize]
        shr rsi, 1
        call copyElem
    .not_copy
    ret

back:
    mov rax, [rdi + sz]
    dec rax
    shl rax, 2
    add rax, [rdi + elem]
    mov rax, [rax]
    ret

copyVector:
    push rdi
    mov rdi, VectorInt_size
    call malloc
    push rax
    mov rcx, [rsp]
    mov rdx, [rcx + sz]
    mov [rax + sz], rdx
    mov rdx, [rcx + alignSize]
    mov [rax + alignSize], rdx
    mov rdi, rdx
    shl rdi, 2
    call malloc
    pop rdx
    pop rdi

    mov rcx, [rdi + sz]
    shl rcx, 2
    cmp rcx, 0
    je .size_zero
    mov rdx, [rdi + elem]
    .loop_copy
        mov esi, [rdx + rcx - 4]
        mov [rax + rcx - 4], esi
        sub rcx, 4
        jnz .loop_copy
    .size_zero
    mov [rdx + elem], rax
    mov rax, rdx
    ret

deleteVector:
    push rdi
    mov rdi, [rdi + elem]
    call free
    pop rdi
    call free
    ret
