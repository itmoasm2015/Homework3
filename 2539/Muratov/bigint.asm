default rel

extern calloc
extern free
extern memcpy

global biFromInt
global biFromString
global biDelete
global biAdd
global biSub
global biMul
global biCmp
global biSign
global biDivRem
global biToString

section .text

; offsets in structure
%define sign                    0 ; points to sign, if this number is 1 if bigint is negative and 0 otherwise.
%define size                    8 ; points to current size of number
%define capacity                16 ; points to capacity of vector
%define data                    24 ; points to allocated vector 

%macro push_registers 0  ; push register according to calling convention
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
%endmacro   

%macro pop_registers 0  ; pop registers values
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
%endmacro     

; rdi - pointer to bigint
; rsi - size of bigint in qwords
; rax - pointer to bigint
new_vector:
    push_registers
    lea rdx, [rsi * 2] ; capacity = 2 * size
    mov r13, rdx       
    
    ;allocating memory for vector 
    push rdi
    push rsi
    mov rbp, rsp
    mov rdi, rdx
    mov rsi, 8 ; qword = 8 bytes
    and rsp, ~15  ; aligning stack
    call calloc
    test rax, rax
    jnz .correct
    ret     ; if can't allocate, return
.correct:
    mov rsp, rbp
    pop rsi
    pop rdi
    
    mov [rdi + size], rsi
    mov [rdi + capacity], r13
    mov [rdi + data], rax
    mov rax, rdi
    pop_registers

; rdi - pointer to bigint
; rsi - size, new capacity must be greater or equal to this size 
extend_vector:  
    push_registers
    push rdi
    mov r15, [rdi + data]
    mov r14, [rdi + size]
    call new_vector ; making new vector
    mov r13, rsp
    mov rdi, [rax + data]
    mov rsi, r15
    lea rdx, [r14 * 8] ; size of vector in bytes
    and rsp, ~15  ; aligning stack
    call memcpy ; copy data to new place in memory
    mov rdi, r15
    and rsp, ~15  ; aligning stack
    call free ; free memory where was data before the function
    mov rsp, r13
    pop rdi
    pop_registers

; rdi - pointer to bigint
; rax - copyied bigint
; Copy given bigint
; local function
biCopy:
    push_registers
    mov r12, rdi
    ;allocate memory for new bigint
    push rdi
    mov rbp, rsp
    mov rdi, 4
    mov rsi, 8 ; qword = 8 bytes
    and rsp, ~15  ; aligning stack
    call calloc
    test rax, rax
    jnz .correct
    ret ; if can't allocate, finish program
.correct:
    mov rsp, rbp
    pop rdi
    
    mov rdi, rax
    mov r13, [r12 + size]
    mov rsi, r13
    call new_vector
    mov r14, rax
    mov r15, rsp
    mov rdi, [rax + data]
    mov rsi, [r12 + data]
    lea rdx, [r13 * 8]
    and rsp, ~15  ; aligning stack
    call memcpy ; copy our bigint
    mov rsp, r15
    mov [r14 + size], r13
    mov bl, byte [r12 + sign]
    mov byte [r14 + sign], bl
    mov rax, r14
    pop_registers    

; rdi - long long
; rax - pointer to bigint
biFromInt:
    push_registers
    mov r14, rdi
    ;allocating memory for new bigint
    push rdi
    mov rbp, rsp
    mov rdi, 4
    mov rsi, 8
    and rsp, ~15  ; aligning stack
    call calloc
    test rax, rax
    jnz .correct
    ret ; if can't allocate, finish program
.correct:
    mov rsp, rbp
    pop rdi
    
    mov rdi, rax
    mov rsi, 4
    call new_vector
    mov qword [rax + size], 1 ; initial size is 1
    cmp r14, 0
    jge .positive_int
    mov byte [rax + sign], 1 ; setting sign
    neg r14 ; number in field data will be positive
    jmp .finish
    .positive_int:
        mov byte [rax + sign], 0 ; setting sign
    .finish:
        mov r12, [rax + data]
        mov [r12], r14 ; initialize data
        pop_registers

