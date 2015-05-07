;;; vector.asm
;;; Operations on auto-resizing vectors of uint64

%include "macro.inc"
%include "vector.inc"

section .data
CONST_0:        dq 0

section .text

extern malloc
extern free

global vectorNew
global vectorDelete
global vectorSize
global vectorResize
global vectorGet
global vectorSet

;; @cdecl64
;; Vector vectorNew(unsigned int initialCapacity);
;;
;; Allocates a new vector with provided initial capacity
;; and fill it with zeroes
;;
;; @param  RDI initialCapacity
;; @return RAX Pointer on the vector struct
vectorNew:
              push  rdi
              call  vectorNewRaw

              pop   rcx             ; Get the length of vector to RCX
              lea   rdi, [rax + vector.data]

              cld                   ; Clear dir flag just in case
              push  rax
              xor   rax, rax        ; Zero it out
              rep   stosq
              pop   rax
              ret


;; @cdecl64
;; Vector vectorNewRaw(unsigned int initialCapacity);
;;
;; Allocates a new vector with provided initial capacity
;; and garbage inside
;;
;; @param  RDI initialCapacity
;; @return RAX Pointer on the vector struct
vectorNewRaw:
              push  rdi
              lea   rdi, [rdi*8 + vector_size]
              call  malloc

              pop   rdi             ; Set 0 size and given capacity
              xor   r10, r10        ; That is for operand sizes match
              mov   [rax + vector.size], r10
              mov   [rax + vector.capacity], rdi

              ret

;; @cdecl64
;; void vectorDelete(Vector vec)
;;
;; Frees a vector.
;;
;; @param  RDI vec -- vector to free
vectorDelete:
              call  free
              ret

;; @cdecl64
;; int vectorSize(Vector vec)
;;
;; Returns vector size.
;;
;; @param  RDI vec
;; @return RAX Vector size
vectorSize:
              mov   rax, [rdi + vector.size]
              ret

;; @cdecl64
;; uint64_t vectorGet(Vector vec, unsigned int i);
;;
;; Get element by index.
;;
;; @param  RDI vec
;; @param  RSI i
;; @return RAX Vector size
vectorGet:
              mov   rax, [rdi + rsi*8 + vector.data]
              ret

;; @cdecl64
;; void vectorSet(Vector vec, unsigned int i, uint64_t val);
;;
;; Set element by index.
;;
;; @param  RDI vec
;; @param  RSI i
;; @param  RDX val
;; @return RAX Vector size
vectorSet:
              mov   [rdi + rsi*8 + vector.data], rdx
              ret

;; @cdecl64
;; Vector vectorResize(Vector vec, unsigned int newSize);
;;
;; Resizes a vector, reallocating if necessary
;;
;; @param  RDI vec     -- vector to resize
;; @param  RSI newSize -- new size
;; @return RAX Address of resized vector
vectorResize:
              CDECL_ENTER 0, 0
              mov   r12, [rdi + vector.size]     ; size
              mov   r13, [rdi + vector.capacity] ; capacity

              cmp   rsi, r13        ; Check if new size exceeds capacity
              jle   .assign_size    ; and reallocate vector, if so

              mpush rsi, rdi
              lea   rdi, [rsi*2]
              call  vectorNewRaw    ; Allocate a bigger vector

              pop   rdi             ; Seems weird, but we actually need to restore initial RDI
              push  rdi

              lea   rsi, [rdi + vector.data] ; Prepare pointers for copying
              lea   rdi, [rax + vector.data]
              mov   rcx, r12        ; the old size is in RCX

              cld                   ; Copy data
              rep   movsq

              push  rax
              pop   rdi             ; Clear old vector
              call  vectorDelete

              pop   rax
              mov   rdi, rax        ; Point RDI to new vector and restore passed size in RSI
              pop   rsi
.assign_size:
              mov   [rdi + vector.size], rsi
              cmp   rsi, r12        ; If new size is bigger than old, zero out the tail
              jle   .return

              push  rdi             ; Prepare pointers for tail zeroing
              add   rdi, vector_size
              add   rdi, r12
              mov   rcx, rsi
              sub   rcx, r12

              xor   rax, rax        ; Zero it out
              cld
              rep   stosb
              pop   rdi
.return:
              mov   rax, rdi        ; Return vector address in RAX
              CDECL_RET
