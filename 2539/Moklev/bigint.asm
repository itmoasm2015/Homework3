%macro mpush 1-*    ; multiple push
    %rep %0
        push %1
        %rotate 1
    %endrep
%endmacro

%macro mpop 1-*     ; multiple pop
    %rep %0
        %rotate -1
        pop %1
    %endrep
%endmacro

%macro zero_sign_flush 1 ; check if number is 0 and set "+" sign
    push rdx                            ; save temp register
    cmp qword [%1 + BigInt.size], 1     ; if number.size > 1 => not zero
    jg .skip            
    mov rdx, [%1 + BigInt.data]         
    cmp qword [rdx], 0                  ; if number.data[0] != 0 => not zero
    jne .skip
    mov qword [%1 + BigInt.sign], 0     ; flush sign to "+"
.skip:
    pop rdx                             ; restore temp register
%endmacro

%macro print 1-2
    mpush rax, rbx, rcx, rdx, rdi, rsi, r8, r9, r10, r11
    mov rdi, .macro_string%2
    mov rsi, %1
    xor rax, rax
    call printf
    mpop rax, rbx, rcx, rdx, rdi, rsi, r8, r9, r10, r11
    jmp .after_macro_string%2
.macro_string%2:
    db "%llu", 10, 0
.after_macro_string%2:
%endmacro

extern malloc
extern calloc
extern aligned_alloc
extern free
extern printf

; conversions from
global biFromInt        ; done
global biFromString     ; done

; destruction
global biDelete         ; done

; arithmetic
global biAdd            ; done
global biSub            ; done
global biMul            ; done
global biCmp            ; done
global biSign           ; done

; advanced arithmetic
global biDivRem         ; TODO optional

; advanced conversion to
global biToString       ; done optional

; # BigInt
; layout in memory:
; |   sign   |   size   | capacity | data pointer |
; |  8 bytes |  8 bytes | 8 bytes  |    8 bytes   |
; offset: 
;   sign:     0  bytes
;   size:     8  bytes
;   capacity: 16 bytes
;   data:     24 bytes

struc BigInt
    .sign:      resq 1
    .size:      resq 1
    .capacity:  resq 1
    .data:      resq 1 
endstruc

section .rodata
    HALF_B: dq 0x8000000000000000  

section .text

; **
; * void ensure_capacity(BigInt a, uint64_t capacity)
; *
; * BigInt is like a vector, so ensure_capacity checks
; * if a.capacity >= capacity, if it's not true
; * allocates new block of memory with new_block.capacity >= capacity,
; * copies all data from old memory to new and frees old memory
; * 
; * @param a -- given BigInt
; * @param capacity -- required capacity
; * @asm rdi -- BigInt a
; * @asm rsi -- uint64_t capacity
; **
ensure_capacity:    
    enter 0, 0
    
    mov rdx, [rdi + BigInt.capacity]
    cmp rdx, rsi
    jge .return

.enlarge_loop:
    shl rdx, 1
    cmp rdx, rsi
    jl .enlarge_loop

    mpush r14, r15
    
    mov r14, rdx
    mov r15, rdi
    mov rdi, r14
    mov rsi, 8
    call calloc
    
    mov [r15 + BigInt.capacity], r14
    mov rcx, [r15 + BigInt.size]
    mov r14, [r15 + BigInt.data]
    test rcx, rcx
    jz .after_loop
.loop:
    mov rdx,  [r14 + 8 * rcx - 8]
    mov [rax + 8 * rcx - 8], rdx 
    loop .loop
.after_loop:

    mov rdi, r14
    mov [r15 + BigInt.data], rax
    call free

    mpop r14, r15

.return:
    leave
    ret

; **
; * BigInt biFromInt(int64_t value)
; *
; * Constructs BigInt equal to value
; * 
; * @param value -- required value
; * @return -- BigInt equal to value
; * @asm rdi -- uint64_t value
; ** 
biFromInt:
    enter 0, 0

    mpush r13, r14, r15
    mov r15, rdi
    mov rdi, 32
    call malloc
    mov r13, rax
    mov rdi, 1
    mov rsi, 8
    call calloc
    mov [r13 + BigInt.data], rax
    mov r14, r15
    shr r14, 63
    test r14, r14
    jz .afterneg
    neg r15 
