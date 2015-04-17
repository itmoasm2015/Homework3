default rel

extern calloc
extern free
extern memcpy

global vectorNew
global vectorDelete
global vectorPushBack
global vectorGet
global vectorSet

%assign	DEFAULT_CAPACITY	4
%assign ELEM_SIZE		4

%macro round_next_2_power 1
	dec	%1
	or	%1, 1
	or	%1, 2
	or	%1, 4
	or	%1, 8
	or	%1, 16
	inc	%1
%endmacro

struc Vector
	.data		resq	1
	.size		resq	1
	.capacity	resq	1
endstruc

;; Vector vectorNew(size_t size);
;;
;; Creates a vector that can hold at least SIZE elements.
;; Takes:
;;	* RDI: size of vector.
;; Returns:
;;	* RAX: pointer to newly created vector.
vectorNew:
	push	rdi
	mov	rdi, 1
	mov	rsi, Vector_size
	call	calloc
	mov	rdx, rax
	pop	rdi

	round_next_2_power	rdi
	mov	rsi, ELEM_SIZE
	call	calloc

	mov	[rdx + Vector.data], rax
	mov	[rdx + Vector.capacity], rdi
	mov	qword [rdx + Vector.size], 0

	mov	rax, rdx
	ret

;; void vectorDelete(Vector v);
;;
;; Deletes vector.
;; Takes:
;;	* RDI: pointer to vector.
vectorDelete:
	push	rdi
; Free array of elements.
	mov	rdi, [rdi + Vector.data]
	call	free
; Free vector struct memory.
	pop	rdi
	call	free
	ret

;; Ensures that one extra element can be added.
;; If there is no space for extra element, doubles VECTOR's capacity.
;;
;; Takes:
;;	RDI: pointer to VECTOR.
vectorEnsureCapacity:
	mov	rax, [rdi + Vector.size]
	cmp	rax, [rdi + Vector.capacity]
; if SIZE < CAPACITY then nothing to do here.
	jl	.done
.enlarge:
	push	rdi
; RDI stores new capacity, which is 2 times more than previous.
	mov	rdi, [rdi + Vector.capacity]
	shl	rdi, 1
	mov	rsi, ELEM_SIZE
; Allocate memory for new array.
	call	calloc
; Save pointer to memory.
	push	rax

; Copy elements from old array to newly created with memcpy.
; 1st parameter: dst
	mov	rdi, rax
; 2nd parameter: src
	mov	rax, [rsp + 8]
	mov	rsi, [rax + Vector.data]
; 3rd parameter: count
	mov	rdx, [rax + Vector.capacity]

	call	memcpy

	mov	rax, [rsp + 8]
; Delete old array.
	mov	rdi, [rax + Vector.data]
	call	free

; Restore pointer to new array.
	pop	rdx
; And save it to vector.
	mov	[rax + Vector.data], rdx
; Update capacity.
	shl	qword [rax + Vector.capacity], 1
.done:
	ret

;; unsigned vectorGet(Vector v, size_t index);
;;
;; Returns INDEX'th element of VECTOR, or 0 if INDEX is out of bounds.
;; Takes:
;;	* RDI: pointer to VECTOR.
;;	* RSI: INDEX
;; Returns:
;;	* RAX: INDEX'th element of VECTOR.
vectorGet:
	cmp	rsi, 0
	jl	.out_of_bounds
	cmp	rsi, [rdi + Vector.size]
	jge	.out_of_bounds

	mov	rax, [rdi + Vector.data]
	mov	rax, [rax + rsi * ELEM_SIZE]

	ret
.out_of_bounds:
	xor	rax, rax
	ret

;; void vectorSet(Vector v, size_t index, unsigned element);
vectorSet:
	


