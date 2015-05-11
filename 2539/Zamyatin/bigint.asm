extern 		malloc
extern 		free
global biFromInt
global biDelete
global biSign
global biCmp
global biAdd
global biSub
global biMulShort
global biToString
global biLeftShift
global biCopy
global biMul
global biDivRem

DIGIT 	equ 	1000000000
; int: sign
; int: number of digits
; int*: data
; one digit - 10^9


biDivRem:
	ret

; allocates rsi bytes and fill it zeroes
; rdi - BigInt
allocate:
	sub 	rsp, 16
	mov 	[rsp], rdi ; store bigint
	call 	malloc
	mov 	rdi, [rsp] ; take bigint
	add 	rsp, 16
	.loop: ; fill zeroes
		cmp 	rdi, 0
		je 		.finish
		sub 	rdi, 4
		mov 	dword [rax + rdi], 0
		jmp 	.loop
	.finish:
	ret
;=============
; creates BigInt from int64_t
biFromInt:
	sub 	rsp, 16
	mov  	[rsp + 8], rdi
	mov 	rdi, 16
	call 	malloc
	mov 	[rsp], rax
	mov 	rdi, 16
	call 	malloc
	mov 	rdi, 0
	mov 	[rax], rdi
	mov 	[rax + 8], rdi
	mov 	rdi, [rsp]
	mov 	[rdi + 8], rax
	mov 	rsi, [rsp + 8]
	mov		dword [rdi], 0
	mov		dword [rdi+4], 0
	; some init stuff
	cmp 	rsi, 0
	jge 	.positive
		neg 	rsi ; change sign
		mov 	dword [rdi], 1
	.positive:
		xchg 	rax, rsi
		mov 	r8, DIGIT
		.loop: ; fill digits
			mov 	rdx, 0
			div 	r8
			mov 	[rsi], edx
			add 	rsi, 4
			add 	dword [rdi + 4], 1
			cmp 	rax, 0
			je 		.finish
			jmp  	.loop
		.finish:
		add 	rsp, 16
		mov 	rax, rdi
	ret
;=============
; removes zeroes from begin(end) of number
biTrim:
	push 	rdi
	xor 	rsi, rsi
	mov 	esi, 	dword [rdi + 4];
	mov 	rdi, [rdi + 8]
	.loop
		cmp 	esi, 0
		je 		.finish
		dec		esi ; decrement lengtn of number from end untill positive digit
		cmp 	dword [rdi + rsi * 4], 0
		je 		.loop
	.finish
	pop 	rdi
	cmp 	esi, 0
	inc 	esi
	mov 	dword [rdi + 4], esi
	ret
;=============
; frees memory allocated for BigInt
biDelete:
	sub 	rsp, 16
	mov 	[rsp], rdi
	mov 	rdi, [rdi + 8]
	call 	free
	mov 	rdi, [rsp]
	call 	free
	add 	rsp, 16
	ret
;=============
; takes sign of BigInt
biSign:
	mov 	esi, [rdi]
	cmp 	esi, 0
	mov 	rax, -1
	jg 		.return ; if sign is minus - return
	mov 	esi, [rdi + 4]
	mov 	rax, 1
	cmp 	esi, 1
	jg  	.return ; check length of number, if bigger then one, sign is plus
	mov 	rdi, [rdi + 8]
	cmp 	dword [rdi], 0
	jg 		.return ; check digit of number, if bigger then zero, sign is plus, otherwise zero
	mov 	rax, 0
	.return:
		ret	
