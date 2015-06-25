default rel

extern malloc
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

%define argument1 rdi
%define argument2 rsi
%define argument3 rdx
%define argument4 rcx
%define res rax  ; Registers which are arguments and result for functions accordingly to System V calling convention

; argument1 before the macro is pointer on bigint, argument2 - bigint size
%macro flag_expand 0
   push r14
   mov r14, [argument1 + bigint.capacity]
   cmp r14, argument2
   jge %%not_expand ; we don't need to expand if capacity >= size
   call vec_expand
%%not_expand:
   pop r14
%endmacro

%macro nullchecker 0
   cmp argument1, 0
   jne %%bigint_is_not_zero
   ret ; if given in some function bigint is NULL then finish program. Otherwise, do nothing
%%bigint_is_not_zero
%endmacro

%macro end_funct 0  ; Restore registers values
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	pop rbp
	ret
%endmacro

%macro start_funct 0  ; Save register values which we must save accordingly to System V calling convention
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
%endmacro

%macro allocate_align 1  ; Allocates memory with align 16 bytes. Result of executing is in rax (previously defined result)
	push rbp
	push argument1
	push argument2
	mov rbp, rsp
	mov argument1, %1
	mov argument2, 8 ; qword = 8 bytes
	and rsp, ~15  ; align the stack
	call calloc
	test res, res
	jnz %%right
	ret                    ; Can't allocate, finish program
%%right:
	mov rsp, rbp
	pop argument2
	pop argument1
	pop rbp
%endmacro

struc bigint
	.flag:		resb 1 ; 0 if flag is '+' and 1 if flag is '-'
	.size:		resq 1
	.capacity:	resq 1
	.data:		resq 1 ; pointer to vector
endstruc	

; argument1 - pointer on bigint, argument2 - size of bigint in qwords,res - pointer on bigint
new_vec:
	start_funct
	lea rdx, [argument2 * 2] ; initial capacity in qwords, capacity = 2 * size
	mov r13, rdx        ; save initial capacity in r13
	allocate_align rdx
	mov [argument1 + bigint.size], argument2
	mov [argument1 + bigint.capacity], r13
	mov [argument1 + bigint.data], res
	mov res, argument1
	end_funct

; Copy given bigint,argument1 - pointer on bigint,res - copyied bigint
bigint_Copy:
    start_funct
    mov r12, argument1
    allocate_align 4
    mov argument1, res
    mov r13, [r12 + bigint.size]
    mov argument2, r13
    call new_vec
    mov r14, res
    mov r15, rsp
    and rsp, ~15 ; align the stack
    mov argument1, [res + bigint.data]
    mov argument2, [r12 + bigint.data]
    lea argument3, [r13 * 8]
    call memcpy ; copy our bigint
    mov rsp, r15
    mov [r14 + bigint.size], r13
    mov bl, byte [r12 + bigint.flag]
    mov byte [r14 + bigint.flag], bl
    mov res, r14
    end_funct

; argument1 - pointer on bigint,argument2 - size, new capacity must be greater or equal to this size
vec_expand:
	start_funct
	push argument1
	mov r15, [argument1 + bigint.data]
	mov r14, [argument1 + bigint.size]
	call new_vec
	mov r13, rsp
	and rsp, ~15 ; align the stack
	mov argument1, [res + bigint.data] ; argument1 isn't argument1 from the beginning of the function, because we call new_vec and it changes argument1
	mov argument2, r15
	lea argument3, [r14 * 8] ; size of vector in bytes
	call memcpy ; copy data to new place in memory
	mov argument1, r15
	and rsp, ~15
	call free ; free memory where was data before the function
	mov rsp, r13
	pop argument1
	end_funct

; argument1 - long long int,res - pointer on bigint
biFromInt:
	start_funct
	mov r14, argument1 ; save argument, because we will be call functions at this function
	allocate_align 4  ; 25 bytes - size of bigint struct, allocate 32 bytes
	mov argument1, res
	mov argument2, 4
	call new_vec
	mov qword [res + bigint.size], 1 ; initial size is 1, because it's now only one int
	cmp r14, 0
	jge .posit_int
	mov byte [res + bigint.flag], 1 ; flag is '-' now
	neg r14  ; number in field .data will be positive
	jmp .exit
