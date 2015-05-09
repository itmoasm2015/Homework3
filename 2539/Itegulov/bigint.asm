default rel

%include "ivector.inc"

;;; bigint structure
struc bigint
.sign: resq 1   ; sign of bigint
.vector: resq 1 ; vector, containing elements of 
endstruc

;;; bigint is stored as vector of uint64, no leading zeros are allowed.
;;; Sign of bigint is qword for alignment.

extern malloc
extern free

extern vecNew
extern vecAlloc
extern vecFree
extern vecEnsureCapacity
extern vecPush

global biFromInt
global biFromString
global biDelete
global biAdd
global biSub
global biMul
global biCmp
global biSign
global biToString
global biDivRem

;;; bigint biAlloc(uint64 length)
;;; Allocates new bigint with specified length (in qwords).
biAlloc:
	enter 0, 0
	
	push rdi
	mov rdi, bigint_size
	call malloc   ; allocate bigint structure
	pop rdi

	test rax, rax
	jz .ret      ; if bigint malloc failed, then return NULL

	push rax
	call vecAlloc ; allocate vector for bigint
	pop rdi

	test rax, rax
	jz .failed      ; if vector malloc failed, then free bigint and return NULL
	
	mov [rdi + bigint.vector], rax

	mov rax, rdi
.ret
	leave
	ret

.failed
	call free
	xor rax, rax
	jmp .ret

;;; bigint biFromInt(uint64 value)
;;; Creates simple bigint, representing value.
biFromInt:
	enter 0, 0
	push rdi
	mov rdi, 1
	call biAlloc
	pop rdi
	test rax, rax
	jz .ret
	
	mov rsi, rdi
	shr rsi, 63     ; remove all bit, excluding sign bit
	mov [rax + bigint.sign], rsi
	
.abs
	neg rdi
	js .abs         ; rdi = abs(rdi)

	mov rdx, [rax + bigint.vector]
	mov rcx, [rdx + vector.data]
	mov [rcx], rdi
	test rdi, rdi
	jne .ret
	dec qword [rdx + vector.size]
.ret
	leave 
	ret

