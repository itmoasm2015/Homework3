Default rel
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

;; also in System V r8 and r9 is args but there is no functions taking so much arguments
%define Arg1 rdi
%define Arg2 rsi
%define Arg3 rdx
%define Arg4 rcx
%define Res rax
	
	;; System V callee saved registers
%macro begin 0			
	push rbp
	push rbx
	push r12
	push r13
	push r14
	push r15
%endmacro

%macro end 0
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	pop rbp
	ret
%endmacro

	;; allocates %1 qwords aligned on 16 bytes
	;; result in Res
%macro alloc16 1
	push rbp
	push Arg1
	push Arg2
	mov rbp, rsp
	mov Arg1, %1
	mov Arg2, 8	;qword in bytes
	and rsp, ~15	; align the stack (substracts 0 or 8 bytes)
	call calloc
	test Res, Res
	jnz %%done 
	ret			;allocation failed
%%done:
	mov rsp, rbp
	pop Arg2
	pop Arg1
	pop rbp
%endmacro

struc bigint
	.sign:		resb 1		;0 for '-', 1 for '+'
	.size:		resq 1
	.capacity:	resq 1
	.data:		resq 1		;pointer to vector
endstruc				;only positive numbers are stored


;;Arg1 - int64
;; Res - bigint ptr
biFromInt:
	begin
	
	xor r12, r12
	mov r12, Arg1		;save input
	
	alloc16 4		;we need 25 bytes for structure, allocate bit more 8*4 = 32 bytes
	mov Arg1, Res
	mov Arg2, 4	;first time we alloc a bit more to avoid multiple expands of vector
	call newVec
	mov qword [Res + bigint.size], 1 ;initial size
	
	cmp r12, 0
	jl .negative 
	mov byte [Res + bigint.sign], 1
	jmp .sign_set

	.negative:
	mov byte [Res + bigint.sign], 0
	neg r12			;make positive

	.sign_set:
	mov r14, [Res + bigint.data]
	mov [r14], r12 
	end


;; Arg1 -> string
;; Res -> bigint 
biFromString:
	begin
	mov r12, Arg1		;save string ptr
	mov Arg1, 0
	call biFromInt
	mov r13, Res		;save pointer to new bigint
	
	cmp byte [r12], 0	;empty string
	jz .bad_string
	
	mov byte [r13 + bigint.sign], 1 ;'+'
	cmp byte [r12], '-'
	jne .sign_done
	mov byte [r13 + bigint.sign], 0
	inc r12
	.sign_done:

	cmp byte [r12], 0	;only sign
	jz .bad_string

	
	.skip_leading_zeros:
		cmp byte [r12], '0'
		jne .skipped
		inc r12
		cmp byte [r12], 0 ; end of string => there are only zeros => all done
		jz .all_done
		jmp .skip_leading_zeros
	.skipped:

	

	mov Arg1, r13
	xor rbx, rbx
	.loop:
		mov bl, byte [r12]
		inc r12
		cmp bl, 0
		je .all_done
		cmp bl, '0'
		jl .bad_string
		cmp bl, '9'
		jg .bad_string

		sub rbx, '0'
		mov Arg2, 10
		call biMulInt
		mov Arg2, rbx
		call biAddInt
		jmp .loop
		
	.all_done:
	mov Res, Arg1
	end

	.bad_string:
	mov Arg1, r13
	call biDelete 
	xor Res, Res
	end

biDelete:
	begin
	mov r15, rsp	
	and rsp, ~15
	mov r12, Arg1
	mov Arg1, [Arg1 + bigint.data]
	call free		;free vector
	and rsp, ~15
	mov Arg1, r12
	call free		;free struc
	mov rsp, r15
	end

;; checks, if expand needed and then calls expandVec 
%macro expandMacro 0
	push r12
	mov r12, [Arg1 + bigint.capacity]
	cmp r12, Arg2
	jge %%capacity_done
	call expandVec
%%capacity_done:	
	pop r12
	
%endmacro
	
