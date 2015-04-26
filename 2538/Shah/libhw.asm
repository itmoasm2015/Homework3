default rel

section .text

extern malloc, free, strlen

global biFromInt
global biFromString
global biDelete
global biToString
global biSign
global biCmp
global biAdd
global biSub
global biMul
global biDivRem

%define SIGN 0
%define SIZE 8
%define VALUE 16

%define setf(f) or rcx, f
%define testf(f) test rcx, f

; push 13 regs
%macro PUSH_REGS 0
    push rdi
    push rsi
    push rbx
    push rcx
    push rdx
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
%endmacro

%macro POP_REGS 0
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdx
    pop rcx
    pop rbx
    pop rsi
    pop rdi
%endmacro

; struct BigInt
; int64 sign
; int64 size
; int64* values
; BASE = 2^64


; rdi - size
; create new BigInt with rdi values
; return rax - pointer to new BigInt
; memory need to be aligned 16 bytes
%macro allocateMemory 0
    push rdi
    imul rdi, 8
    add rdi, 8
    PUSH_REGS
    call malloc
    POP_REGS
    push rax
    mov rdi, 24
    PUSH_REGS
    sub rsp, 8
    call malloc
    add rsp, 8
    POP_REGS
    xor rdi, rdi
    mov [rax + SIGN], rdi
    pop rdi
    mov [rax + VALUE], rdi
    pop rdi
    mov [rax + SIZE], rdi
%endmacro


; rdi - BigInt
; rdx - size
; create copy of existing BigInt with rdx < size of rdi
; memory aligned 16 bytes
%macro biCreateCopy 0
    PUSH_REGS
    xchg rdi, rdx
    sub rsp, 8
    allocateMemory
    add rsp, 8
    xchg rdi, rdx

    mov r8, [rdi + SIGN]
    mov [rax + SIGN], r8
    mov r8, [rdi + VALUE]
    mov r9, [rax + VALUE]
%%copy_loop:
    mov r10, [r8]
    mov [r9], r10
    add r8, 8
    add r9, 8
    dec rdx
    jnz %%copy_loop

    POP_REGS
%endmacro

; rdi - BigInt
; remove unneccessary zeroes from BigInt
; memory aligned 16 bytes
%macro biTrim 0
    PUSH_REGS
    mov r8, [rdi + SIZE]
    dec r8
    jz %%trim_end
    mov r9, r8
    shl r9, 3
    add r9, [rdi + VALUE]

%%trim_loop:
    mov r10, [r9]
    cmp r10, 0
    jne %%trim_loop_end
    sub r9, 8
    dec r8
    jnz %%trim_loop

%%trim_loop_end:
    inc r8
    ; if there isn't zero in the end of values
    ; return
    cmp r8, [rdi + SIZE]
    je %%trim_end

    mov [rdi + SIZE], r8
    push rdi
    mov rdi, r8
    shl rdi, 3
    PUSH_REGS
    sub rsp, 8
    call malloc
    add rsp, 8
    POP_REGS
    pop rdi
    
    push rax
    mov r9, [rdi + VALUE]
%%trim_copy_loop:
    mov r10, [r9]
    mov [rax], r10
    add rax, 8
    add r9, 8
    dec r8
    jnz %%trim_copy_loop

    push rdi
    mov rdi, [rdi + VALUE]
    PUSH_REGS
    call free
    POP_REGS
    pop rdi
    pop rax
    mov [rdi + VALUE], rax

%%trim_end:
    POP_REGS
%endmacro

; create big integer from integer
; rdi - integer 64bit
; rax - result
biFromInt:
    push r8
    push rdi
    mov rdi, 1
    sub rsp, 8
    allocateMemory 
    add rsp, 8
    xor r8, r8
    pop rdi
    cmp rdi, 0
    je .push_value
    jl .negative
    mov r8, 1
    jmp .push_value
.negative:
    mov r8, -1
    neg rdi
.push_value:
    mov [rax + SIGN], r8
    mov r8, [rax + VALUE]
    mov [r8], rdi
    cmp rdi, 0
    jne .not_zero
    mov [rax + SIGN], rdi
.not_zero:
    pop r8
    ret

; rdi - BigInt
biDelete:
    PUSH_REGS
    push rdi
    mov rdi, [rdi + VALUE]
    sub rsp, 8
    call free
    add rsp, 8
    pop rdi
    call free
    POP_REGS
    ret

