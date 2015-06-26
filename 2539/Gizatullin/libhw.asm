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

%define ARG rdi
%define ARG2 rsi

%define SIGN 0
%define SIZE 8
%define VAL 16

%define setf(f) or rcx, f
%define testf(f) test rcx, f

; macros to push 13 registers
%macro pushAll 0
	push rbp
	push rbx
    push rcx
    push rdi
    push rdx
    push rsi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
%endmacro

; macros to pop 13 registers
%macro popAll 0
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rdi
    pop rcx
    pop rbx
    pop rbp
%endmacro

; structure BigInteger
; int64 signum
; int64 size of number
; int64* values
; BASE = 2^64
; digits are stored in ascending order
; trailing zeros are removed

; ARG - size
; creates new BigInteger with ARG values
; returns pointer to new BigInteger in rax
; memory is aligned to 16 bytes
%macro allocateMemory 0
    push ARG
    imul ARG, 8
    add ARG, 8
    pushAll
    call malloc
    popAll
    push rax
    mov ARG, 24
    pushAll
    sub rsp, 8
    call malloc
    add rsp, 8
    popAll
    xor ARG, ARG
    mov [rax + SIGN], ARG
    pop ARG
    mov [rax + VAL], ARG
    pop ARG
    mov [rax + SIZE], ARG
%endmacro

; creates copy of existing BigInteger with rdx < size of ARG
; ARG - BigInteger
; rdx - size of copy equal to ARG
; call memory aligned to 16 bytes
%macro biCreateCopy 0
    pushAll
    xchg ARG, rdx
    sub rsp, 8
    allocateMemory
    add rsp, 8
    xchg ARG, rdx

    mov r8, [ARG + SIGN]
    mov [rax + SIGN], r8
    mov r8, [ARG + VAL]
    mov r9, [rax + VAL]
    ; copies values from destination
%%copy_loop:
    mov r10, [r8]
    mov [r9], r10
    add r8, 8
    add r9, 8
    dec rdx
    jnz %%copy_loop

    popAll
%endmacro

; removes trailing zeros from BigInteger
; ARG - BigInteger
; memory aligned to 16 bytes
%macro biTrim 0
    pushAll
    mov r8, [ARG + SIZE]
    dec r8
    jz %%trim_end
    mov r9, r8
    shl r9, 3
    add r9, [ARG + VAL]

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
    cmp r8, [ARG + SIZE]
    je %%trim_end

    mov [ARG + SIZE], r8
    push ARG
    mov ARG, r8
    shl ARG, 3
    pushAll
    sub rsp, 8
    call malloc
    add rsp, 8
    popAll
    pop ARG
    
    push rax
    mov r9, [ARG + VAL]
    ; copies non-zero digits from source to new array
%%trim_copy_loop:
    mov r10, [r9]
    mov [rax], r10
    add rax, 8
    add r9, 8
    dec r8
    jnz %%trim_copy_loop

    push ARG
    mov ARG, [ARG + VAL]
    pushAll
    call free
    popAll
    pop ARG
    pop rax
    mov [ARG + VAL], rax
%%trim_end:
    popAll
%endmacro

; creates BigInteger from Integer
; ARG - Integer 64bit
; rax - result
biFromInt:
    push r8
    push ARG
    mov ARG, 1
    sub rsp, 8
    allocateMemory 
    add rsp, 8
    xor r8, r8
    pop ARG
    cmp ARG, 0
    je .push_value
    jl .negative
    mov r8, 1
    jmp .push_value
.negative:
    mov r8, -1
    neg ARG
.push_value:
    mov [rax + SIGN], r8
    mov r8, [rax + VAL]
    mov [r8], ARG
    cmp ARG, 0
    jne .not_zero
    mov [rax + SIGN], ARG
.not_zero:
    pop r8
    ret

; deletes BigInteger
; ARG - BigInteger
biDelete:
    pushAll
    push ARG
    mov ARG, [ARG + VAL]
    sub rsp, 8
    call free
    add rsp, 8
    pop ARG
    call free
    popAll
    ret

; multiplies BigInteger to Integer
; ARG - BigInteger
; rbx - multiplier
; BigInt *= rbxeger
%macro mul_long_short 0
    pushAll
    mov rcx, [ARG + SIZE]
    mov ARG, [ARG + VAL]
    xor ARG2, ARG2
    clc
    
    ; multiplies each digit to rbx
    ; and saves result