.afterneg:
    mov rax, r13
    mov r13, [r13 + BigInt.data]
    mov qword [rax + BigInt.sign], r14
    mov qword [rax + BigInt.size], 1
    mov qword [rax + BigInt.capacity], 1
    mov qword [r13], r15
    mpop r13, r14, r15
    
    leave       
    ret

; **
; * BigInt biFromString(const char * s)
; * 
; * Constructs BigInt from it's string representation
; * 
; * @param s -- string representation
; * @return -- BigInt with string representation s
; * @asm rdi -- char* s
; **
biFromString:
    enter 0, 0

    mpush r14, r15
    mov r14, rdi
    
    mov rdi, 0
    call biFromInt
    mov r15, rax
 
    cmp byte [r14], '-'
    je .negative
    jmp .loop

.negative:
    mov qword [r15 + BigInt.sign], 1
    inc r14
  
.loop:

    mov rdi, r15
    mov rsi, 10
    call scalarMul
    xor rcx, rcx
    mov cl, [r14]
    sub cl, '0'

    cmp cl, 0
    jl .error
    cmp cl, 9
    jg .error

    mov rdi, rcx
    call biFromInt
    push rax
    mov rdi, r15
    mov rsi, rax
    call rawAdd
    pop rdi
    call biDelete

    inc r14
    cmp byte [r14], 0
    jne .loop
 
    cmp qword [r15 + BigInt.size], 1
    jg .after
    mov rax, [r15 + BigInt.data]
    cmp qword [rax], 0
    jne .after
    mov qword [r15 + BigInt.sign], 0

.after:

    mov rax, r15
    mpop r14, r15

    leave
    ret

.error:

    mov rdi, r15
    call biDelete
    xor rax, rax
    
    mpop r14, r15
    leave
    ret

; ** 
; * void biDelete(BigInt a) 
; * 
; * Frees all memory for a
; *
; * @param a -- BigInt to free
; * @asm rdi -- BigInt a
; ** 
biDelete:
    enter 0, 0
    
    mpush r15
    test rdi, rdi
    jz .return
    mov r15, rdi
    mov rdi, [rdi + BigInt.data]
    call free
    mov rdi, r15
    call free

.return:
    mpop r15
    leave
    ret

; **
; * void recalcSize(BigInt a)
; *
; * Set a.size corresponding with size @contract
; * (size is count of significant 'digits')
; * 
; * @param a -- given BigInt to set proper size
; * @asm rdi -- BigInt a
; **
recalcSize:
    enter 0, 0

    mov rcx, [rdi + BigInt.capacity]
    mov r8, [rdi + BigInt.data]
.loop:
    mov rax, [r8 + 8 * rcx - 8]
    test rax, rax
    jnz .after_loop
    loop .loop
.after_loop:

    test rcx, rcx
    jnz .after_unit
    mov rcx, 1
.after_unit:
    mov [rdi + BigInt.size], rcx
    leave
    ret

; **
; * void rawAdd(BigInt a, BigInt b)
; *
; * Increment absolute value of a by 
; * absolute value of b
; *
; * @param a -- destination
; * @param b -- source
; * @asm rdi -- BigInt a
; * @asm rsi -- BigInt b
; **
global rawAdd
rawAdd:
    enter 0, 0

    mpush r14, r15
    mov r14, rdi
    mov r15, rsi
    mov rsi, [r14 + BigInt.size]
    mov rdx, [r15 + BigInt.size]
    cmp rsi, rdx
    jge .after_max
    mov rsi, rdx
.after_max:
    inc rsi
    push rsi
    call ensure_capacity ; (BigInt a, uint64_t capacity)
    pop rsi
    mov rdi, r15
    call ensure_capacity
    
    mov r8, [r14 + BigInt.capacity]
    dec r8

    mov r9,  [r14 + BigInt.data]
    mov r10, [r15 + BigInt.data]

    shl r8, 3
    add r10, r8
    add r9, r8
    shr r8, 3

    ; r14 -- (BigInt)    a
    ; r15 -- (BigInt)    b
    ; r8  -- (uint64_t)  min(a.size, b.size) 
    ; r9  -- (uint64_t*) a.data + r8 * 8
    ; r10 -- (uint64_t*) b.data + r8 * 8

    clc
    mov rcx, r8
