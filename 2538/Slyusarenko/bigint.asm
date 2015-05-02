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

%define arg1 rdi
%define arg2 rsi
%define arg3 rdx
%define arg4 rcx
%define result rax  ; Registers which are arguments and result for functions accordingly to System V calling convention

%macro function_start 0  ; Save register values which we must save accordingly to System V calling convention
	push rbp
	push rbx
	push r12
	push r13
	push r14
	push r15
%endmacro	

%macro function_end 0  ; Restore registers values
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	pop rbp
	ret
%endmacro	

%macro alloc_with_align 1  ; Allocates memory with align 16 bytes. Result of executing is in rax (previously defined result)
	push rbp
	push arg1
	push arg2
	mov rbp, rsp
	mov arg1, %1
	mov arg2, 8 ; qword = 8 bytes
	and rsp, ~15  ; align the stack
	call calloc
	test result, result
	jnz %%correct
	ret                    ; Can't allocate, finish program
%%correct:
	mov rsp, rbp
	pop arg2
	pop arg1
	pop rbp
%endmacro	

; arg1 before the macro is pointer on bigint, arg2 - bigint size
%macro check_need_to_expand 0
	push r14
	mov r14, [arg1 + bigint.capacity]
	cmp r14, arg2
	jge %%not_expand ; we don't need to expand if capacity >= size
	call expand_vector
%%not_expand:
	pop r14
%endmacro	

%macro check_null 0
	cmp arg1, 0
	jne %%bigint_is_not_null
	ret ; if given in some function bigint is NULL then finish program. Otherwise, do nothing
%%bigint_is_not_null
%endmacro		


struc bigint
	.sign:		resb 1 ; 0 if sign is '+' and 1 if sign is '-'
	.size:		resq 1
	.capacity:	resq 1
	.data:		resq 1 ; pointer to vector
endstruc	

; arg1 - pointer on bigint
; arg2 - size of bigint in qwords
; result - pointer on bigint
new_vector:
	function_start
	lea rdx, [arg2 * 2] ; initial capacity in qwords, capacity = 2 * size, because i don't want to do so much expands
	mov r13, rdx        ; save initial capacity in r13
	alloc_with_align rdx
	mov [arg1 + bigint.size], arg2
	mov [arg1 + bigint.capacity], r13
	mov [arg1 + bigint.data], result
	mov result, arg1
	function_end

; arg1 - pointer on bigint
; arg2 - size, new capacity must be greater or equal to this size 
expand_vector:	
	function_start
	push arg1
	mov r15, [arg1 + bigint.data]
	mov r14, [arg1 + bigint.size]
	call new_vector
	mov r13, rsp
	and rsp, ~15 ; align the stack
	mov arg1, [result + bigint.data] ; arg1 isn't arg1 from the beginning of the function, because we call new_vector and it changes arg1
	mov arg2, r15
	lea arg3, [r14 * 8] ; size of vector in bytes
	call memcpy ; copy data to new place in memory
	mov arg1, r15
	and rsp, ~15
	call free ; free memory where was data before the function
	mov rsp, r13
	pop arg1
	function_end

; Copy given bigint
; arg1 - pointer on bigint
; result - copyied bigint
biCopy:
	function_start
	mov r12, arg1
	alloc_with_align 4
	mov arg1, result
	mov r13, [r12 + bigint.size]
	mov arg2, r13
	call new_vector
	mov r14, result
	mov r15, rsp
	and rsp, ~15 ; align the stack
	mov arg1, [result + bigint.data]
	mov arg2, [r12 + bigint.data]
	lea arg3, [r13 * 8]
	call memcpy ; copy our bigint
	mov rsp, r15
	mov [r14 + bigint.size], r13
	mov bl, byte [r12 + bigint.sign]
	mov byte [r14 + bigint.sign], bl
	mov result, r14
	function_end	

; arg1 - long long int
; result - pointer on bigint
biFromInt:
	function_start
	mov r14, arg1 ; save argument, because we will be call functions at this function
	alloc_with_align 4  ; 25 bytes - size of bigint struct, allocate 32 bytes
	mov arg1, result
	mov arg2, 4
	call new_vector
	mov qword [result + bigint.size], 1 ; initial size is 1, because it's now only one int
	cmp r14, 0
	jge .positive_int
	mov byte [result + bigint.sign], 1 ; sign is '-' now
	neg r14  ; number in field .data will be positive
	jmp .finish
	.positive_int:
		mov byte [result + bigint.sign], 0 ; sign is '+' now
	.finish:
		mov r12, [result + bigint.data]
		mov [r12], r14 ; initialize data
		function_end

