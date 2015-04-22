default rel

extern calloc
extern free

extern vectorNew
extern vectorPushBack
extern vectorDelete
extern vectorSize

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


%macro push_back 2
	push	rdi
	push	rsi
	mov	rdi, %1
	mov	rsi, %2
	call	vectorPushBack
	pop	rsi
	pop	rdi
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
	push_back	[r8 + Bigint.vector], rdx
	pop	rax
	mov	rdi, rax

	cmp	rdi, 0
	je	.done
	jmp	.div_loop

.zero:
	push_back	[r8 + Bigint.vector], 0

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
	push	rdi
	push	rsi
	push	rdx

	xor	rcx, rcx

	cmp	rcx, rdx
	jge	.done

	cmp	[rdi + Bigint.sign], SIGN_MINUS
	jne	.first_digit

	mov	byte [rsi + rcx], '-'
	inc	rcx

;; stack: | LIMIT | *BUFFER | *BIGINT | ...

.first_digit:
	push	rcx
	call	vectorBack

	



.digit_loop:
	call	vectorSize

	cmp	rax, 2

.done:
	ret


;; Writes char %2 to buffer %1.
%macro write_to_buf 2

%endmacro



