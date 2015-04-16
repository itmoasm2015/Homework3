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

BASE equ 1000000000

global newVector
global pushBack
global popBack
global element
global deleteVector

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

deleteVector:
    push rdi
    mov rdi, [rdi + elem]
    call free
    pop rdi
    call free
    ret

%macro element 3;to vec index
    push rbp
    mov %1, [%2 + vec]
    mov rbp, [%1 + elem]
    mov %1, [rbp + 4*%3]
    pop rbp
%endmacro

%macro setElement 3;vec index x
    push rbp
    mov rbp, [%1 + vec]
    mov rbp, [rbp + elem]
    mov [rbp + 4*%2], %3
    pop rbp
%endmacro

;Структура длинного числа
struc BigInt
    sign:     resq 1
    vec:      resq 1
endstruc

%macro length 2;to vec
    push rbp
    mov rbp, [%2 + vec]
    mov %1, [rbp + sz]
    pop rbp
%endmacro

biFromInt:
    push rdi
    mov rdi, BigInt_size
    call malloc
    push rax
    mov rdi, 1
    call newVector
    pop rdx
    mov [rdx + vec], rax
    mov rax, rdx
    pop rdi

    cmp rdi, 0
    js .minus
    ;plus
        mov qword [rax + sign], 1
        jmp .sign_done
    .minus
        mov qword [rax + sign], 0
        imul rdi, -1
    .sign_done
    setElement rax, 0, rdi
    ret

cmpData:
    push rbx
    length rax, rdi
    length rbx, rsi
    cmp rax, rbx
    ja .more
    jb .less
    ;lens equal
        mov rcx, rax
        dec rcx
        .cmp_loop
            element rax, rdi, rcx
            element rbx, rsi, rcx
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
        mov rax, 1
        jmp .cmpData_done
    .equals
        mov rax, -1
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
        js .equals
        xor rax, [rdi + sign]
        cmp rax, 0
        je .less
        jmp .more
    .more
        mov eax, 1
        jmp .cmp_done
    .less
        mov eax, -1
        jmp .cmp_done
    .equals
        xor eax, eax
    .cmp_done
    ret

biSign:
    cmp qword [rdi + sign], 0
    je .minus
        mov rdi, [rdi + vec]
        cmp qword [rdi + sz], 1
        je .len_eq1
            mov eax, 1
            jmp .sign_done
        .len_eq1
            mov rax, [rdi + elem]
            cmp qword [rax], 0
            je .zero
                mov eax, 1
                jmp .sign_done
        .zero
            xor eax, eax
            jmp .sign_done
    .minus
        mov eax, -1
    .sign_done
    ret

biAdd:
    ret
