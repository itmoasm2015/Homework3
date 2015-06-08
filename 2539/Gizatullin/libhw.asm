default rel

section .text

extern calloc, malloc, free, strlen

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

; macros to push 13 registers
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

; macros to pop 13 registers
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

; structure BigInteger
; int64 signum
; int64 size of number
; int64* values
; BASE = 2^64
; digits are stored in ascending order
; trailing zeros are removed

; rdi - size
; creates new BigInteger with rdi values
; returns pointer to new BigInteger in rax
; memory is aligned to 16 bytes
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

; creates copy of existing BigInteger with rdx < size of rdi
; rdi - BigInteger
; rdx - size of copy equal to rdi
; call memory aligned to 16 bytes
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
    ; copies values from destination
%%copy_loop:
    mov r10, [r8]
    mov [r9], r10
    add r8, 8
    add r9, 8
    dec rdx
    jnz %%copy_loop

    POP_REGS
%endmacro

; removes trailing zeros from BigInteger
; rdi - BigInteger
; memory aligned to 16 bytes
%macro biTrim 0
    PUSH_REGS
    mov r8, [rdi + SIZE]
    dec r8
    jz %%trim_end
    mov r9, r8
    shl r9, 3
    add r9, [rdi + VALUE]

    ; finds first non-zero digit
%%trim_loop:
    mov r10, [r9]
    cmp r10, 0
    jne %%trim_loop_end
    sub r9, 8
    dec r8
    jnz %%trim_loop
%%trim_loop_end:
    ; r8 - position of first non-zero digit
    inc r8
    ; if there aren't zeros in the end of number, returns
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
    ; copies non-zero digits from source to new array
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

; creates BigInteger from Integer
; rdi - Integer 64bit
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

; deletes BigInteger
; rdi - BigInteger
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

; multiplies BigInteger to Integer
; rdi - BigInteger
; rbx - multiplier
; BigInt *= rbxeger
%macro mul_long_short 0
    PUSH_REGS
    mov rcx, [rdi + SIZE]
    mov rdi, [rdi + VALUE]
    xor rsi, rsi
    clc
    
    ; multiplies each digit to rbx
    ; and saves result
%%mul_ls_loop:
    mov rax, [rdi]
    mul rbx
    add rax, rsi
    mov rsi, 0
    adc rsi, rdx
    mov [rdi], rax

    add rdi, 8
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

; adds Integer to BigInteger
; rdi - BigInteger
; rsi - summand
; result is rdi += rsi
%macro add_long_short 0
    PUSH_REGS
    mov rcx, [rdi + SIZE]
    mov rdi, [rdi + VALUE]
    mov rax, rsi
    xor rdx, rdx
%%add_ls_loop:
    add [rdi], rax
    adc rdx, 0
    mov rax, rdx
    test rax, rax
    jz %%add_ls_end
    xor rdx, rdx
    add rdi, 8
    dec rcx
    jnz %%add_ls_loop
%%add_ls_end:
    POP_REGS
%endmacro

; compares BigInteger to zero by checking last digit
; rdi - BigInteger
; result: rax = 0 if number is equal to zero
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

; creates BigInteger from string
; rdi - string
; rax - new BigInteger
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
    ; asssuming the length of 10-base number as N
    ; it's enough to round up N / 8 in 2^64-base
    allocateMemory 
    ; rdi - BigInteger
    ; rax - BigInteger
    ; r8 - string
    mov rdi, rax
    mov r8, rsi
    mov rsi, [rdi + SIZE]
    mov rax, [rdi + VALUE]
    xor rbx, rbx
    xor r9, r9
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
    ja              .invalid_char
    ; r9 - number of digits
    inc r9
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
    ; if there is no digits return NULL
    test r9, r9
    jz .invalid_char
    biTrim
    isZeroFast
    mov rax, rdi
    POP_REGS
    ret

; returns signum of the BigInteger
; rdi - BigInteger
biSign:
    mov rax, [rdi + SIGN]
    ret

