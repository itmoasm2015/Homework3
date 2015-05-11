;;; vector.asm
;;; Operations on auto-resizing vectors of uint64_t
;;;
;;; A place for data is allocated separately from vector data structure itself
;;; in order to prevent pointer invalidating after reallocation (which is essential
;;; in such functions as biAdd, biSub and biMul)

%include "macro.inc"
%include "vector.inc"

section .text

extern malloc
extern free

global vectorNew
global vectorNewRaw
global vectorCopy
global vectorCopyTo
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
              mpush rsi, rdi        ; Store RDI and RSI because they are going to be spoiled
              call  vectorNewRaw

              mpop  rsi, rcx        ; Get the capacity of vector to RCX
              GET_DATA rdi, rax     ; Store vector data pointer in RDI
              
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
              mov   rdi, vector_size
              ALIGNED_CALL malloc   ; Allocate space for vector itself

              pop   rdi             ; Restore given capacity
              push  rdi
              
              lea   rdi, [rdi*8]    ; Get number of bytes to alloc
              push  rax
              ALIGNED_CALL malloc   ; Allocate space for vector data

              mpop  rdi, r8        
              SET_DATA r8, rax      ; Write the data pointer to vector structure
              mov   rax, r8
              
              mov   qword [rax + vector.size], 0 ; Set 0 size, 0 sign and given capacity
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

              mov   r8, [rsi + vector.size] ; Save size in R8 for a while
              mov   rcx, 3          ; Copy all metadata, except data pointer

              mpush rdi, rsi
              cld
              rep   movsq           ; Metadata copied, RSI and RDI are now pointing on data pointers

              mpop  rdi, rsi
              
              GET_DATA rdi, rdi
              GET_DATA rsi, rsi
              mov   rcx, r8
              
              rep   movsq
              ret
              
;; @cdecl64
;; void vectorCopyTo(Vector dst, Vector src);
;;
;; Assignment operator. Copies contents from SRC to DST
;;
;; @param  RDI dst  -- destination vector
;; @param  RSI src  -- source vector
;; @saves  RDI
vectorCopyTo:
              mpush rdi, rsi
              mov   rsi, [rsi + vector.size]
              call  vectorResize    ; Set dst.size = src.size

              mov   r8, rsi         ; Store vector size in R8
              pop   rsi

              mov   rcx, 3          ; Copy all metadata but data pointer

              mpush rdi, rsi
              cld
              rep   movsq           ; Metadata copied, RSI and RDI are now pointing on data pointers
              mpop  rdi, rsi

              GET_DATA rdi, rdi
              GET_DATA rsi, rsi
              mov   rcx, r8
              rep   movsq           
              
              pop   rdi             ; We save RDI for convenience
              ret


;; @cdecl64
;; void vectorDelete(Vector vec)
;;
;; Frees a vector.
;;
;; @param  RDI vec -- vector to free
vectorDelete:
              push  rdi
              GET_DATA rdi, rdi     ; Free vector data
              ALIGNED_CALL free
              
              pop   rdi
              ALIGNED_CALL free     ; and vector itself
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
;; @return RAX Vector element
vectorGet:
              GET_DATA rax, rdi
              mov   rax, [rax + rsi*8]
              ret

;; @cdecl64
;; void vectorSet(Vector vec, unsigned int i, uint64_t val);
;;
;; Set element by index.
;;
;; @param  RDI vec
;; @param  RSI i
;; @param  RDX val
vectorSet:
              GET_DATA rax, rdi
              mov   [rax + rsi*8], rdx
              ret

;; @cdecl64
;; void vectorResize(Vector vec, unsigned int newSize, int64_t tailFill);
;;
;; Resizes a vector, reallocating data if necessary
;;
;; @param  RDI vec      -- vector to resize
;; @param  RSI newSize  -- new size
;; @param  RDX tailFill -- an int64_t to fill the rest of resized vector
;; @saves RDI, RSI, RDX
vectorResize:
              CDECL_ENTER 0, 0
              mov   r12, [rdi + vector.size]     ; size
              mov   r13, [rdi + vector.capacity] ; capacity

              cmp   rsi, r13        ; Check if new size exceeds capacity
              jle   .assign_size    ; and reallocate vector, if so

              mpush rdx, rsi, rdi
              lea   rsi, [rsi*2]
              mov   [rdi + vector.capacity], rsi ; Save new capacity (newSize*2)
              
              lea   rdi, [rsi*8]    ; Get number of bytes to allocate (newSize*2*sizeof(uint64_t))
              ALIGNED_CALL malloc   ; Allocate a bigger data space

              pop   rdi             ; Seems weird, but we actually need to restore initial RDI
              push  rdi

              GET_DATA rsi, rdi     ; Prepare pointers for copying
              mov   rdi, rax
              mov   rcx, r12        ; the old size is in RCX

              cld                   ; Copy data
              rep   movsq

              pop   rdi             ; Clear old vector
              push  rdi
              GET_DATA rdi, rdi
              
              push  rax             ; Save new data address
              ALIGNED_CALL free     ; Free old data            

              mpop  rdi, rax
              SET_DATA rdi, rax     ; Point data pointer on new data
              mpop  rdx, rsi
.assign_size:
              mov   [rdi + vector.size], rsi
              cmp   rsi, r12        ; If new size is bigger than old, then fill the tail
              jle   .return

              push  rdi             ; Prepare pointers for tail filling
              GET_DATA rdi, rdi
              lea   rdi, [rdi + r12*8]
              mov   rcx, rsi
              sub   rcx, r12

              mov   rax, rdx        ; Fill the tail with given value
              cld
              rep   stosq
              pop   rdi
.return:
              CDECL_RET


;; @cdecl64
;; Vector vectorAppend(Vector vec, uint64_t val);
;;
;; Append a value to vector, incrementing its size
;;
;; @param  RDI vec  -- vector to append to
;; @param  RSI val  -- value to append
;; @saves  RDI
vectorAppend:
              mov   rdx, [rdi + vector.size]
              inc   rdx
              xchg  rdx, rsi
              call  vectorResize
              ret