.posit_int:
    mov byte [res + bigint.flag], 0 ; flag is '+' now
.exit:
    mov r12, [res + bigint.data]
    mov [r12], r14 ; initialize data
    end_funct

; argument1 - string, res - pointer on bigint
biFromString:
	start_funct
	mov r14, argument1  ; because we want to call other functions from this function and we will use argument1 to do this
	mov argument1, 0
	call biFromInt
	mov argument1, r14
	cmp byte [argument1], '-'
	je .set_minus_flag
	mov byte [res + bigint.flag], 0 ; flag '+'
	jmp .after_set_flag
.after_set_flag:
	mov argument1, res
	cmp byte [r14], 0
	je .not_correct_string_format ; string is '-' or empty
.skip_nulls:
    cmp byte [r14], '0'
    jne .jumping_over
    inc r14
    jmp .skip_nulls
.set_minus_flag:
    mov byte [res + bigint.flag], 1 ; flag '-'
    inc r14 ; look on next symbol
    jmp .after_set_flag
.jumping_over:
	cmp byte [r14], 0
	je .bare_string ; string isn't actually empty, but it contains only '0' symbols, so returned bigint is like in case of empty string
.take_bigint:
    xor rbx, rbx
    mov bl, byte [r14]
    cmp bl, '0'
    jl .not_correct_string_format
    cmp bl, '9'
    jg .not_correct_string_format
    sub rbx, '0'
    mov argument2, 10
    call biMulInt ; multiple current res (argument1) on 10 (argument2)
    mov argument2, rbx
    call biAddInt ; add current digit (argument2 = rbx) to current result (argument1). After this function, we have result after this cicle iteration
    inc r14 ; next symbol
    cmp byte [r14], 0
    jne .take_bigint
	mov res, argument1 ; because result is in argument1 after cicle
	end_funct
.not_correct_string_format:
    call biDelete ; free memory which was allocated to this bigint
    xor res, res ; return NULL
    end_funct
.bare_string:
	end_funct

