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
global getFirstInt		;debug function

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
%endmacro

%macro end 0
	pop r14
	pop r13
	pop r12
	pop rbx
	pop rbp
	ret
%endmacro

	;; allocates memory aligned on 16 bytes
	;; result in Res
%macro alloc16 1
	push rbp
	push Arg1
	push Arg2
	mov rbp, rsp
	mov Arg1, 16
	mov Arg2, %1
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
	
	alloc16 25
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
	mov [Res + bigint.data], r12 ;r13 is vector pointer
	end

biFromString:	ret
biDelete:
	begin
	mov r12, Arg1
	mov Arg1, [Arg1 + bigint.data]
	call free		;free vector
	mov Arg1, r12
	call free		;free struc
	end

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
	
	;; increase capacity
	inc r12			;space for carry
	push Arg2
	mov Arg2, r12
	call expandVec
	pop Arg2
	dec r12			;size of bigint2

	
	lea r13, [Arg1 + bigint.data] ;vector1 pointer
	lea r14, [Arg2 + bigint.data] ;vector2 pointer
	clc
	 .loop:
	 	mov r15, [r14]	
	 	lea r14, [r14 + 8]
	 	adc [r13], r15
	 	lea r13, [r13 + 8]
	 	dec r12
	 	jnz .loop
	
	 .carry:
	 	adc qword [r13], 0
	 	lea r13, [r13 + 8]
	 	jc .carry
	end
	
	.sub:
	
	end

;; adds int64 to bigint
;; Arg1 -> bigint
;; Arg2 = int
;; Res -> bigint 
biAddInt:
	begin
	push Arg1
	mov r12, [Arg1 + bigint.size]

	inc r12
	push Arg2
	mov Arg2, r12
	call expandVec
	pop Arg2
	dec r12
	
	lea Arg1, [Arg1 + bigint.data]
	xor r13, r13
	add [Arg1], Arg2
	lea Arg1, [Arg1 + 8]
	.carry:
	 	adc qword [Arg1], 0
	 	lea Arg1, [Arg1 + 8]
	 	jc .carry 
		
	pop Res
	end

;; multiplies bigint on int64
;; Arg1 -> bigint
;; Arg2 = int
;; Res -> bigint 
biMulInt:
	begin

	end


biSub:	ret
biMul:	ret
biCmp:	ret

	
%macro biSignMacro 1
	cmp qword [%1 + bigint.data], 0
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
	
;;Arg1 - ptr to bigint
biSign:
	begin
	biSignMacro Arg1
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
	lea r13, [Arg1 + bigint.data + r12 * 8 - 8] 
	xor rdx, rdx

	.loop:
		mov rax, [r13]
		div Arg2	;rax = rdx:rax / arg2, rdx = rdx:rax % arg2
		mov [r13], rax
		cmp rax, 0
		jnz .size_ok
			dec qword [Arg1 + bigint.size] ;size decreased
		.size_ok:
		sub r13, 8
		dec r12
		jnz .loop

	cmp qword [Arg1 + bigint.size], 0
	jz .ok
		inc qword [Arg1 + bigint.size]
	.ok:
	;;Arg3 == rdx, so remainder is already here
	pop Arg1
	end

;;creates copy of bigint 
;;Arg1 -> bigint
;;result: Res -> copy of bigint 
biCpy:	
	begin

	mov r12, Arg1
	alloc16 25
	mov Arg1, Res
	mov r13, [r12 + bigint.size]
	mov Arg2, r13
	call newVec
	mov r14, Res		;save ptr on new bigint
	
	mov r15, rsp
	and rsp, ~15		;align the stack
	lea Arg1,[Res + bigint.data]
	lea Arg2, [r12 + bigint.data] ;memcpy(void *dest,const void *src,size_t num)
	lea Arg3, [r13 * 8]	;size in bytes
	call memcpy	
	mov rsp, r15		;restore stack pointer
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
		cmp qword [Arg1 + bigint.data], 0
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

	
getFirstInt:
	begin
	mov Arg2, 11
	call biAddInt
	mov Res, [Res + bigint.data]
	end


;; Arg1 - bigint ptr	
;; Arg2 - size of new vector in qwords
;; Res - bigint ptr 
newVec:
	begin
	
	lea Arg3, [Arg2 * 2]	;initial capacity = size * 2
	mov r13, Arg3		;save capacity in qwords 
        lea Arg3, [Arg3 * 8]	;qword -> bytes
	alloc16 Arg3
        mov [Arg1 + bigint.size], Arg2
	mov [Arg1 + bigint.capacity], r13
	mov [Arg1 + bigint.data], Res 
	mov Res, Arg1
	
	end

;; increases capacity if it less than Arg2
;; Arg1 - bigint ptr (saved)
;; Arg2 - size 
expandVec:
	begin
	push Arg1
	
	mov r12, [Arg1 + bigint.capacity]
	cmp r12, Arg2
	jge .capacity_done

	mov r13, [Arg1 + bigint.data] ;save previous data ptr
	;; here we need to allocate more memory for vector
	mov Arg3, [Arg1 + bigint.size] ;save previous size
	call newVec
	
	mov r15, rsp
	and rsp, ~15		;align the stack
	mov Arg1, [Arg1 + bigint.data] ;memcpy(void *dest,const void *src,size_t num)
	mov Arg2, r13
	lea Arg3, [Arg3 * 8]	;size in bytes
	call memcpy
	
	mov Arg1, r13
	call free		;free previous data
	
	mov rsp, r15		;restore stack pointer
	.capacity_done:

	pop Arg1
	end
 


