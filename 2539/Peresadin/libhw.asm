default rel

section .text

extern malloc
extern free

extern newVector
extern pushBack
extern popBack
extern back
extern deleteVector
extern copyVector

global biFromInt
global biFromString
global biDelete
global biAdd
global biSub
global biMul
global biCmp
global biSign

struc VectorInt
    sz:        resq 1
    alignSize: resq 1
    elem:      resq 1;элементы вектора
endstruc

BASE equ 100000000

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

addData:
    length r9, rdi
    length rax, rsi
    cmp r9, rax
    ja .ok_max
        mov r9, rax
    .ok_max
    length r8, rdi
    cmp r8, r9
    je .not_push
        push rsi
        xor rsi, rsi
        .loop_push
            call pushBack
            inc r8
            cmp r8, r9
            jb .loop_push
        pop rsi
    .not_push

    xor r8, r8
    mov rcx, r9
    xor rax, rax;carry
    mov r11, BASE
    mov r9, [rdi + vec]
    mov r9, [r9 + elem]
    mov r10, [rsi + vec]
    mov r10, [r10 + elem]
    .loop
        add rax, [r9 + 4*r8]
        add rax, [r10 + 4*r8]
        xor rdx, rdx
        div r11
        mov [r9 + 4*r8], rdx
        inc r8
        cmp r8, rcx
        ja .loop
    cmp rax, 0
    je .done
        mov rsi, rax
        call pushBack
    .done
    ret

subData:
    length rcx, rsi
    xor r8, r8
    xor rax, rax;carry
    mov r9, [rdi + vec]
    mov r9, [r9 + elem]
    mov r10, [rsi + vec]
    mov r10, [r10 + elem]
    .loop
        imul rax, -1
        add rax, [r9 + 4*r8]
        sub rax, [r10 + 4*r8]
        jns .pos_carry
            add rax, BASE
        .pos_carry
        mov [r9 + 4*r8], rax
        inc r8
        cmp r8, rcx
        ja .loop
    cmp rax, 0

    je .done;TODO write
        mov rsi, rax
        call pushBack
    .done

    .pop_back_zeroes
        call back
        cmp rax, 0
        je .break
        length rax, rdi
        cmp rax, 1
        je .break
        call popBack
        jmp .pop_back_zeroes
    .break
    ret

biAdd:
    mov rax, [rsi + sign]
    cmp rax, [rdi + sign]
    jne .not_eq_sign
        call addData
        jmp .done
    .not_eq_sign
        call cmpData
        cmp rax, 1
        je .a_more_b
            cmp rax, -1
            je .res_zero
                xchg rdi, rsi
                call copyVector
                push rax
                push rdi
                push rsi
                call subData
                mov qword rax, [rsp]
                mov rdi, [rax + vec]
                call deleteVector
                pop rsi
                pop rdi
                mov rax, [rdi + vec]
                mov [rsi + vec], rax
                pop rax
                mov [rdi + vec], rax
                mov qword [rsi + sign], 0
                jmp .done
            .res_zero
                call subData
                mov qword [rdi + sign], 1
                jmp .done
        .a_more_b
            call subData
            mov rax, [rsi + sign]
            cmp [rdi + sign], rax
            ja .b_neg
                mov qword [rdi + sign], 0
            .b_neg
            jmp .done
    .done
    ret

biSub:
    push rbx
    length rcx, rsi
    xor r8, r8
    xor rax, rax
    .loop
    pop rbx
    ret
