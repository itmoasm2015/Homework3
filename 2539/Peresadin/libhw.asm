default rel

section .text

extern malloc
extern free

global biFromInt
global biFromString
global biDelete
global biAdd
global biSub
global biMul
global biCmp
global biSign

;Структура матрицы
struc BigInt
    sign:     resq 1
    len:      resq 1
    data:     resq 1;элементы матрицы
endstruc

biFromInt:
    push rdi
    mov rdi, BigInt_size
    call malloc
    push rax
    mov rdi, 1
    call malloc
    pop rdx
    mov [rdx + data], rax
    mov rax, rdx
    pop rdi

    cmp rdi, 0
    mov qword [rax + len], 1
    jb .minus
    ;plus
        mov qword [rax + sign], 1
        mov qword [rax + data], rdi
        jmp .sign_done
    .minus
        mov qword [rax + sign], 0
        imul rdi, -1
        mov [rax + data], rdi
    .sign_done
    ret

cmpData:
    push rbx
    mov rax, [rsi + len]
    mov [rdi + len], rax
    ja .more
    jb .less
    ;lens equal
        mov rcx, [rdi + len]
        dec rcx
        .cmp_loop
            mov rax, [rdi + data]
            mov rax, [rax + rcx]
            mov rbx, [rsi + data]
            mov rbx, [rbx + rcx]
            cmp rax, rbx
            ja .more
            jb .less
            sub rcx, 1
            jns .cmp_loop
        jmp .equals
    .more
        xor rax, rax
        jmp .cmpData_done
    .less
        mov qword rax, 1
        jmp .cmpData_done
    .equals
        mov qword rax, -1
    .cmpData_done
    pop rbx
    ret

biCmp:
    mov rax, [rsi + sign]
    cmp [rdi + sign], rax
    ja .more
    jb .less
    ;signs equal
        call cmpData
        cmp rax, 0
        jb .equals
        xor rax, [rdi + sign]
        cmp rax, 0
        je .less
        jmp .more
    .more
        mov qword rax, 1
        jmp .cmp_done
    .less
        mov qword rax, -1
        jmp .cmp_done
    .equals
        xor rax, rax
    .cmp_done
