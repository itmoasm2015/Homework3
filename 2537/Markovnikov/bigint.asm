default rel
section .text

extern malloc, calloc

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
