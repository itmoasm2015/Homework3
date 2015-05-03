default rel

section .text


%include "vector.i"


extern malloc
extern free


global allocAlign
global freeAlign

global vecAlloc
global vecFree
global vecCopy
global vecResize
global vecAdd

global vecSize
global vecCapacity
global vecGet
global vecSet


default_capacity    equ     10


%macro              calc_capacity 1
                    shr %1, 1
                    lea %1, [%1 * 3 + default_capacity]
%endmacro

; void * allocAlign(uint64_t size);
; Allocates `size` bytes with stack aligned by 16 bytes.
;
; Takes:
;   RDI - uint64_t size
; Returns:
;   RAX - pointer to allocated memory

allocAlign:         test rsp, 15
                    jz .just_alloc
                    sub rsp, 8
                    call malloc
                    add rsp, 8
                    ret
.just_alloc:        call malloc
                    ret

; void freeAlign(void * ptr);
; Frees `ptr` with stack aligned by 16 bytes.
;
; Takes:
;   RDI - void * ptr

freeAlign:          test rsp, 15
                    jz .just_free
                    sub rsp, 8
                    call free
                    add rsp, 8
                    ret
.just_free:         call free
                    ret

; vector * vecAlloc(uint64_t size);
; Allocates a new int vector with `size` elements.
;
; Takes:
;   RDI - uint64_t size
; Returns:
;   RAX - pointer to a new vector

vecAlloc:           push rdi
    ; allocate `capacity` bytes
                    calc_capacity rdi
                    lea rdi, [rdi * 8 + vector.data]
                    call allocAlign
                    pop rdi
                    mov [rax + vector.size], rdi
                    calc_capacity rdi
                    mov [rax + vector.capacity], rdi
    ; set all elements to zero
                    mov r8, rax
                    mov rcx, rdi
                    lea rdi, [rax + vector.data]
                    xor rax, rax
                    cld
                    rep stosq
                    mov rax, r8
                    ret

; void vecFree(vector * vec);
; Releases memory previously occupied by vector `vec`.
;
; Takes:
;   RDI - vector * vec

vecFree:            call freeAlign
                    ret

; void vecCopy(vector * dst, vector * src);
; Copies first `src.size` elements from `src` to `dst` vector.
;
; Takes:
;   RDI - vector * dst
;   RSI - vector * src

vecCopy:            mov rcx, [rsi + vector.size]
                    add rdi, vector.data
                    add rsi, vector.data
                    cld
                    rep movsq
                    ret

; vector * vecResize(vector * vec, uint64_t new_size);
; Sets vector `vec` size to `new_size`
; and returns pointer to a (non-)modified vector.
;
; Takes:
;   RDI - vector * vec
;   RSI - uint64_t new_size
; Returns:
;   RAX - pointer to a vector of size `new_size`.

vecResize:          cmp [rdi + vector.capacity], rsi
    ; should we reallocate vector?..
                    jae .non_modified
    ; ... yes, we should
                    push rdi
                    mov rdi, rsi
                    call vecAlloc
                    mov rdi, rax
                    pop rsi
                    push rax
                    push rsi
    ; copy contents of the old vector
                    call vecCopy
                    pop rdi
    ; free old vector
                    call vecFree
                    pop rax
                    ret
.non_modified:      mov rax, rdi
    ; ... no, we should not
    ; check if we are extending size
                    xchg [rdi + vector.size], rsi
                    cmp [rdi + vector.size], rsi
                    jbe .decrease_size
    ; set elements [old_size; new_size) to zero
                    mov r8, rax
                    xor rax, rax
                    mov rcx, [rdi + vector.size]
                    sub rcx, rsi
                    lea rdi, [rdi + 8 * rsi + vector.data]
                    cld
                    rep stosq
                    mov rax, r8
.decrease_size:     ret

; vector * vecAdd(vector * vec, uint64_t value);
; Adds `value` to the end of `vec`
; and resizes the latter, if necessary. 
;
; Takes:
;   RDI - vector * vec
;   RSI - uint64_t value
; Returns:
;   RAX - pointer to a vector with a new `value` element.

vecAdd:             push rsi
    ; set `vec` size to (size + 1)
                    mov rsi, [rdi + vector.size]
                    inc rsi
                    push rsi
                    call vecResize
                    pop r8
                    pop rsi
    ; set new element to `value`
                    lea r8, [r8 * 8 + 8]
                    mov [rax + r8], rsi
                    ret

; uint64_t vecSize(vector * vec);
; Returns size of `vec`.
;
; Takes:
;   RDI - vector * vec
;
; Returns:
;   RAX - vec.size

vecSize:            mov rax, [rdi + vector.size]
                    ret

; uint64_t vecCapacity(vector * vec);
; Returns capacity of `vec`.
;
; Takes:
;   RDI - vector * vec
;
; Returns:
;   RAX - vec.capacity

vecCapacity:        mov rax, [rdi + vector.capacity]
                    ret

; uint64_t vecGet(vector * vec, uint64_t index);
; Returns `index`th value of `vec`.
;
; Takes:
;   RDI - vector * vec
;   RSI - uint64_t index
;
; Returns:
;   RAX - vec[index]

vecGet:             mov rax, [rdi + rsi * 8 + 16]
                    ret

; void vecSet(vector * vec, uint64_t index, uint64_t value);
; Sets `index`th value of `vec` to `value`.
;
; Takes:
;   RDI - vector * vec
;   RSI - uint64_t index
;   RDX - uint64_t value

vecSet:             mov [rdi + rsi * 8 + 16], rdx
                    ret