; argument1 - pointer on bigint,argument2 - long long int (it's positive because i use it in my code like positive). After the function argument1_after = argument1_start + argument2
biAddInt:
	start_funct
	mov r14, [argument1 + bigint.size] ; maybe need to expand
	inc r14 ; after function size of vector <= size of vector before the function + 1
	push argument2
	mov argument2, r14
	flag_expand
	dec r14
	pop argument2 ; restore value of argument2 after expand
	mov rbx, argument1
	mov argument1, [argument1 + bigint.data]
	xor rdx, rdx ; carry
	xor r13, r13
.jump:
    add [argument1], argument2
    adc rdx, 0 ; carry is in rdx now
    mov argument2, rdx ; carry is in argument2 now
    xor rdx, rdx
    inc r13
    add argument1, 8
    cmp argument2, 0 ; if carry is 0 then finish cycle
    jne .jump
    cmp r13, r14
    jg .carry_iteration_last
.finish_jump:
    mov argument1, rbx
    end_funct
.carry_iteration_last:
    mov [argument1], rdx ; move carry to new qword
    mov argument1, rbx
    inc r14 ; increment size of vector in qwords
    mov [argument1 + bigint.size], r14
    end_funct

; argument1 - pointer on bigint,argument2 - long long int (it's positive because i use it in my code like positive). After the function argument1_after = argument1_start * argument2
biMulInt:
	start_funct
	mov r14, [argument1 + bigint.size]
	push r14 ; save value of r14 to stack because i change it in my function
	push argument1
	inc r14 ; after function size of vector <= size of vector before the function + 1
	push argument2
	mov argument2, r14
	flag_expand
	dec r14
	pop argument2 ; restore value of argument2 after expand
	mov r13, [argument1 + bigint.data]
	xor r12, r12 ; information about carry is in r12
.jump:
    mov rax, [r13]
    mul argument2 ; rax * argument2 = rdx:rax
    add rax, r12 ; carry from last cycle iteration
    adc rdx, 0 ; carry
    mov [r13], rax
    add r13, 8 ; next qword
    mov r12, rdx ; carry is in r12 now
    xor rdx, rdx
    dec r14
    jnz .jump
	cmp r12, 0
	jne .carry_iteration_last	; it's enough because size of bigint can increased only by one qword
	pop argument1
	pop r14
	end_funct	
.carry_iteration_last:
    pop argument1
    pop r14 ; restore value of bigint size
    mov [r13], r12 ; move carry to new qword
    inc r14 ; increment size of vector in qwords
    mov [argument1 + bigint.size], r14
    mov r14, [argument1 + bigint.size]
    end_funct

; argument1 - pointer on bigint,return -1 if argument1 < 0, 1 if argument1 > 0 and 0 if argument1 == 0
biSign:
	nullchecker
	start_funct
	mov r14, qword [argument1 + bigint.size]
	cmp r14, 1 ; if size of bigint is 1 then bigint can be zero (or maybe not, need to think about it)
	je .flag_to_return_zero
	mov bl, byte [argument1 + bigint.flag]
	cmp bl, 1
	je .return_minus_one
	mov res, 1
	end_funct

.flag_to_return_zero:
	mov r14, qword [argument1 + bigint.data]
	mov rax, [r14]
	cmp rax, 0
	je .return_zero
	mov bl, byte [argument1 + bigint.flag]
	cmp bl, 1
	je .return_minus_one
	mov res, 1
	end_funct

.return_zero:
	xor res, res
	end_funct		

.return_minus_one:
	mov res, -1
	end_funct	

; argument1 - pointer on first bigint
; argument2 - pointer on second bigint	
; return -1 if argument1 < argument2, 0 if argument1 == argument2, 1 if argument1 > argument2
biCmp:	
	start_funct
	call biSign
	mov r14, res ; information about sign of first bigint is in r14 now
	mov r13, argument1
	mov argument1, argument2
	call biSign
	mov r12, res ; information about sign of second bigint is in r12 now
	mov argument2, argument1
	mov argument1, r13 ; restore argument1 and argument2
	cmp r14, r12
	jg .return_one ; sign of first > sign of second => return 1
	jl .return_minus_one ; sign of first < sign of second => return -1
	cmp r14, 0
	je .return_zero ; first ans second bigint are 0
	cmp r14, -1
	je .flag_is_minus
	mov r11, [argument1 + bigint.size]
	mov r10, [argument2 + bigint.size]
	cmp r11, r10
	ja .return_one ; size of first bigint > size of second bigint and sign is '+' => return 1
	jb .return_minus_one ; size of first bigint < size of second bigint and sign is '+' => return -1	
	mov r10, [argument1 + bigint.data]
	mov r9, [argument2 + bigint.data]
	lea r10, [r10 + 8 * r11 - 8] ; most significant qword of argument1 is in r10 now
	lea r9, [r9 + 8 * r11 - 8] ; most significant qword of argument2 is in r9 now
.jump_posit:
    mov rbx, [r10] ; current qword of argument1
    mov rcx, [r9] ; current qword of argument2
    cmp rbx, rcx
    ja .return_one ; jump above, because jump greater don't do that i want
    jb .return_minus_one ; jump below, because jump less greater don't do that i want
    sub r10, 8 ; to next qword
    sub r9, 8 ; to next qword
    dec r11
    jz .return_zero ; all qword are equal => bigints are equal
    jmp .jump_posit
.return_one:
	mov res, 1
	end_funct
.return_minus_one:
	mov res, -1
	end_funct
.return_zero:
	mov res, 0
	end_funct
.flag_is_minus:
	mov r11, [argument1 + bigint.size]
	mov r10, [argument1 + bigint.size]
	cmp r11, r10
	jg .return_minus_one ; size of first bigint > size of second bigint and sign is '-' => return -1
	jl .return_one ; size of first bigint < size of second bigint and sign is '-' => return 1	
	mov r10, [argument1 + bigint.data]
	mov r9, [argument2 + bigint.data]
	lea r10, [r10 + 8 * r11 - 8] ; most significant qword of argument1 is in r10 now
	lea r9, [r9 + 8 * r11 - 8] ; most significant qword of argument2 is in r9 now
.jump:
    mov rbx, [r10] ; current qword of argument1
    mov rcx, [r9] ; current qword of argument2
    cmp rbx, rcx
    jg .return_minus_one
    jl .return_one
    sub r10, 8 ; to next qword
    sub r9, 8 ; to next qword
    dec r11
    jz .return_zero ; all qword are equal => bigints are equal
    jmp .jump

; argument1 - pointer on first bigint,argument2 - pointer on second bigint.After the function argument1_after = argument1_start + argument2
biAdd:
	start_funct
	mov r15, [argument1 + bigint.size]
	mov r8, [argument2 + bigint.size]
	mov rbx, r15 ; maximal size of argument
	cmp r15, r8
	jl .argument2_size_greater
.going_on:
	inc rbx ; size of argument1 after the function <= max(size of argument1 before, size of argument2 before) + 1
	mov rcx, argument2 ; save value of argument2, because i check if need to expand that use argument2
	mov argument2, rbx
	flag_expand
	mov argument2, rcx ; restore value of argument2
	mov cl, byte [argument1 + bigint.flag]
	mov bl, byte [argument2 + bigint.flag]
	mov r11, [argument1 + bigint.data]
	mov r10, [argument2 + bigint.data]
	cmp cl, bl ; if sign is equal then our operation is equal to add, else our operation is equal to sub
	je .flag_equal
	mov byte [argument2 + bigint.flag], cl ; add = change flag + sub
	call biSub
	mov byte [argument2 + bigint.flag], bl ; restore flag of argument2, function biSub don't change bl, because it saves rbx accordingly to calling convention
	end_funct
.argument2_size_greater:
	mov rbx, r15
	jmp .going_on
.flag_equal:	
	xor r12, r12 ; current size of vector in qwords
.jump:
    mov r9, [r10]
    lea r10, [r10 + 8]
    adc [r11], r9
    lea r11, [r11 + 8]
    inc r12
    dec r8 ; finish our jump if it's no more to add (no carry and second bigint is finished)
    jz .only_bear ; second bigint is finished, maybe it's carry
    jmp .jump
.only_bear:
	jnc .finish_jump ; no carry
.bear_jump:
    mov rbx, [r11]
    adc rbx, 0
    mov [r11], rbx
    inc r12
    lea r11, [r11 + 8]
    jc .bear_jump
.finish_jump:
	cmp [argument1 + bigint.size], r12
	jge .not_incremented
	mov [argument1 + bigint.size], r12 ; move real size of vector of argument1 in qwords to size field
	end_funct
.not_incremented:
	end_funct	

; argument1 - pointer on first bigint,argument2 - pointer on second bigint.After the function argument1_after = argument1_start - argument2
biSub:
	start_funct
	push argument2 ; save value of argument2, because i mustn't change it in biSub
	mov cl, byte [argument1 + bigint.flag]
	mov bl, byte [argument2 + bigint.flag]
	cmp bl, cl
	je .flag_equal ; if flag is equal then do sub else change flag and do add
	mov byte [argument2 + bigint.flag], cl
	call biAdd
	mov byte [argument2 + bigint.flag], bl ; restore flag of argument2, function biAdd don't change bl, because it saves rbx accordingly to calling convention
	pop argument2 ; restore value of argument2 before function end
	end_funct
.flag_equal:
	mov byte [argument1 + bigint.flag], 0
	mov byte [argument2 + bigint.flag], 0 ; change flags on positive, because i want to compare absolute values of bigints 
	push rcx ; save flag of argument2
	call biCmp
	mov r15, res ; save information if bigint was copyied
	pop rcx ; restore flag of argument2
	mov byte [argument2 + bigint.flag], cl ; restore flag of argument2
	cmp res, -1
	je .arguments_swap
.after_swap:
    adc r13, 0 ; set to zero carry flag
    mov r13, [argument1 + bigint.data]
    mov r12, [argument2 + bigint.data]
    mov r11, [argument1 + bigint.size] ; jump can't have more than r11 iterations, because argument1 > argument2 and it won't be carry after r11 iterations
    mov rcx, [argument2 + bigint.size]
.jump:
    mov r10, [r12]
    lea r12, [r12 + 8]
    sbb [r13], r10
    lea r13, [r13 + 8]
    dec rcx
    jz .only_bear ; second argument is finished, it's only carry now
    dec r11
    jnz .jump
.after_bear:
    cmp r15, -1
    je .was_swapped ; if it was swapped then i must do some other things then if it wasn't swap
    jmp .change_size_argument1 ; if it wasn't swap then we must do nothing, but change size of argument1, because everything is already done
.arguments_swap:
    push argument1 ; push argument1 to delete copy after function executing
    push argument1 ; save value of argument1 to stack, because i want to use argument1 in function bigint_Copy
    mov argument1, argument2
    call bigint_Copy
    mov argument1, res ; argument1 is now pointed on copyied bigint
    pop argument2 ; restore value of argument1, it's now written to argument2 (it means that swap is already done)
    jmp .after_swap
.only_bear:
	jnc .after_bear ; no carry
	dec r11 ; from the last iteration of jump
	jz .after_bear
.bear_jump:
    mov rcx, 0
    adc rcx, 0 ; carry
    sbb [r13], rcx
    lea r13, [r13 + 8]
    dec r11
    jz .after_bear
    jmp .bear_jump
.was_swapped:
	mov cl, 1
	sub cl, byte [argument1 + bigint.flag] ; must have other flag, because arguments were swapped
	mov byte [argument1 + bigint.flag], cl
.change_size_argument1:
	mov r12, [argument1 + bigint.data]
	mov r13, [argument1 + bigint.size]
	lea r12, [r12 + 8 * r13 - 8] ; while first qword of bigint is 0, decrement size
.decrement_size_jump:
    mov r11, [r12]
    cmp r11, 0
    je .decrement_size
.after_decrement_size:
    cmp r15, -1
    je .delete_was_swapped ; delete copyied bigint if was swappped and it's copy
    mov [argument1 + bigint.size], r13 ; set actual size
    pop argument2 ; restore value of argument2 before end_funct
    end_funct
.delete_was_swapped:
    pop rbx ; begin value of argument1 is in rbx now
    mov [rbx + bigint.size], r13 ; set actual size
    mov cl, byte [argument1 + bigint.flag]
    mov byte [rbx + bigint.flag], cl ; move all information from argument1 to rbx
    push argument1 ; save value argument1 to delete it after memcpy
    push r15
    mov r15, rsp
    and rsp, ~15 ; align the stack to call memcpy
    mov argument2, [argument1 + bigint.data]
    mov argument1, [rbx + bigint.data]
    lea argument3, [r13 * 8] ; arguments for memcpy
    call memcpy
    mov rsp, r15
    pop r15
    pop argument1
    call biDelete ; delete copy of bigint in function
    mov argument1, rbx
    pop argument2 ; restore value of argument2 before end_funct
    end_funct
.decrement_size:
	sub r12, 8
	dec r13
	cmp r13, 0
	je .increment_size ; if res bigint is 0 then r13 will be 0 at the end of cycle, but i don't want size of bigint 0 because of some collisions
	jmp .decrement_size_jump
.increment_size: 
	inc r13 ; we are here only if res of function biSub is 0. And we must increment it, because size of bigint mustn't be 0, because of some collisions
	jmp .after_decrement_size

; argument1 - pointer on first bigint
; argument2 - pointer on second bigint
; After the function argument1_after = argument1_start * argument2
biMul:
	start_funct
	mov al, byte [argument1 + bigint.flag]
	mov bl, byte [argument2 + bigint.flag]
	cmp al, bl
	je .set_plus_flag ; if flags are equal then result flag is '+', else result flag is '-'
	mov byte [argument1 + bigint.flag], 1
.after_set_flag:
    mov r15, qword [argument1 + bigint.size]
    push r15 ; save size of argument1 to stack, because this size can be changed by vec_expand, but this size is interesting for the function
    mov r14, qword [argument2 + bigint.size]
    add r15, r14 ; size of result <= size of argument1 + size of argument2
    push argument2 ; save value of argument2 to stack, because some next opertions needs another argument2
    mov argument2, r15
    flag_expand
    mov r13, argument1 ; save value of argument1, because i want to call function biFromInt with diffetent argument1
    mov argument1, 0
    call biFromInt
    mov argument1, r13 ; restore value of argument1
    mov r13, res ; r13 is a pointer on new bigint now
    push argument1
    mov argument1, r13
    mov argument2, r15
    flag_expand
    pop argument1 ; restore value of argument1 and argument2
    pop argument2
    pop r15 ; restore size of argument1
    mov r14, [argument2 + bigint.size] ; size of argument2 is in r14 now
    xor r12, r12 ; i
    mov r10, [r13 + bigint.data]
    mov r9, [argument1 + bigint.data]
    mov r8, [argument2 + bigint.data]
    push argument2 ; save value of argument2 to stack, because i want to use rsi in cycle
    push r13 ; save value of bigint3 to stack, because i want to use r13 in cycle
.first_for:
    xor r11, r11 ; j
    xor rsi, rsi ; carry
    lea rcx, [r9 + r12 * 8]
    mov rcx, [rcx] ; bigint1[i]
.second_for:
    cmp r11, r14
    je .set_null_to_rbx ; rbx = (j < bigint2.size ? bigint2[j] : 0)
    lea rbx, [r8 + r11 * 8]
    mov rbx, [rbx] ; bigint2[j]
.going_on_second_for:
    mov rax, rcx
    mul rbx ; bigint1[i] * (j < bigint2.size ? bigint2[j] : 0)
    lea r13, [r10 + r12 * 8]
    lea r13, [r13 + r11 * 8] ; r13 = pointer on bigint3[i + j]
    add rax, [r13]
    adc rdx, 0 ; carry
    add rax, rsi ; add carry from last iteration
    adc rdx, 0
    mov rsi, rdx ; save carry from this iteration
    mov [r13], rax
    inc r11
    cmp r11, r14
    jge .flag_to_finish_second_for ; bigint2 finished, finish second cycle if no carry
    jmp .second_for
.after_second_for:
    inc r12
    cmp r12, r15
    jl .first_for
    pop r13 ; restore pointer on bigint3
    pop argument2 ; restore value of argument2
    mov r14, [r13 + bigint.capacity] ; register to get real size of bigint3
    lea r10, [r10 + r14 * 8 - 8]
.get_real_size:
    cmp qword [r10], 0
    jne .get_size
    dec r14
    sub r10, 8
    jmp .get_real_size
.get_size:
    mov [argument1 + bigint.size], r14 ; set real size to size of argument1
    push argument1
    push argument2 ; save values of argument1 and argument2, because i want to use memcpy which requiers argument1 and argument2
    mov r15, rsp
    and rsp, ~15
    mov argument1, [argument1 + bigint.data]
    mov argument2, [r13 + bigint.data]
    lea argument3, [r14 * 8]
    call memcpy ; copy resulted bigint to argument1
    mov rsp, r15
    mov argument1, r13
    call biDelete ; delete temporary bigint3
    pop argument2
    pop argument1 ; restore values of argument1 and argument2
    end_funct
.flag_to_finish_second_for:
	cmp  rsi, 0
	je .after_second_for
	jmp .second_for
.set_null_to_rbx:
	xor rbx, rbx
	jmp .going_on_second_for
.set_plus_flag:
    mov byte [argument1 + bigint.flag], 0
    jmp .after_set_flag

biDelete:
    start_funct
    mov r15, rsp
    and rsp, ~15
    mov r14, argument1
    mov argument1, [argument1 + bigint.data] ; free data
    call free
    mov argument1, r14 ; free struct
    and rsp, ~15
    call free
    mov rsp, r15
    end_funct

; argument1 - pointer on bigint,argument2 - long long int (it's positive because i use it in my code like positive).After the function argument1_after = argument1_start / argument2, res = argument1_start % argument2
biDivInt:
    start_funct
    mov r14, [argument1 + bigint.size]
    mov r10, [argument1 + bigint.data]
    lea r10, [r10 + 8 * r14 - 8] ; most significant qword is in r10 now
    xor rdx, rdx
    xor r13, r13
.jump:
    mov rax, [r10]
    div argument2 ; rax = rdx:rax / argument2, rdx = rdx:rax % argument2
    mov [r10], rax
    cmp rax, 0
    je .flag_to_reduct_size ; need to decrease size if and only if rax == 0 and it's first iteration of cycle
    jmp .after_reduction
.reduction_size:
    cmp qword [argument1 + bigint.size], 1 ; i don't want decrement size if it's 1
    je .after_reduction
    dec qword [argument1 + bigint.size]
.after_reduction:
    inc r13
    sub r10, 8
    dec r14
    jnz .jump
    mov res, rdx ; remainder is in res
    end_funct
.flag_to_reduct_size:
    cmp r13, 0 ; check if it's first iteration of cycle
    je .reduction_size
    jmp .after_reduction

; argument1 - pointer on bigint,argument2 - pointer on buffer,argument3 - limit of symbols, we mustn't write to buffer more symbols than limit
biToString:
    nullchecker ; if pointer on bigint is null then i mustn't do something
    start_funct
    call biSign
    cmp res, 0
    je .flag_not_interesting ; if bigint is zero then it can be "-0" and "+0", i must print "0"
    mov r8, argument1 ; i need to save argument1 and work with it's copy because function changes bigint
    mov r13, argument2 ; i need to save pointer on buffer because function boCopy changes it
    mov r12, argument3 ; i need to save it because in bigint_Copy i call memcpy
    call bigint_Copy
    mov argument1, res ; copyied bigint is in argument1 now
    mov argument2, r13 ; restore pointer on buffer
    mov argument3, r12 ; restore limit
    cmp argument3, 1
    je .finish_write_to_string ; if we must print only 0
    mov cl, byte [argument1 + bigint.flag]
    cmp cl, 1
    je .write_minus
    jmp .after_flag
.finish_write_to_string:
    mov byte [r13], 0
    call biDelete ; delete copyied bigint, because it's not need now
    mov argument1, r8 ; restore value of bigint
    end_funct
.flag_not_interesting:
    mov byte [argument2], '0'
    inc argument2
    mov byte [argument2], 0
    end_funct
.write_minus
    mov byte [r13], '-'
    inc r13
    dec argument3
.after_flag:
    cmp argument3, 1
    je .finish_write_to_string
    mov r12, r13 ; position from which we need to reverse string
    mov argument2, 10 ; to call biDivInt
.jump:
    mov r11, argument3 ; save limit value
    call biDivInt
    add res, '0'
    mov byte [r13], al
    inc r13
    call biSign
    cmp res, 0 ; it means that our bigint is 0 and we must finish this cycle, because biSign returns 0 if and only if bigint == 0
    je .reverse_string
    mov argument3, r11 ; restore limit value
    dec argument3
    cmp argument3, 1
    je .limit_exhausted ; we can't print something because limit is exhausted
    jmp .jump ; argument1 after the iteration = argument1 before the iteration / 10, argument1 before the iteration % 10 is written to string
; reverse string from position r12 to position r13 - 1
.reverse_string:
    push rcx
    push rdx ; save value of registers to stack
    mov r10, r13 ; save position to write next symbol
    dec r13 ; r13 is pointed on the last symbol
.reverse:
    cmp r12, r13
    jge .finish_last_reverse
    mov cl, byte [r12]
    mov dl, byte [r13]
    mov byte [r12], dl
    mov byte [r13], cl
    inc r12
    dec r13
    jmp .reverse
.finish_last_reverse:
    mov r13, r10
    pop rdx
    pop rcx ; restore value of registers
    jmp .finish_write_to_string
; if limit is exhausted, we want to write the beginning of bigint, but if we don't do something special for this case, we will print the end of bigint
.limit_exhausted:
    mov r11, r12
.divide:
    call biDivInt
    add res, '0'
    mov byte [r11], al
    inc r11
    call biSign
    cmp res, 0 ; it means that our bigint is 0 and we must finish this cycle, because biSign returns 0 if and only if bigint == 0
    je .double_reverse_string
    cmp r11, r13
    je .limit_exhausted ; if string is full again and we want to print the beginning of number we need just to start function again
    jmp .divide
; reverse string from position r12 to position r11 - 1 and from position r11 to position r13 - 1
.double_reverse_string:
    push rcx
    push rdx ; save value of registers to stack
    mov r10, r11 ; save position to begin second reverse
    dec r11
.first_reverse:
    cmp r12, r11
    jge .finish_first_reverse
    mov cl, byte [r12]
    mov dl, byte [r11]
    mov byte [r12], dl
    mov byte [r11], cl
    inc r12
    dec r11
    jmp .first_reverse
.finish_first_reverse:
    mov r12, r10
    pop rdx
    pop rcx ; restore value of registers
    jmp .reverse_string

; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
; *quotient in rdi
; *remainder in rsi
; numerator in rdx
; denominator in rcx
; division of n-bit BigInt on m-bit BigInt works in n^2 / 64 operations.
biDivRem: ; it has not done yet
    ret
