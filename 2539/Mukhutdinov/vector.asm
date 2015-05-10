;;; vector.asm
;;; Operations on auto-resizing vectors of uint64_t

%include "macro.inc"
%include "vector.inc"

section .text

extern malloc
extern free

global vectorNew
global vectorNewRaw
global vectorCopy
global vectorDelete
global vectorSize
global vectorResize
global vectorAppend
global vectorGet
global vectorSet

;; @cdecl64
;; Vector vectorNew(unsigned int initialCapacity, int64_t fillVal);
;;
;; Allocates a new vector with provided initial capacity
;; and fill it with given value
;;
;; @param  RDI initialCapacity
;; @param  RSI fillVal -- an int64_t which will be stored in every vector cell
;; @return RAX Pointer on the vector struct
vectorNew:
              push  rdi
              call  vectorNewRaw

              pop   rcx             ; Get the length of vector to RCX
              lea   rdi, [rax + vector.data]

              cld                   ; Clear dir flag just in case
              push  rax
              mov   rax, rsi        ; Fill values
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
              ALIGNED_CALL malloc

              pop   rdi             ; Set 0 size, 0 sign and given capacity
              mov   qword [rax + vector.size], 0
              mov   qword [rax + vector.sign], 0
              mov   [rax + vector.capacity], rdi

              ret

;; @cdecl64
;; Vector vectorCopy(Vector orig);
;;
;; Allocates a new vector and copies the data from given vector
;; to new
;;
;; @param  RDI orig  -- original vector
;; @return RAX Pointer on copy
vectorCopy:
              push  rdi
              mov   rdi, [rdi + vector.capacity]
              call  vectorNewRaw    ; Allocate the vector of the same capacity

              pop   rsi
              mov   rdi, rax        ; because RSI is source, and RDI is destination

              push  rax             ; Save copy address
              mov   rcx, [rsi + vector.size]

              add   rcx, vector_size / 8 ; RCX = orig.size()*8 + sizeof(vector) -- count of bytes which store all the vector data
             
              cld                   ; Clear dir flag just in case
              rep   movsq

              pop   rax
              ret
              
;; @cdecl64
;; void vectorDelete(Vector vec)
;;
;; Frees a vector.
;;
;; @param  RDI vec -- vector to free
vectorDelete:
              ALIGNED_CALL free
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
;; Vector vectorResize(Vector vec, unsigned int newSize, int64_t tailFill);
;;
;; Resizes a vector, reallocating if necessary
;;
;; @param  RDI vec     -- vector to resize
;; @param  RSI newSize -- new size
;; @param  RDX tailFill -- an int64_t to fill the rest of resized vector
;; @return RAX Address of resized vector
vectorResize:
              CDECL_ENTER 0, 0
              mov   r12, [rdi + vector.size]     ; size
              mov   r13, [rdi + vector.capacity] ; capacity

              cmp   rsi, r13        ; Check if new size exceeds capacity
              jle   .assign_size    ; and reallocate vector, if so

              mpush rdx, rsi, rdi
              lea   rdi, [rsi*2]
              call  vectorNewRaw    ; Allocate a bigger vector

              pop   rdi             ; Seems weird, but we actually need to restore initial RDI
              push  rdi

              lea   rsi, [rdi + vector.data] ; Prepare pointers for copying
              lea   rdi, [rax + vector.data]
              mov   rcx, r12        ; the old size is in RCX

              cld                   ; Copy data
              rep   movsq

              pop   rdi             ; Clear old vector
              push  rax
              call  vectorDelete

              pop   rax
              mov   rdi, rax        ; Point RDI to new vector and restore passed size in RSI
              mpop  rdx, rsi
.assign_size:
              mov   [rdi + vector.size], rsi
              cmp   rsi, r12        ; If new size is bigger than old, then fill the tail
              jle   .return

              push  rdi             ; Prepare pointers for tail filling
              lea   rdi, [rdi + r12*8 + vector.data]
              mov   rcx, rsi
              sub   rcx, r12

              mov   rax, rdx        ; Fill the tail with given value
              cld
              rep   stosq
              pop   rdi
.return:
              mov   rax, rdi        ; Return vector address in RAX
              CDECL_RET


;; @cdecl64
;; Vector vectorAppend(Vector vec, uint64_t val);
;;
;; Append a value to vector, incrementing its size
;;
;; @param  RDI vec  -- vector to append to
;; @param  RSI val  -- value to append
;; @return RAX Address of altered vector
vectorAppend:
              mov   rdx, [rdi + vector.size]
              inc   rdx
              xchg  rdx, rsi
              call  vectorResize
              ret
