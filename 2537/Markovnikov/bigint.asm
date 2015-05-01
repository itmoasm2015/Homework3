default rel
section .text

extern malloc, calloc, strlen, free

global biFromInt
global biFromString
global biToString
global biDelete
global biSign
global biAdd
global biAdd
global biSub
global biMul
global biDivRem
global biCmp

;; BigInt structure representation:
;;      bigint - array of 32-bit numbers, where
;;      bigint[0] - sign of the number:
;;              * 1     - if > 0
;;              * 0     - if = 0
;;              * -1    - if < 0
;;      bigint[1] - a count of digits
;;      bigint[2..bigint[1] + 1] - digits that are in the base = 10^9

BASE equ 1000000000
;; Takes poiner to BigInt and deletes leading nulls from it
%macro deleteLeadingNulls 1
    push rcx
    push rdx

    %%loop1

    mov ecx, [%1 + 4]
    sub ecx, 1
    cmp ecx, 0
    je %%finish
    mov rdx, 0
    cmp [%1 + 4 * rcx + 8], edx
    jne %%finish
    mov edx, [%1 + 4]
    sub edx, 1
    mov [%1 + 4], edx

    jmp %%loop1
    %%finish:
    pop rdx
    pop rcx
%endmacro

;; BigInt biFromInt(int64_t x)
;;      Returns BigInt converted from int64_t x
;; Takes:   rdi - int to convert
;; Returns: rax - BigInt
biFromInt
    push rcx                ; sign
    push rbx

    cmp rdi, 0
    xor rcx, rcx
    mov ecx, 1
    jge .isPositive
    mov ecx, -1             ; set negative sign
    neg rdi                 ; take absolute value
    .isPositive:
    push rdi
    push rsi
    mov rdi, 3
    add rdi, 2
    mov rsi, 4
    call calloc             ; malloc memory for 3 digits
    pop rdi
    pop rdi

    mov rbx, rax
    mov rax, rdi
    mov rdx, 0              ; take 3 digits
    mov r9, BASE
    div r9
    mov [rbx + 8], edx
    mov rdx, 0
    div r9
    mov [rbx + 12], edx
    mov rdx, 0
    div r9
    mov [rbx + 16], edx

    mov [rbx], ecx          ; set sign
    mov eax, 3              ; count == 3
    mov [rbx + 4], eax      ; set count

    deleteLeadingNulls rbx

    mov eax, [rbx + 4]
    cmp eax, 1

    jne .continue1
    mov eax, [rbx + 8]
    cmp eax, 0
    jne .continue1
    mov eax, 0
    mov [rbx], eax
    mov rax, 1
    jmp .createBi1
    .continue1:
    xor rax, rax
    .createBi1:

    push rbx
    push rsi
    push rdi
    mov rdi, 8
    call malloc
    pop rdi
    pop rsi
    pop rbx
    mov [rax], rbx
    pop rbx
    pop rcx
    ret

;; BigInt biFromString(char const *s)
;;      Creates a BigInt from a decimal string representation
;; Takes:   RDI - pointer to the string
;; Returns: RAX - BigInt of the string or NULL if string is invalid number
biFromString:
    push rcx                    ; sign in rcx
    mov rcx, 1                  ; set positive sign
    cmp byte[rdi], '-'          ; if minus then set negative sign
    jne .skip_sign
    inc rdi                     ; take next char
    mov rcx, -1                 ; set negative sign
    .skip_sign:
    .skip_nulls:
        cmp byte[rdi], '0'
        jne .break1
        inc rdi
        cmp byte[rdi], 0        ; if the end of line
        je .break2
        jmp .skip_nulls
    .break2:
    sub rdi, 1
    .break1:
    push rdi
    call strlen
    pop rdi
    push rbx
    mov rbx, rax                ; put length to rbx
    cmp rbx, 0
    je .no_digits
    mov rdx, 0
    mov rax, rbx
    add rax, 8
    push rbx
    mov rbx, 0
    mov ebx, 9
    div ebx
    mov r11, rax
    pop rbx
    push rbx
    push r11
    push rdi
    push rsi
    mov rdi, r11
    add rdi, 2
    mov rsi, 4
    call calloc
    pop rsi
    pop rdi
    pop r11
    pop rbx
    mov rsi, rax
    mov rax, rcx
    mov [rsi], eax
    mov rax, r11
    mov [rsi + 4], eax
    mov rcx, 0
    .loop:
    mov r11, rbx
    sub rbx, 9
    cmp rbx, 0
    jge .skip_null_1
    mov rbx, 0
    .skip_null_1:
    mov r9, 0 
    .loop1:
    mov r10, 0
    mov r9b, byte[rdi + rbx]
    mov rax, 0
    cmp r9b, '0'
    jl .bad_format
    cmp r9b, '9'
    jg .bad_format
    sub bl, '0'
    mov rax, r9
    mov rcx, 10
    mul rcx
    add rax, r10
    mov r9, rax
    inc rbx
    cmp r11, rbx
    jne .loop1 
    sub rbx, 9
    cmp rbx, 0
    jge .skip_null_2
    mov rbx, 0
    .skip_null_2:
    mov rax, r9
    mov [rsi + 4 * rcx + 8], eax
    inc rcx
    cmp rbx, 0
    jne .loop
    mov eax, [rsi + 4]
    cmp eax, 1
    jne .go_not_null
    mov eax, [rsi + 8]
    cmp eax, 0
    jne .go_not_null
    mov eax, 0
    mov [rsi], eax
    mov rax, 1
    jmp .null_break
    .go_not_null:
    mov rax, 0
    .null_break:
    push rdi
    push rsi
    mov rdi, 8
    call malloc
    pop rsi
    pop rdi
    mov [rax], rsi
    pop rbx
    pop rcx
    ret

    .bad_format:
    push rdi
    mov rdi, rsi
    call free
    pop rdi

    .no_digits:
    mov rax, 0
    pop rbx
    pop rcx
    ret








