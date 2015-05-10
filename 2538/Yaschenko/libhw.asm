default rel

%include "macros.mac"
%include "libhw.i"
%include "libmyvec.i"

extern vectorNew
extern vectorPushBack
extern vectorDelete
extern vectorSize
extern vectorBack
extern vectorGet
extern vectorSet
extern vectorEmpty
extern vectorPopBack
extern vectorCopy

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

global biGetVector


section .text

;; Bigint stores digits with 1e18 base.
%assign	BASE		1000000000000000000
%assign	BASE_LEN	18
%assign	SIGN_PLUS	1
%assign	SIGN_MINUS	-1
%assign	SIGN_ZERO	0


;; Creates new Bigint with empty vector and ZERO_SIGN.
;; Returns:
;;	* RAX: pointer to newly created Bigint.
biNew:
	mov	rdi, 0
	call	_biNew
	ret

;; Creates new Bigint with vector of size X.
;; Takes:
;;	* RDI: size X of vector.
;; Returns:
;;	* RAX: pointer to newly created Bigint.
_biNew:
;; Create vector of size X to store digits of Bigint.
	call	vectorNew
	push	rax

;; Allocates memory for BigInt struct.
	mov	rdi, 1
	mov	rsi, Bigint_size
	call	__calloc

	pop	rdx
	mov	[rax + Bigint.vector], rdx
	mov	qword [rax + Bigint.sign], SIGN_ZERO

	ret


biGetVector:
	mov		rax, [rdi + Bigint.vector]
	ret


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

;; BigInt biFromString(char const *s);
;;
;; Creates a Bigint from string.
;; Takes:
;;	* RDI: pointer to string.
;; Returns:
;;	* RAX: pointer to a newly created Bigint.
biFromString:
	mpush		rdi
	call		biNew
	mpop		rdi

	push		rax

	mov		qword [rax + Bigint.sign], SIGN_PLUS

	cmp		byte [rdi], '-'
	jne		.process_digits
	mov		qword [rax + Bigint.sign], SIGN_MINUS
	inc		rdi

.process_digits:
	mpush		rdi
	call		__strlen
	mpop		rdi

	cmp		rax, 0
	je		.bad_string

	mov		rcx, rax

.digits_loop:
	xor		r8, r8
	mov		rax, rcx
	sub		rax, BASE_LEN
	cmp		rax, 0
	jge		.one_digit
	xor		rax, rax
; R8: current digit.
.one_digit:
	xor		rdx, rdx
	mov		dl, [rdi + rax]
	cmp		dl, '0'
	jl		.bad_string
	cmp		dl, '9'
	jg		.bad_string
	sub		dl, '0'

	imul		r8, 10
	add		r8, rdx

	inc		rax
	cmp		rax, rcx
	jl		.one_digit

	mov		rdx, [rsp]
	mpush		rdi, rcx, rdx, r8
	vector_push_back	[rdx + Bigint.vector], r8
	mpop		rdi, rcx, rdx, r8

	sub		rcx, BASE_LEN
	cmp		rcx, 0
	jg		.digits_loop

.digits_done:
	mov		rdi, [rsp]
	call		_biTrimZeros
	pop		rax
	jmp		.done

.bad_string:
	pop		rdi
	call		biDelete
	xor		rax, rax

.done:
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

	call	__free
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

;; These macros are used only here, so don't move it to macros.

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

;; Flag if digits started.
	xor		r8, r8

.first_digit_loop:
	xor	rdx, rdx
	div	rbx

	cmp		r8, 0
	jne		.write_digit
	cmp	rax, 0
	je	.skip_write

.write_digit:
	mov		r8, 1
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

	cmp	rbx, 0
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
	mov		rdi, [rdi + Bigint.vector]
	mov		rsi, [rsi + Bigint.vector]
	call		_digsCmpAbs
	ret

;; Comapres two vectors as digits.
;;
;; Takes:
;;	* RDI: pointer to first vector.
;;	* RSI: pointer to second vector.
;; Retutrs:
;;	* RAX: -1 if |a| < |b|
;; 	        0 if |a| = |b|
;;	        1 if |a| > |b|
_digsCmpAbs:
	mpush		rdi, rsi
	vector_size	rsi
	mov		rdx, rax
	mpop		rdi, rsi

	mpush		rdi, rsi
	vector_size	rdi
	mpop		rdi, rsi

	cmp		rax, rdx
	jl		.lt
	jg		.gt

	mov		rcx, rax
	dec		rcx