;;Arg1 -> bigInt1
;;Arg2 -> bigInt2
;;res: bigInt1 += bigInt2
biAdd:
	begin

	;; check signs
	movzx r13, byte [Arg1 + bigint.sign]
	movzx r14, byte [Arg2 + bigint.sign]
	cmp r13, r14
	jne .sub
	
	;;signs is equal
	mov r12, [Arg2 + bigint.size]
	cmp r12, [Arg1 + bigint.size]
	jge .max_in_r12
	mov r12, [Arg1 + bigint.size]
	.max_in_r12:
	
	;; increase capacity
	inc r12			;space for carry
	push Arg2
	mov Arg2, r12
	expandMacro
	pop Arg2
	
	mov r12,[Arg2 + bigint.size]

	mov r13, [Arg1 + bigint.data] ;vector1 pointer
	mov r14, [Arg2 + bigint.data] ;vector2 pointer
	mov r8, 0		      ;size counter
	
	clc
	 .loop:
	 	mov r15, [r14]	
	 	lea r14, [r14 + 8]
	 	adc [r13], r15
	 	lea r13, [r13 + 8]
		inc r8
		dec r12
	 	jnz .loop

	jnc .done
	 .carry:
	 	adc qword [r13], 0
	 	lea r13, [r13 + 8]
		inc r8
	 	jc .carry
	.done:
	cmp [Arg1 + bigint.size], r8
	jge .size_done
	mov [Arg1 + bigint.size], r8 ;update size
	.size_done:
	end
	
	.sub:			;b1 -= -b2
	xor byte [Arg2 + bigint.sign], 1
	push Arg2
	call biSub
	pop Arg2
	xor byte [Arg2 + bigint.sign], 1 ;change sign back
	
	end

;; adds int64 to bigint
;; Arg1 -> bigint
;; Arg2 = int
;; result: Arg1 -> bigint
biAddInt:
	begin
	push Arg1
	mov r12, [Arg1 + bigint.size]

	inc r12
	push Arg2
	mov Arg2, r12
	expandMacro
	pop Arg2
	dec r12

	mov Arg1, [Arg1 + bigint.data]
	xor r13, r13
	mov r15, 1
	add [Arg1], Arg2
	lea Arg1, [Arg1 + 8]
	jnc .done
	.carry:
	 	adc qword [Arg1], 0
	 	lea Arg1, [Arg1 + 8]
		inc r15
	 	jc .carry
	.done:

	pop Arg1
	cmp r15, [Arg1 + bigint.size]
	jle .end
	mov [Arg1 + bigint.size], r15 	;; update size

	.end:
	end

;; multiplies bigint on int64
;; Arg1 -> bigint
;; Arg2 = int
;; result: Arg1 -> bigint 
biMulInt:
	begin
	mov r15, Arg1
	mov r12, [Arg1 + bigint.size]

	inc r12
	push Arg2
	mov Arg2, r12
	expandMacro
	pop Arg2
	dec r12

	mov Arg1, [Arg1 + bigint.data]
	xor r13, r13
	.loop:
		mov rax, [Arg1]
		mul Arg2	;rdx:rax = rax * arg2
		add rax, r13	;add carried part from previous multiplication
		adc rdx, 0
		mov [Arg1], rax
		lea Arg1, [Arg1 + 8]
		mov r13, rdx	;save carried part
		dec r12
		jnz .loop

	cmp r13, 0
	jz .done
		mov [Arg1], r13
		inc qword [r15 + bigint.size]
	.done:
	
	mov Arg1, r15
	end