%%mul_ls_loop:
    mov rax, [ARG]
    mul rbx
    add rax, ARG2
    mov ARG2, 0
    adc ARG2, rdx
    mov [ARG], rax

    add ARG, 8
    dec rcx
    jnz %%mul_ls_loop

    test ARG2, ARG2
    jz %%mul_ls_end
%%mul_add_ls_loop:
    add [ARG], ARG2
    mov ARG2, 0
    adc ARG2, 0
    add ARG, 8
    test ARG2, ARG2
    jnz %%mul_add_ls_loop
%%mul_ls_end:
    popAll
%endmacro

; adds Integer to BigInteger
; ARG - BigInteger
; ARG2 - summand
; result is ARG += ARG2
%macro add_long_short 0
    pushAll
    mov rcx, [ARG + SIZE]
    mov ARG, [ARG + VAL]
    mov rax, ARG2
    xor rdx, rdx
%%add_ls_loop:
    add [ARG], rax
    adc rdx, 0
    mov rax, rdx
    test rax, rax
    jz %%add_ls_end
    xor rdx, rdx
    add ARG, 8
    dec rcx
    jnz %%add_ls_loop
%%add_ls_end:
    popAll
%endmacro

; compares BigInteger to zero by checking last digit
; ARG - BigInteger
; result: rax = 0 if number is equal to zero
%macro isZeroFast 0
    push r8
    mov r8, [ARG + SIZE]
    dec r8
    shl r8, 3
    add r8, [ARG + VAL]

    mov rax, [r8]
    test rax, rax
    jnz %%not_zero

    mov [ARG + SIGN], rax
    jmp %%end_check
%%not_zero:
%%end_check:
    pop r8
%endmacro

; creates BigInteger from string
; ARG - string
; rax - new BigInteger
biFromString:
    pushAll
    pushAll
    sub rsp, 8
    call strlen
    add rsp, 8
    popAll
    mov ARG2, ARG
    mov ARG, rax
    shr ARG, 3
    inc ARG
    ; asssuming the length of 10-base number as N
    ; it's enough to round up N / 8 in 2^64-base
    allocateMemory 
    ; ARG - BigInteger
    ; rax - BigInteger
    ; r8 - string
    mov ARG, rax
    mov r8, ARG2
    mov ARG2, [ARG + SIZE]
    mov rax, [ARG + VAL]
    xor rbx, rbx
    xor r9, r9
.loop_zero:
    mov [rax], rbx
    add rax, 8
    dec ARG2
    jnz .loop_zero 
.get_sign:
    mov rbx, 10
    mov rax, ARG
    mov ARG2, 1
    mov [ARG + SIGN], ARG2
    xor ARG2, ARG2
    cmp byte [r8], '-'
    jne .loop
    mov ARG2, -1
    mov [ARG + SIGN], ARG2
    xor ARG2, ARG2
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
    sub ARG2, '0'
    ; add current char
    add_long_short
    inc r8
    jmp .loop
.invalid_char:
    call biDelete
    xor rax, rax
    popAll
    ret
.end_loop:
    ; if there is no digits return NULL
    test r9, r9
    jz .invalid_char
    biTrim
    isZeroFast
    mov rax, ARG
    popAll
    ret

; returns signum of the BigInteger
; ARG - BigInteger
biSign:
    mov rax, [ARG + SIGN]
    ret

; compares 2 unsigned BigIntegers
; ARG - 1st BigInteger
; ARG2 - 2nd BigInteger
; returns -1 if 1st is less than 2nd
;          1 if 1st is greater than 2nd
;          0 if 1st is equal to 2nd
biCmpUnsigned:
    pushAll
    mov rax, [ARG + SIZE]
    mov r9, [ARG2 + SIZE]
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
    mov r12, [ARG + VAL]
    mov r13, [ARG2 + VAL]
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
    popAll
    ret

; compares two BigIntegers
; ARG - 1st BigInteger
; ARG2 - 2nd BigInteger
CMP_NEGATIVE_FLAG equ 1<<1
biCmp:
    pushAll
    xor rax, rax
    xor rcx, rcx
    mov r8, [ARG + SIGN]
    mov r9, [ARG2 + SIGN]
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
    popAll
    ret