; rdi - BigInt
; rbx - multiplier
; BigInt *= rbx
%macro mul_long_short 0
    PUSH_REGS
    ; lea rcx, [rdi + 8*SIZE + VALUE]
    ; mov r9, [rsi + VALUE]
    mov rcx, [rdi + SIZE]
    mov rdi, [rdi + VALUE]
    ; mov rsi, [rsi + VALUE]
    xor rsi, rsi
    clc
    
%%mul_ls_loop:
    mov rax, [rdi]
    mul rbx
    add rax, rsi
    mov rsi, 0
    adc rsi, rdx
    mov [rdi], rax

    add rdi, 8
    ; add r9, 8
    dec rcx
    jnz %%mul_ls_loop

    test rsi, rsi
    jz %%mul_ls_end

%%mul_add_ls_loop:
    add [rdi], rsi
    mov rsi, 0
    adc rsi, 0
    add rdi, 8
    test rsi, rsi
    jnz %%mul_add_ls_loop
    

%%mul_ls_end:
    POP_REGS
%endmacro

 ; rdi - BigInt
 ; rsi - summand
 ; rdi += rsi
%macro add_long_short 0
    PUSH_REGS
    ; lea rcx, [rdi + 8*SIZE + VALUE]
    mov rcx, [rdi + SIZE]
    mov rdi, [rdi + VALUE]
    mov rax, rsi
    xor rdx, rdx

%%add_ls_loop:
    add [rdi], rax
    adc rdx, 0
    mov rax, rdx
    ; continue adding while CF was
    test rax, rax
    jz %%add_ls_end
    xor rdx, rdx
    add rdi, 8
    dec rcx
    jnz %%add_ls_loop

%%add_ls_end:
    POP_REGS
%endmacro


; rdi - BigInt
; checks if BigInt is zero
; by checking all values
; result =  rax = 0 if zero
%macro isZeroSlow 0
    push rcx
    push r8
    mov rcx, [rdi + SIZE]
    mov r8, [rdi + VALUE]

%%is_zero_loop:
    mov rax, [r8]
    test rax, rax
    jnz %%not_zero
    add r8, 8
    dec rcx
    jnz %%is_zero_loop

    xor rax, rax
    mov [rdi + SIGN], rax
    jmp %%isZero_end
    
%%not_zero:
    mov rax, 1

%%isZero_end:
    pop r8
    pop rcx
%endmacro

; rdi - BigInt
; checks if BigInt is zero
; by checking only last value
; result = rax = 0 if zero
%macro isZeroFast 0
    push r8
    mov r8, [rdi + SIZE]
    dec r8
    shl r8, 3
    add r8, [rdi + VALUE]

    mov rax, [r8]
    test rax, rax
    jnz %%not_zero

    mov [rdi + SIGN], rax
    jmp %%end_check

%%not_zero:

%%end_check:
    pop r8
%endmacro

; rdi - string
; rax - new BigInt
biFromString:
    PUSH_REGS
    PUSH_REGS
    sub rsp, 8
    call strlen
    add rsp, 8
    POP_REGS
    mov rsi, rdi
    mov rdi, rax
    shr rdi, 3
    inc rdi
    ; use some mathematic
    ; length of 10-base number = N
    ; it's enough to N/8 round up in 2^64-base
    allocateMemory 
    ; rdi - bigint
    ; rax - bigint
    ; r8 - string
    mov rdi, rax
    mov r8, rsi
    mov rsi, [rdi + SIZE]
    mov rax, [rdi + VALUE]
    xor rbx, rbx
.loop_zero:
    mov [rax], rbx
    add rax, 8
    dec rsi
    jnz .loop_zero 

.get_sign:
    mov rbx, 10
    mov rax, rdi
    mov rsi, 1
    mov [rdi + SIGN], rsi
    xor rsi, rsi
    cmp byte [r8], '-'
    jne .loop
    mov rsi, -1
    mov [rdi + SIGN], rsi
    xor rsi, rsi
    inc r8
.loop:
    mov sil, byte [r8]
    cmp sil, 0
    je .end_loop

    cmp             sil, '0'
    jb              .invalid_char
    cmp             sil, '9'
    ; mul number on 10
    mul_long_short
    sub rsi, '0'
    ; add current char
    add_long_short
    inc r8
    jmp .loop

