section .text


%include "vector.i"


extern aligned_alloc
extern free


global vecNew
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


; vector * vecNew();
; Allocates a new int vector with 0 elements.
;
; Returns:
;   RAX - pointer to a new vector

; vector * vecAlloc(uint64_t size);
; Allocates a new int vector with `size` elements.
;
; Takes:
;   RDI - uint64_t size
; Returns:
;   RAX - pointer to a new vector

vecNew:             xor rdi, rdi
vecAlloc:           push rdi
                    calc_capacity rdi
                    lea rsi, [rdi * 8 + vector.data]
                    mov rdi, 16
                    call aligned_alloc
                    pop rdi
                    mov [rax + vector.size], rdi
                    calc_capacity rdi
                    mov [rax + vector.capacity], rdi
                    ret

; void vecFree(vector * vec);
; Releases memory previously occupied by vector `vec`.
;
; Takes:
;   RDI - vector * vec

vecFree:            call free
                    ret

; void vecCopy(vector * dst, vector * src);
; Copies first `src.size` elements from `src` to `dst` vector.
;
; Takes:
;   RDI - vector * dst
;   RSI - vector * src

vecCopy:            mov rcx, [rsi + vector.size]
                    add rcx, rcx
                    add rdi, vector.data
                    add rsi, vector.data
                    cld
                    rep movsd
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
                    jae .non_modified
                    push rdi
                    mov rdi, rsi
                    call vecAlloc
                    mov rdi, rax
                    pop rsi
                    push rax
                    push rsi
                    call vecCopy
                    pop rdi
                    call vecFree
                    pop rax
                    ret
.non_modified:      mov [rdi + vector.size], rsi
                    mov rax, rdi
                    ret

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
                    mov rsi, [rdi + vector.size]
                    inc rsi
                    push rsi
                    call vecResize
                    pop r8
                    pop rsi
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