;=============
; compare two BigInt's
biCmp:
	mov 	ecx, dword [rdi]
	shl 	ecx, 1
	or 		ecx, dword [rsi] ; mask of sign
	cmp 	ecx, 1
	je 		.ret1
	cmp 	ecx, 2
	je 		.ret2
	; check signs of numbers and making decision about comparing, and store mask of sign
	mov 	rdx, 0
	mov 	edx, dword [rdi + 4]
	cmp 	edx, dword [rsi + 4]
	jg 		.g  ;compare length of numbers
	jl  	.l  ;*
	mov 	rdi, [rdi + 8]
	mov 	rsi, [rsi + 8]
	.loop: ; find first diff
		cmp 	edx, 0
		je 		.retEq
		dec 	edx
		mov 	eax, dword [rdi + 4*rdx]
		cmp 	eax, dword [rsi + 4*rdx]
		jg 		.g
		jl 		.l
		jmp 	.loop
	
	.g:
		cmp 	ecx, 0
		je 		.ret1
		jmp 	.ret2

	.l:
		cmp 	ecx, 0
		je 		.ret2
		jmp 	.ret1
	
	.ret1:
		mov 	rax, 1
		ret
	.ret2:
		mov 	rax, -1
		ret
	.retEq:
		mov 	rax, 0
		ret
;=============
; makes string. don't put zero at end of string. you should care about zero at the end.
biToString:
	push 	rdi
	push 	rsi
	call 	biTrim
	pop 	rsi
	pop 	rdi

	push 	r10
	push 	r11
	cmp 	rdx, 0
	je 		.return

	cmp 	dword [rdi], 0 ; take sign
	je 		.pos
	mov 	byte [rsi], '-'
	inc 	rsi
	dec 	rdx  
	.pos:
	mov 	r8, 0
	mov 	r8d, dword [rdi + 4]
	shl 	r8, 2
	mov 	r9, rdx
	mov 	rdi, [rdi + 8]
	mov 	r10, 10

	sub 	r8, 4
	mov 	rax, 0
	mov 	eax, dword [rdi + r8]
	mov 	r11, 0
	.loop2: ; handle first digit, to trims zeroes from one digit
		cmp 	r9, 0
		je 		.finish2
		mov 	rdx, 0
		div 	r10
		add 	rdx, 	'0'
		push 	rdx
		inc 	r11
		dec 	r9
		cmp 	rax, 0
		jg 	.loop2
	.finish2:

	.loop3: ; for reversed order
		pop 	rax
		mov 	byte [rsi], al
		inc 	rsi
		dec 	r11
		cmp 	r11, 0
		jg 		.loop3
	
	.loop: ; make string, r9 - limit, r8 - length of number
		cmp 	r9, 0
		je 		.return
		cmp 	r8, 0
		je 		.finish
		sub 	r8, 4
		mov 	rax, 0
		mov 	eax, dword [rdi + r8]
		mov 	rcx, 9
		cmp 	rcx, r9
		jle 	.loop1
		mov 	rcx, r9
		.loop1:
			cmp 	rcx, 0
			je 		.finish1
			mov 	rdx, 0
			div 	r10
			add 	rdx, 	'0'
			dec 	rcx
			mov 	byte [rsi + rcx], dl
			dec 	r9
			jmp 	.loop1
		.finish1:
		add 	rsi, 9
		jmp 	.loop
	.finish:
		
	.return:
		pop 	r10
		pop 	r11
		ret