;;Arg1 -> bigInt1
;;Arg2 -> bigInt2
;;res: bigInt1 += bigInt2 
biSub:
	begin

	;; check signs
	movzx r13, byte [Arg1 + bigint.sign]
	movzx r14, byte [Arg2 + bigint.sign]
	cmp r13, r14
	jne .add
	
	cmp r13, 0
	jz .negative
	call biCmp
	cmp Res, 0
	jge .simple_sub
	jmp .reverse_sub	;b1 < b2 -> answ = -(b2 - b1)
	
	.negative:
	call biCmp
	cmp Res, 0
	jle .simple_sub
	jmp .reverse_sub

	.simple_sub:
		mov r12, [Arg2 + bigint.size]
		mov r13, [Arg1 + bigint.data] ;vector1 pointer
		mov r14, [Arg2 + bigint.data] ;vector2 pointer
	
		clc
		.loop:
			mov r15, [r14]	
			lea r14, [r14 + 8]
			sbb [r13], r15
			lea r13, [r13 + 8]
			dec r12
			jnz .loop

		jnc .done
		.borrow:
			sbb qword [r13], 0
			lea r13, [r13 + 8]
			inc r8
			jc .borrow
		.done:
		;;update size
		mov r14, [Arg1 + bigint.size] 
		mov r13, [Arg1 + bigint.data]
		lea r13, [r13 + r14 * 8 - 8]
		.decrease_size:
			cmp qword [r13], 0
			jnz .decrease_done
			lea r13, [r13 - 8]
			dec qword [Arg1 + bigint.size]
			cmp qword [Arg1 + bigint.size], 1
			jg .decrease_size
		.decrease_done:
		end
	
	.reverse_sub:
		mov r12, Arg1	;save *b1
		mov Arg1, Arg2
		call biCpy	; tmp = b2
		mov Arg1, Res
		mov Arg2, r12
		mov r14, Res	;save tmp pointer
		call biSub	;tmp -= b1
		;;b1 = tmp 
		mov r15, [r14 + bigint.size]
		mov [r12 + bigint.size], r15
		xor byte [r12 + bigint.sign], 1 ;change sign
		mov r15, [r14 + bigint.capacity]
		mov [r12 + bigint.capacity], r15
		mov r13, [r12 + bigint.data]
		mov r15, [r14 + bigint.data]
		mov [r12 + bigint.data], r15 ;update data

		push rbp
		mov rbp, rsp
		and rsp, ~15	;align stack
		mov Arg1, r13
		call free 	;free old data
		mov rsp, rbp
		pop rbp
	
		end
	
	.add:			;b1 += -b2
	xor byte [Arg2 + bigint.sign], 1
	call biAdd
	xor byte [Arg2 + bigint.sign], 1 ;change sign back
	end


;;Arg1 -> bigInt1
;;Arg2 -> bigInt2
;;res: bigInt1 += bigInt2
biMul:
	begin
	
	mov r11, [Arg1 + bigint.size]
	mov r12, [Arg2 + bigint.size]
	add r11, r12

	mov r12, Arg1
	mov r13, Arg2
	push r11
	mov Arg1, 0
	call biFromInt		;temporary bigint
	pop r11
	mov Arg2, r13
	mov r8, Res		;tmp ptr
	mov Arg1, Res
	;; increase capacity of tmp  (b1.size + b2.size + 1)
	inc r11			;space for carry
	mov Arg2, r11
	push r11
	push r8
	expandMacro
	pop r8
	pop r11
	dec r11
	mov Arg2, r13
	mov Arg1, r12		;restore Arg1

	;; set sign
	cmp byte [Arg2 + bigint.sign], 0 ; if '-' change sign
	jnz .sign_set
	xor byte [Arg1 + bigint.sign], 1

	.sign_set:
	mov [r8 + bigint.size], r11 ;set size
	
	mov r13, [Arg1 + bigint.data] ;vector1 pointer
	mov r14, [Arg2 + bigint.data] ;vector2 pointer
	mov r15, [r8 + bigint.data]   ;vector3(tmp) pointer
	mov r11, 0		      ;i

	.loop1:
		lea r9, [r13 + r11 * 8]
		mov r9, [r9] 	; b1[i]
		mov r10, 0	; j
		xor r12, r12
		clc
		.loop2:
			lea rcx, [r15 + r11 * 8]
			lea rcx, [rcx + r10 * 8]
			mov rax, [r14 + r10 * 8] ;b2[j]
			mul r9			 ;b1[i] * b2[j]
			add rax, [rcx]		 ;+= c[i + j]
			adc rdx, 0
			add rax, r12 ; add carried part
			adc rdx, 0
			mov r12, rdx ; save carried part
			
			mov [rcx], rax
			
			inc r10
			cmp r10, [Arg2 + bigint.size]
			jne .loop2
		.carry:
			lea rcx, [r15 + r11 * 8]
			lea rcx, [rcx + r10 * 8]
			mov rax, [rcx] ;c[i + j]
			add rax, r12 ; add carried part
			mov r12, 0
			adc r12, 0 ; save carried part
			mov [rcx], rax 
			inc r10
			cmp r12, 0
			jnz .carry
		
			
		inc r11
		cmp r11, [Arg1 + bigint.size]
		jne .loop1
	;;update size
	mov r14, [r8 + bigint.size] 
	mov r13, [r8 + bigint.data]
	lea r13, [r13 + r14 * 8 - 8]
	.decrease_size:
		cmp qword [r13], 0
		jnz .decrease_done
		lea r13, [r13 - 8]
		dec qword [r8 + bigint.size]
		cmp qword [r8 + bigint.size], 1
		jg .decrease_size
	.decrease_done:
	;; b1 = tmp
	mov r11, [r8 + bigint.size]
	mov [Arg1 + bigint.size], r11
	mov r11, [r8 + bigint.capacity]
	mov [Arg1 + bigint.capacity], r11
	mov r8, [r8 + bigint.data]
	mov r9, [Arg1 + bigint.data]
	mov [Arg1 + bigint.data], r8 ;b1.data = tmp.data
	
	mov Arg1, r9
	mov rbp, rsp
	and rsp, ~15		;align stack
	call free		;free old data
	mov rsp, rbp
	end