.invalid_char:
    call biDelete
    xor rax, rax
    POP_REGS
    ret

.end_loop:
    ; delete unneccessary values
    biTrim
    isZeroFast
    mov rax, rdi
    POP_REGS
    ret

; rdi - bigint
biSign:
    mov rax, [rdi + SIGN]
    ret

; rdi - 1st
; rsi - 2nd
; compare two unsigned BigInts 
; return -1 = 1st < 2nd
;         1 = 1st > 2nd
;         0 = 1st = 2nd
%macro biCmpUnsigned 0
    PUSH_REGS
    mov rax, [rdi + SIZE]
    mov r9, [rsi + SIZE]
    sub rax, r9
    cmp rax, 0
    jg %%greater_un
    jl %%less_un

    ; r10 - i
    ; r11 - j
    ; r12 - end block for i
    ; r13 - end block for j
    mov r12, [rdi + VALUE]
    mov r13, [rsi + VALUE]
    mov r10, r9
    shl r10, 3
    add r10, r12
    mov r11, r9
    shl r11, 3
    add r11, r13

%%cmp_loop:
    sub r10, 8
    sub r11, 8
    mov rbx, [r10]
    mov rdx, [r11]
    cmp rbx, rdx
    ja %%greater_un
    jb %%less_un
    dec r9
    jnz %%cmp_loop

    jmp %%equals
%%equals:
    mov rax, 0
    jmp %%end_cmp_un

%%greater_un:
    mov rax, 1
    jmp %%end_cmp_un

%%less_un:
    mov rax, -1
    jmp %%end_cmp_un

%%end_cmp_un:
    POP_REGS
%endmacro

; rdi - 1st
; rsi - 2nd
; compare two BigInts
CMP_NEGATIVE_FLAG equ 1<<1
biCmp:
    PUSH_REGS
    xor rax, rax
    xor rcx, rcx
    mov r8, [rdi + SIGN]
    mov r9, [rsi + SIGN]
    cmp r8, r9
    jne .diff_signs

    biCmpUnsigned

    cmp r8, 0
    jge .cmp_positive
    neg rax

.cmp_positive:
    jmp .end_cmp

    ; r10 - i

.diff_signs:
    mov rax, r8
    sub rax, r9
    cmp rax, 0
    jg .greater
    jl .less
    jmp .end_cmp

.greater:
    mov rax, 1
    jmp .end_cmp

.less:
    mov rax, -1
    jmp .end_cmp


.end_cmp:
    POP_REGS
    ret

; rdi - BigInt
; rbx - divisor
; rdi /= rbx
; remainder in rax
%macro div_long_short 0
    push r9
    push r10
    push rdx
    mov r9, [rdi + SIZE]
    mov r10, r9
    shl r10, 3
    add r10, [rdi + VALUE]
    xor rdx, rdx

%%div_loop:
    sub r10, 8
    mov rax, [r10]
    div rbx
    mov [r10], rax
    dec r9
    jnz %%div_loop

%%div_ls_end:
    mov rax, rdx
    pop rdx
    pop r10
    pop r9
%endmacro

; rdi - BigInt
; rsi - string
; rdx - limit
biToString:
    PUSH_REGS
    mov r12, [rdi + SIGN]
    ; if BigInt is zero
    ; then do some special
    test r12, r12
    jnz .not_zero_string
    mov rdi, '0'
    mov byte [rsi], dil
    xor rdi, rdi
    inc rsi
    mov byte [rsi], dil
    jmp .string_pop_regs

.not_zero_string:
    dec rdx
    mov r12, rdx
    mov rdx, [rdi + SIZE]
    biCreateCopy
    mov r13, [rdi + SIGN]
    ; work with copy of BigInt
    mov rdi, rax
    mov rax, 20
    mov r14, [rdi + SIZE]
    mul r14
    mov rbp, rsp
    sub rsp, rax
    mov r14, rbp
    xor r15, r15

    ; rdi - copy BigInt  
    mov r8, rsp

.string_loop:
    isZeroSlow
    test rax, rax
    jz .write_str 
    mov rbx, 10
    div_long_short
    add rax, '0'
    inc r15
    dec r14
    mov byte [r14], al
    jmp .string_loop

.write_str:
    cmp r13, 0
    jge .write_str_loop
    xor rdx, rdx
    mov dl, '-'
    inc r15
    dec r14
    mov byte [r14], dl