; divides BigInteger by short
; ARG - BigInteger
; rbx - divisor
; result: ARG /= rbx
; remainder is stored in rax
%macro div_long_short 0
    push r9
    push r10
    push rdx
    mov r9, [ARG + SIZE]
    mov r10, r9
    shl r10, 3
    add r10, [ARG + VAL]
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
    mov r9, [ARG + SIZE]
    dec r9
    jz %%div_ls_end
    mov r10, r9
    shl r10, 3
    add r10, [ARG + VAL]
    mov r10, [r10]
    test r10, r10
    jnz %%div_ls_end
    mov [ARG + SIZE], r9
%%div_ls_end:
    mov rax, rdx
    pop rdx
    pop r10
    pop r9
%endmacro

; converts BigInteger to string
; ARG - BigInteger
; ARG2 - string
; rdx - limit
biToString:
    pushAll
    mov r12, [ARG + SIGN]
    ; case when number is 0
    ; is processed separately
    test r12, r12
    jnz .not_zero_string
    ; if number is 0 prints it specially
    mov ARG, '0'
    mov byte [ARG2], dil
    xor ARG, ARG
    inc ARG2
    mov byte [ARG2], dil
    jmp .string_pop_regs
.not_zero_string:
    dec rdx
    mov r12, rdx
    mov rdx, [ARG + SIZE]
    ; creates copy of BigInteger 
    ; to divide it during conversion
    biCreateCopy
    mov r13, [ARG + SIGN]
    mov ARG, rax
    mov rax, 20
    mov r14, [ARG + SIZE]
    mul r14
    mov rbp, rsp
    sub rsp, rax
    mov r14, rbp
    xor r9, r9
    ; ARG - copy BigInteger
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
    mov byte [ARG2], al
    inc ARG2
    inc r14
    dec r12
    jz .string_end
    dec r9
    jnz .write_str_loop
.string_end:
    xor rax, rax
    mov byte [ARG2], al
    mov rsp, rbp
    call biDelete
.string_pop_regs:
    popAll
    ret

; increases the size of the BigInteger and copies it
; ARG - original BigInteger
; rdx - size 
; sets (rdx - size of ARG) values to zero
; memory is aligned to 16 bytes
%macro increaseCapacity 0
    pushAll
    push rdx

    push ARG
    mov ARG, rdx
    shl ARG, 3
    pushAll
    call malloc
    popAll
    pop ARG
    mov r8, [ARG + SIZE]
    mov r9, [ARG + VAL]
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
    push ARG
    mov ARG, [ARG + VAL]
    ; removes previous values
    pushAll
    sub rsp, 8
    call free
    add rsp, 8
    popAll
    pop ARG
    pop rax
    mov [ARG + VAL], rax
    pop rdx
    mov [ARG + SIZE], rdx
    popAll
%endmacro

; adds up 2 unsigned BigIntegers
; ARG - 1st summand, unsigned BigInteger
; ARG2 - 2st summand, unsigned BigInteger
; size of ARG > size of ARG2
; ARG += ARG2
%macro add_long_long 0
    pushAll

    mov r9, [ARG + VAL]
    mov r10, [ARG2 + VAL]
    mov r11, [ARG + SIZE]
    mov r12, [ARG2 + SIZE]

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
    popAll
%endmacro

; subtracts one BigInteger from another, both are unsigned
; ARG - minuend, 1st unsigned BigInteger
; ARG2 - subtrahend, 2nd unsigned BigInteger
; ARG -= ARG2
; both are alighned to 16 bytes
SUB_LESS_FLAG equ 1
%macro sub_long_long 0
    pushAll
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
    mov r8, [ARG + SIGN]
    neg r8
    mov [ARG + SIGN], r8
    mov rdx, [ARG2 + SIZE]
    sub rsp, 8
    increaseCapacity
    add rsp, 8
%%sub_normal:
    mov r8, [ARG + VAL]
    mov r9, [ARG2 + VAL]
    mov r10, [ARG + SIZE]
    mov r11, [ARG2 + SIZE]

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
    popAll
%endmacro

; adds up 2 BigIntegers
; ARG - 1st summand, BigInteger
; ARG2 - 2nd summand, BigInteger
; result: ARG += ARG2
biAdd:
    pushAll

    mov r8, [ARG + SIGN]
    mov r9, [ARG2 + SIGN]
    test r8, r8
    jz .add_to_zero
    test r9, r9
    jz .add_end
    cmp r8, r9
    jne .diff_signs
    jmp .add_eq_signs