.add_loop:
    mov rax, rcx
    not rax                     ; neg set cf flag
    inc rax                     ; so need to use not + inc
    mov rdx, [r10 + 8 * rax]
    adc [r9 + 8 * rax], rdx 
    loop .add_loop

    adc qword [r9], 0

    mov rdi, r14
    call recalcSize

    mpop r14, r15
    leave
    ret

; **
; * void rawSub(BigInt a, BigInt b)
; *
; * Decrement absoute value of bigger number a
; * by absolute value of b
; *
; * @param a -- destination
; * @param b -- source
; * @contract -- |destination| >= |source|
; * @asm rdi -- BigInt a
; * @asm rsi -- BigInt b
; **
rawSub:
    enter 0, 0

    mpush r14, r15
    mov r14, rdi
    mov r15, rsi
    mov rsi, [r14 + BigInt.size]
    mov rdx, [r15 + BigInt.size]
    cmp rsi, rdx
    jge .after_max ; TODO r14 is max
    mov rsi, rdx
.after_max:
    push rsi
    call ensure_capacity ; (BigInt a, uint64_t capacity)
    pop rsi
    mov rdi, r15
    call ensure_capacity
    
    mov r8, [r14 + BigInt.size]
    
    
    mov r9,  [r14 + BigInt.data]
    mov r10, [r15 + BigInt.data]

    shl r8, 3
    add r10, r8
    add r9, r8
    shr r8, 3

    ; r14 -- (BigInt)    a
    ; r15 -- (BigInt)    b
    ; r8  -- (uint64_t)  min(a.size, b.size) 
    ; r9  -- (uint64_t*) a.data + r8 * 8
    ; r10 -- (uint64_t*) b.data + r8 * 8

    clc
    mov rcx, r8
.sub_loop:
    mov rax, rcx
    not rax                     ; neg set cf flag
    inc rax                     ; so need to use not + inc
    mov rdx, [r10 + 8 * rax]
    sbb [r9 + 8 * rax], rdx 
    loop .sub_loop

.after_borrow:
    mov rdi, r14
    call recalcSize

    mpop r14, r15
    leave
    ret

; **
; * BigInt biCopyOf(BigInt a)
; *
; * 
; *
; * @param a -- inut BigInt
; * @asm rdi -- BigInt a
; **
biCopyOf:
    enter 0, 0
    
    mpush r14, r15
    mov r15, rdi

    mov rdi, 8 * 4
    call malloc
    mov r14, rax
    mov rdi, [r15 + BigInt.capacity]
    mov rsi, 8
    ;shl rdi, 3
    call calloc
    mov [r14 + BigInt.data], rax
    mov rdx, [r15 + BigInt.sign]
    mov [r14 + BigInt.sign], rdx
    mov rdx, [r15 + BigInt.size]
    mov [r14 + BigInt.size], rdx
    mov rdx, [r15 + BigInt.capacity]
    mov [r14 + BigInt.capacity], rdx
    mov rcx, [r15 + BigInt.size]
    mov r9, [r15 + BigInt.data]
    mov r8, [r14 + BigInt.data]
.loop:
    mov rdx, [r9 + 8 * rcx - 8]
    mov [r8 + 8 * rcx - 8], rdx
    loop .loop

    mov rax, r14
    mpop r14, r15
    leave
    ret

; rdi -- BigInt a
; rsi -- BigInt b
biReplace:
    enter 0, 0

    mpush r14, r15
    mov r14, rdi
    mov r15, rsi

    mov rdi, [r14 + BigInt.data]
    call free
    mov rdi, [r15 + BigInt.capacity]
    mov rsi, 8
    call calloc
    mov [r14 + BigInt.data], rax
    
    mov rdx, [r15 + BigInt.sign]
    mov [r14 + BigInt.sign], rdx
    mov rdx, [r15 + BigInt.size]
    mov [r14 + BigInt.size], rdx
    mov rdx, [r15 + BigInt.capacity]
    mov [r14 + BigInt.capacity], rdx
    
    mov rcx, [r15 + BigInt.capacity]
    mov r8, [r14 + BigInt.data]
    mov r9, [r15 + BigInt.data]