;=============
; subtract two bigints. answer is x, where x = ||a| - |b||
biSubAbs:
	cmp 	rdi, rsi
	jne 	.diff
	mov 	rsi, 0
	call biMulShort
	ret
	.diff:
	push 	r13
	push 	r12
	push 	r10
	push 	r11
	push 	rdi
	push 	rsi
	mov 	r13, 0
	mov 	r12, rdi
	mov 	r8d, dword [rdi]
	mov 	r9d, dword [rsi]
	mov 	dword [rdi], 0
	mov 	dword [rsi], 0
	push 	rdi
	push 	rsi
	call 	biCmp
	pop 	rsi
	pop 	rdi
	mov 	dword [rdi], r8d
	mov 	dword [rsi], r9d
	pop 	rsi
	pop 	rdi
	cmp 	rax, 0
	jge 	.ok
	xchg 	rdi, rsi
	.ok:
	push 	rdi
	push 	rsi
	mov 	rsi, 0
	mov 	esi, dword [rdi + 4]
	inc 	rsi
	shl 	rsi, 2
	mov 	rdi, rsi
	call 	allocate ; allocate place for new digits
	mov 	rcx, rax
	pop 	rsi
	pop 	rdi
	mov 	r8, 0
	mov 	r8d, dword [rdi + 4]
	mov 	r9, 0
	mov 	r9d, dword [rsi + 4]
	
	mov 	rdi, [rdi + 8]
	mov 	rsi, [rsi + 8]

	mov 	rax, [r12 + 8]
	mov	 	[r12 + 8], rcx

	push 	rax
	push 	r12
	
	mov 	r10, DIGIT
	mov	 	r11, 0
	mov 	r12, [r12 + 8]	
	.loop1:
		cmp 	r9, 0
		je 		.finish1
		inc 	r13
		mov 	rax, 0
		mov 	eax, dword [rdi]
		sub 	eax, dword [rsi]
		sub 	rax, r11
		mov 	r11, 0
		cmp 	eax, 0
		jge  	.oook
			mov	 	r11, 1
			add 	rax, r10
		.oook:
		mov 	dword [rcx], eax
		add 	rdi, 4
		add 	rsi, 4
		add 	rcx, 4
		add 	r12, 4
		dec 	r9
		dec 	r8
		jmp 	.loop1
	.finish1:

	.loop2:
		cmp 	r8, 0
		je 		.finish2
		inc 	r13
		mov 	rax, 0
		mov 	eax, dword [rdi]
		sub 	rax, r11
		mov 	r11, 0
		cmp 	rax, 0
		jge  	.ooook
			mov	 	r11, 1
			add 	rax, r10
		.ooook:
		mov 	dword [rcx], eax
		add 	rdi, 4
		add 	rcx, 4
		add 	r12, 4
		dec 	r8
		jmp 	.loop2
	.finish2:

		pop 	rdi

		cmp 	r11d, 1
		jl 		.ook
			inc 	r13
		.ook:
		mov 	dword [rdi + 4], r13d
		call 	biTrim 
		pop 	rdi
		pop 	r11
		pop 	r10
		pop 	r12
		pop 	r13
		call 	free
		ret
;=============
; add two bigints. answer is x, where x = |a| + |b|
biAddAbs:
	cmp 	rdi, rsi
	jne 	.diff
	mov 	rsi, 2
	call biMulShort
	ret
	.diff:
	push 	r8
	push 	r9
	push 	r10
	push 	r11
	push 	r12

	push 	rdi
	push 	rsi
	mov 	r8, 0
	mov 	r9, 0
	mov 	r8d, dword [rdi + 4]
	mov 	r9d, dword [rsi + 4]
	push 	r8
	push 	r9
	mov 	rdi, r8
	cmp 	r8, r9
	jg 		.ok
		mov 	rdi, r9
	.ok:
	inc 	rdi
	shl 	rdi, 2
	call 	allocate
	pop 	r9
	pop 	r8
	pop 	rsi
	mov 	rdi, [rsp]
	mov 	rcx, rax
	xchg 	[rdi + 8], rax
	push 	rax
	mov 	rdi, rax
	mov 	rsi, [rsi + 8]
	mov 	r10, DIGIT
	mov 	r11, 0
	mov 	r12, 0

	cmp 	r8, r9
	jg 		.loop1
		xchg	r8, r9
		xchg 	rdi, rsi
	.loop1:
		cmp 	r9, 0
		je 		.finish1
		mov 	rdx, 0
		mov 	rax, 0
		mov 	eax, dword [rdi]
		add 	eax, dword [rsi]
		add 	rax, r11
		div 	r10
		mov 	dword [rcx], edx
		mov 	r11, rax
		dec 	r8
		dec 	r9
		add 	rdi, 4
		add 	rsi, 4
		add 	rcx, 4
		inc 	r12
		jmp 	.loop1
	.finish1:
	.loop2:
		cmp 	r8, 0
		je 		.finish2
		mov 	rdx, 0
		mov 	rax, 0
		mov 	eax, dword [rdi]
		add 	rax, r11
		div 	r10
		mov 	dword [rcx], edx
		mov 	r11, rax
		dec 	r8
		dec 	r9
		add 	rdi, 4
		add 	rcx, 4
		inc 	r12
		jmp 	.loop2
	.finish2:	
	mov 	dword [rcx], r11d
	cmp 	r11d, 0
	je  	.ook
		inc 	r12
	.ook:
	pop 	rdi
	call 	free
	pop 	rdi
	mov	 	dword [rdi + 4], r12d
	pop 	r12
	pop 	r11
	pop 	r10
	pop 	r9
	pop 	r8

	ret	