; rdi - pointer to bigint
; rsi - long long (it's positive because i use it in my code like positive)
; local function
biAddInt:
    push_registers
    mov r14, [rdi + size]
    inc r14 ; after function size of vector <= size of vector before the function + 1
    push rsi
    mov rsi, r14
    ;check if we should extend vector
    mov r13, [rdi + capacity]
    cmp r13, rsi
    jge .dont_extend ; we don't need to extend if capacity >= size
    call extend_vector
.dont_extend:
    
    dec r14
    pop rsi ; restore value of rsi after extend
    mov rbx, rdi
    mov rdi, [rdi + data]
    xor rdx, rdx ; carry
    xor r13, r13
    .loop:
        add [rdi], rsi
        adc rdx, 0 ; carry in rdx
        mov rsi, rdx ; carry in rsi
        xor rdx, rdx
        inc r13
        add rdi, 8
        cmp rsi, 0 ; if carry is 0 then finish cycle
        jne .loop
    cmp r13, r14
    jg .carry_after_last_iteration  
    .finish_loop:   
        mov rdi, rbx
        pop_registers    

    .carry_after_last_iteration:
        mov [rdi], rdx ; move carry to new qword
        mov rdi, rbx
        inc r14 ; increment size of vector in qwords
        mov [rdi + size], r14   
        pop_registers

; rdi - pointer to bigint
; rsi - long long int (it's positive because i use it in my code like positive)
; local function
biMulInt:
    push_registers
    mov r14, [rdi + size]
    push r14 ; save value of r14 to stack because I change it in my function
    push rdi
    inc r14 ; after function size of vector <= size of vector before the function + 1
    push rsi
    mov rsi, r14
    ;check if we should extend vector
    mov r13, [rdi + capacity]
    cmp r13, rsi
    jge .not_extend ; we don't need to extend if capacity >= size
    call extend_vector
.not_extend:
    
    dec r14
    pop rsi ; restore value of rsi after extend
    mov r13, [rdi + data]
    xor r12, r12 ; information about carry is in r12
    .loop:
        mov rax, [r13]
        mul rsi ; rax * rsi = rdx:rax
        add rax, r12 ; carry from last cycle iteration
        adc rdx, 0 ; carry
        mov [r13], rax
        add r13, 8 ; next qword
        mov r12, rdx ; carry is in r12 now
        xor rdx, rdx
        dec r14
        jnz .loop   
    cmp r12, 0
    jne .carry_after_last_iteration ; it's enough because size of bigint can be increased only by one qword
    pop rdi
    pop r14
    pop_registers    
    .carry_after_last_iteration:
        pop rdi
        pop r14 ; restore value of bigint size
        mov [r13], r12 ; move carry to new qword
        inc r14 ; increment size of vector in qwords
        mov [rdi + size], r14
        mov r14, [rdi + size]
        pop_registers


; rdi - string
; rax - pointer to bigint
biFromString:
    push_registers
    mov r14, rdi  
    mov rdi, 0
    call biFromInt
    mov rdi, r14
    cmp byte [rdi], '-'
    je .set_minus_sign
    mov byte [rax + sign], 0 ; sign '+'
    jmp .after_setting_sign

.after_setting_sign:
    mov rdi, rax
    cmp byte [r14], 0
    je .wrong_string_format ; string is '-' or empty
    .skip_zeros:
        cmp byte [r14], '0'
        jne .skipped
        inc r14
        jmp .skip_zeros

.skipped:
    cmp byte [r14], 0
    ; if string contains only '0' symbols, then return bigint like in case of empty string    
    je .empty_string
    .get_bigint:
        xor rbx, rbx
        mov bl, byte [r14]
        cmp bl, '0'
        jl .wrong_string_format
        cmp bl, '9'
        jg .wrong_string_format
        sub rbx, '0'
        mov rsi, 10
        call biMulInt ; multiply current result by 10
        mov rsi, rbx
        call biAddInt ; add current digit to result
        inc r14 ; moving to the next symbol
        cmp byte [r14], 0
        jne .get_bigint
    mov rax, rdi
    pop_registers    

.set_minus_sign:
    mov byte [rax + sign], 1 ; set sign
    inc r14 ; moving to the next symbol
    jmp .after_setting_sign

.empty_string:
    pop_registers

.wrong_string_format:
    ; freeing memory which was allocated to this bigint and return null
    call biDelete
    xor rax, rax
    pop_registers        

; rdi - pointer to bigint
biDelete:
    push_registers
    mov r15, rsp
    mov r14, rdi
    mov rdi, [rdi + data] ; delete vector with data
    and rsp, ~15  ; aligning stack
    call free
    mov rdi, r14 ; delete structure
    and rsp, ~15  ; aligning stack
    call free
    mov rsp, r15
    pop_registers


; rdi - pointer to first bigint
; rsi - pointer to second bigint
; After the execution bigint in rsi remains the same and bigint in rdi is sum of two bigints
biAdd:
    push_registers
    mov r15, [rdi + size]
    mov r8, [rsi + size]
    mov rbx, r15
    cmp r15, r8
    jl .rsi_size_greater

    .continue:
    inc rbx ; size of rdi after the function <= max(size of first argument before, size of second argument before) + 1
    mov rcx, rsi
    mov rsi, rbx
  
    ;check if we should extend vector  
    mov r14, [rdi + capacity]
    cmp r14, rsi
    ;we don't need to extend if capacity >= size
    jge .not_extend
    call extend_vector
.not_extend:
    
    mov rsi, rcx
    mov cl, byte [rdi + sign]
    mov bl, byte [rsi + sign]
    mov r11, [rdi + data]
    mov r10, [rsi + data]
    ; if signs are equal then add bigints else subtract
    cmp cl, bl
    je .equal_sign
    mov byte [rsi + sign], cl
    call biSub
    mov byte [rsi + sign], bl
    pop_registers

.rsi_size_greater:
    mov rbx, r15
    jmp .continue

.equal_sign:    
    xor r12, r12 ; current size of vector in qwords
    .loop:
        mov r9, [r10]
        lea r10, [r10 + 8]
        adc [r11], r9
        lea r11, [r11 + 8]
        inc r12
        dec r8 ; finish our loop if it's no more to add (no carry and second bigint is finished)
        jz .only_carry ; second bigint is finished, maybe it's carry
        jmp .loop

.only_carry:
    jnc .finish_loop ; no carry
    .carry_loop:
        mov rbx, [r11]
        adc rbx, 0
        mov [r11], rbx
        inc r12
        lea r11, [r11 + 8]
        jc .carry_loop

.finish_loop:
    cmp [rdi + size], r12
    jge .not_incremented
    mov [rdi + size], r12 ; move real size of vector of first argument in qwords to size field
    pop_registers        

.not_incremented:
    pop_registers    

; rdi - pointer to first bigint
; rsi - pointer to second bigint
; After the execution bigint in rsi remains the same and bigint in rdi is result of subtraction of two bigints
biSub:
    push_registers
    push rsi
    mov cl, byte [rdi + sign]
    mov bl, byte [rsi + sign]
    cmp bl, cl
    je .equal_sign ; if signs are equal then do subtraction else call biAdd
    mov byte [rsi + sign], cl
    call biAdd
    mov byte [rsi + sign], bl
    pop rsi
    pop_registers

.equal_sign:
    mov byte [rdi + sign], 0
    mov byte [rsi + sign], 0 ; change signs to compare bigints
    ; save sign of second argument
    push rcx
    call biCmp
    mov r15, rax
    ; restore sign of second argument
    pop rcx
    mov byte [rsi + sign], cl
    cmp rax, -1
    je .swap_args
    .after_swap:
        adc r13, 0 ; carry flag
        mov r13, [rdi + data]
        mov r12, [rsi + data]
        mov r11, [rdi + size]
        mov rcx, [rsi + size]
        .loop:
            mov r10, [r12]
            lea r12, [r12 + 8]
            sbb [r13], r10
            lea r13, [r13 + 8]
            dec rcx
            jz .only_carry ; second argument is ended check for carry
            dec r11
            jnz .loop   

        .after_carry:   
            cmp r15, -1
            je .was_swap
            ; if it wasn't swap then we must change size of first argument
            jmp .change_size 

.only_carry:
    jnc .after_carry ; no carry
    dec r11 ; from the last iteration of loop
    jz .after_carry
    .carry_loop:    
        mov rcx, 0
        adc rcx, 0 ; carry
        sbb [r13], rcx
        lea r13, [r13 + 8]
        dec r11
        jz .after_carry
        jmp .carry_loop     

.was_swap:
    mov cl, 1
    ; change sign, because arguments were swapped
    sub cl, byte [rdi + sign]
    mov byte [rdi + sign], cl
    
.change_size:
    mov r12, [rdi + data]
    mov r13, [rdi + size]
    lea r12, [r12 + 8 * r13 - 8]
    .decrement_size_loop:
        mov r11, [r12]
        cmp r11, 0
        je .decrement_size

    .after_decrement_size:
        cmp r15, -1
        je .delete_was_swap ; delete copyied bigint if was swap and it's copy
        mov [rdi + size], r13 ; set actual size
        pop rsi ; restore value of second argument before pop_registers
        pop_registers

    .delete_was_swap:
        pop rbx ; begin value of rdi is in rbx now
        mov [rbx + size], r13 ; set actual size
        mov cl, byte [rdi + sign]
        mov byte [rbx + sign], cl ; move all information from rdi to rbx
        push rdi ; save value rdi to delete it after memcpy
        push r15
        mov r15, rsp
        mov rsi, [rdi + data]
        mov rdi, [rbx + data]
        lea rdx, [r13 * 8] ; arguments for memcpy
        and rsp, ~15  ; aligning stack
        call memcpy
        mov rsp, r15
        pop r15
        pop rdi
        call biDelete ; delete copy of bigint in function
        mov rdi, rbx
        pop rsi ; restore value of rsi before pop_registers
        pop_registers    

.decrement_size:
    sub r12, 8
    dec r13
    cmp r13, 0
    je .increment_size ; if result bigint is 0 then r13 will be 0 at the end of cycle, but i don't want size of bigint 0 because of some collisions
    jmp .decrement_size_loop    

.increment_size: 
    inc r13 ; we are here only if result of function biSub is 0. And we must increment it, because size of bigint mustn't be 0, because of some collisions
    jmp .after_decrement_size   

.swap_args:
    push rdi
    push rdi
    mov rdi, rsi
    call biCopy
    mov rdi, rax ; rdi is now pointed to copyied bigint
    pop rsi ; restore value of rdi, it's now written to rsi (it means that swap is already done)
    jmp .after_swap


; rdi - pointer to bigint
; return -1 if rdi < 0, 1 if rdi > 0 and 0 if rdi == 0
biSign:
    cmp rdi, 0
    jne .bigint_is_not_null
    ret ; if given bigint is NULL then finish program
.bigint_is_not_null
    push_registers
    mov r14, qword [rdi + size]
    cmp r14, 1 ; if size of bigint is 1 then bigint can be zero
    je .maybe_return_zero
    mov bl, byte [rdi + sign]
    cmp bl, 1
    je .return_minus_one
    mov rax, 1
    pop_registers

.maybe_return_zero:
    mov r14, qword [rdi + data]
    mov rax, [r14]
    cmp rax, 0
    je .return_zero
    mov bl, byte [rdi + sign]
    cmp bl, 1
    je .return_minus_one
    mov rax, 1
    pop_registers

.return_zero:
    xor rax, rax
    pop_registers        

.return_minus_one:
    mov rax, -1
    pop_registers    

; rdi - pointer to first bigint
; rsi - pointer to second bigint   
; return -1 if rdi < rsi, 0 if rdi == rsi, 1 if rdi > rsi
biCmp:  
    push_registers
    call biSign
    mov r14, rax 
    mov r13, rdi
    mov rdi, rsi
    call biSign
    mov r12, rax
    mov rsi, rdi
    mov rdi, r13 ; restore rdi and rsi
    cmp r14, r12
    jg .return_positive ; sign of first > sign of second => return 1
    jl .return_negative ; sign of first < sign of second => return -1
    cmp r14, 0
    je .return_zero ; first and second bigint are 0
    cmp r14, -1
    je .sign_is_minus
    mov r11, [rdi + size]
    mov r10, [rsi + size]
    cmp r11, r10
    ja .return_positive
    jb .return_negative   
    mov r10, [rdi + data]
    mov r9, [rsi + data]
    lea r10, [r10 + 8 * r11 - 8] ; most significant qword of rdi is in r10 now
    lea r9, [r9 + 8 * r11 - 8] ; most significant qword of rsi is in r9 now
    .loop_positive:
        mov rbx, [r10] ; current qword of rdi
        mov rcx, [r9] ; current qword of rsi
        cmp rbx, rcx
        ja .return_positive
        jb .return_negative
        sub r10, 8 ; to next qword
        sub r9, 8 ; to next qword
        dec r11
        jz .return_zero ; if all qword are equal then bigints are equal
        jmp .loop_positive

.return_positive:
    mov rax, 1
    pop_registers    

.return_negative:
    mov rax, -1
    pop_registers    

.return_zero:
    mov rax, 0
    pop_registers    

.sign_is_minus:
    mov r11, [rdi + size]
    mov r10, [rdi + size]
    cmp r11, r10
    jg .return_negative ; size of first bigint > size of second bigint and sign is '-' => return -1
    jl .return_positive ; size of first bigint < size of second bigint and sign is '-' => return 1   
    mov r10, [rdi + data]
    mov r9, [rsi + data]
    lea r10, [r10 + 8 * r11 - 8] ; most significant qword of rdi is in r10 now
    lea r9, [r9 + 8 * r11 - 8] ; most significant qword of rsi is in r9 now
    .loop:
        mov rbx, [r10] ; current qword of rdi
        mov rcx, [r9] ; current qword of rsi
        cmp rbx, rcx
        jg .return_negative
        jl .return_positive
        sub r10, 8 ; to next qword
        sub r9, 8 ; to next qword
        dec r11
        jz .return_zero ; all qword are equal => bigints are equal
        jmp .loop

; rdi - pointer to first bigint
; rsi - pointer to second bigint
; After the execution bigint in rsi remains the same and bigint in rdi is multiplication of two bigints
biMul:
    push_registers
    mov al, byte [rdi + sign]
    mov bl, byte [rsi + sign]
    cmp al, bl
    je .set_plus_sign ; if signs are equal then result sign is '+', else result sign is '-'
    mov byte [rdi + sign], 1
    .after_setting_sign:
        mov r15, qword [rdi + size]
        push r15 ; save size of rdi to stack, because this size can be changed by extend_vector, but this size is interesting for the function
        mov r14, qword [rsi + size]
        add r15, r14 ; size of result <= size of rdi + size of rsi
        push rsi ; save value of rsi to stack, because some next opertions needs another rsi
        mov rsi, r15
        
        ;check if we should extend vector
        mov r13, [rdi + capacity]
        cmp r13, rsi
        jge .not_extend ; we don't need to extend if capacity >= size
        call extend_vector
    .not_extend:
        
        mov r13, rdi 
        mov rdi, 0
        call biFromInt
        mov rdi, r13 ; restore value of rdi
        mov r13, rax ; r13 is a pointer to new bigint now
        push rdi
        mov rdi, r13
        mov rsi, r15
        
        ;check to extend again
        mov r12, [rdi + capacity]
        cmp r12, rsi
        jge .not_extend2 ; we don't need to extend if capacity >= size
        call extend_vector
    .not_extend2:
        
        pop rdi ; restore value of rdi and rsi
        pop rsi
        pop r15 ; restore size of rdi
        mov r14, [rsi + size] ; size of rsi is in r14 now
        xor r12, r12 ; i
        mov r10, [r13 + data]
        mov r9, [rdi + data]
        mov r8, [rsi + data]
        push rsi
        push r13
        .first_for:
            xor r11, r11 ; j
            xor rsi, rsi ; carry
            lea rcx, [r9 + r12 * 8]
            mov rcx, [rcx] ; bigint1[i]
            .second_for:
                cmp r11, r14
                je .continue_second_for ; rbx = (j < bigint2.size ? bigint2[j] : 0)
                lea rbx, [r8 + r11 * 8]
                mov rbx, [rbx] ; bigint2[j]
                jmp .continue_second_for2
                .continue_second_for:
                xor rbx, rbx
                .continue_second_for2:
                    mov rax, rcx
                    mul rbx ; bigint1[i] * (j < bigint2.size ? bigint2[j] : 0)
                    push r9
                    lea r9, [r10 + r12 * 8]
                    lea r9, [r9 + r11 * 8] ; r13 = pointer to bigint3[i + j]
                    add rax, [r9]
                    adc rdx, 0 ; carry
                    add rax, rsi ; add carry from last iteration
                    adc rdx, 0
                    mov rsi, rdx ; save carry from this iteration
                    mov [r9], rax
                    pop r9
                    add r11, 1
                    cmp r11, r14
                    jge .maybe_finish_second_for ; bigint2 finished, finish second cycle if no carry
                    jmp .second_for
            .after_second_for:
                inc r12
                cmp r12, r15
                jl .first_for

        pop r13 ; restore pointer to bigint3
        pop rsi ; restore value of rsi
        mov r14, [r13 + capacity] ; register to get real size of bigint3
        lea r10, [r10 + r14 * 8 - 8]
        .get_real_size:
            cmp qword [r10], 0
            jne .got_size
            dec r14
            sub r10, 8
            jmp .get_real_size

        .got_size:  
            mov [rdi + size], r14 ; set real size to size of rdi
            push rdi
            push rsi ; save values of rdi and rsi, because i want to use memcpy which requiers rdi and rsi
            mov r15, rsp
            mov rdi, [rdi + data]
            mov rsi, [r13 + data]
            lea rdx, [r14 * 8]
            
            and rsp, ~15  ; aligning stack
            call memcpy ; copy resulted bigint to rdi
            mov rsp, r15
            mov rdi, r13
            call biDelete ; delete temporary bigint3
            pop rsi
            pop rdi ; restore values of rdi and rsi
            pop_registers


.maybe_finish_second_for:
    cmp  rsi, 0
    je .after_second_for
    jmp .second_for

.set_plus_sign:
    mov byte [rdi + sign], 0
    jmp .after_setting_sign

; rdi - pointer to bigint
; rsi - long long (it's positive because i use it in my code like positive)
; local function
biDivInt:   
    push_registers
    mov r14, [rdi + size]
    mov r10, [rdi + data]
    lea r10, [r10 + 8 * r14 - 8] ; most significant qword is in r10 now
    xor rdx, rdx
    xor r13, r13
    .loop:
        mov rax, [r10]
        div rsi ; rax = rdx:rax / rsi, rdx = rdx:rax % rsi
        mov [r10], rax
        cmp rax, 0
        je .maybe_decrease_size ; need to decrease size if and only if rax == 0 and it's first iteration of cycle
        jmp .after_decrease
        .decrease_size:
            cmp qword [rdi + size], 1 ; i don't want decrement size if it's 1, because i don't want to have size of bigint 0, because of some collisions
            je .after_decrease
            dec qword [rdi + size]
        .after_decrease:
            inc r13
            sub r10, 8
            dec r14
            jnz .loop
    mov rax, rdx ; remainder is in rax
    pop_registers   

.maybe_decrease_size:
    cmp r13, 0 ; check if it's first iteration of cycle
    je .decrease_size 
    jmp .after_decrease 

; rdi - pointer to bigint
; rsi - pointer to buffer
; rdx - limit of symbols, we mustn't write to buffer more symbols than limit
biToString:
    cmp rdi, 0
    jne .bigint_is_not_null
    ret ; if given in some function bigint is NULL then finish program
.bigint_is_not_null
    push_registers
    call biSign
    cmp rax, 0
    je .sign_not_interesting ; if zero then ignore sign
    mov r8, rdi ; i need to save rdi and work with it's copy because function changes bigint
    mov r13, rsi ; i need to save pointer to buffer because function boCopy changes it
    mov r12, rdx ; i need to save it because in biCopy i call memcpy
    call biCopy
    mov rdi, rax ; copyied bigint is in rdi now
    mov rsi, r13
    mov rdx, r12
    cmp rdx, 1 
    je .finish_write_to_string ; if we must print only 0
    mov cl, byte [rdi + sign]
    cmp cl, 1
    je .write_minus
    jmp .after_sign

.write_minus    
    mov byte [r13], '-'
    inc r13
    dec rdx

.after_sign:
    cmp rdx, 1
    je .finish_write_to_string
    mov r12, r13 ; position from which we need to reverse string
    mov rsi, 10 ; to call biDivInt
    .loop:
        mov r11, rdx
        call biDivInt
        add rax, '0'
        mov byte [r13], al
        inc r13
        call biSign
        cmp rax, 0 ; it means that our bigint is 0 and we must finish this cycle, because biSign returns 0 if and only if bigint == 0
        je .reverse_string
        mov rdx, r11 ; restore limit value
        dec rdx
        cmp rdx, 1
        je .limit_reached ; we can't print something because limit is reached
        jmp .loop ; rdi after the iteration = rdi before the iteration / 10, rdi before the iteration % 10 is written to string

; if limit is reached, we want to write the beginning of bigint, but if we don't do something special for this case, we will print the end of bigint
.limit_reached:
    mov r11, r12
    .divide:
        call biDivInt
        add rax, '0'
        mov byte [r11], al
        inc r11
        call biSign
        cmp rax, 0 ; it means that our bigint is 0 and we must finish this cycle, because biSign returns 0 if and only if bigint == 0
        je .double_reverse_string
        cmp r11, r13
        je .limit_reached ; if string is full again and we want to print the beginning of number we need just to start function again
        jmp .divide

; reverse string from position r12 to position r11 - 1 and from position r11 to position r13 - 1
.double_reverse_string:
    push rcx
    push rdx
    mov r10, r11
    dec r11
    .first_rev:
        cmp r12, r11
        jge .finish_first_reverse
        mov cl, byte [r12]
        mov dl, byte [r11]
        mov byte [r12], dl
        mov byte [r11], cl
        inc r12
        dec r11
        jmp .first_rev
    .finish_first_reverse:  
        mov r12, r10
        pop rdx
        pop rcx ; restore value of registers
        jmp .reverse_string

; reverse string from position r12 to position r13 - 1
.reverse_string:
    push rcx
    push rdx
    mov r10, r13
    dec r13 ; r13 is points to the last symbol
    .rev:
        cmp r12, r13
        jge .finish_last_reverse
        mov cl, byte [r12]
        mov dl, byte [r13]
        mov byte [r12], dl
        mov byte [r13], cl
        inc r12
        dec r13
        jmp .rev
    .finish_last_reverse:   
        mov r13, r10
        pop rdx
        pop rcx ; restore value of registers    
        jmp .finish_write_to_string

.finish_write_to_string:
    mov byte [r13], 0
    call biDelete ; delete copyied bigint, because it's not need now
    mov rdi, r8 ; restore value of bigint
    pop_registers

.sign_not_interesting:
    mov byte [rsi], '0'
    inc rsi
    mov byte [rsi], 0
    pop_registers    

;;;;;;;;;
biDivRem:
    ;not implemented
    ret         
    