.digit_loop:
	mpush		rdi, rsi, rcx
	vector_get	rsi, rcx
	mov		rdx, rax
	mpop		rdi, rsi, rcx

	mpush		rdi, rsi, rcx, rdx
	vector_get	rdi, rcx
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



;; void biMul(BigInt dst, BigInt src);
;;
;; Multiplies DST by SRC inplace.
;; Takes:
;;	* RDI: pointer to DST.
;;	* RSI: pointer to SRC.
biMul:
	mpush		r12, r13, r14, r15

	mov		rax, [rdi + Bigint.sign]
	mov		rdx, [rsi + Bigint.sign]

	cmp		rax, SIGN_ZERO
	je		.zero
	cmp		rdx, SIGN_ZERO
	je		.zero

.mul_signs:
	mov		rcx, rdx
	xor		rdx, rdx
	imul		rcx
	push		rax
	jmp		.start_mul

.zero:
	mpush		rdi, rsi
	vector_delete	[rdi + Bigint.vector]
	mpop		rdi, rsi

	mpush		rdi, rsi
	vector_new	0
	mpop		rdi, rsi

	mov		[rdi + Bigint.vector], rax
	mov		qword [rdi + Bigint.sign], SIGN_ZERO
	jmp		.done

.start_mul:
	mpush		rdi, rsi
	vector_size	[rsi + Bigint.vector]
	mov		r9, rax
	mpop		rdi, rsi

	mpush		rdi, rsi, r9
	vector_size	[rdi + Bigint.vector]
	mov		r8, rax
	mpop		rdi, rsi, r9

	mov		rcx, r8
	add		rcx, r9

	mpush		rdi, rsi, r8, r9
	bigint_new	rcx
	mpop		rdi, rsi, r8, r9

	mov		r15, rax
	pop		rax
	mov		[r15 + Bigint.sign], rax

;; R10: i loop counter.
	xor		r10, r10
.loop_i:
;; R11: j loop counter.
	xor		r11, r11
;; R12: carry
	xor		r12, r12
.loop_j:
	mov		rcx, r10
	add		rcx, r11
	push		rcx

	mpush		rdi, rsi
	vector_get	[r15 + Bigint.vector], rcx
	mpop		rdi, rsi

	push		rax
;; stack: c[i + j] | i + j | *C | ...

;; R13: a[i]
	mpush		rdi, rsi
	vector_get	[rdi + Bigint.vector], r10
	mov		r13, rax
	mpop		rdi, rsi

;; RAX: b[j]
	mpush		rdi, rsi
	vector_get	[rsi + Bigint.vector], r11
	mpop		rdi, rsi

;; RAX = a[i] * b[j]
	xor		rdx, rdx
	mul		r13

;; RAX = a[i] * b[j] + c[i + j]
	add		rax, [rsp]
	add		rsp, 8
;; stack: i + j | *C | ...
;; RAX = a[i] * b[j] + c[i + j] + CARRY
	add		rax, r12

;; RAX = RAX % BASE
;; RDX = RAX / BASE
	mpush		rbx
	mov		rbx, BASE
	idiv		rbx
	mpop		rbx

;; Update CARRY with new value.
	mov		r12, rax

	mpush		rdi, rsi
	;mov		rdi, [r15 + Bigint.vector]
	;mov		rsi, [rsp + 16]
	;mov		rdx, rax
	;call	vectorSet
	vector_set	[r15 + Bigint.vector], [rsp + 16], rdx
	mpop		rdi, rsi
	add		rsp, 8

	inc		r11

;; If CARRY > 0 do extra iteration.
	cmp		r12, 0
	jg		.loop_j

	cmp		r11, r9
	jl		.loop_j

	inc		r10
	cmp		r10, r8
	jl		.loop_i

.mul_done:
	push		rdi
	mov		rdi, r15
	call		_biTrimZeros
	pop		rdi

	push		rdi
	vector_delete	[rdi + Bigint.vector]
	pop		rdi

	mov		rdx, [r15 + Bigint.vector]
	mov		[rdi + Bigint.vector], rdx

	mov		rdx, [r15 + Bigint.sign]
	mov		[rdi + Bigint.sign], rdx

	mov		rdi, r15
	call		__free

