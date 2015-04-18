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

%assign	DEFAULT_CAPACITY	4
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
	mov	rdx, [rdi + Vector.size]
	inc	rdx
	mov	[rax + rdx * ELEM_SIZE], rsi

	ret


