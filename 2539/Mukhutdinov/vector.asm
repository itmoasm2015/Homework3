;;; vector.asm
;;; Operations on auto-resizing vectors of uint64

%include "macro.inc"
%include "vector.inc"

section .data
CONST_0:        dq 0

section .text

extern malloc
extern free

global vectorNew, vectorDelete, vectorEnsureCapacity, vectorAdd

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
;; void vectorResize(Vector vec, unsigned int newSize);
;;
;; Resizes a vector, reallocating if necessary
;;
;; @param  RDI vec     -- vector to resize
;; @param  RSI newSize -- new size
;; @return RAX Address of resized vector
vectorResize:
              CDECL_ENTER 0, 0
              mov   r8, [rdi + vector.size]
              mov   r9, [rdi + vector.capacity]

              cmp   rsi, r9         ; Check if new size exceeds capacity
              jle   .assign_size    ; and reallocate vector, if so

              mpush  rdi, rsi
              lea   rdi, [rsi*2]
              call  vectorNewRaw    ; Allocate a bigger vector

              pop   rdi             ; Seems weird, but we actually need to restore initial RDI
              push  rdi

              lea   rsi, [rdi + vector.data] ; Prepare pointers for copying
              lea   rdi, [rax + vector.data]
              mov   rcx, r8         ; the old size is in RCX

              cld                   ; Copy data
              rep   movsq

              pop   rdi             ; Clear old vector
              call  vectorDelete

              mov   rdi, rax        ; Point RDI to new vector and restore passed size in RSI
              pop   rsi
.assign_size:
              mov   [rdi + vector.size], rsi
              cmp   rsi, r8         ; If new size is bigger than old, zero out the tail
              jle   .return

              push  rdi
              add   rdi, vector_size
              add   rdi, r8
              mov   rcx, rsi
              sub   rcx, r8

              xor   rax, rax
              cld
              rep   stosb
              pop   rdi
.return:
              mov   rax, rdi
              CDECL_RET
