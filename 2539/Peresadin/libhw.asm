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
global biMul

struc VectorInt
    sz:        resq 1
    alignSize: resq 1
    elem:      resq 1;элементы вектора
endstruc

TEN equ 10
BASE equ 100000000
BASE_LEN equ 8

%macro element 3;to vec index
    push r15
    mov r15, [%2 + vec]
    mov r15, [r15 + elem]
    mov %1, dword [r15 + 4*%3]
    pop r15
%endmacro

%macro setElement 3;vec index x
    push r15
    mov r15, [%1 + vec]
    mov r15, [r15 + elem]
    mov dword [r15 + 4*%2], %3
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

newBi:
    mov rdi, BigInt_size
    call malloc
    push rax
    mov rdi, 0
    call newVector
    pop rdx
    mov [rdx + vec], rax
    mov rax, rdx
    ret

biFromString:
    push rbx
    mov rbx, 1
    cmp byte [rdi], '-' 
    jne .not_minus
        xor rbx, rbx
        inc rdi
    .not_minus
    
    xor rcx, rcx
    .loop_end_line
        cmp byte [rdi], '0'
        jb .error
        cmp byte [rdi], '9'
        ja .error
        inc rdi
        inc rcx
        cmp byte [rdi], 0
        jne .loop_end_line
    cmp rcx, 0
    je .error
    push rdi
    push rcx
    call newBi
    pop rcx
    pop rdi
    mov rsi, rax
    sub rdi, rcx
    add rcx, rdi
    .loop_num
        xor eax, eax
        mov r8, rcx
        sub r8, BASE_LEN
        cmp r8, rdi
        ja .calc_dig_loop
            mov r8, rdi
        .calc_dig_loop
            mov edx, 10
            mul edx
            xor edx, edx
            mov dl, [r8]
            sub dl, '0'
            add eax, edx
            inc r8
            cmp r8, rcx
            jne .calc_dig_loop
        push rcx
        push rdi
        push rsi
        mov rdi, [rsi + vec]
        mov esi, eax
        call pushBack
        pop rsi
        pop rdi
        pop rcx
        sub rcx, BASE_LEN
        cmp rcx, rdi
        ja .loop_num
    mov rax, rsi
    mov [rax + sign], rbx
    pop rbx
    ret

    .error
    xor rax, rax
    pop rbx
    ret

biFromInt:
    push rdi
    call newBi
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
                mov rax, 1
                jmp .sign_done
        .zero
            xor rax, rax
            jmp .sign_done
    .minus
        mov rax, -1
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
                push rdi
                push rsi
                xchg rdi, rsi
                call copyVector
                mov rdi, [rsp]
                mov rsi, [rsp + 8]
                add rsp, 16

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
                push rdi
                call subData
                pop rdi
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
        mov rdi, [rsp + 8]
        call biAdd
        mov rsi, [rsp]
        xor qword [rsi + sign], 1
    .zero
    add rsp, 16
    ret

biMul:
    push rbx
    push r12
    push r13

    push rdi
    push rsi
    call biSign
    push rax
    mov rdi, [rsp + 16]
    call biSign
    mul qword [rsp]
    add rsp, 8
    cmp rax, 0
    je .res_zero

    push rax
    mov rax, [rsp + 8]
    length r13, rax
    mov rsi, [rsp + 16]
    length r12, rsi
    mov rdi, r12
    add rdi, r13
    call newVector
    mov rsi, [rsp + 8]
    mov rdi, [rsp + 16]
    push rax

    xor r8, r8
    .loop1
        xor r9, r9
        mov rcx, [rsp]
        mov rcx, [rcx + elem]
        lea rcx, [rcx + 4*r8]
        xor rax, rax
        .loop2
            xor rdx, rdx
            mov edx, [rcx]
            add rax, rdx
            mov r10, rax
            xor rax, rax
            xor rbx, rbx
            element eax, rdi, r8
            element ebx, rsi, r9
            mul rbx
            add rax, r10
            xor rdx, rdx
            mov rbx, BASE
            div rbx
            mov [rcx], edx

            add rcx, 4
            inc r9
            cmp r9, r13
            jne .loop2

            .loop_carry
                cmp rax, 0
                je .break_loop_carry
                xor rdx, rdx
                mov edx, [rcx]
                add rax, rdx
                mov rbx, BASE
                div rbx
                mov dword [rcx], edx
                add rcx, 4
                jmp .loop_carry
            .break_loop_carry
        inc r8
        cmp r8, r12
        jne .loop1
    pop rax
    pop rdx
    add rsp, 16
    cmp rdx, -1
    je .less_zero
        mov qword [rdi + sign], 1
        jmp .sign_done
    .less_zero
        mov qword [rdi + sign], 0
    .sign_done
    push rax
    push rdi
    mov rdi, [rdi + vec]
    call deleteVector

    mov rdi, [rsp + 8]
    call back
    cmp eax, 0
    jne .no_pop_zero
        call popBack
    .no_pop_zero
    pop rdi
    pop rax
    mov [rdi + vec], rax
    jmp .done

    .res_zero
        pop rsi
        pop rdi
        mov qword [rdi + sign], 1
        push rdi
        mov rdi, [rdi + vec]
        call deleteVector
        mov rdi, 1
        call newVector
        pop rdi
        mov [rdi + vec], rax
    .done
    pop r13
    pop r12
    pop rbx
    ret
