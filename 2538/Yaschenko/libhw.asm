default rel

extern calloc
extern free

extern vectorNew
extern vectorPushBack
extern vectorDelete
extern vectorSize
extern vectorBack

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
%assign BASE_LEN	9
%assign SIGN_PLUS	1
%assign SIGN_MINUS	-1

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
	mov	qword [rax + Bigint.sign], SIGN_PLUS

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

	cmp	rdi, 0
	jge	.zero_check

.negative:
	mov	qword [r8 + Bigint.sign], SIGN_MINUS
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
	vector_push_back	[r8 + Bigint.vector], 0

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

; RCX holds number of already written bytes.
	xor	rcx, rcx

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

	push	rbx
	push	rdx

	mov	rbx, BASE / 10
;%assign	i BASE/10
;%rep	BASE_LEN
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
	check_limits rcx, rdx

	cmp	rax, 0
	jg	.first_digit_loop
;%assign i i/10
;%endrep
.first_digit_done:
	pop	rdx
	pop	rbx

.digit_loop:


.done:
	pop	rdx
	pop	rsi
	pop	rdi

	ret