.loop:
    mov rdx, [r9 + 8 * rcx - 8]
    mov [r8 + 8 * rcx - 8], rdx
    loop .loop

    mpop r14, r15
    leave
    ret

; rdi -- BigInt a
; rsi -- BigInt b
biAdd:
    enter 0, 0

    push rdi
    mov rdx, [rdi + BigInt.sign]
    cmp rdx, [rsi + BigInt.sign]
    jne .diff_sign

.equal_sign:
    call rawAdd
    jmp .return

.diff_sign
    call rawCmp
    cmp rax, 0
    jl .less
        
.greater:    
    call rawSub
    jmp .return

.less
    mpush rdi, rsi 

    ; rdi -- a
    ; rsi -- b

    mov rdi, rsi
    call biCopyOf
    
    ; rax -- copy(b)

    mpop rdi, rsi
    mpush rdi, rsi, rax

    mov rsi, rdi
    mov rdi, rax
    call rawSub

    ; (stack) rax -- copy(b) - a

    mpop rdi, rsi, rax
    
    ; rdi -- a
    ; rsi -- b
    ; rax -- a - copy(b)

    mov rsi, rax
    push rax
    ; rdi -- a
    ; rsi -- a - copy(b)
    call biReplace
    pop rdi         ; rdi := (pop) rax
    ; rdi -- a - copy(b)
    call biDelete
    ;jmp .return

.return:

    pop rdi
    zero_sign_flush rdi

    leave
    ret

; rdi -- BigInt a
; rsi -- BigInt b
biSub:
    enter 0, 0

    push r15
    mov r15, [rsi + BigInt.sign]
    xor r15, 1
    mov [rsi + BigInt.sign], r15
    push rsi
    call biAdd  
    pop rsi
    xor r15, 1
    mov [rsi + BigInt.sign], r15
    pop r15

    leave
    ret

; rdi -- BigInt a
; rsi -- uint64_t b
scalarMul:
    enter 0, 0

    mpush rdi, rsi

    mov rsi, [rdi + BigInt.size]
    inc rsi
    call ensure_capacity 

    mpop rdi, rsi

    mov r10, [rdi + BigInt.data]
    mov rcx, [rdi + BigInt.size]
    xor r8, r8
    xor r9, r9
.loop:
    mov rax, rsi
    mul qword [r10 + 8 * r8]
    mov [r10 + 8 * r8], rax
    add [r10 + 8 * r8], r9
    mov r9, rdx
    inc r8
    loop .loop 
    
    mov [r10 + 8 * r8], r9
    call recalcSize    
    
    leave    
    ret

; rdi -- BigInt a
; rsi -- uint64_t b
biShift:
    enter 0, 0

    test rsi, rsi
    jnz .consistent_shift

    leave
    ret

.consistent_shift:
    mpush r14, r15
    mov r15, rdi
    mov r14, rsi

    add rsi, [rdi + BigInt.size]
    call ensure_capacity
    
    mov r8, [r15 + BigInt.data] 
    lea r9, [r8 + 8 * r14]
    mov rcx, [r15 + BigInt.size]
.loop:
    mov rdx, [r8 + 8 * rcx - 8]
    mov [r9 + 8 * rcx - 8], rdx
    loop .loop    

    mov rcx, r14
.zero_loop:
    mov qword [r8 + 8 * rcx - 8], 0
    loop .zero_loop

    add [r15 + BigInt.size], r14 

    mpop r14, r15
    leave
    ret

; rdi -- BigInt a
; rsi -- BigInt b
biMul:
    enter 0, 0

    cmp qword [rsi + BigInt.size], 1
    jg .consistent_mul
    mov r8, [rsi + BigInt.data]
    cmp qword [r8], 0
    jne .consistent_mul
    
    push rdi
    mov rdi, 0
    call biFromInt
    pop rdi
    push rax
    mov rsi, rax
    call biReplace
    pop rdi
    call biDelete
    
    leave
    ret

.consistent_mul:
    mpush r12, r13, r14, r15
    mov r14, rdi
    mov r15, rsi
    mov r12, [rsi + BigInt.data]

    mov rdi, 0
    call biFromInt
    mov r13, rax
   
    mov rcx, [r15 + BigInt.size]
