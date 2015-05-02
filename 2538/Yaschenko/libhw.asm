default rel

extern calloc
extern free

extern vectorNew
extern vectorPushBack
extern vectorDelete
extern vectorSize
extern vectorBack
extern vectorGet

global biFromInt
global biFromString
global biToString
global biDelete
global biSign
global biAdd
global biSub
global biMul
global biDivRem
global biCmp


section .text

;; Bigint stores digits with 1e9 base.
%assign	BASE		1000000000
%assign	BASE_LEN	9
%assign	SIGN_PLUS	1
%assign	SIGN_MINUS	-1
%assign	SIGN_ZERO	0

struc Bigint
	.vector		resq	1
	.sign		resq	1
endstruc


;; Creates new Bigint with empty vector.
;; Returns:
;;	* RAX: pointer to newly created Bigint.
biNew:
;; Create vector of size 0 to store digits of Bigint.
	mov	rdi, 0
	call	vectorNew
	push	rax

;; Allocates memory for BigInt struct.
	mov	rdi, 1
	mov	rsi, Bigint_size
	call	calloc

	pop	rdx
	mov	[rax + Bigint.vector], rdx
	mov	qword [rax + Bigint.sign], SIGN_ZERO

	ret

;; Pushes %2 to vector %1.
%macro vector_push_back 2
	mov	rdi, %1
	mov	rsi, %2
	call	vectorPushBack
%endmacro

%macro vector_back 1
	mov	rdi, %1
	call	vectorBack
%endmacro

%macro vector_size 1
	mov	rdi, %1
	call	vectorSize
%endmacro

%macro vector_get 2
	mov	rdi, %1
	mov	rsi, %2
	call	vectorGet
%endmacro

%macro bigint_set_sign 2
	mov	%1, %2
%endmacro


;; Pushes given set of registers on stack.
%macro mpush 1-*
	%rep	%0
	push	%1
	%rotate	1
	%endrep
%endmacro

;; Pops given set of registers from stack in reversed order.
%macro mpop 1-*
	%rep	%0
	%rotate -1
	pop	%1
	%endrep
%endmacro

;; Divides given reg by 10
;; (RAX, RDX and RCX are reserved)
%macro div10 1
	push	rax
	push	rdx
	push	rcx

	xor	rdx, rdx
	mov	rax, %1
	mov	rcx, 10
	idiv	rcx
	mov	%1, rax

	pop	rcx
	pop	rdx
	pop	rax
%endmacro


;; BigInt biFromInt(int64_t x);
;;
;; Creates a BigInt from 64-bit signed integer.
;; Takes:
;;	* RDI: number X.
;; Returns:
;;	* RAX: pointer to a newly created BigInt.
biFromInt:
	push	rdi
;; Create empty Bigint.
	call	biNew
	pop	rdi
	push	rax
	mov	r8, rax

	bigint_set_sign		qword [r8 + Bigint.sign], SIGN_PLUS
	cmp	rdi, 0
	jge	.zero_check

.negative:
	bigint_set_sign		qword [r8 + Bigint.sign], SIGN_MINUS
	neg	rdi

.zero_check:
	cmp	rdi, 0
	je	.zero

.div_loop:
	xor	rdx, rdx
	mov	rax, rdi
	mov	rcx, BASE
	div	rcx

	mov	r8,	[rsp]
	push	rax
	vector_push_back	[r8 + Bigint.vector], rdx
	pop	rax
	mov	rdi, rax

	cmp	rdi, 0
	je	.done
	jmp	.div_loop

.zero:
;; TODO: don't push back 0 if bigint is zero.
	vector_push_back	[r8 + Bigint.vector], 0
	bigint_set_sign		qword [r8 + Bigint.sign], SIGN_ZERO

.done:
	pop	rax
	ret

;; void biDelete(BigInt bi);
;;
;; Deletes a Bigint.
;; Takes:
;;	* RDI: pointer to Bigint.
biDelete:
	push	rdi
	mov	rdi, [rdi + Bigint.vector]
	call	vectorDelete
	pop	rdi

	call	free
	ret

;; int biSign(BigInt bi);
;;
;; Returns sign of Bigint BI:
;;	-1: if BI < 0
;;	 0: if BI = 0
;;	 1: if BI > 0
;; Takes:
;;	* RDI: pointer to Bigint BI.
;; Returns:
;;	* RAX: sign of Bigint BI.
biSign:
	mov		rax, [rdi + Bigint.sign]
	ret



;; void biToString(BigInt bi, char *buffer, size_t limit);
;;
;; Generate a decimal string representation from a Bigint BI.
;; Writes at most limit bytes to buffer BUFFER.
;; Takes:
;;	* RDI: pointer to Bigint BI.
;;	* RSI: pointer to destination buffer.
;;	* RDX: max number of chars.
biToString:

;; Writes byte %3 to [%1 + %2].
%macro write_byte 3
	mov	byte [%1 + %2], %3
	inc	%2
%endmacro

;; Increments %1 and jumps to .done if %1 >= %2.
%macro check_limits 2
	cmp	%1, %2
	jge	.done
%endmacro

%macro save_regs 0
	push	rdi
	push	rsi
	push	rcx
	push	rdx
%endmacro

%macro restore_regs 0
	pop	rdx
	pop	rcx
	pop	rsi
	pop	rdi
%endmacro

	push	rdi
	push	rsi
	push	rdx