.add_to_zero:
    mov [ARG + SIGN], r9
.add_eq_signs:
    ; rdx is equal to the maximum of summands' sizes
    ; without if
    push r9
    mov rdx, [ARG + SIZE]
    mov r9, [ARG2 + SIZE]
    sub rdx, r9
    mov r10, rdx
    shr r10, 63
    and r10, 0x1
    imul r10, rdx
    mov rdx, [ARG + SIZE]
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
    popAll
    ret

; subtracts one BigInteger from another
; ARG - minuend, 1st BigInteger
; ARG2 - subtrahend, 2nd BigInteger
; result: ARG -= ARG2
biSub:
    ; assumes that ARG - ARG2 = ARG + (-ARG2)
    push r8
    mov r8, [ARG2 + SIGN]
    neg r8
    mov [ARG2 + SIGN], r8
    call biAdd
    mov r8, [ARG2 + SIGN]
    neg r8
    mov [ARG2 + SIGN], r8
    pop r8
    ret

; sets values of BigInteger to zero
; ARG - BigInteger
; doesn't involve sign
; it's equal to memset(digits, 0, sizeof(digits))
%macro biSetToZero 0
    push ARG
    push rcx
    push r10
    xor r10, r10
    mov rcx, [ARG + SIZE]
    mov ARG, [ARG + VAL]
%%set_zero:
    mov [ARG], r10
    add ARG, 8
    dec rcx
    jnz %%set_zero

    pop r10
    pop rcx
    pop ARG
%endmacro

; multiplies 2 BigInteger
; ARG - 1st multiplier, BigInteger
; ARG2 - 2nd multiplier, BigInteger
; result: 1st *= 2nd
biMul:
    pushAll
    ; creates copy of 1st multiplier
    mov rdx, [ARG + SIZE]
    biCreateCopy
    mov r8, rax
    add rdx, [ARG2 + SIZE]
    increaseCapacity
    biSetToZero
    ; ARG - product, resulting BigInteger
    ; r9 - 2nd multiplier
    ; r8 - copy of 1st multiplier
    xchg ARG2, r9
    push r8
    mov r10, [r8 + VAL]
    mov r11, [r8 + SIZE]
    mov r8, [r9 + VAL]
    mov rcx, [r9 + SIZE]
    mov r12, [ARG + VAL]
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
    xor ARG2, ARG2

;.loop_j:    mov rax, [r10]   add r10, 8   mul rbx    add rax, ARG2    adc rdx, 0    mov ARG2, rdx    add rax, r13   mov r13, 0    adc r13, 0    add [r12], rax    adc r13, 0    add r12, 8    dec r11    jnz .loop_j

.loop_j:  
 push r8   
  mov rax, [r10]  
    add r10, 8   
     mul rbx   
      add rax, ARG2   
       adc rdx, 0   
        mov ARG2, rdx   
         add rax, r13  
          mov r8, 0   
           adc r8, 0   
                add [r12], rax   
                 adc r8, 0    
                 add r12, 8  
                  mov r13, r8  
                    dec r11   
                     pop r8   
                      jnz .loop_j    
; adds remainder if it is left
.loop_rem:
    mov rax, ARG2
    xor ARG2, ARG2
    add rax, r13
    mov r13, 0
    adc r13, 0
    add [r12], rax
    adc r13, 0

;    add r12, 8
    push r8
    add r8, 8
    mov r12, r8
    pop r8

    test r13, r13
    jnz .loop_rem
.loop_i_continue:
    dec rcx
    jnz .loop_i

    pop r12
    pop r10
    pop r11
    pop r8

    mov r10, [ARG + SIGN]
    imul r10, [r9 + SIGN]
    mov [ARG + SIGN], r10
    biTrim
    isZeroFast
    mov ARG, r8
    call biDelete
    popAll
    ret
  
; shifts BigInteger to the right (by meaning) 
; r9 - BigInteger
%macro biShiftOne 0
    push ARG
    push rcx
    push r10
    push r11
    push r12

    mov ARG, [r9 + VAL]
    mov rcx, [r9 + SIZE]
    xor r10, r10
    xor r11, r11