; compares 2 unsigned BigIntegers
; rdi - 1st BigInteger
; rsi - 2nd BigInteger
; returns -1 if 1st is less than 2nd
;          1 if 1st is greater than 2nd
;          0 if 1st is equal to 2nd
biCmpUnsigned:
    PUSH_REGS
    mov rax, [rdi + SIZE]
    mov r9, [rsi + SIZE]
    ; compares sizes of numbers
    sub rax, r9
    cmp rax, 0
    jg .greater_un
    jl .less_un

    ; if sizes are equals, checks by values
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
.cmp_loop:
    sub r10, 8
    sub r11, 8
    mov rbx, [r10]
    sub rbx, [r11]
    ; if digit of 1st number greater than the 2nd, than 1st BigInteger is greater
    ja .greater_un
    ; if digit of 1st number less than the 2nd, than 1st BigInteger is less
    jb .less_un
    dec r9
    jnz .cmp_loop

    jmp .equals
.equals:
    mov rax, 0
    jmp .end_cmp_un
.greater_un:
    mov rax, 1
    jmp .end_cmp_un
.less_un:
    mov rax, -1
    jmp .end_cmp_un
.end_cmp_un:
    POP_REGS
    ret

; compares two BigIntegers
; rdi - 1st BigInteger
; rsi - 2nd BigInteger
CMP_NEGATIVE_FLAG equ 1<<1
biCmp:
    PUSH_REGS
    xor rax, rax
    xor rcx, rcx
    mov r8, [rdi + SIGN]
    mov r9, [rsi + SIGN]
    cmp r8, r9
    jne .diff_signs

    ; if 2 numbers have the same sign, compares them
    call biCmpUnsigned

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

; divides BigInteger by short
; rdi - BigInteger
; rbx - divisor
; result: rdi /= rbx
; remainder is stored in rax
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

    ; checks if last digit is zero
    ; and decreases size if it's necessary
    mov r9, [rdi + SIZE]
    dec r9
    jz %%div_ls_end
    mov r10, r9
    shl r10, 3
    add r10, [rdi + VALUE]
    mov r10, [r10]
    test r10, r10
    jnz %%div_ls_end
    mov [rdi + SIZE], r9
%%div_ls_end:
    mov rax, rdx
    pop rdx
    pop r10
    pop r9
%endmacro

; converts BigInteger to string
; rdi - BigInteger
; rsi - string
; rdx - limit
biToString:
    PUSH_REGS
    mov r12, [rdi + SIGN]
    ; case when number is 0
    ; is processed separately
    test r12, r12
    jnz .not_zero_string
    ; if number is 0 prints it specially
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
    ; creates copy of BigInteger 
    ; to divide it during conversion
    biCreateCopy
    mov r13, [rdi + SIGN]
    mov rdi, rax
    mov rax, 20
    mov r14, [rdi + SIZE]
    mul r14
    mov rbp, rsp
    sub rsp, rax
    mov r14, rbp
    xor r9, r9
    ; rdi - copy BigInteger
    mov r8, rsp

    ; divides number by 10
    ; saves remainder on stack
.string_loop:
    isZeroFast
    test rax, rax
    jz .write_str 
    mov rbx, 10
    div_long_short
    add rax, '0'
    inc r9
    dec r14
    mov byte [r14], al
    jmp .string_loop
.write_str:
    cmp r13, 0
    jge .write_str_loop
    xor rdx, rdx
    mov dl, '-'
    inc r9
    dec r14
    mov byte [r14], dl

    ; writes bytes from stack to string
.write_str_loop:
    mov al, byte [r14]
    mov byte [rsi], al
    inc rsi
    inc r14
    dec r12
    jz .string_end
    dec r9
    jnz .write_str_loop
.string_end:
    xor rax, rax
    mov byte [rsi], al
    mov rsp, rbp
    call biDelete
.string_pop_regs:
    POP_REGS
    ret

; increases the size of the BigInteger and copies it
; rdi - original BigInteger
; rdx - size 
; sets (rdx - size of rdi) values to zero
; memory is aligned to 16 bytes
%macro increaseCapacity 0
    PUSH_REGS
    push rdx

    push rdi
    mov rdi, rdx
    shl rdi, 3
    PUSH_REGS
    call malloc
    POP_REGS
    pop rdi
    mov r8, [rdi + SIZE]
    mov r9, [rdi + VALUE]
    push rax

    ; copies digits from origin
    ; or sets new digits as zeros
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
    ; removes previous values
    PUSH_REGS
    sub rsp, 8
    call free
    add rsp, 8
    POP_REGS
    pop rdi
    pop rax
    mov [rdi + VALUE], rax
    pop rdx
    mov [rdi + SIZE], rdx
    POP_REGS
