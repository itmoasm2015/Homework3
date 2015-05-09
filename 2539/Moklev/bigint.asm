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

%macro zero_sign_flush 1-2 ; check if number is 0 and set "+" sign
    push rdx                            ; save temp register
    cmp qword [%1 + BigInt.size], 1     ; if number.size > 1 => not zero
    jg .skip%2            
    mov rdx, [%1 + BigInt.data]         
    cmp qword [rdx], 0                  ; if number.data[0] != 0 => not zero
    jne .skip%2
    mov qword [%1 + BigInt.sign], 0     ; flush sign to "+"
.skip%2:
    pop rdx                             ; restore temp register
%endmacro

%macro aligned_call 1                   ; call with stack alignment 16
    mov r8, rsp                         ; look at current value of rsp
    and r8, 15                          ; find rsp % 16
    mov r9, 16                          ; calc 16 - (rsp % 16)
    sub r9, r8
    add r9, 8                           ; we are going to push another register, so reserve 8 bytes more
    sub rsp, r9                         ; reserve needed to align 16 bytes and 8 more
    push r9                             ; push 64-bit register, so 8 bytes more, 8 + 8 = 16, align 16 saved
    call %1                             ; call function with aligned stack
    pop r9                              ; restore amount of shifted bytes
    add rsp, r9                         ; shift them back
%endmacro

extern malloc
extern calloc
extern free

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
global biDivRem         ; done optional

; advanced conversion to
global biToString       ; done optional

; # BigInt
; layout in memory:
; |   sign   |   size   | capacity | data pointer |
; |  8 bytes |  8 bytes | 8 bytes  |    8 bytes   |
; fields: 
;   sign:     sign of number (+: 0, -: 1)
;       @contract: sign == 0, if number >= 0 and sign == 1, if number < 0 (so there is restricted number "-0")
;   size:     count of significant 64-bit digits
;       @contract: size is equal to max(capacity - [count of leading zeroes], 1) 
;   capacity: size of allocated 'data' memory block
;   data:     memory block, contains all digits of number

struc BigInt
    .sign:      resq 1
    .size:      resq 1
    .capacity:  resq 1
    .data:      resq 1 
endstruc

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
    cmp rdx, rsi                        ; if a.capacity >= capacity
    jge .return                         ; enlarging is not needed

.enlarge_loop:                                      
    shl rdx, 1                          ; capacity x2 until it is enough
    cmp rdx, rsi
    jl .enlarge_loop

    mpush r14, r15
    
    mov r14, rdx                        ; save arguments
    mov r15, rdi                        
    mov rdi, r14                        ; allocate new block with size r14
    mov rsi, 8                          ; sizeof(uint64_t) = 8
    aligned_call calloc
    
    mov [r15 + BigInt.capacity], r14    ; assign new capacity
    mov rcx, [r15 + BigInt.size]        ; counter = a.size
    mov r14, [r15 + BigInt.data]        ; pointer to a.data
    test rcx, rcx                       ; if size == 0
    jz .after_loop                      ; do not enter the loop
.loop:
    mov rdx,  [r14 + 8 * rcx - 8]       ; copy prefix of old memory block
    mov [rax + 8 * rcx - 8], rdx        ; to the new memory block
    loop .loop
.after_loop:

    mov [r15 + BigInt.data], rax        ; assign new data pointer
    mov rdi, r14                        ; free old memory block
    aligned_call free

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
    mov r15, rdi                            ; save argument
    mov rdi, 32                             ; allocate 4 * sizeof(uint64_t) memory block
    aligned_call malloc
    mov r13, rax                            ; save pointer to new BigInt
    mov rdi, 1                              ; allocate new data for BigInt
    mov rsi, 8                              ; one uint64_t and assign it to zero
    aligned_call calloc
    mov [r13 + BigInt.data], rax            ; assign data pointer
    mov r14, r15                            ; if value is negative
    shr r14, 63                             ; transform value into sign (pos. => 0, neg. => 1)
    test r14, r14                           ; if positive -- skip neg step
    jz .afterneg
    neg r15                                 ; if negavite -- take absolute value (neg again)
.afterneg:
    mov rax, r13                            ; return pointer to constructed BigInt
    mov r13, [r13 + BigInt.data]            
    mov qword [rax + BigInt.sign], r14      ; set sign = r14
    mov qword [rax + BigInt.size], 1        ; set size = 1
    mov qword [rax + BigInt.capacity], 1    ; set capacity = 1
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
    mov r14, rdi                            ; save argument
    
    mov rdi, 0                              ; construct accumulator = BigInt(0)
    call biFromInt
    mov r15, rax                            ; save pointer to accumulator
 
    cmp byte [r14], '-'                     ; if s[0] == '-' => reverse sign
    je .negative
    jmp .loop

.negative:
    mov qword [r15 + BigInt.sign], 1        ; set sign to 1 if negative
    inc r14                                 ; skip first char
  
