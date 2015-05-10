
default rel

; vector structure
; your typical vector with ensureCapacity and stuff
; stores qwords
struc vector
.size: resq 1
.capacity: resq 1
.data_ptr: resq 1
endstruc

section .text

extern malloc
extern memmove ; for me to think less
extern memcpy ; may work faster than rep movsb because sse
extern free
extern abort ; for illegal states from which we can't run

global vectorNew
global vectorNewSized
global vectorDelete
global vectorEnsureCapacity
global vectorPush
global vectorZeroExtend
global vectorRightShift

; vector vectorNew()
; creates new vector of zero size
; returns null on allocation failure
vectorNew:
	xor rdi, rdi

; vector vectorNewSized(uint64 size)
; creates new vector with given size and fills it with... trash.
; returns null on allocation failure
vectorNewSized:
	enter 0, 0
	push r12
	push r13
	
	mov r12, rdi ; r12: required size
	
	mov rdi, vector_size
	call malloc
	
	test rax, rax
	jz .ret ; return null if failed
	
	mov [rax + vector.size], r12 ; initialize fields
	mov [rax + vector.capacity], r12
	mov r13, rax ; r13: precious vector
	
	test r12, r12
	jz .zero_size ; if vector is of zero length, no storage will be allocated
	
	mov rdi, r12
	shl rdi, 3
	call malloc ; allocate storage
	
	test rax, rax
	jnz .ok
	
	mov rdi, r13 ; deallocate vector and return null on allocation failure
	call free
	jmp .ret
	
.zero_size:
	xor rax, rax ; this will be stored into data pointer
	
.ok:
	mov [r13 + vector.data_ptr], rax
	mov rax, r13 ; move vector to return register
	
.ret:
	pop r13
	pop r12
	leave
	ret

; void vectorDelete(vector)
; deletes vector and frees memory used by it
vectorDelete:
	enter 8, 0 ; 8 bytes for alignment
	push r12
	
	mov r12, rdi ; r12: stored vector
	mov rdi, [rdi + vector.data_ptr]
	call free ; free data (assuming free(0) does nothing)
	
	mov rdi, r12
	call free ; free vector itself
	
	pop r12
	leave
	ret

; void vectorEnsureCapacity(vector, uint64 count)
; makes sure there is storage for at least count elements
; calls abort() if unable to allocate memory
vectorEnsureCapacity:
	enter 0, 0
	push r12
	push r13
	
	mov rax, [rdi + vector.capacity]
	cmp rax, rsi
	
	ja .ret ; if the vector already has enough space, return
	
	shl rsi, 1 ; double requested size for vectorPush use and to achive amortized O(1) per operation
	mov r12, rdi ; r12: vector
	mov r13, rsi ; r13: requested size
	
	shl rsi, 3
	mov rdi, rsi
	call malloc
	
	test rax, rax
	jz abort ; abort if allocation has failed - there is no other way to signal the error
	
	mov [r12 + vector.capacity], r13 ; update capacity
	
	mov r13, rax ; r13: now new data pointer
	
	mov rsi, [r12 + vector.data_ptr]
	mov rdi, rax
	mov rdx, [r12 + vector.size]
	shl rdx, 3
	
	call memcpy ; copy old data to new storage
	
	mov rdi, [r12 + vector.data_ptr]
	call free ; delete old storage
	
	mov [r12 + vector.data_ptr], r13 ; move new storage into field
	
.ret
	pop r13
	pop r12
	leave
	ret

; void vectorPush(vector, uint64 value)
; appends given value to the end of a vector
vectorPush:
	enter 0, 0
	push r12
	push r13
	
	mov r12, rdi ; r12: vector
	mov r13, rsi ; r13: value
	
	mov rsi, [rdi + vector.size]
	inc rsi
	call vectorEnsureCapacity ; make sure vector has space for new element
	
	mov rdi, [r12 + vector.data_ptr]
	mov rsi, [r12 + vector.size] ; load data pointer and size into registers
	
	mov [rdi + 8 * rsi], r13 ; store the element
	inc rsi
	mov [r12 + vector.size], rsi ; store increased data pointer
	
	pop r13
	pop r12
	leave
	ret

; void vectorZeroExtend(vector, uint64 size)
; makes sure there is at least size capacity, and that elements beyound vector size are zeroes
vectorZeroExtend:
	enter 0, 0
	push r12
	push r13
	
	mov r12, rdi ; r12: vector
	mov r13, rsi ; r13: required size
	call vectorEnsureCapacity ; make sure that there is enough capacity
	
	mov rcx, [r12 + vector.size]
	mov rdx, rcx
	
	cmp rcx, r13
	jae .ret ; if there is enough size, nothing to do
	
	sub r13, rcx ; calculate how many elements need zeroing
	xchg r13, rcx
	
	xor rax, rax
	mov rdi, [r12 + vector.data_ptr]
	lea rdi, [rdi + rdx * 8]
	
	cld
	rep stosq ; zero out rcx elements after size
	; would memset be faster?
	
.ret:
	pop r13
	pop r12
	leave
	ret

; void vectorRightShift(vector, uint64 count)
; if vector is empty, does nothing
; otherwise adds count zeroes to the beginning
vectorRightShift:
	test rsi, rsi
	
	jnz .not_zero ; nothing to do if shift is zero
	ret
	
.not_zero
	enter 0, 0
	push r12
	push r13
	
	mov r12, rdi ; r12: vector
	mov r13, rsi ; r13: requested shift
	
	mov rcx, [rdi + vector.size]
	test rcx, rcx
	jz .ret ; if vector is of size zero, nothing to do
	
	add rcx, rsi ; calculate new required size
	
	mov rax, [rdi + vector.capacity]
	cmp rcx, rax
	jbe .no_extend ; check if capacity is enough
	; we avoid calling vectorEnsureCapacity here because we are copying data anyways,
	; and we want to avoid extra copies. division is already slow, no point in making it slower.
	
	; here we have copypasted code from vectorEnsureCapacity
	mov rdi, rcx
	shl rdi, 3 ; calculate new size in bytes
	
	call malloc
	test rax, rax
	jz abort ; abotr if new array can't be allocated
	
	mov r10, rax ; r10: new data
	mov rcx, r13
	
	mov rdi, rax
	xor rax, rax
	
	cld
	rep stosq ; zero out first requested amount of elements of new data
	
	mov rsi, [r12 + vector.data_ptr]
	mov rcx, [r12 + vector.size]
	mov rax, rcx ; copy size now to avoid copying it
	
	cld ; now copy the actual data
	rep movsq ; rdi is good since zero-wiping
	
	add rax, r13
	mov [r12 + vector.size], rax ; update the size
	
	mov rdi, [r12 + vector.data_ptr]
	mov [r12 + vector.data_ptr], r10 ; put new array in place
	
	call free ; delete old array
	
	jmp .ret
	
.no_extend: ; the case where we fit
	; this whole block calculates how to move the data inside of the buffer
	mov rdx, [rdi + vector.size]
	mov rsi, [rdi + vector.data_ptr]
	mov rax, rdx
	add rax, r13
	mov [rdi + vector.size], rax
	mov rdi, [rdi + vector.data_ptr]
	lea rdi, [rdi + r13 * 8]
	shl rdx, 3
	call memmove ; and this actually moves it. it's sure overlapping, so better avoid trouble
	
	mov rdi, [r12 + vector.data_ptr]
	mov rcx, r13
	xor rax, rax
	
	cld
	rep stosq ; and this just zeroes out the requested beginning
	
.ret
	pop r13
	pop r12
	leave
	ret