%endmacro

; adds up 2 unsigned BigIntegers
; rdi - 1st summand, unsigned BigInteger
; rsi - 2st summand, unsigned BigInteger
; size of rdi > size of rsi
; rdi += rsi
%macro add_long_long 0
    PUSH_REGS

    mov r9, [rdi + VALUE]
    mov r10, [rsi + VALUE]
    mov r11, [rdi + SIZE]
    mov r12, [rsi + SIZE]

    ; r9 - values of 1st summand
    ; r10 - values of 2nd summand
    ; r11 - size of 1st summand
    ; r12 - size of 2nd summand
    xor rdx, rdx
    clc
%%add_ll_loop:
    mov rax, 0
    ; if r12 > 0, rax = current 2nd value, else rax = 0
    test r12, r12
    jz %%add_ll_loop_check
    mov rax, [r10]
    lea r10, [r10 + 8]
    dec r12
    jmp %%add_ll_loop_skip

    ; if 2nd summand is ended, checks if there is nothing to carry
    ; then breaks
%%add_ll_loop_check:
    test rdx, rdx
    jz %%add_ll_end
%%add_ll_loop_skip:
    mov r13, [r9]
    add rax, rdx
    mov rdx, 0
    adc rdx, 0
    add r13, rax
    adc rdx, 0
    mov [r9], r13
    lea r9, [r9 + 8]
    dec r11
    jnz %%add_ll_loop
%%add_ll_end:
    POP_REGS
%endmacro

; subtracts one BigInteger from another, both are unsigned
; rdi - minuend, 1st unsigned BigInteger
; rsi - subtrahend, 2nd unsigned BigInteger
; rdi -= rsi
; both are alighned to 16 bytes
SUB_LESS_FLAG equ 1
%macro sub_long_long 0
    PUSH_REGS
    xor rcx, rcx
    sub rsp, 8
    call biCmpUnsigned
    add rsp, 8
    ; if minuend is less than subtrahend
    ; then increases size of minuend to size of subtrahend
    ; and inverts sign of result
    cmp rax, -1
    jne %%sub_normal
    setf(SUB_LESS_FLAG)
    mov r8, [rdi + SIGN]
    neg r8
    mov [rdi + SIGN], r8
    mov rdx, [rsi + SIZE]
    sub rsp, 8
    increaseCapacity
    add rsp, 8
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
    sub r12, rdx
    mov rdx, 0
    adc rdx, 0
    sub r12, rax
    jmp %%sub_ll_loop_next
%%sub_ll_loop_less:
    sub rax, rdx
    mov rdx, 0
    adc rdx, 0
    sub rax, r12
    mov r12, rax
%%sub_ll_loop_next:
    mov [r8], r12
    adc rdx, 0
    add r8, 8
    add r9, 8
    dec r10
    jnz %%sub_ll_loop
%%sub_ll_end:
    POP_REGS
%endmacro

; adds up 2 BigIntegers
; rdi - 1st summand, BigInteger
; rsi - 2nd summand, BigInteger
; result: rdi += rsi
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
    jmp .add_eq_signs
.add_to_zero:
    mov [rdi + SIGN], r9
.add_eq_signs:
    ; rdx is equal to the maximum of summands' sizes
    ; without if
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
    jmp .add_end
.add_end:
    biTrim
    isZeroFast
    POP_REGS
    ret

; subtracts one BigInteger from another
; rdi - minuend, 1st BigInteger
; rsi - subtrahend, 2nd BigInteger
; result: rdi -= rsi
biSub:
    ; assumes that rdi - rsi = rdi + (-rsi)
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

; sets values of BigInteger to zero
; rdi - BigInteger
; doesn't involve sign
; it's equal to memset(digits, 0, sizeof(digits))
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