.done:
	mpop		r12, r13, r14, r15
	ret

;; Removes leading zeros from Bigint.
;; Takes:
;;	* RDI: pointer to Bigint.
_biTrimZeros:
.loop:
	push		rdi
	vector_empty	[rdi + Bigint.vector]
	pop		rdi

	cmp		rax, 1
	je		.done

	push		rdi
	vector_back	[rdi + Bigint.vector]
	pop		rdi

	cmp		rax, 0
	jne		.done

	push		rdi
	vector_pop_back	[rdi + Bigint.vector]
	pop		rdi
	jmp		.loop

.done:
	ret


;; void biAdd(BigInt dst, BigInt src);
;;
;; Adds Bigint SRC to Bigint DST.
;; Takes:
;;	* RDI: pointer to DST.
;;	* RSI: pointer to SRC.
biAdd:
	mpush		r14, r15
	mov		rdx, [rsi + Bigint.sign]
	mov		rax, [rdi + Bigint.sign]
	cmp		rdx, SIGN_ZERO
	je		.done

;; Save signs.
	mpush		rax, rdx

	cmp		rax, SIGN_ZERO
	jne		.non_zero

.copy_dst_to_src:
	mpush		rdi, rsi
	vector_delete	[rdi + Bigint.vector]
	mpop		rdi, rsi

	mpush		rdi, rsi
	vector_copy	[rsi + Bigint.vector]
	mpop		rdi, rsi

	mov		[rdi + Bigint.vector], rax

	mov		rcx, [rsi + Bigint.sign]
	mov		[rdi + Bigint.sign], rcx

;; Forget signs.
	add		rsp, 16

	jmp		.done

.non_zero:
	mpop		rax, rdx

	cmp		rax, rdx
	jne		.signs_diff

.signs_equal:
	mpush		rdi, rsi
	bigint_add_digits	[rdi + Bigint.vector], [rsi + Bigint.vector]
	mpop		rdi, rsi
	jmp		.trim_zeros

.signs_diff:
	mpush		rdi, rsi, rax, rdx
	mov		rdi, [rdi + Bigint.vector]
	mov		rsi, [rsi + Bigint.vector]
	call		_biSubDigits
	mov		r14, rax
	mov		r15, rdx
	mpop		rdi, rsi, rax, rdx

	mpush		rdi, rsi, rax, rdx
	mov		rdi, [rdi + Bigint.vector]
	call		__free
	mpop		rdi, rsi, rax, rdx
	mov		[rdi + Bigint.vector], r14
;; sign
	imul		r15, [rdi + Bigint.sign]
	mov		[rdi + Bigint.sign], r15

.trim_zeros:
	call		_biTrimZeros

.done:
	mpop		r14, r15
	ret

;; void biSub(BigInt dst, BigInt src);
;;
;; Subtracts Bigint SRC from Bigint DST.
;; Takes:
;;	* RDI: pointer to DST.
;;	* RSI: pointer to SRC.
biSub:
	mov		rax, [rsi + Bigint.sign]
	cmp		rax, SIGN_ZERO
	je		.done
.do_sub:
	neg		qword [rdi + Bigint.sign]
	mpush		rdi, rsi
	call		biAdd
	mpop		rdi, rsi
	neg		qword [rdi + Bigint.sign]
.done:
	ret


;; void _biAddDigits(Vector dst, Vector src);
;;
;; Adds one Bigint's digits to another's.
;; Takes:
;;	* RDI: pointer to DST.
;;	* RSI: pointer to SRC.
_biAddDigits:
;; Carry
	mpush		rdi, rsi
	vector_size	rsi
	mov		rdx, rax
	mpop		rdi, rsi

	mpush		rdi, rsi, rdx
	vector_size	rdi
	mpop		rdi, rsi, rdx


;; R10: max(DST.size(), SRC.size())
	mov		r10, rax
	cmp		rdx, rax
	jng		.pre_add_loop
	mov		r10, rdx

	mpush		rdi, rsi, rax, rdx, r10
	mov		rcx, r10
	sub		rcx, rax
;; Add extra 0 for possible carry.
	inc		rcx
.push_back_loop:
	dec		rcx

	mpush		rdi, rcx
	vector_push_back	rdi, 0
	mpop		rdi, rcx

	loop		.push_back_loop

	mpop		rdi, rsi, rax, rdx, r10

