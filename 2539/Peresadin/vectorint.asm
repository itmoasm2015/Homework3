default rel

section .text

SIZE_TYPE db equ 8

extern malloc
extern free

global newVetor
global pushBack
global popBack
global deleteVector

struc VectorInt
    size:      resq 1
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
    mov [rax + size], rdi
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

pushBack:
    mov rax, [rdi + alignSize]
    cmp [rdi + size], rax

    jne .push_back

    .push_back
    mov rax, [rdi + size]
    mov rdx, [rdi + elem]
    mov [rdx + SIZE*rax], rsi
    inc qword [rdi + size]
    ret
section .data