; arg1 - string
; result - pointer on bigint
biFromString:
	function_start
	mov r14, arg1  ; because we want to call other functions from this function and we will use arg1 to do this
	mov arg1, 0
	call biFromInt
	mov arg1, r14
	cmp byte [arg1], '-'
	je .set_minus_sign
	mov byte [result + bigint.sign], 0 ; sign '+'
	jmp .after_setting_sign

.after_setting_sign:
	mov arg1, result
	cmp byte [r14], 0
	je .wrong_string_format ; string is '-' or empty
	.skip_zeros:
		cmp byte [r14], '0'
		jne .skipped
		inc r14
		jmp .skip_zeros

.skipped:
	cmp byte [r14], 0
	je .empty_string ; string isn't actually empty, but it contains only '0' symbols, so returned bigint is like in case of empty string
	.get_bigint:
		xor rbx, rbx
		mov bl, byte [r14]
		cmp bl, '0'
		jl .wrong_string_format
		cmp bl, '9'
		jg .wrong_string_format
		sub rbx, '0'
		mov arg2, 10
		call biMulInt ; multiple current result (arg1) on 10 (arg2)
		mov arg2, rbx
		call biAddInt ; add current digit (arg2 = rbx) to current result (arg1). After this function, we have result after this cicle iteration
		inc r14 ; next symbol
		cmp byte [r14], 0
		jne .get_bigint
	mov result, arg1 ; because result is in arg1 after cicle
	function_end	

.set_minus_sign:
	mov byte [result + bigint.sign], 1 ; sign '-'
	inc r14 ; look on next symbol
	jmp .after_setting_sign

.empty_string:
	function_end

.wrong_string_format:
	call biDelete ; free memory which was allocated to this bigint
	xor result, result ; return NULL
	function_end		

biDelete:
	function_start
	mov r15, rsp
	and rsp, ~15
	mov r14, arg1
	mov arg1, [arg1 + bigint.data] ; free data
	call free
	mov arg1, r14 ; free struct
	and rsp, ~15
	call free
	mov rsp, r15
	function_end