.write_str_loop:
    mov al, byte [r14]
    mov byte [rsi], al
    inc rsi
    inc r14
    dec r12
    jz .string_end
    dec r15
    jnz .write_str_loop

.string_end:
    xor rax, rax
    mov byte [rsi], al
    mov rsp, rbp
    call biDelete
.string_pop_regs:
    POP_REGS
    ret

; rdi - 1st bigInt
; rdx - size 
; create a new values array to this BigInt
; copy previous values
; set (rdx - size of rdi) values to zero
; mem aligned 16 bytes
%macro increaseCapacity 0
    PUSH_REGS
    push rdx

    push rdi
    mov rdi, rdx
    shl rdi, 3
    PUSH_REGS
    sub rsp, 8
    call malloc
    add rsp, 8
    POP_REGS
    pop rdi
    mov r8, [rdi + SIZE]
    mov r9, [rdi + VALUE]
    push rax

%%cap_loop:
    test r8, r8
    jz %%cap_loop_skip
    mov r10, [r9]
    add r9, 8
    dec r8

%%cap_loop_skip:
    mov [rax], r10
    xor r10, r10
    add rax, 8
    dec rdx
    jnz %%cap_loop

%%cap_loop_end:
    push rdi
    mov rdi, [rdi + VALUE]
    ; delete previous values
    PUSH_REGS
    call free
    POP_REGS
    pop rdi
    pop rax
    mov [rdi + VALUE], rax
    pop rdx
    mov [rdi + SIZE], rdx
    POP_REGS
%endmacro

; rdi - 1st unsigned BigInt
; rsi - 2st unsigned BigInt
; size of rdi > size of rsi
; rdi += rsi
%macro add_long_long 0
    PUSH_REGS

    mov r9, [rdi + VALUE]
    mov r10, [rsi + VALUE]
    mov r11, [rdi + SIZE]
    mov r12, [rsi + SIZE]

    ; r9 - 1st values
    ; r10 - 2nd values
    ; r11 - size of 1st
    ; r12 - size of 2nd
    xor rdx, rdx
    clc
%%add_ll_loop:
    mov rax, 0
    ; if r12 > 0
    ; then rax = current 2nd value
    ; else rax = 0
    test r12, r12
    je %%add_ll_loop_skip
    mov rax, [r10]
    lea r10, [r10 + 8]
    dec r12

%%add_ll_loop_skip:
    add rax, rdx
    mov r13, [r9]
    adc r13, rax
    mov [r9], r13
    mov rdx, 0
    adc rdx, 0
    lea r9, [r9 + 8]
    dec r11
    jnz %%add_ll_loop

%%add_ll_end:
    POP_REGS
%endmacro

; rdi - 1st unsigned BigInt
; rsi - 2nd unsigned BigInt
; rdi -= rsi
SUB_LESS_FLAG equ 1
%macro sub_long_long 0
    PUSH_REGS
    biCmpUnsigned
    xor rcx, rcx
    ; if unsigned 1st < 2nd
    ; then increase size of 1st to size of 2nd
    ; and invert sign
    cmp rax, -1
    jne %%sub_normal
    setf(SUB_LESS_FLAG)
    mov r8, [rdi + SIGN]
    neg r8
    mov [rdi + SIGN], r8
    mov rdx, [rsi + SIZE]
    increaseCapacity

%%sub_normal:
    mov r8, [rdi + VALUE]
    mov r9, [rsi + VALUE]
    mov r10, [rdi + SIZE]
    mov r11, [rsi + SIZE]

    xor rdx, rdx
    clc
%%sub_ll_loop:
    mov rax, 0
    test r11, r11
    jz %%sub_ll_loop_skip
    mov rax, [r9]
    dec r11

%%sub_ll_loop_skip:
    mov r12, [r8]
    testf(SUB_LESS_FLAG)
    jnz %%sub_ll_loop_less
%%sub_ll_loop_normal:
    add rax, rdx
    sub r12, rax
    jmp %%sub_ll_loop_next
%%sub_ll_loop_less:
    add r12, rdx
    sub rax, r12
    mov r12, rax
%%sub_ll_loop_next:
    mov [r8], r12
    mov rdx, 0
    adc rdx, 0
    add r8, 8
    add r9, 8
    dec r10
    jnz %%sub_ll_loop

