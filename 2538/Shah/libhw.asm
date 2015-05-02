default rel

section .text

extern malloc, free, strlen, calloc

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
; digits saved from low to high
; there aren't zeroes in the end of number


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
; rdx - size of copy
; rdx <= size of rdi
; create copy of existing BigInt with rdx < size of rdi
; call memory aligned 16 bytes
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
    ; copy values from destination
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

    ; find fist non-zero digit
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
    ; copy non-zero digits from source to new array
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
    mov rcx, [rdi + SIZE]
    mov rdi, [rdi + VALUE]
    xor rsi, rsi
    clc
    
    ; mul each digit to rbx
    ; and save result
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

 ; rdi - BigInt
 ; rsi - summand
 ; rdi += rsi
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
; by checking only last digit
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
    ; r9 - count of digits
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
    ; if there is no digits => return NULL
    test r9, r9
    jz .invalid_char
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
biCmpUnsigned:
    PUSH_REGS
    mov rax, [rdi + SIZE]
    mov r9, [rsi + SIZE]
    ; compare size of numbers
    sub rax, r9
    cmp rax, 0
    jg .greater_un
    jl .less_un

    ; size are equals => need loop to check
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
    ; digits 1st - digit 2nd > 0 => 1st > 2nd
    ja .greater_un
    ; digits 1st - digit 2nd < 0 => 1st < 2nd
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

    ; numbers have same sign can compare it
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

    ; check if last digit is zero
    ; and decrease size if necessary
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
    ; if number = 0 print it special
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
    ; create copy of BigInt
    ; because we had to divide it
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

    ; rdi - copy BigInt  
    mov r8, rsp

    ; divide number by 10
    ; save remainder on stack
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

    ; write bytes from stack to string
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

    ; copy digits from old place to new
    ; or set new digit to zero
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
    jz %%add_ll_loop_check
    mov rax, [r10]
    lea r10, [r10 + 8]
    dec r12
    jmp %%add_ll_loop_skip

    ; if 2nd summand is over
    ; then check if no carry => break
%%add_ll_loop_check:
    test rdx, rdx
    jz %%add_ll_end

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
    xor rcx, rcx
    call biCmpUnsigned
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
; equals memset(digits, 0, sizeof(digits))
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
    ; it's equals to calloc, but calloc
    ; works too long
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
    ; result[i + j] += 1st[i] * 2nd[j] (with carry)
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
  

; r9 - BigInt
; BigInt << 1
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

; r9 - BigInt R
; rdi - BigInt N
; rcx - i
; sets first bit of R to i-th bit of N
; R(0) = N(i)
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

; r8 - BigInt
; rcx - num of bit
; set rcx bit of r8 to 1
; Q(i) := 1
%macro biSetBitToOne 0
    push rcx
    push r10
    push r11
    push r12
    dec rcx
    mov r10, [r8 + VALUE]

    ; find necessary digit
%%loop:
    cmp rcx, 64
    jl %%loop_end

    sub rcx, 64
    add r10, 8
    jmp %%loop

%%loop_end:
    ; get bit and set in to 1
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

; rdi - 1st
; rsi - 2nd
; size 1st == size 2nd + 1
; unsinged cmp
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
    ; digits 1st - digit 2nd > 0 => 1st > 2nd
    ja %%greater_un
    ; digits 1st - digit 2nd < 0 => 1st < 2nd
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

; rdi - 1st
; rsi - 2nd
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


; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
; rdi - quotient
; rsi - remainder
; rdx - numerator
; rcx - denominator
; using the binary version of long division
; full explanation here: http://en.wikipedia.org/wiki/Division_algorithm#Integer_division_.28unsigned.29_with_remainder
; works for 64 * length(numerator) * length(denominator)
biDivRem:
    PUSH_REGS
    push rdi
    push rsi
    push rdi
    ; create quotient and save in r8
    mov rdi, [rdx + SIZE]
    allocateMemory
    mov rdi, rax
    biSetToZero
    mov r8, rdi
    ; create remainder and save in r9
    ; size of remainder = size of denominator + 1
    mov rdi, [rcx + SIZE]
    inc rdi
    allocateMemory
    mov rdi, rax
    biSetToZero
    mov r9, rdi
    pop rdi
    ; r8 - size of numerator(quotient)
    ; r9 - size of denominator(remainder)
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

.loop:
    ; R << 1
    biShiftOne
    ; sets first bit to bit number i of numerator
    ; R(0) := N(i)
    biSetBitOf
    push rdi
    mov rdi, r9
    biDivCmp
    pop rdi
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

    mov r10, [rdi + SIGN]
    imul r10, [rsi + SIGN]
    mov [r8 + SIGN], r10
    mov r10, [rdi + SIGN]
    mov [r9 + SIGN], r10

    mov rdi, r8
    biTrim
    isZeroFast
    mov rdi, r9
    biTrim
    isZeroFast
    pop rsi
    pop rdi
    mov [rdi], r8
    mov [rsi], r9
    POP_REGS
    ret