.loop:
    push rcx

    cmp qword [r12 + 8 * rcx - 8], 0
    jz .skip_mul
    
    mov rdi, r14
    call biCopyOf 
    pop rcx
    push rcx
    push rax

    mov rdi, rax
    mov rsi, [r12 + 8 * rcx - 8]
    call scalarMul

    pop rdi
    pop rcx
    push rcx
    push rdi
    lea rsi, [rcx - 1]
    call biShift

    pop rsi
    push rsi
    mov rdi, r13
    call rawAdd

    pop rdi
    call biDelete

.skip_mul:
    pop rcx
    loop .loop
   
    mov rdx, [r15 + BigInt.sign]
    xor rdx, [r14 + BigInt.sign]
    mov [r13 + BigInt.sign], rdx
    
    mov rdi, r14
    mov rsi, r13
    call biReplace
    
    mov rdi, r13
    call biDelete

    zero_sign_flush r14
             
    mpop r12, r13, r14, r15
    leave
    ret

; rdi -- BigInt a
; rsi -- BigInt b
rawCmp:
    enter 0, 0

    push qword [rdi + BigInt.sign]
    push qword [rsi + BigInt.sign]
    mov qword [rdi + BigInt.sign], 0
    mov qword [rsi + BigInt.sign], 0
    call biCmp    
    pop qword [rsi + BigInt.sign]
    pop qword [rdi + BigInt.sign]
    
    leave
    ret

; int biCmp(BigInt a, BigInt b)
biCmp:
    enter 0, 0
    mpush r14, r15
    mov rax, [rsi + BigInt.sign]
    sub rax, [rdi + BigInt.sign]   
    jnz .return
    cmp qword [rdi + BigInt.sign], 1
    jne .after_swap
    xchg rdi, rsi
.after_swap:

    mov rax, [rdi + BigInt.size]
    sub rax, [rsi + BigInt.size]
    jnz .return 
    
    mov rcx, [rdi + BigInt.size]
    mov r8, [rdi + BigInt.data]
    mov r9, [rsi + BigInt.data]
    test rcx, rcx
    jz .after_loop
.loop:
    mov rax, [r8 + 8 * rcx - 8]
    sub rax, [r9 + 8 * rcx - 8]
    jnz .return
    loop .loop
.after_loop:
 
    
.return:
    jb .negative
    ja .positive
    jmp .exit

.negative:
    mov rax, -1
    jmp .exit

.positive:
    mov rax, 1
;   jmp .exit

.exit:
    mpop r14, r15
    leave
    ret

; rdi -- BigInt a
biSign:
    xor rax, rax
    mov rsi, [rdi + BigInt.data]
    cmp qword [rdi + BigInt.size], 1
    jg .skip
    cmp qword [rsi], 0
    je .return

.skip:
    mov rax, [rdi + BigInt.sign]
    shl rax, 1
    dec rax
    neg rax

.return:
    ret

; rdi -- BigInt a
; rsi -- uint64_t b
scalarDiv:
    enter 0, 0
    mpush r13, r14, r15
    mov r15, rdi
    mov r14, rsi

    mov rdi, 0
    call biFromInt
    push rax
    mov rdi, rax 
    mov rsi, [r15 + BigInt.size]
    push rsi
    call ensure_capacity
    pop rsi
    pop r13
    mov [r13 + BigInt.size], rsi

    mov rcx, [r15 + BigInt.size]
    mov r8, [r15 + BigInt.data]
    mov r9, [r13 + BigInt.data]
    xor r10, r10
.loop:
    mov rdx, r10
    mov rax, [r8 + 8 * rcx - 8]
    div r14
    mov r10, rdx
    mov [r9 + 8 * rcx - 8], rax
    loop .loop  

    push r10
    mov rdi, r15
    mov rsi, r13
    call biReplace
    mov rdi, r13
    call biDelete
    mov rdi, r15
    call recalcSize
    pop rax

    mpop r13, r14, r15 

    leave
    ret