%%sub_ll_end:
    POP_REGS
%endmacro


; rdi - 1st BigInt
; rsi - 2nd BigInt
; rdi += rsi
biAdd:
    PUSH_REGS

    mov r8, [rdi + SIGN]
    mov r9, [rsi + SIGN]
    test r8, r8
    jz .add_to_zero
    test r9, r9
    jz .add_end
    cmp r8, r9
    jne .diff_signs

.add_to_zero:
    mov [rdi + SIGN], r9

.add_eq_signs:
    ; rdx = max(size of 1st, size of 2nd)
    push r9
    mov rdx, [rdi + SIZE]
    mov r9, [rsi + SIZE]
    sub rdx, r9
    mov r10, rdx
    shr r10, 63
    and r10, 0x1
    imul r10, rdx
    mov rdx, [rdi + SIZE]
    sub rdx, r10
    inc rdx
    pop r9

    increaseCapacity
    add_long_long
    jmp .add_end

.diff_signs:
    sub_long_long
    biTrim
    isZeroFast
    jmp .add_end

.add_end:
    POP_REGS
    ret

; rdi - 1st BigInt
; rsi - 2nd BigInt
; rdi -= rsi
biSub:
    ; rdi - rsi = rdi + (-rsi)
    push r8
    mov r8, [rsi + SIGN]
    neg r8
    mov [rsi + SIGN], r8
    call biAdd
    mov r8, [rsi + SIGN]
    neg r8
    mov [rsi + SIGN], r8
    pop r8
    ret

; rdi - BigInt
; set values to zero
; don't touch sign
%macro biSetToZero 0
    push rdi
    push rcx
    push r10
    xor r10, r10
    mov rcx, [rdi + SIZE]
    mov rdi, [rdi + VALUE]

%%set_zero:
    mov [rdi], r10
    add rdi, 8
    dec rcx
    jnz %%set_zero

    pop r10
    pop rcx
    pop rdi
%endmacro

; rdi - 1st BigInt
; rsi - 2nd BigInt
; 1st *= 2nd
biMul:
    PUSH_REGS
    ; create copy of 1st
    mov rdx, [rdi + SIZE]
    biCreateCopy
    mov r8, rax

    add rdx, [rsi + SIZE]
    increaseCapacity
    biSetToZero

    ; rdi - result BigInt
    ; r9 - 2nd BigInt (multiplier)
    ; r8 - copy of 1st

    xchg rsi, r9
    push r8
    mov r10, [r8 + VALUE]
    mov r11, [r8 + SIZE]
    mov r8, [r9 + VALUE]
    mov rcx, [r9 + SIZE]
    mov r12, [rdi + VALUE]
    sub r12, 8
    ; r8 - values of 2nd BigInt
    ; rcx - size of 2nd BigInt
    ; r10 - values of initial 1st BigInt
    ; r11 - size of initial 1st BigInt
    ; r12 - values of result BigInt
    push r11
    push r10
    push r12
    xor r13, r13
    ; for i = 0 .. size of 2nd
    ; for j = 0 .. size of 1st
    ; result[i + j] += 1st[i] * 2nd[j]
.loop_i:
    mov rbx, [r8]
    add r8, 8
    mov r10, [rsp + 8]
    ; shift place for add
    mov r12, [rsp]
    add r12, 8
    mov [rsp], r12
    mov r11, [rsp + 16]
    xor rsi, rsi
.loop_j:
    mov rax, [r10]
    add r10, 8
    mul rbx
    add rax, rsi
    adc rdx, 0
    mov rsi, rdx
    add rax, r13
    mov r13, 0
    adc r13, 0
    add [r12], rax
    adc r13, 0
    add r12, 8
    dec r11
    jnz .loop_j

; add remainder if it was
.loop_rem:
    mov rax, rsi
    xor rsi, rsi
    add rax, r13
    mov r13, 0
    adc r13, 0
    add [r12], rax
    adc r13, 0
    add r12, 8
    test r13, r13
    jnz .loop_rem

.loop_i_continue:
    dec rcx
    jnz .loop_i
    pop r12
    pop r10
    pop r11
    pop r8

    mov r10, [rdi + SIGN]
    imul r10, [r9 + SIGN]
    mov [rdi + SIGN], r10
    biTrim
    isZeroFast
    mov rdi, r8
    call biDelete
    POP_REGS
    ret
  
  
