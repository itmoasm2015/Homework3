default rel

extern calloc
extern free
extern memcpy

global vectorNew
global vectorDelete
global vectorPushBack
global vectorGet
global vectorSet
global vectorSize
global vectorPushBack
global vectorBack
global vectorCapacity
global vectorPopBack

%assign	DEFAULT_CAPACITY	8
%assign ELEM_SIZE		4

;; Round up to the next highest power of 2.
;; See https://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2
%macro round_next_2_power 1
	push	rax
	dec	%1
	mov	rax, %1

	shr	rax, 1
	or	%1, rax

	shr	rax, 1
	or	%1, rax

	shr	rax, 2
	or	%1, rax

	shr	rax, 4
	or	%1, rax

	shr	rax, 8
	or	%1, rax

	inc	%1
	pop	rax
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
	cmp	rdi, DEFAULT_CAPACITY
	jge	.round_up

	mov	rdi, DEFAULT_CAPACITY

.round_up:
	round_next_2_power rdi
	push	rdi
	mov	rsi, ELEM_SIZE
	call	calloc
	push	rax

	mov	rdi, 1
	mov	rsi, Vector_size
	call	calloc

	pop	rdx
	mov	[rax + Vector.data], rdx

	pop	rdx
	mov	[rax + Vector.capacity], rdx

	pop	rdx
	mov	[rax + Vector.size], rdx

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
; stack: | *NEWDATA | *VECTOR | ...

; Copy elements from old array to newly created with memcpy.
; 1st parameter: dst
	mov	rdi, rax
; 2nd parameter: src
	mov	rax, [rsp + 8]
	mov	rsi, [rax + Vector.data]
; 3rd parameter: count
	mov	rdx, [rax + Vector.capacity]
	imul	rdx, ELEM_SIZE

	call	memcpy

	mov	rax, [rsp + 8]
; Delete old array.
	mov	rdi, [rax + Vector.data]
	call	free

; Restore pointer to new array.
	pop	rdx
; And save it to vector.
	pop	rdi
	mov	[rdi + Vector.data], rdx
; Update capacity.
	shl	qword [rdi + Vector.capacity], 1
.done:
	ret

;; unsigned vectorGet(Vector v, size_t index);
;;
;; Returns INDEX'th element of VECTOR, or 0 if INDEX is out of bounds.
;; Takes:
;;	* RDI: pointer to VECTOR.
;;	* RSI: INDEX
;; Returns:
;;	* RAX: INDEX'th element of VECTOR, or 0 if index is out of bounds.
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


;; unsigned vectorBack(Vector v);
;;
;; Returns last element of VECTOR, or zero if vector is empty.
;; Takes:
;;	* RDI: pointer to VECTOR.
;; Returns:
;;	* RAX: last element of VECTOR.
vectorBack:
	mov	rsi, [rdi + Vector.size]
	cmp	rsi, 0
	jle	.out_of_bounds
	dec	rsi

	mov	rdi, [rdi + Vector.data]
	mov	rax, [rdi + rsi * ELEM_SIZE]

	ret
.out_of_bounds:
	xor	rax, rax
	ret

;; void vectorSet(Vector v, size_t index, unsigned element);
;;
;; Sets INDEX'th element of VECTOR to ELEMENT. Does nothing if INDEX is out of bounds.
;; Takes:
;;	* RDI: pointer to VECTOR.
;;	* RSI: INDEX.
;;	* RDX: value of ELEMENT.
vectorSet:
	cmp	rsi, 0
	jl	.out_of_bounds
	cmp	rsi, [rdi + Vector.size]
	jge	.out_of_bounds

	mov	rax, [rdi + Vector.data]
	mov	[rax + rsi * ELEM_SIZE], rdx

	ret
.out_of_bounds
	ret

;;size_t vectorSize(Vector v);
;;
;; Returns size of VECTOR.
;; Takes:
;;	* RDI: pointer to VECTOR.
;; Returns:
;;	* RAX: size of VECTOR.
vectorSize:
	mov	rax, [rdi + Vector.size]
	ret

;;size_t vectorCapacity(Vector v);
;;
;; Returns capacity of VECTOR.
;; Takes:
;;	* RDI: pointer to VECTOR.
;; Returns:
;;	* RAX: capacity of VECTOR.
vectorCapacity:
	mov	rax, [rdi + Vector.capacity]
	ret


;; void vectorPushBack(Vector v, unsigned element);
;;
;; Adds ELEMENT at the end of VECTOR.
;; Vector automatically grows up in size if there is no space to store ELEMENT.
;; Takes:
;;	* RDI: pointer to VECTOR.
;;	* RSI: value of ELEMENT.
vectorPushBack:
	push	rdi
	push	rsi
	call	vectorEnsureCapacity
	pop	rsi
	pop	rdi

	mov	rax, [rdi + Vector.data]
	mov	rcx, [rdi + Vector.size]
	mov	[rax + rcx * ELEM_SIZE], rsi
	inc	rcx
	mov	[rdi + Vector.size], rcx

	ret


;; void vectorPopBack(Vector v);
;;
;; Pops last element from VECTOR.
;; Takes:
;;	* RDI: pointer to VECTOR.
vectorPopBack:
	mov	rsi, [rdi + Vector.size]
	cmp	rsi, 0
	jle	.out_of_bounds

	dec	rsi
	mov	[rdi + Vector.size], rsi

;; TODO: shrink vector if it's size is less than capacity / 4.

	ret
.out_of_bounds:
	ret


