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
    push r15
    mov %1, [%2 + vec]
    mov r15, [%1 + elem]
    mov %1, [r15 + 4*%3]
    pop r15
%endmacro

%macro setElement 3;vec index x
    push r15
    mov r15, [%1 + vec]
    mov r15, [r15 + elem]
    mov [r15 + 4*%2], %3
    pop r15
%endmacro

;Структура длинного числа
struc BigInt
    sign:     resq 1
    vec:      resq 1
endstruc

%macro length 2;to vec
    push r15
    mov r15, [%2 + vec]
    mov %1, [r15 + sz]
    pop r15
%endmacro

biFromInt:
    push rdi
    mov rdi, BigInt_size
    call malloc
    push rax
    mov rdi, 0
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

    push rax
    push r12
    mov rbx, BASE
    xchg rdi, rax
    mov rdi, [rdi + vec]
    mov r12, rdi
    .push_long_long
        xor rdx, rdx
        div rbx
        mov rsi, rdx
        push rax
        call pushBack
        pop rax
        mov rdi, r12
        cmp rax, 0
        jne .push_long_long
    pop r12
    pop rax
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
        mov rax, [rdi + vec]
        mov rax, [rax + elem]
        lea rax, [rax + 4*rcx]

        mov rbx, [rsi + vec]
        mov rbx, [rbx + elem]
        lea rbx, [rbx + 4*rcx]

        .cmp_loop
            mov edx, [rax]
            cmp edx, [rbx]
            ja .more
            jb .less
            sub rax, 4
            sub rbx, 4
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
            cmp dword [rax], 0
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
    push rbx
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
    mov rbx, BASE
    mov r9, [rdi + vec]
    mov r9, [r9 + elem]
    mov r10, [rsi + vec]
    mov r10, [r10 + elem]
    .loop
        add eax, [r9 + 4*r8]
        add eax, [r10 + 4*r8]
        xor edx, edx
        div rbx
        mov [r9 + 4*r8], edx
        inc r8
        cmp r8, rcx
        ja .loop
    cmp rax, 0
    je .done
        mov rsi, rax
        call pushBack
    .done
    pop rbx
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
        imul eax, -1
        add eax, [r9 + 4*r8]
        sub eax, [r10 + 4*r8]
        jns .pos_carry
            add eax, BASE
            mov [r9 + 4*r8], eax
            mov eax, 1
            jmp .done_sub
        .pos_carry
            mov [r9 + 4*r8], eax
            xor eax, eax
        .done_sub
        inc r8
        cmp r8, rcx
        jne .loop

    cmp eax, 0
    je .done
    .sub_carry_loop
        imul eax, -1
        add eax, [r9 + 4*r8]
        jns .pos_carry_2
            add eax, BASE
            mov [r9 + 4*r8], eax
            mov eax, 1
            jmp .sub_carry_loop
        .pos_carry_2
        mov [r9 + 4*r8], eax
    .done

    push r12
    length r12, rdi
    mov rdi, [rdi + vec]
    .pop_back_zeroes_loop
        call back
        cmp eax, 0
        je .break
        cmp r12, 1
        je .break
        call popBack
        dec r12
        jmp .pop_back_zeroes_loop
    .break
    pop r12
    ret

biAdd:
    mov rax, [rsi + sign]
    cmp rax, [rdi + sign]
    jne .not_eq_sign
        call addData
        jmp .done
    .not_eq_sign
        call cmpData
        cmp rax, 0
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
            push rdi
            push rsi
            call subData
            pop rsi
            pop rdi
            mov rax, [rsi + sign]
            cmp [rdi + sign], rax
            ja .b_neg
                mov qword [rdi + sign], 0
            .b_neg
            jmp .done
    .done
    ret

biSub:
    push rdi
    push rsi
    xchg rdi, rsi
    call biSign
    cmp rax, 0
    je .zero
        mov rsi, [rsp]
        xor qword [rsi + sign], 1
        mov rsi, [rsp]
        mov rdi, [rsp + 8]
        call biAdd
        mov rsi, [rsp]
        xor qword [rsi + sign], 1
    .zero
    ret