; rdi -- BigInt a
; rsi -- char* buffer
; rdx -- size_t limit
biToString:
    enter 0, 0

    cmp rdx, 1
    jg .consistent_to_string
    test rdx, rdx
    jnz .unit_limit
    leave 
    ret                 ; do nothing if limit is 0
.unit_limit:
    mov byte [rsi], 0   ; write terminating 0 if limit is 1
    leave
    ret
.consistent_to_string:  ; consistent case
    mpush r12, r13, r14, r15
    mov r15, rdi
    mov r13, rdx 
    mov r12, rdi
    
    cmp qword [r12 + BigInt.sign], 0
    je .after_minus
    mov byte [rsi], '-'
    inc rsi
    dec r13
    
.after_minus:
    push rsi
    
    mov rdi, r15
    call biCopyOf
    mov r15, rax

    mov rdi, [r15 + BigInt.size]
    shl rdi, 5    ; 32 * a.size  
    call malloc
    mov r14, rax  ; temp buffer
    xor rcx, rcx
.loop:
    push rcx

    mov rdi, r15
    mov rsi, 10
    call scalarDiv 
    add rax, '0'
    pop rcx
    mov [r14 + rcx], al
    inc rcx
    push rcx

    mov rdi, r15
    call recalcSize
    
    pop rcx
    cmp qword [r15 + BigInt.size], 1
    jg .loop    
    mov rdx, [r15 + BigInt.data]
    cmp qword [rdx], 0
    jne .loop

    pop rsi 
    
    inc rcx
    mov r9, rcx
    dec r9
    cmp r13, rcx
    jge .after_min
    mov rcx, r13
    
.after_min:

    dec rcx
    mov byte [rsi + rcx], 0
    test rcx, rcx
    jz .after_copy

.copy_loop:
    mov r8, r9
    sub r8, rcx
    mov rdx, [r14 + r8]
    mov [rsi + rcx - 1], dl
    loop .copy_loop
.after_copy:

    mov rdi, r14
    call free
    mov rdi, r15
    call biDelete
  
    mpop r12, r13, r14, r15
    
    leave
    ret

; rdi -- BigInt a
negShift1:

    mov rdx, [rdi + BigInt.size]
    dec rdx
    test rdx, rdx
    jnz .consistent_shift
    mov rdx, [rdi + BigInt.data]
    mov qword [rdx], 0
    ret

.consistent_shift:
    mov [rdi + BigInt.size], rdx
    mov r8, [rdi + BigInt.data]
    xor rcx, rcx
.loop:
    mov rax, [r8 + 8 * rcx + 8]
    mov [r8 + 8 * rcx], rax
    inc rcx
    cmp rcx, rdx
    jl .loop
    mov qword [r8 + 8 * rcx], 0 

    ret

; rdi -- BigInt* quotient
; rsi -- BigInt* remainder
; rdx -- BigInt numerator
; rcx -- BigInt denominator
biDivRem:
    enter 0, 0
       
    mpush rbx, r12, r13, r14, r15
    xor rbx, rbx   ; was_normalized(B)
    mov r12, [rdi] ; Q
    mov r13, [rsi] ; R
    mov r14, rdx   ; A
    mov r15, rcx   ; B
    ; A / B = Q + R / B

    ; ---- copy A and B ---- ;
    
    mov rdi, r14
    call biCopyOf
    mov r14, rax
    mov rdi, r15
    call biCopyOf
    mov r15, rax

    ; ---- normalization of B ---- ;
    
    mov rdx, [r15 + BigInt.data]
    mov rcx, [r15 + BigInt.size]
    ; ---- testing area ---- ;
    bt qword [rdx + 8 * rcx - 8], 63

    jc .after_normalization

    bsr rbx, qword [rdx + 8 * rcx - 8]
    mov rcx, 63
    sub rcx, rbx
    mov rbx, 1
    shl rbx, cl 

    mov rdi, r15
    mov rsi, rbx
    call scalarMul
    mov rdi, r14
    mov rsi, rbx
    call scalarMul    
    