;=============
; add two bigints. looks at signs and make desicion
biAdd:
	mov 	ecx, dword [rdi]
	shl 	ecx, 1
	or 		ecx, dword [rsi]
	cmp 	ecx, 0
	je 		.A
	cmp 	ecx, 1
	je 		.B
	cmp 	ecx, 2
	je 		.C
	cmp 	ecx, 3
	je 		.D
	
	.A:
		call 	biAddAbs
		jmp 	.return
	.B:
		push 	rdi
		push 	rsi
		mov 	dword [rsi], 0
		call  biCmp
		mov 	rsi, [rsp]
		mov		rdi, [rsp + 8]
		mov 	dword [rsi], 1
		push 	rax
		call 	biSubAbs
		pop 	rax
		pop 	rsi
		pop 	rdi
		cmp 	rax, 0
		jge 	.return
		mov 	dword [rdi], 1
		jmp 	.return
	.C:
		push 	rdi
		push 	rsi
		mov 	dword [rdi], 0
		call  biCmp
		mov 	rsi, [rsp]
		mov		rdi, [rsp + 8]
		push 	rax
		call 	biSubAbs
		pop 	rax
		pop 	rsi
		pop 	rdi
		cmp 	rax, 0
		jle 	.return
		mov 	dword [rdi], 1
		jmp 	.return
	.D:
		call 	biAddAbs
		jmp 	.return

	.return:
		ret
;=============
; subltract two bigints. looks at signs and make desicion
biSub:
 	mov 	eax, 0
 	mov 	eax, dword [rsi]
 	push 	rax
 	inc 	eax
 	and 	eax, 1
 	mov 	dword[rsi], eax
 	push 	rsi
 	call 	biAdd
 	pop 	rsi
 	pop 	rax
 	mov 	dword[rsi], eax
 	ret
;=============
; mul bigint and one digit
biMulShort:
	cmp 	esi, 0
	jge 	.positive
	neg 	esi
	inc 	dword [rdi]
	and   dword [rdi], 1
	.positive:
	push 	r10
	push 	r11
	push 	rdi
	mov 	r8d, dword [rdi + 4]
	mov 	rdi, r8
	inc 	rdi
	shl 	rdi, 2
	push 	r8
	push 	rsi
	call 	allocate
	pop 	rsi
	pop 	r8
	pop 	rdi
	mov 	rcx, rax
	mov 	rax, [rdi + 8]
	mov 	[rdi + 8], rcx
	push 	rdi
	push 	rax
	mov 	rdi, rax
	mov 	r11, 0
	mov 	r10, DIGIT
	.loop:
		cmp 	r8, 0
		je 		.finish
		mov 	rax, 0
		mov 	eax, dword [rdi]
		mul 	rsi
		add 	rax, r11
		mov 	rdx, 0
		div 	r10
		mov 	dword [rcx], edx
		mov 	r11, rax
		add 	rdi, 4
		add 	rcx, 4
		dec 	r8	
		jmp 	.loop
	.finish
	mov 	dword [rcx], r11d
	pop 	rdi
	push 	r11
	call 	free
	pop 	r11
	pop 	rdi
	cmp 	r11d, 0
	je 		.ook
		inc 	dword [rdi + 4]
	.ook:
	call 	biTrim
	pop 	r11
	pop 	r10
	ret