; arg1 - pointer on bigint
; arg2 - long long int (it's positive because i use it in my code like positive)
; After the function arg1_after = arg1_start + arg2
biAddInt:
	function_start
	mov r14, [arg1 + bigint.size] ; maybe need to expand
	inc r14 ; after function size of vector <= size of vector before the function + 1
	push arg2
	mov arg2, r14
	check_need_to_expand
	dec r14
	pop arg2 ; restore value of arg2 after expand
	mov rbx, arg1
	mov arg1, [arg1 + bigint.data]
	xor rdx, rdx ; carry
	xor r13, r13
	.loop:
		add [arg1], arg2
		adc rdx, 0 ; carry is in rdx now
		mov arg2, rdx ; carry is in arg2 now
		xor rdx, rdx
		inc r13
		add arg1, 8
		cmp arg2, 0 ; if carry is 0 then finish cycle
		jne .loop
	cmp r13, r14
	jg .carry_after_last_iteration	
	.finish_loop:	
		mov arg1, rbx
		function_end	

	.carry_after_last_iteration:
		mov [arg1], rdx ; move carry to new qword
		mov arg1, rbx
		inc r14 ; increment size of vector in qwords
		mov [arg1 + bigint.size], r14	
		function_end

; arg1 - pointer on bigint
; arg2 - long long int (it's positive because i use it in my code like positive)
; After the function arg1_after = arg1_start * arg2
biMulInt:
	function_start
	mov r14, [arg1 + bigint.size]
	push r14 ; save value of r14 to stack because i change it in my function
	push arg1
	inc r14 ; after function size of vector <= size of vector before the function + 1
	push arg2
	mov arg2, r14
	check_need_to_expand
	dec r14
	pop arg2 ; restore value of arg2 after expand
	mov r13, [arg1 + bigint.data]
	xor r12, r12 ; information about carry is in r12
	.loop:
		mov rax, [r13]
		mul arg2 ; rax * arg2 = rdx:rax
		add rax, r12 ; carry from last cycle iteration
		adc rdx, 0 ; carry
		mov [r13], rax
		add r13, 8 ; next qword
		mov r12, rdx ; carry is in r12 now
		xor rdx, rdx
		dec r14
		jnz .loop	
	cmp r12, 0
	jne .carry_after_last_iteration	; it's enough because size of bigint can increased only by one qword
	pop arg1
	pop r14
	function_end	
	.carry_after_last_iteration:
		pop arg1
		pop r14 ; restore value of bigint size
		mov [r13], r12 ; move carry to new qword
		inc r14 ; increment size of vector in qwords
		mov [arg1 + bigint.size], r14
		mov r14, [arg1 + bigint.size]
		function_end

; arg1 - pointer on bigint
; arg2 - long long int (it's positive because i use it in my code like positive)
; After the function arg1_after = arg1_start / arg2, result = arg1_start % arg2
biDivInt:	
	function_start
	mov r14, [arg1 + bigint.size]
	mov r10, [arg1 + bigint.data]
	lea r10, [r10 + 8 * r14 - 8] ; most significant qword is in r10 now
	xor rdx, rdx
	xor r13, r13
	.loop:
		mov rax, [r10]
		div arg2 ; rax = rdx:rax / arg2, rdx = rdx:rax % arg2
		mov [r10], rax
		cmp rax, 0
		je .maybe_decrease_size ; need to decrease size if and only if rax == 0 and it's first iteration of cycle
		jmp .after_decrease
		.decrease_size:
			cmp qword [arg1 + bigint.size], 1 ; i don't want decrement size if it's 1, because i don't want to have size of bigint 0, because of some collisions
			je .after_decrease
			dec qword [arg1 + bigint.size]
		.after_decrease:
			inc r13
			sub r10, 8
			dec r14
			jnz .loop
	mov result, rdx ; remainder is in result
	function_end

.maybe_decrease_size:
	cmp r13, 0 ; check if it's first iteration of cycle
	je .decrease_size 
	jmp .after_decrease	

; arg1 - pointer on bigint
; arg2 - pointer on buffer
; arg3 - limit of symbols, we mustn't write to buffer more symbols than limit
biToString:
	check_null ; if pointer on bigint is null then i mustn't do something
	function_start
	call biSign
	cmp result, 0
	je .sign_not_interesting ; if bigint is zero then it can be "-0" and "+0", i must print "0"
	mov r8, arg1 ; i need to save arg1 and work with it's copy because function changes bigint
	mov r13, arg2 ; i need to save pointer on buffer because function boCopy changes it
	mov r12, arg3 ; i need to save it because in biCopy i call memcpy
	call biCopy
	mov arg1, result ; copyied bigint is in arg1 now
	mov arg2, r13 ; restore pointer on buffer
	mov arg3, r12 ; restore limit
	cmp arg3, 1 
	je .finish_write_to_string ; if we must print only 0
	mov cl, byte [arg1 + bigint.sign]
	cmp cl, 1
	je .write_minus
	jmp .after_sign

.write_minus	
	mov byte [r13], '-'
	inc r13
	dec arg3

.after_sign:
	cmp arg3, 1
	je .finish_write_to_string
	mov r12, r13 ; position from which we need to reverse string
	mov arg2, 10 ; to call biDivInt
	.loop:
		mov r11, arg3 ; save limit value
		call biDivInt
		add result, '0'
		mov byte [r13], al
		inc r13
		call biSign
		cmp result, 0 ; it means that our bigint is 0 and we must finish this cycle, because biSign returns 0 if and only if bigint == 0
		je .reverse_string
		mov arg3, r11 ; restore limit value
		dec arg3
		cmp arg3, 1
		je .limit_exhausted ; we can't print something because limit is exhausted
		jmp .loop ; arg1 after the iteration = arg1 before the iteration / 10, arg1 before the iteration % 10 is written to string

; if limit is exhausted, we want to write the beginning of bigint, but if we don't do something special for this case, we will print the end of bigint
.limit_exhausted:
	mov r11, r12
	.divide:
		call biDivInt
		add result, '0'
		mov byte [r11], al
		inc r11
		call biSign
		cmp result, 0 ; it means that our bigint is 0 and we must finish this cycle, because biSign returns 0 if and only if bigint == 0
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
	push rdx ; save value of registers to stack
	mov r10, r13 ; save position to write next symbol
	dec r13 ; r13 is pointed on the last symbol
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
	mov arg1, r8 ; restore value of bigint
	function_end

.sign_not_interesting:
	mov byte [arg2], '0'
	inc arg2
	mov byte [arg2], 0
	function_end	

; arg1 - pointer on bigint
; return -1 if arg1 < 0, 1 if arg1 > 0 and 0 if arg1 == 0
biSign:
	check_null
	function_start
	mov r14, qword [arg1 + bigint.size]
	cmp r14, 1 ; if size of bigint is 1 then bigint can be zero (or maybe not, need to think about it)
	je .maybe_return_zero
	mov bl, byte [arg1 + bigint.sign]
	cmp bl, 1
	je .return_minus_one
	mov result, 1
	function_end

.maybe_return_zero:
	mov r14, qword [arg1 + bigint.data]
	mov rax, [r14]
	cmp rax, 0
	je .return_zero
	mov bl, byte [arg1 + bigint.sign]
	cmp bl, 1
	je .return_minus_one
	mov result, 1
	function_end

.return_zero:
	xor result, result
	function_end		

.return_minus_one:
	mov result, -1
	function_end	

; arg1 - pointer on first bigint
; arg2 - pointer on second bigint	
; return -1 if arg1 < arg2, 0 if arg1 == arg2, 1 if arg1 > arg2
biCmp:	
	function_start
	call biSign
	mov r14, result ; information about sign of first bigint is in r14 now
	mov r13, arg1
	mov arg1, arg2
	call biSign
	mov r12, result ; information about sign of second bigint is in r12 now
	mov arg2, arg1
	mov arg1, r13 ; restore arg1 and arg2
	cmp r14, r12
	jg .return_one ; sign of first > sign of second => return 1
	jl .return_minus_one ; sign of first < sign of second => return -1
	cmp r14, 0
	je .return_zero ; first ans second bigint are 0
	cmp r14, -1
	je .sign_is_minus
	mov r11, [arg1 + bigint.size]
	mov r10, [arg2 + bigint.size]
	cmp r11, r10
	ja .return_one ; size of first bigint > size of second bigint and sign is '+' => return 1
	jb .return_minus_one ; size of first bigint < size of second bigint and sign is '+' => return -1	
	mov r10, [arg1 + bigint.data]
	mov r9, [arg2 + bigint.data]
	lea r10, [r10 + 8 * r11 - 8] ; most significant qword of arg1 is in r10 now
	lea r9, [r9 + 8 * r11 - 8] ; most significant qword of arg2 is in r9 now
	.loop_positive:
		mov rbx, [r10] ; current qword of arg1
		mov rcx, [r9] ; current qword of arg2
		cmp rbx, rcx
		ja .return_one ; jump above, because jump greater don't do that i want
		jb .return_minus_one ; jump below, because jump less greater don't do that i want
		sub r10, 8 ; to next qword
		sub r9, 8 ; to next qword
		dec r11
		jz .return_zero ; all qword are equal => bigints are equal
		jmp .loop_positive

.return_one:
	mov result, 1
	function_end	

.return_minus_one:
	mov result, -1
	function_end	

.return_zero:
	mov result, 0
	function_end	

.sign_is_minus:
	mov r11, [arg1 + bigint.size]
	mov r10, [arg1 + bigint.size]
	cmp r11, r10
	jg .return_minus_one ; size of first bigint > size of second bigint and sign is '-' => return -1
	jl .return_one ; size of first bigint < size of second bigint and sign is '-' => return 1	
	mov r10, [arg1 + bigint.data]
	mov r9, [arg2 + bigint.data]
	lea r10, [r10 + 8 * r11 - 8] ; most significant qword of arg1 is in r10 now
	lea r9, [r9 + 8 * r11 - 8] ; most significant qword of arg2 is in r9 now
	.loop:
		mov rbx, [r10] ; current qword of arg1
		mov rcx, [r9] ; current qword of arg2
		cmp rbx, rcx
		jg .return_minus_one
		jl .return_one
		sub r10, 8 ; to next qword
		sub r9, 8 ; to next qword
		dec r11
		jz .return_zero ; all qword are equal => bigints are equal
		jmp .loop

; arg1 - pointer on first bigint
; arg2 - pointer on second bigint
; After the function arg1_after = arg1_start + arg2
biAdd:
	function_start
	mov r15, [arg1 + bigint.size]
	mov r8, [arg2 + bigint.size]
	mov rbx, r15 ; maximal size of argument
	cmp r15, r8
	jl .arg2_size_greater

	.continue:
	inc rbx ; size of arg1 after the function <= max(size of arg1 before, size of arg2 before) + 1
	mov rcx, arg2 ; save value of arg2, because i check if need to expand that use arg2
	mov arg2, rbx
	check_need_to_expand
	mov arg2, rcx ; restore value of arg2
	mov cl, byte [arg1 + bigint.sign]
	mov bl, byte [arg2 + bigint.sign]
	mov r11, [arg1 + bigint.data]
	mov r10, [arg2 + bigint.data]
	cmp cl, bl ; if sign is equal then our operation is equal to add, else our operation is equal to sub
	je .equal_sign
	mov byte [arg2 + bigint.sign], cl ; add = change sign + sub
	call biSub
	mov byte [arg2 + bigint.sign], bl ; restore sign of arg2, function biSub don't change bl, because it saves rbx accordingly to calling convention
	function_end

.arg2_size_greater:
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
	cmp [arg1 + bigint.size], r12
	jge .not_incremented
	mov [arg1 + bigint.size], r12 ; move real size of vector of arg1 in qwords to size field
	function_end		

.not_incremented:
	function_end	

; arg1 - pointer on first bigint
; arg2 - pointer on second bigint
; After the function arg1_after = arg1_start - arg2
biSub:
	function_start
	push arg2 ; save value of arg2, because i mustn't change it in biSub
	mov cl, byte [arg1 + bigint.sign]
	mov bl, byte [arg2 + bigint.sign]
	cmp bl, cl
	je .equal_sign ; if sign is equal then do sub else change sign and do add
	mov byte [arg2 + bigint.sign], cl
	call biAdd
	mov byte [arg2 + bigint.sign], bl ; restore sign of arg2, function biAdd don't change bl, because it saves rbx accordingly to calling convention
	pop arg2 ; restore value of arg2 before function end
	function_end

.equal_sign:
	mov byte [arg1 + bigint.sign], 0
	mov byte [arg2 + bigint.sign], 0 ; change signs on positive, because i want to compare absolute values of bigints 
	push rcx ; save sign of arg2
	call biCmp
	mov r15, result ; save information if bigint was copyied
	pop rcx ; restore sign of arg2
	mov byte [arg2 + bigint.sign], cl ; restore sign of arg2
	cmp result, -1
	je .swap_args
	.after_swap:
		adc r13, 0 ; set to zero carry flag
		mov r13, [arg1 + bigint.data]
		mov r12, [arg2 + bigint.data]
		mov r11, [arg1 + bigint.size] ; loop can't have more than r11 iterations, because arg1 > arg2 and it won't be carry after r11 iterations
		mov rcx, [arg2 + bigint.size]
		.loop:
			mov r10, [r12]
			lea r12, [r12 + 8]
			sbb [r13], r10
			lea r13, [r13 + 8]
			dec rcx
			jz .only_carry ; second argument is finished, it's only carry now
			dec r11
			jnz .loop	

		.after_carry:	
			cmp r15, -1
			je .was_swap ; if it was swap then i must do some other things then if it wasn't swap
			jmp .change_size_of_arg1 ; if it wasn't swap then we must do nothing, but change size of arg1, because everything is already done

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
	sub cl, byte [arg1 + bigint.sign] ; must have other sign, because arguments were swapped
	mov byte [arg1 + bigint.sign], cl
	

.change_size_of_arg1:
	mov r12, [arg1 + bigint.data]
	mov r13, [arg1 + bigint.size]
	lea r12, [r12 + 8 * r13 - 8] ; while first qword of bigint is 0, decrement size
	.decrement_size_loop:
		mov r11, [r12]
		cmp r11, 0
		je .decrement_size

	.after_decrement_size:
		cmp r15, -1
		je .delete_was_swap ; delete copyied bigint if was swap and it's copy
		mov [arg1 + bigint.size], r13 ; set actual size
		pop arg2 ; restore value of arg2 before function_end
		function_end

	.delete_was_swap:
		pop rbx ; begin value of arg1 is in rbx now
		mov [rbx + bigint.size], r13 ; set actual size
		mov cl, byte [arg1 + bigint.sign]
		mov byte [rbx + bigint.sign], cl ; move all information from arg1 to rbx
		push arg1 ; save value arg1 to delete it after memcpy
		push r15
		mov r15, rsp
		and rsp, ~15 ; align the stack to call memcpy
		mov arg2, [arg1 + bigint.data]
		mov arg1, [rbx + bigint.data]
		lea arg3, [r13 * 8] ; arguments for memcpy
		call memcpy
		mov rsp, r15
		pop r15
		pop arg1
		call biDelete ; delete copy of bigint in function
		mov arg1, rbx
		pop arg2 ; restore value of arg2 before function_end
		function_end	

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
	push arg1 ; push arg1 to delete copy after function executing
	push arg1 ; save value of arg1 to stack, because i want to use arg1 in function biCopy
	mov arg1, arg2
	call biCopy
	mov arg1, result ; arg1 is now pointed on copyied bigint
	pop arg2 ; restore value of arg1, it's now written to arg2 (it means that swap is already done)
	jmp .after_swap

; arg1 - pointer on first bigint
; arg2 - pointer on second bigint
; After the function arg1_after = arg1_start * arg2
biMul:
	function_start
	mov al, byte [arg1 + bigint.sign]
	mov bl, byte [arg2 + bigint.sign]
	cmp al, bl
	je .set_plus_sign ; if signs are equal then result sign is '+', else result sign is '-'
	mov byte [arg1 + bigint.sign], 1
	.after_setting_sign:
		mov r15, qword [arg1 + bigint.size]
		push r15 ; save size of arg1 to stack, because this size can be changed by expand_vector, but this size is interesting for the function
		mov r14, qword [arg2 + bigint.size]
		add r15, r14 ; size of result <= size of arg1 + size of arg2
		push arg2 ; save value of arg2 to stack, because some next opertions needs another arg2
		mov arg2, r15
		check_need_to_expand
		mov r13, arg1 ; save value of arg1, because i want to call function biFromInt with diffetent arg1
		mov arg1, 0
		call biFromInt
		mov arg1, r13 ; restore value of arg1
		mov r13, result ; r13 is a pointer on new bigint now
		push arg1
		mov arg1, r13
		mov arg2, r15
		check_need_to_expand
		pop arg1 ; restore value of arg1 and arg2
		pop arg2
		pop r15 ; restore size of arg1
		mov r14, [arg2 + bigint.size] ; size of arg2 is in r14 now
		xor r12, r12 ; i
		mov r10, [r13 + bigint.data]
		mov r9, [arg1 + bigint.data]
		mov r8, [arg2 + bigint.data]
		push arg2 ; save value of arg2 to stack, because i want to use rsi in cycle
		push r13 ; save value of bigint3 to stack, because i want to use r13 in cycle
		.first_for:
			xor r11, r11 ; j
			xor rsi, rsi ; carry
			lea rcx, [r9 + r12 * 8]
			mov rcx, [rcx] ; bigint1[i]
			.second_for:
				cmp r11, r14
				je .set_zero_to_rbx ; rbx = (j < bigint2.size ? bigint2[j] : 0)
				lea rbx, [r8 + r11 * 8]
				mov rbx, [rbx] ; bigint2[j]
				.continue_second_for:
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
					jge .maybe_finish_second_for ; bigint2 finished, finish second cycle if no carry
					jmp .second_for
			.after_second_for:
				inc r12
				cmp r12, r15
				jl .first_for

		pop r13 ; restore pointer on bigint3
		pop arg2 ; restore value of arg2
		mov r14, [r13 + bigint.capacity] ; register to get real size of bigint3
		lea r10, [r10 + r14 * 8 - 8]
		.get_real_size:
			cmp qword [r10], 0
			jne .got_size
			dec r14
			sub r10, 8
			jmp .get_real_size

		.got_size:	
			mov [arg1 + bigint.size], r14 ; set real size to size of arg1
			push arg1
			push arg2 ; save values of arg1 and arg2, because i want to use memcpy which requiers arg1 and arg2
			mov r15, rsp
			and rsp, ~15
			mov arg1, [arg1 + bigint.data]
			mov arg2, [r13 + bigint.data]
			lea arg3, [r14 * 8]
			call memcpy ; copy resulted bigint to arg1
			mov rsp, r15
			mov arg1, r13
			call biDelete ; delete temporary bigint3
			pop arg2
			pop arg1 ; restore values of arg1 and arg2
			function_end


.maybe_finish_second_for:
	cmp  rsi, 0
	je .after_second_for
	jmp .second_for

.set_zero_to_rbx:
	xor rbx, rbx
	jmp .continue_second_for

.set_plus_sign:
	mov byte [arg1 + bigint.sign], 0
	jmp .after_setting_sign

biDivRem:
	ret			
	