.pre_add_loop:
;; R8: loop counter
	xor		r8, r8
;; R9: carry
	xor		r9, r9
.add_loop:
	mpush		rdi, rsi, r8, r9, r10
	vector_get	rsi, r8
	mov		rdx, rax
	mpop		rdi, rsi, r8, r9, r10

	mpush		rdi, rsi, r8, r9, r10
	vector_get	rdi, r8
	mpop		rdi, rsi, r8, r9, r10

	add		rax, rdx
	add		rax, r9

	push		rcx
	mov		rcx, BASE
	xor		r9, r9
	cmp		rax, rcx
	jnge		.set_and_next

	mov		r9, 1
	sub		rax, rcx

.set_and_next:
	pop		rcx
	mpush		rdi, rsi, r8, r9, r10
	vector_set	rdi, r8, rax
	mpop		rdi, rsi, r8, r9, r10

	inc		r8
	cmp		r9, 0
	jg		.add_loop
	cmp		r8, r10
	jl		.add_loop
.done:
	ret


;; void _biSubDigits(Vector src, Vector dst)
;;
;; Subtracts DST from SRC.
;; Takes:
;;	* RDI: pointer to SRC.
;;	* RSI: pointer to DST.
;; Returns:
;;	* RAX: pointer to result
;;	* RDX: -1 if SRC < DST
;;	        1 otherwise
_biSubDigits:
	mpush		r15
	mpush		rdi, rsi
	call		_digsCmpAbs
	mpop		rdi, rsi
	push		rax

	cmp		rax, SIGN_ZERO
	jge		.start_sub

	xchg		rdi, rsi

.start_sub:
	mov		rax, [rdi + Vector.size]
	mov		rdx, [rsi + Vector.size]
	mov		rcx, rax
	cmp		rcx, rdx
	cmovl		rcx, rdx

	mpush		rdi, rsi, rcx
	vector_new	rcx
	mpop		rdi, rsi, rcx
	mov		r15, rax

	xor		r8, r8
	xor		r9, r9
.loop_sub:
	mpush		rcx, r9

	mpush		rdi, rsi, r8
	vector_get	rsi, r8
	mov		rdx, rax
	mpop		rdi, rsi, r8

	mpush		rdi, rsi, r8, rdx
	vector_get	rdi, r8
	mpop		rdi, rsi, r8, rdx

	mpop		rcx, r9

	sub		rax, rdx
	sub		rax, r9
	xor		r9, r9

	cmp		rax, 0
	jge		.set_digit

	mov		r9, 1
	push		rbx
	mov		rbx, BASE
	add		rax, rbx
	pop		rbx

.set_digit:
	mpush		rdi, rsi, r8, r9, rcx
	vector_set	r15, r8, rax
	mpop		rdi, rsi, r8, r9, rcx

	inc		r8
	loop		.loop_sub

.sub_done:
	pop		rdx
	mov		rax, r15

	mpop		r15
	ret


;; Makes a copy of Bigint.
;; Takes:
;;	* RDI: pointer to Bigint.
;; Returns:
;;	* RAX: pointer to a newly created copy.
biCopy:
	push		rdi
;; Allocates memory for BigInt struct.
	mov		rdi, 1
	mov		rsi, Bigint_size
	call		__calloc
	pop		rdi
	push		rax
;; Make a copy of vector.
	push		rdi
	call		vectorCopy
	pop		rdi

	pop		rdx
	mov		rcx, [rdi + Bigint.sign]
	mov		[rdx + Bigint.sign], rcx
	mov		[rdx + Bigint.vector], rax

	mov		rax, rdx

	ret


;; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
;;
;; Compute QUOTIENT and REMAINDER by divising NUMBERATOR by DENOMINATOR.
;; QUOTIENT * DENOMINATOR + REMAINDER = NUMBERATOR
;;
;; REMAINDER must be in range [0, DENOMINATOR) if DENOMINATOR > 0
;;                        and (DENOMINATOR, 0] if DENOMINATOR < 0.
;; Takes:
;;	* RDI: pointer to QUOTIENT.
;;	* RSI: pointer to REMAINDER.
;;	* RDX: pointer to NUMBERATOR.
;;	* RCX: pointer to DENOMINATOR.
biDivRem:
	ret