.loop:

    mov rdi, r15                            ; accumulator *= 10
    mov rsi, 10
    call scalarMul
    xor rcx, rcx                            ; read next char
    mov cl, [r14]
    sub cl, '0'                             ; convert into digit

    cmp cl, 0                               ; if char is not in [0 .. 9]
    jl .error                               ; it is an error
    cmp cl, 9
    jg .error

    mov rdi, rcx                            ; constructs delta = BigInt(digit)
    call biFromInt
    push rax                                ; save argument for future use (to free it's memory)
    mov rdi, r15
    mov rsi, rax
    call rawAdd                             ; accumulator += delta
    pop rdi
    call biDelete                           ; deallocate delta

    inc r14                                 ; go to next char
    cmp byte [r14], 0                       ; if it's not terminator of string
    jne .loop                               ; continue
 
    cmp qword [r15 + BigInt.size], 1        ; perform "-0" case
    jg .after                               ; if a.size == 1
    mov rax, [r15 + BigInt.data]            
    cmp qword [rax], 0                      ; and it's the only 64-bit digit is 0
    jne .after
    mov qword [r15 + BigInt.sign], 0        ; => it's equal to zero, so flush it's sign to 0 (+)

.after:

    mov rax, r15                            ; return pointer to constructed BigInt
    mpop r14, r15

    leave
    ret

.error:                                     ; in case of error (met inappropriate symbol)

    mov rdi, r15                            ; deallocate temporarily created BigInt
    call biDelete
    xor rax, rax                            ; return NULL
    
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
    test rdi, rdi                       ; if NULL -- do not free memory
    jz .return                          ; biDelete(NULL) is ok, do nothing
    mov r15, rdi                        ; firstly free BigInt.data
    mov rdi, [rdi + BigInt.data]
    aligned_call free
    mov rdi, r15                        ; and secondly free BigInt itself
    aligned_call free

.return:
    mpop r15
    leave
    ret

; **
; * void recalcSize(BigInt a)
; *
; * Set a.size corresponding with size @contract
; * (size is a count of significant 'digits')
; * 
; * @param a -- given BigInt to set proper size
; * @asm rdi -- BigInt a
; **
recalcSize:
    enter 0, 0

    mov rcx, [rdi + BigInt.capacity]    ; make a loop to count leading zeroes
    mov r8, [rdi + BigInt.data]         ; store a.data
.loop:
    mov rax, [r8 + 8 * rcx - 8]         ; load 64-bit digit
    test rax, rax                       ; test if 0
    jnz .after_loop                     ; if it's not -- break
    loop .loop                          ; go to the next digit
.after_loop:

    test rcx, rcx                       ; if all digits are zeroes
    jnz .after_unit
    mov rcx, 1                          ; set size = 1 (due to size @contract)
.after_unit:
    mov [rdi + BigInt.size], rcx        ; set calculated size
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
rawAdd:
    enter 0, 0

    mpush r14, r15
    mov r14, rdi                        ; save arguments
    mov r15, rsi
    mov rsi, [r14 + BigInt.size]        ; find max(a.size, b.size)
    mov rdx, [r15 + BigInt.size]
    cmp rsi, rdx                        ; if rsi < rdx
    jge .after_max
    mov rsi, rdx                        ; rsi = rdx
.after_max:
    inc rsi                             ; max(a.size, b.size) + 1 -- maximum size of answer
    push rsi
    call ensure_capacity                ; ensure_capacity(a, max + 1)
    pop rsi
    mov rdi, r15                        ; ensure_capacity(b, max + 1) -- adjust sizes
    call ensure_capacity                ; to fast vertical adding (ensure_capacity does not
                                        ; change value of b, only it's details of realization, 
                                        ; so b is not modified, as required)
    
    mov r8, [r14 + BigInt.capacity]     ; go in loop through all digits
                                        ; note, that the last digits are 0 (by size @contract)
                                        ; but carry flag leads the sum be 1 

    mov r9,  [r14 + BigInt.data]        ; store pointers to a.data
    mov r10, [r15 + BigInt.data]        ; and b.data

    shl r8, 3                           ; *= sizeof(uint64_t)
    add r10, r8                         ; we need to make a loop from first digits, but our loop will be magical (read .add_loop comments)
    add r9, r8                          ; so let's move data pointer to the end of memory block
    shr r8, 3                           ; restore raw count of digits for future use

    ; # State of registers
    ; r14 -- (BigInt)    a
    ; r15 -- (BigInt)    b
    ; r8  -- (uint64_t)  max(a.size, b.size) + 1 
    ; r9  -- (uint64_t*) a.data + r8 * 8
    ; r10 -- (uint64_t*) b.data + r8 * 8

    clc                                 ; clear carry flag (initially we have no carry)
    mov rcx, r8                         ; counter = count of digits
.add_loop:
    mov rax, rcx                        ; ooooookaaaaay, here start unlogical things
    not rax       ; complement rax      ; I need to do save carry flag through the loop 
    inc rax       ; in two steps        ; but cmp changing it. I don't want to use memory (like stack) to push/pop flags
    mov rdx, [r10 + 8 * rax] ; digit    ; because it's slow. So let's do some magic -- use loop for iterating (increment rcx
    adc [r9 + 8 * rax], rdx  ; add with ; and do not touch flags). Than let's recalc index by negating rcx
    loop .add_loop  ; carry from        ; neg changes carry flag, so use inc & not. This is a kind of optimisation
                    ; last addition     ; for fast-working addition (because it's very important to have fast add & sub)
    mov rdi, r14                        
    call recalcSize                     ; to meet the size @contract -- call recalcSize after each operation

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
    mov r14, rdi                    ; save arguments
    mov r15, rsi                    
    mov rsi, [r14 + BigInt.size]    ; calc max(a.size, b.size)
    push rsi                        ; due to rawSub @contract max(a.size, b.size) = a.size
    call ensure_capacity            ; enlarge arguments to fit one size
    pop rsi
    mov rdi, r15
    call ensure_capacity            ; all like in rawAdd
    
    mov r8, [r14 + BigInt.size]     ; count of digits
    mov r9,  [r14 + BigInt.data]    ; a.data
    mov r10, [r15 + BigInt.data]    ; b.data

    shl r8, 3                       ; to understand all this transformatons
    add r10, r8                     ; please read {@link rawAdd} comments
    add r9, r8                      ; rawSub is a kind of copypaste of {@link rawAdd}
    shr r8, 3                       ; so explanations of loop magic are equal

    ; r14 -- (BigInt)    a
    ; r15 -- (BigInt)    b
    ; r8  -- (uint64_t)  min(a.size, b.size) 
    ; r9  -- (uint64_t*) a.data + r8 * 8
    ; r10 -- (uint64_t*) b.data + r8 * 8

    clc                             ; clear borrow flag (actually, carry, but sbb uses cf)
    mov rcx, r8
.sub_loop:
    mov rax, rcx                    ; copy loop counter
    not rax                         ; change it's sign
    inc rax                         
    mov rdx, [r10 + 8 * rax]        ; load next digit
    sbb [r9 + 8 * rax], rdx         ; subtract with borrow from last step
    loop .sub_loop

    mov rdi, r14                    ; to meet the size @contract -- call this function after each operation 
    call recalcSize

    mpop r14, r15
    leave
    ret

; **
; * BigInt biCopyOf(BigInt a)
; *
; * Copies given BigInt and returns it.
; *
; * @param a -- input BigInt
; * @return -- new allocated BigInt, equal to a
; * @asm rdi -- BigInt a
; **
biCopyOf:
    enter 0, 0
    
    mpush r14, r15
    mov r15, rdi                        ; save argument  

    mov rdi, 8 * 4                      ; allocate (4 x uint64_t) uninitialized memory
    aligned_call malloc
    mov r14, rax                        ; save pointer to new data
    mov rdi, [r15 + BigInt.capacity]    ; allocate a.capacity
    mov rsi, 8                          ; uint64_t's, initialized with zeroes
    aligned_call calloc
    mov [r14 + BigInt.data], rax        ; set data pointer of new allocatedd memory
    
    mov rdx, [r15 + BigInt.sign]        ; copy all attributes: sign
    mov [r14 + BigInt.sign], rdx
    mov rdx, [r15 + BigInt.size]        ; size
    mov [r14 + BigInt.size], rdx
    mov rdx, [r15 + BigInt.capacity]    ; capacity
    mov [r14 + BigInt.capacity], rdx

    mov rcx, [r15 + BigInt.size]        ; copy all significats 64-bit digits
    mov r9, [r15 + BigInt.data]         ; from old number
    mov r8, [r14 + BigInt.data]         ; to new
.loop:
    mov rdx, [r9 + 8 * rcx - 8]         ; load digit
    mov [r8 + 8 * rcx - 8], rdx         ; store digit to the new place
    loop .loop

    mov rax, r14                        ; return pointer to new BigInt
    mpop r14, r15
    leave
    ret

; **
; * void biReplace(BigInt a, BigInt b)
; *
; * "Assignment operator" -- a = b;
; * Makes a be equal to b
; *
; * @param a -- destination
; * @param b -- source
; * @asm rdi -- BigInt a
; * @asm rsi -- BigInt b
; **
biReplace:
    enter 0, 0

    mpush r14, r15
    mov r14, rdi                        ; save arguments
    mov r15, rsi

    mov rdi, [r14 + BigInt.data]        ; deallocate old data block of a
    aligned_call free
    mov rdi, [r15 + BigInt.capacity]    ; allocate new, 0-initialized, block of memory
    mov rsi, 8
    aligned_call calloc
    mov [r14 + BigInt.data], rax        ; set new data pointer to a.data
    
    mov rdx, [r15 + BigInt.sign]        ; copy all attributes: sign
    mov [r14 + BigInt.sign], rdx
    mov rdx, [r15 + BigInt.size]        ; size
    mov [r14 + BigInt.size], rdx
    mov rdx, [r15 + BigInt.capacity]    ; capacity
    mov [r14 + BigInt.capacity], rdx
    
    mov rcx, [r15 + BigInt.capacity]    ; copy data from b.data to a.data
    mov r8, [r14 + BigInt.data]
    mov r9, [r15 + BigInt.data]
.loop:
    mov rdx, [r9 + 8 * rcx - 8]         ; load digit
    mov [r8 + 8 * rcx - 8], rdx         ; stare digit at new place
    loop .loop
                                        ; looks like copypaste of biCopyOf -- so it is
    mpop r14, r15
    leave
    ret

; **
; * void biAdd(BigInt a, BigInt b)
; *
; * Increment a by b (corresponding to a and b signs)
; *
; * @param a -- destination and first argument of addition
; * @param b -- second argument of addition
; * @asm rdi -- BigInt a
; * @asm rsi -- BigInt b
; **
biAdd:
    enter 0, 0

    ; # This function is just switch-case for different cases
    ;   of a&b signes and a&b absolute values
    ;   Behind the scenes all work is done by {@link rawAdd} and {@link rawSub}
    
    push rdi                        ; save pointer to argument for future use in .return
    mov rdx, [rdi + BigInt.sign]    ; compare a.sign and b.sign
    cmp rdx, [rsi + BigInt.sign]
    jne .diff_sign

.equal_sign:                        ; if signes are equal, we can simply add absolute values of numbers
    call rawAdd                     ; and leave the old sign of number
    jmp .return

.diff_sign                          ; we need to compare absolute values of numbers
    call rawCmp                     ; because rawSub @contract requires |a| >= |b|
    cmp rax, 0
    jl .less
        
.greater:    
    call rawSub                     ; if @contract is met -- call rawSub, leave old sign
    jmp .return                     ; it's not changed, because |a| >= |b| 

.less
    mpush rdi, rsi 

    ; rdi -- a
    ; rsi -- b

    mov rdi, rsi                    ; copy b (to swap subtraction: copy(b) - a, we must not change b value)
    call biCopyOf
    
    ; rax -- copy(b)

    mpop rdi, rsi
    mpush rdi, rsi, rax

    mov rsi, rdi                    ; subtract copy(b) and a
    mov rdi, rax
    call rawSub

    ; (stack) rax -- copy(b) - a

    mpop rdi, rsi, rax
    
    ; rdi -- a
    ; rsi -- b
    ; rax -- a - copy(b)

    mov rsi, rax                    ; Assign a = (copy(b) - a)
    push rax
    ; rdi -- a
    ; rsi -- a - copy(b)
    call biReplace
    pop rdi ; rdi := (pop) rax      ; deallocate temporarily copied b
    ; rdi -- a - copy(b)
    call biDelete
    ;jmp .return (jump is not needed, just increment rip)

.return:

    pop rdi
    zero_sign_flush rdi             ; if result is "-0" -- make it "+0"

    leave
    ret

; **
; * void biSub(BigInt a, BigInt b)
; *
; * Subtract b from a (with signs)
; *
; * @param a -- destination & first argument of subtraction
; * @param b -- second argument of subtraction 
; * @asm rdi -- BigInt a
; * @asm rsi -- BigInt b
; **
biSub:
    enter 0, 0

    mpush rbx, r13, r14, r15
    mov r14, rdi                    ; save arguments
    mov r15, rsi

    xor rbx, rbx                    ; was not copied
    cmp r14, r15                    ; if &a == &b => copy b
    mov rbx, 1                      ; set copied flag
    mov rdi, r15
    call biCopyOf                   ; copy(b)
    mov r15, rax                    ; store copy

    mov r13, [r15 + BigInt.sign]    ; just change b.sign, call biAdd and return b.sign back
    xor r13, 1                      ; change b.sign
    mov [r15 + BigInt.sign], r13
    mov rdi, r14
    mov rsi, r15
    call biAdd                      ; a += (-b)
    xor r13, 1                      ; change b.sign back
    mov [r15 + BigInt.sign], r13   

    test rbx, rbx                   
    jz .return                      ; if wasn't copied -- skip

    mov rdi, r15
    call biDelete                   ; deallocate temporarily allocated BigInt

.return:
    mpop rbx, r13, r14, r15
    leave
    ret

; ** 
; * void scalarMul(BigInt a, uint64_t b)
; *
; * Multiplies BigInt by short (uint64_t) number
; * 
; * @param a -- first multiplier
; * @param b -- second (short) multiplier
; * @asm rdi -- BigInt a
; * @asm rsi -- uint64_t b
; **
scalarMul:
    enter 0, 0

    mpush rdi, rsi

    mov rsi, [rdi + BigInt.size]    ; reserve (a.size + 1) 64-bit digits
    inc rsi
    call ensure_capacity 

    mpop rdi, rsi

    mov r10, [rdi + BigInt.data]    ; store a.data
    mov rcx, [rdi + BigInt.size]    ; make loop through all digits
    xor r8, r8
    xor r9, r9
.loop:
    mov rax, rsi                    ; multiply b * a.data[r8]
    mul qword [r10 + 8 * r8]
    
    add rax, r9                     ; add long "carry"
    adc rdx, 0                      ; add short carry from previous instruction
    ; cf after this instruction is always 0, because maximum long carry -- (base - 2)
    ; if calc (base - 1) * (base - 1)  = (base - 2) * base + 1
    ; short carry is <= 1, so (long carry + short carry <= base - 1), so new short carry is always 0

    mov [r10 + 8 * r8], rax         ; store low 64 bits of result to b.data
    mov r9, rdx                     ; save new carry
    inc r8                          ; go to next 64-bit digit
    loop .loop 
    
    mov [r10 + 8 * r8], r9          ; store last digit = carry
    call recalcSize    
    
    leave    
    ret

; **
; * void biShift(BigInt a, uint64_t b)
; *
; * Multiplies a by (2^64)^b (shl b in 2^64 numerical system)
; *
; * @param a -- given BigInt
; * @param b -- shift
; * @asm rdi -- BigInt a
; * @asm rsi -- uint64_t b
; **
biShift:
    enter 0, 0

    test rsi, rsi                   ; if shift != 0
    jnz .consistent_shift           ; do consistent things
                                    ; else do nothing
    leave
    ret

.consistent_shift:
    mpush r14, r15
    mov r15, rdi                    ; save agruments
    mov r14, rsi        

    add rsi, [rdi + BigInt.size]    ; rdi -- a, rsi -- a.size + shift
    call ensure_capacity            ; ensure, that capacity is enough
    
    mov r8, [r15 + BigInt.data]     ; store pointer to a.data 
    lea r9, [r8 + 8 * r14]          ; shifted position of a.data (a + shift * sizeof(uint64_t))
    mov rcx, [r15 + BigInt.size]    ; copy all digits by shift higher
.loop:
    mov rdx, [r8 + 8 * rcx - 8]     ; load digit
    mov [r9 + 8 * rcx - 8], rdx     ; store it back to the shifted position
    loop .loop    

    mov rcx, r14                    ; fill the low shifted digits with zeroes
.zero_loop:
    mov qword [r8 + 8 * rcx - 8], 0 ; put zero
    loop .zero_loop

    add [r15 + BigInt.size], r14    ; increment a.size by shift 

    mpop r14, r15
    leave
    ret

; **
; * void biMul(BigInt a, BigInt b)
; *
; * Multiplies a and b and stores the result to a
; *
; * @param a -- first multiplier
; * @param b -- second multiplier
; * @asm rdi -- BigInt a
; * @asm rsi -- BigInt b
; ** 
biMul:
    enter 0, 0

    cmp qword [rsi + BigInt.size], 1    ; check b != 0
    jg .consistent_mul
    mov r8, [rsi + BigInt.data]
    cmp qword [r8], 0
    jne .consistent_mul
        
    push rdi                            ; if b == 0 => assign a = 0
    mov rdi, 0                          ; allocate new BigInt(0)
    call biFromInt
    pop rdi
    push rax
    mov rsi, rax
    call biReplace                      ; assign a = BigInt(0)
    pop rdi
    call biDelete                       ; deallocate temporary BigInt
    
    leave
    ret

.consistent_mul:
    
    cmp qword [rdi + BigInt.size], 1    ; if a == 0 => do nothing
    jg .consistent_consistent_mul
    mov r8, [rdi + BigInt.data]
    cmp qword [r8], 0
    jne .consistent_consistent_mul

    leave
    ret
 

.consistent_consistent_mul:
    mpush r12, r13, r14, r15
    mov r14, rdi                        ; save arguments
    mov r15, rsi
    mov r12, [rsi + BigInt.data]        ; store pointer to b.data

    mov rdi, 0                          ; allocate accumulator = BigInt(0)
    call biFromInt
    mov r13, rax
   
    mov rcx, [r15 + BigInt.size]        ; loop over all digits of a
.loop:
    push rcx                            ; push loop counter

    cmp qword [r12 + 8 * rcx - 8], 0    ; if digit == 0 => skip this step (optimization)
    jz .skip_mul
    
    mov rdi, r14                        ; make copy of a
    call biCopyOf 
    pop rcx
    push rcx
    push rax

    mov rdi, rax                        ; multiply copy(a) * digit
    mov rsi, [r12 + 8 * rcx - 8]
    call scalarMul

    pop rdi
    pop rcx
    push rcx
    push rdi
    lea rsi, [rcx - 1]
    call biShift                        ; shift (copy(a) * digit) left 

    pop rsi
    push rsi
    mov rdi, r13
    call rawAdd                         ; add to the accumulator

    pop rdi
    call biDelete                       ; delete temporary BigInt

.skip_mul:
    pop rcx
    loop .loop
   
    mov rdx, [r15 + BigInt.sign]        ; multiply signs of a & b
    xor rdx, [r14 + BigInt.sign]
    mov [r13 + BigInt.sign], rdx        ; store (a.sign * b.sign) to result.sign
    
    mov rdi, r14
    mov rsi, r13
    call biReplace                      ; assign result to a
    
    mov rdi, r13
    call biDelete                       ; delete temporary result

    zero_sign_flush r14
             
    mpop r12, r13, r14, r15
    leave
    ret

; **
; * int rawCmp(BigInt a, BigInt b)
; *
; * Compare absolute values of a & b.
; * 
; * @return -- negative value, if a < b
; *                         0, if a == b
; *            positive value, if a > b
; * @asm rdi -- BigInt a
; * @asm rsi -- BigInt b
; **
rawCmp:
    enter 0, 0

    push qword [rdi + BigInt.sign]      ; save a.sign
    push qword [rsi + BigInt.sign]      ; save b.sign
    mov qword [rdi + BigInt.sign], 0    ; flush a.sign to 0
    mov qword [rsi + BigInt.sign], 0    ; flush b.sign to 0
    call biCmp                          ; compare with sign (both positive now)
    pop qword [rsi + BigInt.sign]       ; restore a.sign
    pop qword [rdi + BigInt.sign]       ; restore b.sign
    
    leave
    ret

; int biCmp(BigInt a, BigInt b)
biCmp:
    enter 0, 0
    mpush r14, r15
    mov rax, [rsi + BigInt.sign]        ; compare signes
    sub rax, [rdi + BigInt.sign]        ; sign @contract guarantees, than there are no -0 and +0
    jnz .return                         ; so if number have different signs
    cmp qword [rdi + BigInt.sign], 1    ; they are less or greater (less, if a.sign > b.sign and vice versa)
    jne .after_swap
    xchg rdi, rsi                       ; if they are both negative => swap and compare absolute values (a < b => -a > -b, etc)
.after_swap:

    mov rax, [rdi + BigInt.size]        ; if sizes are different
    sub rax, [rsi + BigInt.size]        ; then numbers too (due to size @contract)
    jnz .return 
    
    mov rcx, [rdi + BigInt.size]        ; if signs and sizes are equal -- compare all digits
    mov r8, [rdi + BigInt.data]         ; store a.data 
    mov r9, [rsi + BigInt.data]         ; store b.data
    test rcx, rcx
    jz .after_loop
.loop:
    mov rax, [r8 + 8 * rcx - 8]         ; load digit from b
    sub rax, [r9 + 8 * rcx - 8]         ; and compare with digit from a (if rax != 0 => we will use it while returning answer)
    jnz .return
    loop .loop
.after_loop:
 
    
.return:
    jb .negative                        ; comparison if unsigned, so below and after
    ja .positive
    jmp .exit

.negative:
    mov rax, -1                         ; return -1 if <
    jmp .exit

.positive:
    mov rax, 1                          ; return 1 if >
;   jmp .exit

.exit:
    mpop r14, r15
    leave
    ret

; **
; * int biSign(BigInt a)
; *
; * Compare a with 0. Behave like biCmp(a, 0)
; *
; * 
; * @asm rdi -- BigInt a
; **
biSign:
    xor rax, rax
    mov rsi, [rdi + BigInt.data]        ; compare a with 0
    cmp qword [rdi + BigInt.size], 1    ; if a.size == 1
    jg .skip
    cmp qword [rsi], 0                  ; and the only digit == 0
    je .return                          ; return 0 (rax = 0 from 1st instruction)

.skip:
    mov rax, [rdi + BigInt.sign]        ; else -- transform {0, 1} signs to {-1, 1} form
    shl rax, 1                          ; t_sign = 1 - (sign << 1)
    dec rax
    neg rax

.return:
    ret

; **
; * uint64_t scalarDiv(BigInt a, uint64_t)
; *
; * Divides a by b (without sign) and stores quotient to a. 
; * Returns remainder
; *
; * @param a -- destination and numerator
; * @param b -- denominator
; * @contract b != 0
; * @asm rdi -- BigInt a
; * @asm rsi -- uint64_t b
; **
scalarDiv:
    enter 0, 0
    mpush r13, r14, r15
    mov r15, rdi                        ; save agruments
    mov r14, rsi

    mov rdi, 0                          ; allocate result
    call biFromInt
    push rax
    mov rdi, rax 
    mov rsi, [r15 + BigInt.size]
    push rsi
    call ensure_capacity                ; set result capacity as a.capacity
    pop rsi
    pop r13
    mov [r13 + BigInt.size], rsi

    mov rcx, [r15 + BigInt.size]
    mov r8, [r15 + BigInt.data]
    mov r9, [r13 + BigInt.data]
    xor r10, r10
.loop:
    mov rdx, r10                        ; r10 -- "carry"
    mov rax, [r8 + 8 * rcx - 8]         ; load new digit
    div r14                             ; divide (carry:digit) by b
    mov r10, rdx                        ; store new carry
    mov [r9 + 8 * rcx - 8], rax         ; store resulting digit
    loop .loop  

    push r10                            ; push remainder
    mov rdi, r15                        ; assign a = quotient
    mov rsi, r13
    call biReplace
    mov rdi, r13
    call biDelete                       ; delete temporary BigInt
    mov rdi, r15
    call recalcSize                     ; assure size @contract
    pop rax                             ; return remainder

    mpop r13, r14, r15 

    leave
    ret

; **
; * void biToString(BigInt a, char* buffer, size_t limit)
; *
; * Writes string representation of a to buffer, but
; * not exceeds limit chars (including terminating 0)
; * 
; * @param a -- BigInt to make string
; * @param buffer -- string to write chars
; * @param limit -- limitation of written chars
; * @asm rdi -- BigInt a
; * @asm rsi -- char* buffer
; * @asm rdx -- size_t limit
; **
biToString:
    enter 0, 0

    cmp rdx, 1                          ; if limit > 1 => do consistent work
    jg .consistent_to_string
    test rdx, rdx                       ; if limit != 0 (so == 1) => store '\0' to buffer
    jnz .unit_limit
    leave                       
    ret                                 ; do nothing if limit is 0
.unit_limit:
    mov byte [rsi], 0                   ; write terminating 0 if limit is 1
    leave
    ret
.consistent_to_string:                  ; consistent case
    mpush r12, r13, r14, r15
    mov r15, rdi                        ; save arguments
    mov r13, rdx 
    mov r12, rdi
    
    cmp qword [r12 + BigInt.sign], 0    ; if a < 0
    je .after_minus 
    mov byte [rsi], '-'                 ; store first symbol to '-'
    inc rsi                             ; go to next char in buffer
    dec r13                             ; decrement limit (one char written)
    
.after_minus:
    push rsi
    
    mov rdi, r15                        ; copy BigInt a 
    call biCopyOf
    mov r15, rax

    mov rdi, [r15 + BigInt.size]
    shl rdi, 5                          ; 32 * a.size  
    aligned_call malloc                 ; allocate temp buffer (one 64-bit digit does not exceeds 32 decimal digits)
    mov r14, rax  ; temp buffer
    xor rcx, rcx
.loop:
    push rcx

    mov rdi, r15                        ; div a by 10, convert remainder to char
    mov rsi, 10
    call scalarDiv 
    add rax, '0'                        ; convertation to char
    pop rcx                             ; renew pointer if buffer
    mov [r14 + rcx], al                 ; store to temporary buffer (reversed string)
    inc rcx
    push rcx                            ; save pointer in buffer

    mov rdi, r15
    call recalcSize
    
    pop rcx
    cmp qword [r15 + BigInt.size], 1    ; while a != 0
    jg .loop                            ; continue
    mov rdx, [r15 + BigInt.data]
    cmp qword [rdx], 0
    jne .loop

    pop rsi                             ; load last position in buffer
    
    inc rcx                             
    mov r9, rcx
    dec r9
    cmp r13, rcx
    jge .after_min                      ; calc min(limit, length == last_pos + 1)
    mov rcx, r13
    
.after_min:

    dec rcx                             
    mov byte [rsi + rcx], 0             ; write terminating zero
    test rcx, rcx
    jz .after_copy

.copy_loop:
    mov r8, r9                          ; copy reversed string to direct
    sub r8, rcx
    mov rdx, [r14 + r8]
    mov [rsi + rcx - 1], dl
    loop .copy_loop
.after_copy:

    mov rdi, r14                        ; free temporary buffer
    aligned_call free
    mov rdi, r15
    call biDelete                       ; deallocate temporary BigInt
  
    mpop r12, r13, r14, r15
    
    leave
    ret

; **
; * void negShift1(BigInt a)
; *
; * Shift a right by 1 64-bit digit (a /= 2^64)
; *
; * @param a -- number to shift
; * @asm rdi -- BigInt a
; **
negShift1:

    mov rdx, [rdi + BigInt.size]    
    dec rdx
    test rdx, rdx                   ; if a.size - 1 != 0
    jnz .consistent_shift           ; consistent shift
    mov rdx, [rdi + BigInt.data]
    mov qword [rdx], 0              ; else -- store 0 to the olny digit
    ret

.consistent_shift:
    mov [rdi + BigInt.size], rdx    ; loop over all digits except first
    mov r8, [rdi + BigInt.data]
    xor rcx, rcx
.loop:
    mov rax, [r8 + 8 * rcx + 8]     ; load next digit
    mov [r8 + 8 * rcx], rax         ; store at current position
    inc rcx
    cmp rcx, rdx
    jl .loop
    mov qword [r8 + 8 * rcx], 0     ; last digit is 0 now

    ret

; **
; * void biDivRem(BigInt* quotient, BigInt* remainder, BigInt numerator, BigInt denominator)
; * 
; * Divides numerator by denominator and stores result to quotient and remainder.
; * remainder is in [0, denominator) if denominator > 0 and 
; * in (denominator, 0], if demoninator < 0.
; * If denominator == 0, NULL stores into quotient and remainder
; * If denominator != 0, the following is true:
; * quotient * denominator + remainder = numerator
; *
; *
; * @asm rdi -- BigInt* quotient
; * @asm rsi -- BigInt* remainder
; * @asm rdx -- BigInt numerator
; * @asm rcx -- BigInt denominator
; **
biDivRem:
    enter 0, 0

    cmp qword [rcx + BigInt.size], 1    ; if b == 0
    jg .non_zero_denominator
    mov r8, [rcx + BigInt.data]
    cmp qword [r8], 0
    jnz .non_zero_denominator

    mov r8, 0
    mov [rdi], r8                       ; store NULL to quotient and remainder
    mov [rsi], r8

    leave
    ret

.non_zero_denominator:
    mpush rbx, r12, r13, r14, r15       
    xor rbx, rbx   ; was_normalized(B) ; save registers
    mov r12, rdi   ; &Q -- quotient
    mov r13, rsi   ; &R -- remainder
    mov r14, rdx   ; A -- numerator
    mov r15, rcx   ; B -- denominator
    ; A / B = Q + R / B

    mov rdi, 0
    call biFromInt
    mov [r12], rax
    mov r12, [r12]

    mov rdi, 0
    call biFromInt
    mov [r13], rax
    mov r13, [r13]

    ; ---- copy A and B ---- ;

    mov rdi, r14                        ; copy A
    call biCopyOf               
    mov r14, rax
    
    mov rdi, r15                        ; copy B
    call biCopyOf
    mov r15, rax 

    mov rdi, r14                        ; compare A and B
    mov rsi, r15
    call rawCmp
    cmp rax, 0
    jge .consistent_div                 ; if A > B => divide consisnently
    mov rdi, 0                          ; else Q = 0 and R = A (except B < 0, performs after .return)
    call biFromInt                      ; allocate BigInt(0)
    push rax
    mov rdi, r12
    mov rsi, rax
    call biReplace                      ; and assign it to Q
    pop rdi
    call biDelete                       ; delete temporary BigInt
    mov rdi, r13
    mov rsi, r14
    call biReplace                      ; assign R = A
    xor r8, r8
    mov qword [r13 + BigInt.sign], r8

    jmp .return_after_pop

.consistent_div:
    
    push qword [r14 + BigInt.sign]      ; save A and B signs
    push qword [r15 + BigInt.sign]
    mov r8, 0
    mov qword [r14 + BigInt.sign], r8   ; flush A and B signs
    mov qword [r15 + BigInt.sign], r8

    ; ---- normalization of B ---- ;
    
    mov rdx, [r15 + BigInt.data]        ; the algoritm below (known as Knuth's division or Naive division)
    mov rcx, [r15 + BigInt.size]        ; requiers B be normalized -- if base -- base of numerical system (2^64 we have)
                                        ; the highest digit of B must be >= base / 2 (2^63 we have)
    ; ---- testing area ---- ;
    bt qword [rdx + 8 * rcx - 8], 63    ; if b[n - 1] < base/2

    jc .after_normalization

    bsr rbx, qword [rdx + 8 * rcx - 8]  ; bit scan reverse -- find the highest unit if binary representation of b[n - 1]
    mov rcx, 63         
    sub rcx, rbx
    mov rbx, 1                          ; DEFINITION here ant later: b.size = n, a.size = n + m
    shl rbx, cl                         ; calculate multiplier C: 2^63 <= b[n - 1] * C < 2^64

    mov rdi, r15                        ; multiply B by C
    mov rsi, rbx
    call scalarMul
    mov rdi, r14                        ; multiply A by C
    mov rsi, rbx
    call scalarMul                      ; note, that Q will not change: (A * C) / (B * C) = A / b
                                        ; but R will multiplies by C, so store C to rbx to divide R by C later
    
.after_normalization:
    
    ; ---- preparing Q ---- ;
    xor rdi, rdi                        ; allocates quotient wih capacity = a.size - b.size + 1
    call biFromInt
    push rax
    mov rdi, rax
    mov rsi, [r14 + BigInt.size]
    sub rsi, [r15 + BigInt.size]
    inc rsi ; m + 1
    call ensure_capacity
    mov rdi, r12
    pop rsi
    push rsi
    call biReplace
    pop rdi
    call biDelete

    ; ---- ? ---- ;

    mov rdi, r15                        ; in algorithm we will need (B << j) for different j
    call biCopyOf                       ; let's allocate new number and assign it to (B << m)
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
    
    mov rdi, r14                        ; if A >= (B << m) than Q[m] = 1, else Q[m] = 0
    mov rsi, rax
    call biCmp
    cmp rax, 0
    jl .less

    ; stack: m | shifted_B

.greater_or_equals:                     ; Q[m] = 1
    mov rdx, [r12 + BigInt.data]  
    mov rcx, [rsp] ; m
    mov qword [rdx + 8 * rcx], 1
    mov rdi, r14
    mov rsi, [rsp + 8] ; shifted_B
    call biSub                          ; subtract (B << m) from A -- current remainder
    jmp .after_high_q

.less:                                  ; Q[m] = 0
    mov rdx, [r12 + BigInt.data]  
    mov rcx, [rsp] ; m
    mov qword [rdx + 8 * rcx], 0

.after_high_q:

    dec qword [rsp]
    ; stack: j = m - 1 | shifted_B
    cmp qword [rsp], 0
    jl .after_loop_j
.loop_j:                                ; loop over all digits
    
        mov rdi, [rsp + 8]              ; (B << j) -> (B << j - 1)
        call negShift1

        mov rdx, [r12 + BigInt.data]
        mov rcx, [rsp] ; j
        mov r8, 0xFFFFFFFFFFFFFFFF      ; Q[j] default value
        mov qword [rdx + 8 * rcx], r8

        mov r8, [r14 + BigInt.data]     ; A.data
        mov r9, [r15 + BigInt.data]     ; B.data
        mov r10, [r15 + BigInt.size]    ; n
        mov rax, [r9 + 8 * r10 - 8]     ; b[n - 1]
        add r10, rcx ; n + j
        cmp [r8 + 8 * r10], rax         ; cmp a[n + j], b[n - 1]
        jae .after_quotient_selection

        mov rdx, [r8 + 8 * r10]         ; a[n + j]
        mov rax, [r8 + 8 * r10 - 8]     ; a[n + j - 1]
        sub r10, rcx ; n
        div qword [r9 + 8 * r10 - 8]
        mov r11, [r12 + BigInt.data]
        mov [r11 + 8 * rcx], rax        ; q[j] = (a[n + j] * 2^64 + a[n + j - 1]) / b[n - 1] 


.after_quotient_selection:
        
        ; stack: j | shifted_B
        ; rcx -- j
        ; r8  -- A.data
        ; r9  -- B.data
        ; r10 -- n
        ; r11 -- Q.data
        
        mov rdi, [rsp + 8]              ; copy (B << j)
        call biCopyOf
        push rax
        
        ; stack: temp | j | shifted_B 
       
        mov rdi, rax
        mov rdx, [r12 + BigInt.data]    ; Q.data 
        mov rcx, [rsp + 8]              ; j
        mov rsi, [rdx + 8 * rcx]        ; q[j]
        call scalarMul                  ; calc q[j] * (B << j)
        
        mov rdi, r14
        mov rsi, [rsp]
        call biSub                      ; subtract a[j] * (B << j) from A

        pop rdi ; temp
        call biDelete
        
        ; stack: j | shifted_B

        mov rdi, r14
        call biSign
        cmp rax, 0                      ; biSign(A)
        jge .after_while                ; if A >= 0
.while_loop:
        mov rdx, [r12 + BigInt.data]    ; if A < 0 -- add (B << j) until A >= 0
        mov rcx, [rsp]                  ; some theorem stands, that maximum amount of additions -- 2 (maybe even 1, but strictly <= 2)
        dec qword [rdx + 8 * rcx]
        
        mov rdi, r14
        mov rsi, [rsp + 8]
        call biAdd                      ; A += (B << j)

        mov rdi, r14
        call biSign
        cmp rax, 0
        jl .while_loop 

.after_while:

    ; stack: j | shifted_B
    dec qword [rsp]                     ; j--
    cmp qword [rsp], 0                  ; if j >= 0 -- continue
    jge .loop_j
.after_loop_j:

    ; stack: j | shifted_B
    add rsp, 8      ; drop j    
    pop rdi         ; shifted_B
    call biDelete
  
    mov rdi, r13                        ; assign remainder to current A
    mov rsi, r14
    call biReplace

    mov rdi, r12                        ; assure quotient size @contract
    call recalcSize
  
    test  rbx, rbx                      ; if there was no normalizations -- go to .return
    jz .return

    mov rdi, r13                        ; scale remainder back by C from normalization
    mov rsi, rbx
    call scalarDiv

    mov rdi, r15                        ; scale B back too, required in .return steps
    mov rsi, rbx
    call scalarDiv

.return:
    pop qword [r15 + BigInt.sign]       ; if division was consistent -- restore A and B signs
    pop qword [r14 + BigInt.sign]
.return_after_pop:

    ; # sign processing
    ; Q -- r12
    ; R -- r13
    ; A -- r14
    ; B -- r15
   
    ; # Here goes some code for fixing remainder and quotient after that
    ; Here is a table of signs and transformations of Q and R
    ; + + ........... Q' = Q        | R' = R
    ; + - ........... Q' = -(Q + 1) | R' = B - R
    ; - + ........... Q' = -(Q + 1) | R' = R - B
    ; - - ........... Q' = Q        | R' = -R
    ; If R == 0 -- tranforms are easier:
    ; + + ........... Q' = Q 
    ; + - ........... Q' = -Q
    ; - + ........... Q' = -Q
    ; - - ........... Q' = Q
    
    mov r8, [r14 + BigInt.sign]         ; compare A and B signs
    cmp r8, [r15 + BigInt.sign]
    jne .diff_signs    

.equal_sign:                            ; equal signs
    test r8, r8                         
    jz .clean_up                        ; both positive -- do nothing
    xor qword [r13 + BigInt.sign], 1    ; else R = -R
    jmp .clean_up

.diff_signs:                            ; different signs
    cmp qword [r13 + BigInt.size], 1    ; compare R with 0
    jg .non_zero_remainder              
    mov r10, [r13 + BigInt.data]
    mov r10, [r10]
    test r10, r10
    jnz .non_zero_remainder

.zero_remainder:                        ; if R == 0 
    mov qword [r12 + BigInt.sign], 1    ; just reverse Q.sign
    jmp .clean_up

.non_zero_remainder:                    ; if R != 0
    ; # Q += 1
    mov rdi, 1                          ; increment Q
    call biFromInt
    push rax
    mov rdi, r12
    mov rsi, rax
    call rawAdd
    pop rdi
    call biDelete
    ; # R = B - R                       ; recalc R
    mov rdi, r15
    call biCopyOf
    push rax
    mov rdi, rax
    mov rsi, r13
    call rawSub
    mov rdi, r13
    pop rsi
    push rsi
    call biReplace 
    pop rdi
    call biDelete
    
    ; # change signs 
    mov qword [r12 + BigInt.sign], 1    
    mov r8, [r15 + BigInt.sign]
    mov [r13 + BigInt.sign], r8

.clean_up:
    mov rdi, r14                        ; deallocate copied A
    call biDelete

    mov rdi, r15                        ; deallocate copied B
    call biDelete

    zero_sign_flush r12, 1
    zero_sign_flush r13, 2

    mpop rbx, r12, r13, r14, r15
    
    leave 
    ret
