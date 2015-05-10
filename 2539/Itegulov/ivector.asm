extern malloc
extern memcpy
extern free

global vecNew
global vecAlloc
global vecFree
global vecPush
global vecSet
global vecGet
global vecSize
global vecCapacity

default rel

%include "ivector.inc"

section .text

%define DEFAULT_CAPACITY 0 ; must be multiple of 4

;;; vector* vecNew()
;;; Allocates new vector with default capacity and size.
;;;
;;; vector* vecAlloc(uint64 size);
;;; Allocates new vector with specified size.
;;;
;;; (Capacity is equal to size after this function)
vecNew:
	mov rdi, DEFAULT_CAPACITY
vecAlloc:
	enter 0, 0
	push rdi
	mov rdi, vector_size
	call malloc ; allocate vector structure
	pop rdi
	test rax, rax
	jz .ret ; return NULL if malloc failed

	mov [rax + vector.size], rdi
	mov [rax + vector.capacity], rdi

	mov rsi, rax ; store vector structure
	
	test rdi, rdi
	jz .zero_size
	
	push rsi
	shl rdi, 3
	call malloc
	pop rsi

	test rax, rax
	jnz .success

	mov rdi, rsi
	call free
	jmp .ret ; return NULL if malloc of data failed

.zero_size
	xor rax, rax
.success
	mov [rsi + vector.data], rax
	mov rax, rsi
.ret
	leave
	ret

;;; void vecFree(vector* vec)
;;; Frees memory, occupied by specified vector.
vecFree:
	push rdi
	mov rdi, [rdi + vector.data]
	call free
	pop rdi	
	call free
	ret

;;; void vecEnsure(vector* vec, uint64 size)
;;; Makes sure, that there is enough capacity for specified
;;; size.
vecEnsure:
	enter 0, 0
	push r12
	push r13
	cmp [rdi + vector.capacity], rsi
	ja .ret ; if vector's capacity is greater, than needed
	
	shl rsi, 1 ; allocate twice as needed memory
	push rdi
	push rsi
	
	shl rsi, 3 ; multiply by qword's size
	mov rdi, rsi
	call malloc
	; TODO: check for result of malloc
	pop rsi
	pop rdi
	
	mov [rdi + vector.capacity], rsi
	mov r13, rax
	mov r12, rdi
	
	mov rsi, [r12 + vector.data]
	mov rdi, rax
	mov rdx, [r12 + vector.size]
	shl rdx, 3

	call memcpy ; copy old data to new storage

	mov rdi, [r12 + vector.data]
	call free

	mov [r12 + vector.data], r13

.ret
	pop r13
	pop r12
	leave
	ret

;;; void vecPush(vector* vec, uint64 value)
;;; Adds value to end of vec and resizes it if neccessary.
vecPush:
	enter 0, 0
	push rdi
	push rsi
	mov rsi, [rdi + vector.size]
	inc rsi
	call vecEnsure
	pop rsi
	pop rdi
	mov rdx, [rdi + vector.size]
	mov r8, [rdi + vector.data]
	mov [r8 + 8 * rdx], rsi
	inc rdx
	mov [rdi + vector.size], rdx
	leave
	ret

;;; uint64 vecGet(vector* vec, uint64 index)
;;; Gets indexth element in vector.
vecGet:
	enter 0, 0
	mov rdx, [rdi + vector.data]
	mov rax, [rdx + rsi * 8]
	leave
	ret

;;; void vecSet(vector* vec, uint64 index, uint64 value)
;;; Sets indexth element in vector to value.
vecSet:
	enter 0, 0
	mov r8, [rdi + vector.data]
	mov [r8 + rsi * 8], rdx
	leave
	ret

;;; uint64 vecSize(vector* vec)
;;; Gets vector real size.
vecSize:
	enter 0, 0
	mov rax, [rdi + vector.size]
	leave
	ret

;;; uint64 vecCapacity(vector* vec)
;;; Gets vector's maximal elements count.
vecCapacity:
	enter 0, 0
	mov rax, [rdi + vector.capacity]
	leave
	ret

;;; void vecExtend(vector* vec, uint64 size)
;;; Ensures, that vec has at least size elements (adds zeros if neccessary).
vecExtend:
	enter 0, 0

	push rdi
	push rsi
	call vecEnsure
	pop rsi
	pop rdi

	mov rcx, [rdi + vector.size]
	mov rdx, rcx

	cmp rcx, rsi
	jae .ret      ; if there was enough space, than just return

	sub rsi, rcx
	xchg rsi, rcx

	xor rax, rax
	mov rdi, [rdi + vector.data]
	lea rdi, [rdi + rdx * 8]
	cld
	rep stosq     ; zeroing added elements
.ret
	leave
	ret