; multiplies 2 BigInteger
; rdi - 1st multiplier, BigInteger
; rsi - 2nd multiplier, BigInteger
; result: 1st *= 2nd
biMul:
    PUSH_REGS
    ; creates copy of 1st multiplier
    mov rdx, [rdi + SIZE]
    biCreateCopy
    mov r8, rax
    add rdx, [rsi + SIZE]
    increaseCapacity
    biSetToZero
    ; rdi - product, resulting BigInteger
    ; r9 - 2nd multiplier
    ; r8 - copy of 1st multiplier
    xchg rsi, r9
    push r8
    mov r10, [r8 + VALUE]
    mov r11, [r8 + SIZE]
    mov r8, [r9 + VALUE]
    mov rcx, [r9 + SIZE]
    mov r12, [rdi + VALUE]
    sub r12, 8
    ; r8 - values of 2nd multiplier
    ; rcx - size of 2nd multiplier
    ; r10 - values of initial 1st multiplier
    ; r11 - size of initial 1st multiplier
    ; r12 - values of product, resulting BigInteger
    push r11
    push r10
    push r12
    xor r13, r13
    ; for j = 0 .. size of 2nd
    ; for i = 0 .. size of 1st
    ; result[i + j] += 1st[i] * 2nd[j] (with carry)
.loop_i:
    mov rbx, [r8]
    add r8, 8
    mov r10, [rsp + 8]
    ; shifts place for add
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
; adds remainder if it is left
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
  
; shifts BigInteger to the right (by meaning) 
; r9 - BigInteger
%macro biShiftOne 0
    push rdi
    push rcx
    push r10
    push r11
    push r12

    mov rdi, [r9 + VALUE]
    mov rcx, [r9 + SIZE]
    xor r10, r10
    xor r11, r11
%%loop:
    mov r11, 0x1
    shl r11, 63
    mov r12, [rdi]
    and r11, r12
    shr r11, 63
    shl r12, 1
    or r12, r10
    mov r10, r11
    mov [rdi], r12
    add rdi, 8
    dec rcx
    jnz %%loop

    pop r12
    pop r11
    pop r10
    pop rcx
    pop rdi
%endmacro

; sets first bit of A to i-th bit of B
; r9 - BigInteger A
; rdi - BigInteger B
; rcx - i
; result: A(0) = B(i)
%macro biSetBitOf 0
    push rcx
    push r11
    push r12
    dec rcx
    mov r12, [rdi + VALUE]
%%loop:
    cmp rcx, 64
    jl %%loop_end

    sub rcx, 64
    add r12, 8
    jmp %%loop
%%loop_end:
    mov r11, [r12]
    shr r11, cl
    and r11, 0x1
    mov r12, [r9 + VALUE]
    mov rcx, [r12]
    or rcx, r11
    mov [r12], rcx
    pop r12
    pop r11
    pop rcx
%endmacro

; sets rcx-th bit of r8 to 1
; r8 - BigInteger
; rcx - position of bit to be set
; result: B(i) := 1
%macro biSetBitToOne 0
    push rcx
    push r10
    push r11
    push r12
    dec rcx
    mov r10, [r8 + VALUE]

    ; finds necessary digit
%%loop:
    cmp rcx, 64
    jl %%loop_end

    sub rcx, 64
    add r10, 8
    jmp %%loop
%%loop_end:
    ; gets this bit and sets it to 1
    mov r11, 0x1
    mov r12, [r10]
    shl r11, cl
    or r12, r11
    mov [r10], r12
    pop r12
    pop r11
    pop r10
    pop rcx
%endmacro

; compares 2 unsigned BigIntegers,
; inside the division
; rdi - 1st BigInteger
; rsi - 2nd BigInteger
; size 1st == size 2nd + 1
%macro biDivCmp 0
    PUSH_REGS
    mov r8, [rdi + SIZE]
    dec r8
    shl r8, 3
    add r8, [rdi + VALUE]
    mov r8, [r8]
    test r8, r8
    jnz %%greater_un
    mov r10, [rdi + SIZE]
    dec r10
    mov r11, r10
    shl r11, 3
    mov r8, [rdi + VALUE]
    add r8, r11
    mov r9, [rsi + VALUE]
    add r9, r11