;; RCX holds number of already written bytes.
;; Dec RDX to reserve space for terminator.
	xor	rcx, rcx
	dec	rdx

	check_limits rcx, rdx

	cmp	qword [rdi + Bigint.sign], SIGN_MINUS
	jne	.first_digit

	write_byte rsi, rcx, '-'
	check_limits rcx, rdx

;; stack: | LIMIT | *BUFFER | *BIGINT | ...

.first_digit:
	save_regs
	vector_back [rdi + Bigint.vector]
	restore_regs

.check_zero:
	cmp	rax, 0
	jne	.non_zero

	write_byte rsi, rcx, '0'
	jmp	.done

.non_zero:

	push	rbx
	push	rdx

	mov	rbx, BASE / 10

.first_digit_loop:
	xor	rdx, rdx
	div	rbx

	cmp	rax, 0
	je	.skip_write

	add	rax, 48

	;write_byte rsi, rcx, rax
	mov	[rsi + rcx], al
	inc	rcx

.skip_write:
	div10	rbx

	mov	rax, rdx

	mov	rdx, [rsp]

; "Pop" regs for proper check_limits work
	add	rsp, 16
	check_limits rcx, rdx
	sub	rsp, 16

	cmp	rax, 0
	jg	.first_digit_loop

.first_digit_done:
	pop	rdx
	pop	rbx

.rest_digits:
	save_regs
	vector_size [rdi + Bigint.vector]
	mov	r8, rax
	restore_regs

	sub	r8, 2
	cmp	r8, 0
	jl	.done
.cur_digit:
	save_regs
	vector_get [rdi + Bigint.vector], r8
	restore_regs

	push	rbx
	push	rdx

	mov	rbx, BASE / 10

	mov	r9, BASE_LEN
.cur_digit_loop:
	dec	r9
	xor	rdx, rdx
	div	rbx

	add	rax, 48

	write_byte rsi, rcx, al

	div10	rbx

	mov	rax, rdx

	mov	rdx, [rsp]
; "Pop" regs for proper check_limits work
	add	rsp, 16
	check_limits rcx, rdx
	sub	rsp, 16

	cmp	r9, 0
	jg	.cur_digit_loop

.cur_digit_done:
	pop	rdx
	pop	rbx

	dec	r8
	cmp	r8, 0
	jge	.cur_digit

.done:
	write_byte rsi, rcx, 0
	pop	rdx
	pop	rsi
	pop	rdi

	ret


;; int biCmp(BigInt a, BigInt b);
;;
;; Compares two Bigints.
;; Takes:
;;	* RDI: pointer to first Bigint.
;;	* RSI: pointer to secont Bigint.
;; Returns:
;;	* RAX: -1 if a < b
;; 	        0 if a = b
;;	        1 if a > b
biCmp:
	mov		rax, [rdi + Bigint.sign]
	mov		rdx, [rsi + Bigint.sign]
	cmp		rax, rdx
	jl		.lt
	jg		.gt
	cmp		rax, SIGN_ZERO
	je		.eq

;; Either -/- or +/+
	mpush		rdi, rsi, rdx
	call		biCmpAbs
	mpop		rdi, rsi, rdx

	cmp		rdx, SIGN_MINUS
	je		.both_negative

.both_positive:
	cmp		rax, SIGN_MINUS
	je		.lt
	cmp		rax, SIGN_ZERO
	je		.eq
	jmp		.gt

.both_negative:
	cmp		rax, SIGN_MINUS
	je		.gt
	cmp		rax, SIGN_ZERO
	je		.eq
	jmp		.lt

.lt:
	mov		rax, SIGN_MINUS
	jmp		.done
.gt:
	mov		rax, SIGN_PLUS
	jmp		.done
.eq:
	mov		rax, SIGN_ZERO
	jmp		.done

.done:
	ret

;; int biCmpAbs(BigInt a, BigInt b);
;;
;; Compares two Bigints by absolute value.
;; Takes:
;;	* RDI: pointer to first Bigint.
;;	* RSI: pointer to secont Bigint.
;; Returns:
;;	* RAX: -1 if |a| < |b|
;; 	        0 if |a| = |b|
;;	        1 if |a| > |b|
biCmpAbs:
	mpush		rdi, rsi
	vector_size	[rsi + Bigint.vector]
	mov		rdx, rax
	mpop		rdi, rsi

	mpush		rdi, rsi
	vector_size	[rdi + Bigint.vector]
	mpop		rdi, rsi

	cmp		rax, rdx
	jl		.lt
	jg		.gt

	mov		rcx, rax
	dec		rcx
.digit_loop:
	mpush		rdi, rsi, rcx
	vector_get	[rsi + Bigint.vector], rcx
	mov		rdx, rax
	mpop		rdi, rsi, rcx

	mpush		rdi, rsi, rcx, rdx
	vector_get	[rdi + Bigint.vector], rcx
	mpop		rdi, rsi, rcx, rdx

	cmp		rax, rdx
	jl		.lt
	jg		.gt

	dec		rcx
	cmp		rcx, 0
	jl		.eq
	jmp		.digit_loop

.lt:
	mov		rax, SIGN_MINUS
	jmp		.done
.gt:
	mov		rax, SIGN_PLUS
	jmp		.done
.eq:
	mov		rax, SIGN_ZERO
	jmp		.done

.done:
	ret
