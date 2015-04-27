;;; vector.asm
;;; Operations on auto-resizing vectors of uint64

%include "macro.inc"
%include "vector.inc"

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
              
              pop   rcx             ; Get the length of vector to RCX (+ size and capacity)
              add   rcx, 2          
              mov   rdi, rax        

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
              lea   rdi, [rdi*8 + vector_size]
              call  malloc
              ret

              

             