.after_normalization:
    
    ; ---- preparing Q ---- ;
    xor rdi, rdi
    call biFromInt
    push rax
    mov rdi, rax
    mov rsi, [r14 + BigInt.size]
    sub rsi, [r15 + BigInt.size]
    inc rsi ; m + 1
    call ensure_capacity
    mov rdi, r12
    pop rsi
    call biReplace

    ; ---- ? ---- ;

    mov rdi, r15
    call biCopyOf
    push rax
    mov rdi, rax
    mov rsi, [r14 + BigInt.size]
    sub rsi, [r15 + BigInt.size] ; m
    push rsi
    call biShift
    pop rsi
    pop rax
    push rax
    push rsi

    ; rsi -- m
    ; rax -- shifted_B
    
    mov rdi, r14
    mov rsi, rax
    call biCmp
    cmp rax, 0
    jl .less

    ; stack: m | shifted_B

.greater_or_equals: 
    mov rdx, [r12 + BigInt.data]  
    mov rcx, [rsp] ; m
    mov qword [rdx + 8 * rcx], 1
    mov rdi, r14
    mov rsi, [rsp + 8] ; shifted_B
    call biSub
    jmp .after_high_q

.less:
    mov rdx, [r12 + BigInt.data]  
    mov rcx, [rsp] ; m
    mov qword [rdx + 8 * rcx], 0

.after_high_q:

    dec qword [rsp]
    ; stack: j = m - 1 | shifted_B
    cmp qword [rsp], 0
    jl .loop_j
.loop_j:
    
        mov rdi, [rsp + 8]
        call negShift1

        mov rdx, [r12 + BigInt.data]
        mov rcx, [rsp] ; j
        mov r8, 0xFFFFFFFFFFFFFFFF 
        mov qword [rdx + 8 * rcx], r8

        mov r8, [r14 + BigInt.data]  ; A.data
        mov r9, [r15 + BigInt.data]  ; B.data
        mov r10, [r15 + BigInt.size] ; n
        mov rax, [r9 + 8 * r10 - 8]  ; b[n - 1]
        add r10, rcx ; n + j
        cmp [r8 + 8 * r10], rax      ; cmp a[n + j], b[n - 1]
        jae .after_quotient_selection

        mov rdx, [r8 + 8 * r10]      ; a[n + j]
        mov rax, [r8 + 8 * r10 - 8]  ; a[n + j - 1]
        sub r10, rcx ; n
        div qword [r9 + 8 * r10 - 8]
        mov r11, [r12 + BigInt.data]
        mov [r11 + 8 * rcx], rax     ; q[j] = (a[n + j] * 2^64 + a[n + j - 1]) / b[n - 1] 


.after_quotient_selection:
        
        ; stack: j | shifted_B
        ; rcx -- j
        ; r8  -- A.data
        ; r9  -- B.data
        ; r10 -- n
        ; r11 -- Q.data
        
        mov rdi, [rsp + 8]
        call biCopyOf
        push rax
        
        ; stack: temp | j | shifted_B 
       
        mov rdi, rax
        mov rdx, [r12 + BigInt.data] ; Q.data 
        mov rcx, [rsp + 8] ; j
        mov rsi, [rdx + 8 * rcx] ; q[j]
        call scalarMul
        
        mov rdi, r14
        mov rsi, [rsp]
        call biSub

        pop rdi ; temp
        call biDelete
        
        ; stack: j | shifted_B

        mov rdi, r14
        call biSign
        cmp rax, 0       ; biSign(A)
        jge .after_while ; if A >= 0
.while_loop:
        mov rdx, [r12 + BigInt.data]
        mov rcx, [rsp]
        dec qword [rdx + 8 * rcx]
        
        mov rdi, r14
        mov rsi, [rsp + 8]
        call biAdd

        mov rdi, r14
        call biSign
        cmp rax, 0
        jl .while_loop 

.after_while:


    ; stack: j | shifted_B
    dec qword [rsp]
    cmp qword [rsp], 0
    jge .loop_j
.after_loop_j:

    ; stack: j | shifted_B
    add rsp, 8  ; drop j
    pop rdi     ; shifted_B
    call biDelete
  
    mov rdi, r13
    mov rsi, r14
    call biReplace

    mov rdi, r14
    call biDelete

    mov rsi, r14
    call biDelete
  
    test  rbx, rbx
    jz .return

    mov rdi, r13
    mov rsi, rbx
    call scalarDiv

.return:
    mpop rbx, r12, r13, r14, r15
    
    leave 
    ret