;; Arg1 -> bigint1
;; Res = 0, if b1 == 0
;;       1, if b1 > 0
;;      -1, if b1 < 0
%macro biSignMacro 1
	cmp qword [%1 + bigint.size], 1
	jg %%not_zero
	push r12
	mov r12, [%1 + bigint.data]
	cmp qword [r12], 0
	pop r12
	jnz %%not_zero
	xor Res, Res
	jmp %%end
	
	%%not_zero:
	cmp byte [%1 + bigint.sign], 0
	jz %%negative
	mov Res, 1
	jmp %%end
	
	%%negative:
	mov Res, -1
%%end
%endmacro


;; Arg1 -> bigint1
;; Res = 0, if b1 == 0
;;       1, if b1 > 0
;;      -1, if b1 < 0
biSign:
	begin
	biSignMacro Arg1
	end
	
;; Arg1 -> bigint1
;; Arg2 -> bigint2
;; Res = 0, if b1 == b2
;;       1, if b1 > b2
;;      -1, if b1 < b2
biCmp:
	begin

	biSignMacro Arg1
	mov r12, Res
	biSignMacro Arg2
	cmp r12, Res
	jl .lower
	jg .greater

	;; signs equal
	mov r13, [Arg1 + bigint.size]
	cmp r13, [Arg2 + bigint.size]
	jb .below
	ja .above		

	;; size equal

	mov r14, [Arg1 + bigint.data]
	mov r15, [Arg2 + bigint.data]
	lea r14, [r14 + r13 * 8 - 8]
	lea r15, [r15 + r13 * 8 - 8]
	

	.loop:
		mov rbx, [r14]
		mov r9, [r15]
		cmp rbx, r9
		ja .above
		jb .below
		lea r14, [r14 - 8]
		lea r15, [r15 - 8]
		dec r13
		jnz .loop
	;; bigints are equal
	xor Res, Res
	end
	
	.below:		;answer depends on sign
		cmp r12, 0	;check sign
		jl .greater	;'-'
		jg .lower	;'+'
	.above
		cmp r12, 0
		jl .lower
		jg .greater
	.greater:
	mov Res, 1
	end
	
	.lower:
	mov Res, -1
	end
	
biDivRem:	ret


;;divides bigInt on int64
;;Arg1 -> bigint
;;Arg2 = int64
;;result: Arg1 - pointer on quotient
;;Arg3 - remainder 
biDivInt:
	begin
	push Arg1

	mov r12, [Arg1 + bigint.size]
	mov r13, [Arg1 + bigint.data]
	lea r13, [r13 + r12 * 8 - 8] ; pointer on the last element
	xor rdx, rdx

	.loop:
		mov rax, [r13]
		div Arg2	;rax = rdx:rax / arg2, rdx = rdx:rax % arg2
		mov [r13], rax
		sub r13, 8
		dec r12
		jnz .loop

	;;update size
	mov r14, [Arg1 + bigint.size] 
	mov r13, [Arg1 + bigint.data]
	lea r13, [r13 + r14 * 8 - 8]
	.decrease_size:
		cmp qword [r13], 0
		jnz .decrease_done
		lea r13, [r13 - 8]
		dec qword [Arg1 + bigint.size]
		cmp qword [Arg1 + bigint.size], 1
		jg .decrease_size
	.decrease_done:
	;;Arg3 == rdx, so remainder is already here
	pop Arg1
	end

