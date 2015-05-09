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
	enter 8, 0
	
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
	enter 8, 0
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

;;; void biDelete(bigint* big)
;;; Deletes allocated bigint, freeing all memory, used by it.
biDelete:
	enter 8, 0
	push rdi
	mov rdi, [rdi + bigint.vector]
	call vecFree
	pop rdi
	call free
	leave
	ret

;;; void biUAddShort(bitint* big, uint64 val)
;;; Adds val to big. Assumes, that val is unsigned.
biUAddShort:
	enter 0, 0
	
	test rsi, rsi
	jz .ret	

	mov rdi, [rdi + bigint.vector]
	mov rcx, [rdi + vector.size]

	test rcx, rcx
	jnz .add       ; if bigint is empty, than just push value to it

	call vecPush
	jmp .ret

.add
	mov r8, [rdi + vector.data]
	mov rdx, [r8]

	add rdx, rsi
	mov [r8], rdx  ; added val to lowest part and set cf

	jnc .ret       ; if cf == 0, then just return

	dec rcx
	jrcxz .done    ; if bigint has not enough space, than let's create new digit
.loop
	add r8, 8
	mov rdx, [r8]  ; get current digit
	add rdx, 1     ; inc doesn't set cf, so let's add 1
	mov [r8], rdx  ; write result

	jnc .ret       ; if cf == 0, then just return

	loop .loop
	; FIXME: IT'S BUGGY, NO?!
.done
	mov rsi, 1     ; if we have cf == 1, then let's push it to the end
	call vecPush 

.ret
	leave
	ret