%%loop:
    mov r11, 0x1
    shl r11, 63
    mov r12, [ARG]
    and r11, r12
    shr r11, 63
    shl r12, 1
    or r12, r10
    mov r10, r11
    mov [ARG], r12
    add ARG, 8
    dec rcx
    jnz %%loop

    pop r12
    pop r11
    pop r10
    pop rcx
    pop ARG
%endmacro

; sets first bit of A to i-th bit of B
; r9 - BigInteger A
; ARG - BigInteger B
; rcx - i
; result: A(0) = B(i)
%macro biSetBitOf 0
    push rcx
    push r11
    push r12
    dec rcx
    mov r12, [ARG + VAL]
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
    mov r12, [r9 + VAL]
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
    mov r10, [r8 + VAL]

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
; ARG - 1st BigInteger
; ARG2 - 2nd BigInteger
; size 1st == size 2nd + 1
%macro biDivCmp 0
    pushAll
    mov r8, [ARG + SIZE]
    dec r8
    shl r8, 3
    add r8, [ARG + VAL]
    mov r8, [r8]
    test r8, r8
    jnz %%greater_un
    mov r10, [ARG + SIZE]
    dec r10
    mov r11, r10
    shl r11, 3
    mov r8, [ARG + VAL]
    add r8, r11
    mov r9, [ARG2 + VAL]
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
    popAll
%endmacro
 
; subtracts one BigInteger from another,
; inside the division
; ARG - 1st BigInteger
; ARG2 - 2nd BigInteger
; size 1st == size 2nd + 1
%macro biDivSub 0
    pushAll
%%sub_normal:
    mov r8, [ARG + VAL]
    mov r9, [ARG2 + VAL]
    mov r10, [ARG + SIZE]
    mov r11, [ARG2 + SIZE]
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
    popAll
%endmacro

; divides 1st BigInteger by 2nd
; C-representation:
; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator)
; ARG - quotient
; ARG2 - remainder
; rdx - numerator
; rcx - denominator
biDivRem:
    pushAll
    push ARG
    push ARG2
    push ARG
    xchg ARG, rcx
    isZeroFast
    xchg ARG, rcx
    test rax, rax
    jnz .div_cont

    pop ARG
    pop ARG2
    pop ARG
    mov [ARG], rax
    mov [ARG2], rax
    popAll
    ret
.div_cont:
    ; creates quotient and save sin r8
    ; assuming, size of quotient can't be more than size of numerator
    mov ARG, [rdx + SIZE]
    sub rsp, 8
    allocateMemory
    add rsp, 8
    mov ARG, rax
    biSetToZero
    mov r8, ARG
    ; creates remainder and saves in r9
    ; size of remainder = size of denominator + 1
    mov ARG, [rcx + SIZE]
    inc ARG
    sub rsp, 8
    allocateMemory
    add rsp, 8
    mov ARG, rax
    biSetToZero
    mov r9, ARG
    pop ARG
    ; r8 - quotient
    ; r9 - remainder
    mov ARG, rdx
    mov ARG2, rcx
    ; ARG - numerator
    ; ARG2 - denominator
    mov rcx, [ARG + SIZE]
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
    xchg ARG, r9
    biDivCmp
    xchg ARG, r9
    cmp rax, -1
    je .loop_cont
    ; if R >= D
    push ARG
    mov ARG, r9
    ; R -= D
    biDivSub
    pop ARG
    ; Q(i) := 1
    biSetBitToOne
.loop_cont:
    dec rcx
    jnz .loop
    ; sets signs of quotient and remainder
    mov r10, [ARG + SIGN]
    imul r10, [ARG2 + SIGN]
    mov [r8 + SIGN], r10
    mov r10, [ARG + SIGN]
    mov [r9 + SIGN], r10

    ; clears numbers
    mov ARG, r8
    biTrim
    isZeroFast
    mov ARG, r9
    biTrim
    isZeroFast
    mov ARG, [r9 + SIGN]
    test ARG, ARG
    jz .end_div
    cmp ARG, [ARG2 + SIGN]
    je .end_div
    mov ARG, r9
    call biAdd
    mov ARG, -1
    call biFromInt
    mov ARG2, rax
    mov ARG, r8
    call biAdd
    mov ARG, ARG2
    call biDelete
    jmp .end_div
.end_div:
    pop ARG2
    pop ARG
    ; writes result
    mov [ARG], r8
    mov [ARG2], r9
    popAll
    ret