;;creates copy of bigint 
;;Arg1 -> bigint
;;result: Res -> copy of bigint 
biCpy:	
	begin

	mov r12, Arg1
	alloc16 4		;alloc struc
	mov Arg1, Res
	mov r13, [r12 + bigint.size]
	mov Arg2, r13
	call newVec		;alloc space for data
	mov r14, Res		;save ptr on new bigint
	
	mov rbp, rsp
	and rsp, ~15		;align the stack
	mov Arg1,[Res + bigint.data]
	mov Arg2, [r12 + bigint.data] ;memcpy(void *dest,const void *src,size_t num)
	lea Arg3, [r13 * 8]	;size in bytes
	call memcpy	
	mov rsp, rbp		;restore stack pointer
	mov [r14 + bigint.size], r13
	mov bl, byte [r12 + bigint.sign]
	mov byte [r14 + bigint.sign], bl
	mov Res, r14
	
	end

;;Arg1 -> bigint
;;Arg2 -> buffer
;;Arg3 = limit 
biToString:
	begin

	biSignMacro Arg1
	mov r12, Arg2		;save buffer ptr
	mov r13, Arg3

	cmp r13, 0
	jle .print_done		;no space at all

	dec r13 	;space for 0 in end of string
	cmp r13, 0
	jz .end
	cmp Res, -1
	jne .sign_done
	mov byte [r12], '-'
	dec r13
	inc r12
	cmp r13, 0
	jz .end			;space was only for sign
	.sign_done:

	call biCpy
	mov Arg1, Res		;work with copy
	mov Arg2, 10
	push 0			;end of sequence on stack
	.loop:
		call biDivInt
		add Arg3, '0'
		push Arg3
		biSignMacro Arg1
		cmp Res, 0
		jnz .loop

	.print:
		pop Arg3
		mov [r12], Arg3	;print symbol
		inc r12
		cmp Arg3, 0
		jz .print_done
		dec r13		
		jnz .print	;check limit
	
	.clean_stack:
		pop Arg3
		cmp Arg3, 0
		jnz .clean_stack
	.end:
	mov byte [r12], 0		;end of string

	.print_done:
	call biDelete 		;delete copy
	
	end


;; Arg1 - bigint ptr	
;; Arg2 - size of new vector in qwords
;; Res - bigint ptr 
newVec:
	begin
	
	lea Arg3, [Arg2 * 2]	;initial capacity = size * 2
	mov r13, Arg3		;save capacity in qwords 
	alloc16 Arg3
        mov [Arg1 + bigint.size], Arg2
	mov [Arg1 + bigint.capacity], r13
	mov [Arg1 + bigint.data], Res 
	mov Res, Arg1
	
	end

;; increases capacity to Arg2, size not changed
;; Arg1 - bigint ptr (saved)
;; Arg2 - size, must be greater than current capacity
expandVec:
	begin
	push Arg1
	
	mov r13, [Arg1 + bigint.data] ;save previous data ptr
	;; here we need to allocate more memory for vector
	mov r14, [Arg1 + bigint.size] ;save previous size
	call newVec		      ;Arg2 was set by input

	mov r12, rsp
	and rsp, ~15		;align the stack
	mov Arg1, [Arg1 + bigint.data] ;memcpy(void *dest,const void *src,size_t num)
	mov Arg2, r13
	lea Arg3, [r14 * 8]	;size in bytes
	call memcpy
	
	and rsp, ~15		;align the stack
	mov Arg1, r13
	call free		;free previous data
	
	mov rsp, r12		;restore stack pointer
	pop Arg1
	mov [Arg1 + bigint.size], r14 ;restore size
	end
 