;=============
; shift left for rsi digits
biLeftShift:
	mov 	r8, 0
	mov 	r8d, dword [rdi + 4]
	push 	rdi
	push 	rsi
	add 	r8, rsi
	shl 	r8, 2
	mov 	rdi, r8
	call 	allocate
	pop 	rsi
	pop 	rdi
	mov 	r8, 0
	mov 	r8d, dword [rdi + 4]
	mov 	r9, r8
	add 	r9, rsi
	add 	dword [rdi + 4], esi
	push 	rdi
	mov 	rdi, [rdi + 8]
	.loop:
		cmp 	r8, 0
		je 		.finish
		dec 	r8
		dec 	r9
		mov 	ecx, dword [rdi + 4 * r8]
		mov 	dword [rax + 4 * r9], ecx
		jmp 	.loop
	.finish:
	pop 	rdi
	mov 	rcx, [rdi + 8]
	mov 	[rdi + 8], rax
	mov 	rdi, rcx
	call free
	ret
;=============
; copy big int
biCopy:
	push 	rdi
	mov 	rdi, 16
	call  malloc
	mov		rdi, [rsp]
	mov 	r8, [rdi]
	mov 	[rax], r8
	push 	rax
	mov 	rax, 0
	mov 	eax, dword [rdi + 4]
	shl 	eax, 2
	mov 	rdi, rax
	call 	malloc
	pop 	rsi
	pop 	rdi
	mov 	[rsi + 8], rax
	mov 	r8, 0
	mov 	r8d, dword [rdi + 4]
	mov 	rdi, [rdi + 8]
	.loop:
		cmp 	r8, 0
		je 		.finish
		mov 	r9d, dword [rdi]
		mov 	dword [rax], r9d
		add 	rax, 4
		add 	rdi, 4
		dec 	r8
		jmp 	.loop	
	.finish
	mov 	rax, rsi
	ret
;=============
; mul two big ints
biMul:
	mov 	eax, dword [rdi]
	add 	eax, dword [rsi]
	and 	eax, 1
	mov 	dword [rdi], 0
	push 	r10
	push 	r12
	push 	r13
	push 	rax
	push 	rdi
	push 	rsi
	mov 	rdi, 0
	call 	biFromInt
	mov 	r13, rax
	mov 	r10, 0

	
	.loop:
		mov 	rdi, [rsp + 8]
		mov 	rsi, [rsp]
		cmp 	r10d, dword [rsi+4]
		je 		.finish
		push 	r10
		call 	biCopy
		pop 	r10
		mov 	rdi, rax
		mov	 	rsi, [rsp]
		mov 	rsi, [rsi + 8]
		mov 	rcx, 0
		mov 	ecx, dword [rsi + 4 * r10]
		mov 	rsi, rcx
		push 	rdi
		push 	r10
		call 	biMulShort
		pop 	r10
		pop 	rdi
		mov 	rsi, r10
		push 	rdi
		push 	r10
		call 	biLeftShift
		pop 	r10
		mov 	rdi, [rsp]
		mov		rsi, r13
		xchg 	rsi, rdi
		push 	r10
		call 	biAddAbs
		pop 	r10
		pop 	rdi
		push 	r10
		call 	biDelete
		pop 	r10
		inc 	r10
		jmp 	.loop
	.finish:
	mov 	rdi, r13
	call 	biTrim
	pop 	rsi
	pop 	rdi
	pop 	rax
	mov 	dword [r13], eax
	cmp 	dword [r13 + 4], 1
	jne 	.nonZero
	mov 	r8, [r13 + 8]
	cmp 	dword [r8], 0
	jne 	.nonZero
	mov 	dword [r13], 0
	.nonZero:
	mov	 	r8, [rdi + 8]
	mov 	r9, r13
	push 	r8
	mov 	rsi, [r13]
	mov 	[rdi], rsi
	mov 	rsi, [r13 + 8]
	mov 	[rdi + 8], rsi
	mov	 	rdi, r9
	call 	free
	pop 	rdi 
	call 	free
	pop 	r13
	pop 	r12
	pop 	r10
	ret
section .data
zero: 		dd 		0, 0, 0, 0