%%loop:
    sub r8, 8
    sub r9, 8
    mov r12, [r8]
    mov r13, [r9]
    sub r12, r13
    ; if digit of 1st - digit of 2nd > 0, 
    ; then 1st number is greater than 2nd
    ja %%greater_un
    ; if digit of 1st - digit of 2nd < 0, 
    ; then 1st number is less than 2nd
    jb %%less_un
    dec r10
    jnz %%loop
%%loop_end
    mov rax, 0
    jmp %%end_cmp
%%greater_un
    mov rax, 1
    jmp %%end_cmp
%%less_un
    mov rax, -1
    jmp %%end_cmp
%%end_cmp:
    POP_REGS
%endmacro
 
; subtracts one BigInteger from another,
; inside the division
; rdi - 1st BigInteger
; rsi - 2nd BigInteger
; size 1st == size 2nd + 1
%macro biDivSub 0
    PUSH_REGS
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
%%sub_ll_loop_normal:
    sub r12, rdx
    mov rdx, 0
    adc rdx, 0
    sub r12, rax
%%sub_ll_loop_next:
    mov [r8], r12
    adc rdx, 0
    add r8, 8
    add r9, 8
    dec r10
    jnz %%sub_ll_loop
%%sub_ll_end:
    POP_REGS
%endmacro

; divides 1st BigInteger by 2nd
; C-representation:
; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator)
; rdi - quotient
; rsi - remainder
; rdx - numerator
; rcx - denominator
; complexity - 64 * length(numerator) * length(denominator)
biDivRem:
    PUSH_REGS
    push rdi
    push rsi
    push rdi
    xchg rdi, rcx
    isZeroFast
    xchg rdi, rcx
    test rax, rax
    jnz .div_cont

    pop rdi
    pop rsi
    pop rdi
    mov [rdi], rax
    mov [rsi], rax
    POP_REGS
    ret
.div_cont:
    ; creates quotient and save sin r8
    ; assuming, size of quotient can't be more than size of numerator
    mov rdi, [rdx + SIZE]
    sub rsp, 8
    allocateMemory
    add rsp, 8
    mov rdi, rax
    biSetToZero
    mov r8, rdi
    ; creates remainder and saves in r9
    ; size of remainder = size of denominator + 1
    mov rdi, [rcx + SIZE]
    inc rdi
    sub rsp, 8
    allocateMemory
    add rsp, 8
    mov rdi, rax
    biSetToZero
    mov r9, rdi
    pop rdi
    ; r8 - quotient
    ; r9 - remainder
    mov rdi, rdx
    mov rsi, rcx
    ; rdi - numerator
    ; rsi - denominator
    mov rcx, [rdi + SIZE]
    ; count of bits = size of numerator * 64
    shl rcx, 6
    ; Q - quotient
    ; R - remainder
    ; N - numerator
    ; D - denominator

    ; for i = count of bits - 1 .. 0 do
.loop:
    ; R << 1
    biShiftOne
    ; sets i-th bit of numerator to the first bit if remainder
    ; R(0) := N(i)
    biSetBitOf
    xchg rdi, r9
    biDivCmp
    xchg rdi, r9
    cmp rax, -1
    je .loop_cont
    ; if R >= D
    push rdi
    mov rdi, r9
    ; R -= D
    biDivSub
    pop rdi
    ; Q(i) := 1
    biSetBitToOne
.loop_cont:
    dec rcx
    jnz .loop
    ; sets signs of quotient and remainder
    mov r10, [rdi + SIGN]
    imul r10, [rsi + SIGN]
    mov [r8 + SIGN], r10
    mov r10, [rdi + SIGN]
    mov [r9 + SIGN], r10

    ; clears numbers
    mov rdi, r8
    biTrim
    isZeroFast
    mov rdi, r9
    biTrim
    isZeroFast
    mov rdi, [r9 + SIGN]
    test rdi, rdi
    jz .end_div
    cmp rdi, [rsi + SIGN]
    je .end_div
    mov rdi, r9
    call biAdd
    mov rdi, -1
    call biFromInt
    mov rsi, rax
    mov rdi, r8
    call biAdd
    mov rdi, rsi
    call biDelete
    jmp .end_div
.end_div:
    pop rsi
    pop rdi
    ; writes result
    mov [rdi], r8
    mov [rsi], r9
    POP_REGS
    ret
