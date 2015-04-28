extern aligned_alloc
extern free

global vecNew
global vecAlloc
global vecFree
global vecPush
global vecResize
global vecSize
global vecCapacity
global vecGet
global vecSet

section .text

%define DEFAULT_CAPACITY 8 ; must be multiple of 4

;;; vector* vecNew()
;;; Allocates new empty vector with defaul capacity.
;;;
;;; vector* vecAlloc(uint64 size);
;;; Allocates new vector with specified capacity.
vecNew:
	mov rdi, DEFAULT_CAPACITY
vecAlloc:
	lea rsi, [rdi * 4 + 16]
	push rdi
	mov rdi, 16
	call aligned_alloc
	pop rdi
	mov [rax], dword 0
	mov [rax + 8], rdi
	ret

;;; void vecFree(vector* vec)
;;; Frees memory, occupied by specified vector.
vecFree:
	call free
	ret

;;; void vecCopy(vector* dest, vector* src)
;;; Copies elements of second vector to first vector.
;;; Capacity of second vector is ignored.
vecCopy:
	mov rcx, [rsi]
	add rdi, 16
	add rsi, 16
	cld
	rep movsd
	ret

;;; vector* vecPush(vector* vec, uint32 value);
;;; Adds element to the end of vec and resizes it if
;;; it's necessary. Returns resulting vector.
vecPush:
	push rsi
	mov rsi, [rdi]
	inc rsi
	push rsi
	call vecResize
	pop rdx
	pop rsi
	lea rdx, [rdx * 4 + 16 - 4]
	mov [rax + rdx], rsi
	ret

;;; vector* vecResize(vector* vec, uint64 new_size)
;;; Sets new 
vecResize:
	; TODO: implement	
	ret

;;; int vecCapacity()
;;; Returns vector's capacity (possible count of elements).
vecCapacity:
	mov rax, [rdi + 8]
	ret

;;; int vecSize()
;;; Returns vector's size (count of elements).
vecSize:
	mov rax, [rdi]
	ret

;;; int vecGet(vector* vec, uint64 index);
;;; Returns value of index's element in vector
vecGet:
	mov eax, [rdi + rsi * 4 + 16]
	ret

;;; void vecSet(vector* vec, uint64 index, int value)
;;; Sets value of index's element in vector to specified value 
vecSet:
	mov [rdi + rsi * 4 + 16], edx
	ret
