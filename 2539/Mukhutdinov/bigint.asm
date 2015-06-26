;;; bigint.asm
;;; Big Integers implementation.
;;;
;;; BigInt is implemented using auto-expanding vector from vector.asm.
;;; It stores absolute value in vector's data as an array of uint64_t.
;;; Sign is stored separately in extra field of vector structure: 0 - positive, 1 - negative.
;;;
;;; No leading zeroes are stored in bigint
;;; Only one representation of zero is supported: vector of size 1 with 0 sign and 0 value in single cell.
;;; This invariant is preserved by helper functions __clearTail and __validateZero
              
%include "macro.inc"
%include "vector.inc"

;; Convenience jump macros
%macro JIF_NEG 2
              cmp   [%1 + vector.sign], 1
              je    %2
%endmacro

%macro JIF_POS 2
              cmp   [%1 + vector.sign], 0
              je    %2
%endmacro

;; A macros which simplifies conditional jumps
%macro JCOND 4
	      cmp   %2, %3
	      j%1   %4
%endmacro

%macro JIFE 3
	      JCOND e, %1, %2, %3
%endmacro

;; Append 0 operation is very common, so here are this macro
;;
;; Input:
;;   - RDI - vector to append to
;; Output:
;;   - RDI - address of appended vector
;;   - RAX - original vector address
;; Spoils: everything which malloc can spoil
;; Saves:  RCX, because something related to a size of vector are commonly there
%macro APPEND_0_AND_POINT_TO_END 0
              push  rcx
              xor   rsi, rsi
              call  vectorAppend    
              
              mov   rsi, [rdi + vector.size]
              dec   rsi             ; vector.size() - 1

              mov   rax, rdi        ; Save original vector address in RAX to use it after
              GET_DATA rdi, rdi
              lea   rdi, [rdi + rsi*8]
              pop   rcx
%endmacro

section .text

extern vectorNew
extern vectorNewRaw
extern vectorCopy
extern vectorCopyTo
extern vectorDelete
extern vectorAppend
extern vectorResize
extern malloc
extern free
              
global biFromInt
global biFromString
global biDelete
global biAdd
global biSub
global biMul
global biCmp
global biSign
global biDivRem
global biToString


;; @cdecl64
;; BigInt biFromInt(int64_t x);
;;
;; Creates a BigInt from a single int64_t value.
;;
;; O(1)
;;
;; @param  RDI x -- source integer
;; @return RAX -- a freshly baked BigInt
biFromInt:
              push  rdi
              mov   rdi, 1
              call  vectorNewRaw
              pop   rdi

              cmp   rdi, 0
              jge   .positive       ; Set the sign and invert given int if it's negative

              neg   rdi
              mov   qword [rax + vector.sign], 1
.positive:    
              mov   qword [rax + vector.size], 1
              GET_DATA rsi, rax
              mov   [rsi], rdi
              ret

;; @cdecl64
;; BigInt biFromString(char const *s);
;;
;; Makes a BigInt from a string literal.
;;
;; O(nm), where n - length of string, m - size of bigint
;;
;; @param  RDI s -- address of beginning of string
;; @return RAX -- a freshly baked BigInt
biFromString:
              push  rdi
              mov   rdi, 0
              call  biFromInt       ; Make a fresh BigInt-ish 0
              
              pop   rdi
              xor   rdx, rdx        ; Zero out RDX to ensure that RDX == DL later

              mov   dl, [rdi]       ; first symbol
              JCOND ne, dl, '-', .positive ; Add sign and skip '-' symbol, if present

              mov   qword [rax + vector.sign], 1
              inc   rdi
              mov   dl, [rdi]
.positive:
              xchg  rax, rdi        ; now RDI points to bigint, RAX - to string
              JCOND e, dl, 0, .return_null ; Check for empty or single minus ('-') string.
.main_loop:
              JCOND e, dl, 0,  .return      ; If it's the end of the string - return 
              JCOND l, dl, 48, .return_null ; Check if current symbol is digit,
              JCOND g, dl, 57, .return_null ; and return NULL otherwise

              mpush rax, rdx

              mov   rsi, 10         ; Multiply bigint by 10
              call  __mulByShort

              pop   rdx
              sub   rdx, 48         ; Get int from char
              call  __addShort      ; Add a digit to our bigint

              pop   rax
              xor   rdx, rdx        ; RDX may have been spoiled in prev calls
              inc   rax             ; To the next char
              mov   dl, [rax]
              jmp   .main_loop
.return:      
              call  __validateZero
              mov   rax, rdi
              ret
.return_null:
              call  biDelete        ; Clear allocated bigint (assume that we have it in RDI now)
              xor   rax, rax        ; Return NULL
              ret

              
;; @cdecl64
;; void biDelete(BigInt bi);
;;
;; Deletes a BigInt
;;
;; O(1)
;;
;; @param  RDI bi -- BigInt to delete
biDelete:
              call  vectorDelete
              ret


;; @cdecl64
;; void biAdd(BigInt dst, BigInt src);
;;
;; Adds src to dst, storing result in dst
;;
;; O(max(n, m)), where n - size of DST, m - size of SRC
;; 
;; @param  RDI dst  -- first summand
;; @param  RSI src  -- second summand
biAdd:
              mov   rax, [rdi + vector.sign]
              mov   rdx, [rsi + vector.sign]

              JCOND e, rax, rdx, .add ; If signs are the same, then it's a simple addition

              ;; If signs are different, then this is actually a subtraction
              ;; Compare absolute values to understand what should be dst, and what - src
              mpush rdi, rsi
              call  biCmpAbs
              mpop  rdi, rsi
              
              JCOND ge, rax, 0, .sub ; If |a| > |b|, then it's a regular subtraction (a := a - b)

              ;; If |a| < |b|, then it's a reverse subtraction (a := b - a)
              ;; Also in this case we must set sign of SRC to DST
              mov   qword [rdi + vector.sign], rdx
              call  biSubRevUnsigned 
              ret
.sub:
              call  biSubUnsigned
              call  __validateZero
              ret
.add: 
              call  biAddUnsigned
              ret   

;; @cdecl64
;; void biSub(BigInt dst, BigInt src);
;;
;; Subtracts src from dst, storing result in dst
;;
;; O(max(n, m)), where n - size of DST, m - size of SRC
;;
;; @param  RDI dst  -- minuend
;; @param  RSI src  -- subtrahend
biSub:
              mov   rax, [rdi + vector.sign]
              mov   rdx, [rsi + vector.sign]

              JCOND ne, rax, rdx, biAdd.add ; If signs are different, then it's actually an addition

              ;; If signs are the same, then this is a subtraction
              ;; Compare absolute values of dst and src to know if it's reversal
              mpush rdi, rsi
              call  biCmpAbs
              mpop  rdi, rsi

              JCOND ge, rax, 0, biAdd.sub ; If |a| > |b|, then it's a regular subtraction (a := a - b)

              not   rdx             ; Invert RDX, where sign are stored (0 -> 1, 1 -> 0)
              and   rdx, 1          ; and change the sign of dst (because it will change)
              mov   qword [rdi + vector.sign], rdx
              
              call  biSubRevUnsigned ; Otherwise it's reverse (a := b - a)
              ret
              
;; @cdecl64
;; void biAddUnsigned(BigInt dst, BigInt src);
;;
;; Adds src to dst, storing result in dst
;; Assumes that both summands are positive
;;
;; O(max(n, m)), where n - size of DST, m - size of SRC
;;
;; @param  RDI dst  -- first summand
;; @param  RSI src  -- second summand
biAddUnsigned:
              push  rdi
              mov   rcx, [rdi + vector.size]
              mov   r8, [rsi + vector.size]

              GET_DATA rdi, rdi
              GET_DATA rsi, rsi
              
              clc                   ; Reset carry
              pushf                 ; Save flags to restore CF when needed
.sum_loop:
              xor   rax, rax

              test  r8, r8          ; Test whether we are still in SRC range
              je    .skip_src_copy  ; Don't take digit from SRC in this case

              mov   rax, [rsi]
              add   rsi, 8
              dec   r8
.skip_src_copy:
              popf                  ; Restore CF
              adc   [rdi], rax
              pushf                 ; and save it again

              lea   rdi, [rdi + 8]  ; Use LEA to save CF
              dec   rcx
              jnz   .sum_loop       ; Add until we are not at the end of DST

              jc    .append_zero    ; or till we have carry

              test  r8, r8          
              jne   .append_zero    ; or until we are not at the end of SRC

              popf                  ; Remove flags from stack
              pop   rdi             ; Restore DST address
              ret
              
.append_zero:
              popf                  ; Such a mess with POP/PUSH[f] is necessary to save CF
              pop   rdi             ; between iterations
              pushf 

              mpush rsi, r8         ; RSI and R8 may spoil while append
              APPEND_0_AND_POINT_TO_END
              inc   rcx

              mpop  rsi, r8

              popf
              push  rax             ; Save maybe new vector address
              pushf
              jmp   .sum_loop

;; @cdecl64
;; void biSubUnsigned(BigInt dst, BigInt src);
;;
;; Subtracts src from dst, storing result in dst
;; Assumes that dst and src are positive, and dst >= src
;;
;; O(n), where n - size of DST
;;
;; @param  RDI dst  -- minuend
;; @param  RSI src  -- subtrahend
biSubUnsigned:
              push  rdi
              mov   rcx, [rdi + vector.size]
              mov   r8, [rsi + vector.size]

              GET_DATA rdi, rdi
              GET_DATA rsi, rsi
              
              clc                   ; Reset carry
              pushf                 ; Save CF
.sub_loop:
              xor   rax, rax

              test  r8, r8          ; Test whether we are still in SRC range
              je    .skip_src_copy  ; Don't take digit from SRC in this case

              mov   rax, [rsi]
              dec   r8
.skip_src_copy:
              popf                  ; Restore CF
              sbb   [rdi], rax
              pushf                 ; and save it again

              lea   rdi, [rdi + 8]  ; Use LEA to save CF
              lea   rsi, [rsi + 8]
              
              dec   rcx
              jnz   .sub_loop       ; Subtract until wea re not at the end of DST
              jc    .sub_loop       ; or till we have carry

              popf                  ; Remove flags from stack
              pop   rdi
              call  __clearTail     ; Clear leading zeroes, if they exist
              ret

;; @cdecl64
;; void biRevSubUnsigned(BigInt dst, BigInt src);
;;
;; Reverse subtraction. Subtracts dst from src, storing result in dst
;; Assumes that dst and src are positive, and dst <= src
;;
;; O(m), where m - size of SRC
;;             
;; Mostly copypasted from biSubUnsigned, but I don't know an elegant way not to copypaste
;; ASM code in such situations: a macro would be too large and too specific, wrapping in
;; the more general function would be cumbersome too and taxing because of calls inside loop
;;
;; @param  RDI dst  -- subtrahend
;; @param  RSI src  -- minuend
biSubRevUnsigned:
              push  rdi
              mov   rcx, [rsi + vector.size]

              mpush rsi, rcx        ; We must ensure that here we'll have enough space in DST
              mov   rsi, rcx        ; so we resize it to the size of SRC
              xor   rdx, rdx
              call  vectorResize
              mpop  rsi, rcx
              
              GET_DATA rdi, rdi
              GET_DATA rsi, rsi
              
              clc                   ; Reset carry
              pushf                 ; Save CF
.sub_loop:
              mov   rax, [rdi]
              
              popf                  ; Restore CF
              mov   rdx, [rsi]      ; Subtract dst digit from src and place result in dst
              sbb   rdx, rax
              mov   [rdi], rdx
              pushf                 ; and save it again

              lea   rdi, [rdi + 8]  ; Use LEA to save CF
              lea   rsi, [rsi + 8]  
              
              dec   rcx
              jnz   .sub_loop       ; Subtract until wea re not at the end of DST
              jc    .sub_loop       ; or till we have carry

              popf                  ; Remove flags from stack
              pop   rdi
              call  __clearTail     ; Clear leading zeroes, if they exist
              ret
              
;; @cdecl64
;; void biMul(BigInt src, BigInt dst);
;;
;; Multiplies DST by SRC and stores result in DST
;;
;; O(nm), where n - size of DST, m - size of SRC
;;
;; @param  RDI dst  -- first factor
;; @param  RSI src  -- second factor
biMul:
              CDECL_ENTER 0, 0
              mpush rdi, rsi

              mov   rdi, [rdi + vector.size] ; Prepare arguments for vectorNew
              add   rdi, [rsi + vector.size] ; Size of result should be dst.size() + src.size() to be enough for sure
              xor   rsi, rsi

              push  rdi             ; Save that to set the size later
              call  vectorNew       ; Create new vector for result, filled with zeroes
              pop   rdi

              mov   [rax + vector.size], rdi ; Write vector size down

              mpop  rdi, rsi

              mov   rbx, [rdi + vector.sign] ; Check if signs of dst and src are different, and set sign 1 to result, if so
              JCOND e, rbx, [rsi + vector.sign], .start_job

              mov   qword [rax + vector.sign], 1
.start_job:
              mpush rdi, rax        ; Save result and DST to copy later

              mov   r14, [rdi + vector.size] ; Store vectore sizes
              mov   r15, [rsi + vector.size]
              
              GET_DATA rdi, rdi     ; Pointers on data
              GET_DATA rsi, rsi
              GET_DATA r13, rax

              xor   rcx, rcx        ; i = 0  -- RCX is the outer loop counter
.outer:      
              xor   rdx, rdx        ; Reset carry
              xor   rbx, rbx        ; j = 0  -- RBX is the inner loop counter
.inner:       
              lea   r8, [r13 + rcx*8]
              mov   r8, [r8 + rbx*8]  ; r8 = result[i + j]

              xor   r9, r9
              JCOND ae, rbx, r15, .skip_src_copy ; If we have reached the end of src, assume 0 is its current digit

              mov   r9, [rsi + rbx*8] ; Or copy actual digit otherwise
.skip_src_copy:
              mov   r10, rdx        ; Store previous carry in R10
              mov   rax, [rdi + rcx*8]
              mul   r9

              add   rax, r8         ; Add previously counted result to product
              adc   rdx, 0
              add   rax, r10        ; Add previous carry to product
              adc   rdx, 0

              lea   r8, [r13 + rcx*8]
              lea   r8, [r8 + rbx*8] ; Point R8 to result[i + j]

              mov   [r8], rax       ; Store new result

              inc   rbx             
              JCOND b, rbx, r15, .inner ; Repeat till we are not at the end of src
              
              test  rdx, rdx
              jne   .inner          ; or till we have carry
              
              inc   rcx
              JCOND b, rcx, r14, .outer ; ? i < dst.size()

              mpop  rax, rdi        ; Restore result and dst in reverse order to make __clearTail
              call  __clearTail

              mov   rsi, rdi        ; Prepare args for vectorCopyTo
              mov   rdi, rax
              call  vectorCopyTo    ; Copy result to dst
              call  __validateZero  ; Fix sign if result is zero
              
              CDECL_RET

;; A placeholder for biDivRem function
biDivRem:
              nop
              ret
              
;; @cdecl64
;; void biToString(BigInt bi, char *buffer, size_t limit);
;;
;; Makes a string representation of BigInt and stores it into buffer.
;;
;; O(nm), where n - size of bigint, m - length of string representation
;;
;; @param  RDI bi     -- address of BigInt to store
;; @param  RSI buffer -- address of buffer
;; @param  RDX limit  -- maximal string length
biToString:
              CDECL_ENTER 0, 0
              JCOND e, rdx, 0, .return ; Do nothing if limit is 0
              JCOND e, rdx, 1, .empty  ; Return empty string if limit is 1

              mpush rdx, rsi
              call  vectorCopy      ; Copy our bigint in order to not alter the original bigint
              push  rax             ; Copy address in RAX now
              
              ;; We allocate a buffer which is guaranteed to be enough for the full string
              ;; representation of bigint. We use the fact what uint64_t-'digit' requires
              ;; no more than 32 chars in decimal representation
              mov   rdi, [rax + vector.size]
              shl   rdi, 5
              add   rdi, 2          ; RDI = vector.size*32 + 2 (+2 is for minus sign and \0)
              ALIGNED_CALL malloc   ; RAX is the buffer address

              mov   r15, rax        ; Save buffer address for freeing in the future
              mov   byte [rax], 0   ; Write 0-terminator at first (to detect end of buffer)
              inc   rax
              
              pop   rdi             ; Restore bigint address
.div_loop:
              push  rax
              mov   rsi, 10
              call  __divByShort    ; Remainder is in RDX now

              pop   rax
              add   rdx, 48         ; Write digit to buffer
              mov   byte [rax], dl
              inc   rax

              push  rax
              call  biSign          ; Check if our BigInt is zero now

              JCOND e, rax, 0, .minus_sign
              pop   rax
              jmp   .div_loop
.minus_sign:
              pop   rax
              JCOND e, qword [rdi + vector.sign], 0, .copy_from_buf

              mov   byte [rax], '-'
              inc   rax
              
.copy_from_buf:
              push  rax
              call  biDelete        ; Delete the temporary copy of bigint
              pop   rax
             
              mpop  rcx, rsi        ; Restore limit and string address
              dec   rcx             ; Decrement limit for zero-terminator
.copy_loop:
              dec   rax
              mov   dl, [rax]       ; Take the next symbol

              JCOND e, dl, 0, .finish ; Check if it is zero-terminator

              mov   byte [rsi], dl
              inc   rsi
              dec   rcx
              jz    .finish         ; Stop if we are out of limit

              jmp   .copy_loop
.finish:
              push  rsi
              mov   rdi, r15        ; Free our temp buffer
              ALIGNED_CALL free
              pop   rsi
.empty:
              mov   byte [rsi], 0
.return:
              CDECL_RET


;; @cdecl64
;; int biSign(BigInt bi);
;;
;; Returns 0 if bi == 0, -1 if bi < 0 and 1 if bi > 0
;;
;; O(1)
;;
;; @param  RDI bi -- bigint to compare
;; @return RAX -- result of comparison
biSign:
              ;; Check for zero at first
              JCOND ne, qword [rdi + vector.size], 1, .sign_check
              
              GET_DATA rax, rdi     
              JCOND ne, qword [rax], 0, .sign_check

              xor   rax, rax
              ret
.sign_check:  
              JCOND e, qword [rdi + vector.sign], 1, .neg
              mov   rax, 1
              ret
.neg:
              mov   rax, -1
              ret

;; @cdecl64
;; int biCmp(BigInt a, BigInt b);
;;
;; Compares 2 bigints. Returns 0 if a == b, -1 if a < b, 1 if a > b
;;
;; O(n) in worst case, where n - size of both bigints
;;
;; @param  RDI a  -- first bigint
;; @param  RSI b  -- second bigint
;; @return RAX -- result of comparison
biCmp:
              CDECL_ENTER 0, 0
              ;; Compare signs at first
              ;; Use biSign to avoid troubles with zero
              call  biSign
              mov   r12, rax
              push  rdi
              mov   rdi, rsi
              call  biSign          ; Now sign of a is in R8, sign of b - in RAX
              pop   rdi
              
              cmp   r12, rax        ; Compare signs:
              jl    .a_lt_b         ; if sgn a < sgn b, then a < b
              jg    .a_gt_b         ; and reversed

              ;; Here R12 stores the sign of a and b
              test  r12, r12        ; Check if sign is zero, this means a and b are both zeroes
              je    .equal

              call  biCmpAbs        ; Compare absolute values 
              cmp   rax, 0
              jl    .a_abs_lt_b
              jg    .a_abs_gt_b     
.equal:       
              xor   rax, rax
              CDECL_RET
.a_abs_lt_b:
              cmp   r12, 0          ; |a| < |b|, check sign
              jl    .a_gt_b
              jg    .a_lt_b
.a_abs_gt_b:
              cmp   r12, 0          ; |a| > |b|, check sign
              jl    .a_lt_b
              jg    .a_gt_b
.a_lt_b:
              mov   rax, -1
              CDECL_RET
.a_gt_b:
              mov   rax, 1
              CDECL_RET
              
;; @cdecl64
;; int biCmpAbs(BigInt a. BigInt b);
;;
;; Compares absolute values of 2 bigints
;;
;; O(n) in worst case, where n - size of both bigints
;; 
;; @param  RDI a  -- first bigint
;; @param  RSI b  -- second bigint
;; @return RAX -1 if |a| < |b|, 0 if |a| = |b| and 1 if |a| > |b|
biCmpAbs:
              mov   rcx, [rdi + vector.size] ; Compare sizes now

              cmp   rcx, qword [rsi + vector.size] ; If size of one bigint is bigger than other's, then the former is definitely bigger
              jb    .a_lt_b
              ja    .a_gt_b
              
              ;; Here RCX stores the size of a and b
              GET_DATA rdi, rdi
              GET_DATA rsi, rsi

              dec   rcx
              lea   rdi, [rdi + rcx*8] ; Point to the elder digits
              lea   rsi, [rsi + rcx*8]
              inc   rcx
.compare_loop:
              mov   rax, [rdi]      ; Compare digits from high to low
              cmp   rax, [rsi]
              jb    .a_lt_b         ; If digits are different, we know the answer
              ja    .a_gt_b
              sub   rdi, 8
              sub   rsi, 8
              dec   rcx
              jnz   .compare_loop

              xor   rax, rax
              ret
.a_lt_b:
              mov   rax, -1
              ret
.a_gt_b:
              mov   rax, 1
              ret
             

;; __addShort -- inner non-cdecl function
;;
;; Adds given uint64_t to given BigInt
;;
;; O(n) in worst case, O(1) in general
;;
;; @param  RDI -- BigInt address
;; @param  RDX -- uint64_t to add
;; @return RDI -- Updated BigInt address
;; @spoils RCX, RSI, RAX
__addShort:
              push  rdi
              mov   rcx, [rdi + vector.size]
              GET_DATA rdi, rdi
              
              add   [rdi], rdx      ; Add the RDX to least significant bigint digit
              jnc   .finish         ; and finish, if we have no carry
.carry_loop:
              lea   rdi, [rdi + 8]  ; Use LEA to save CF
              dec   rcx
              jnz   .add_carry      ; Append zero to a vector if necessary

              pop   rdi
              pushf                 ; Save CF
              
              APPEND_0_AND_POINT_TO_END
              inc   rcx             
              
              popf                  ; Restore CF
              push  rax             ; Save vector address again
.add_carry:
              mov   rax, [rdi]
              adc   rax, 0
              mov   [rdi], rax
              jc    .carry_loop
.finish:
              pop   rdi
              ret
              
;; __mulByShort -- inner non-cdecl function
;;
;; Multiplicates given BigInt by given uint64_t
;;
;; O(n), where n - size of bigint
;;
;; @param  RDI -- BigInt address
;; @param  RSI -- uint64_t to multiply
;; @return RDI -- Multiplied BigInt address
;; @spoils RDX, RCX, RAX
__mulByShort:
              push  rdi
              mov   rcx, [rdi + vector.size]
              GET_DATA rdi, rdi
              
              xor   rdx, rdx        ; Reset carry data
.mult_loop:
              mov   r8, rdx         ; Save carry
              mov   rax, [rdi]
              mul   rsi
              add   rax, r8         ; RAX - uint64-digit of result
              adc   rdx, 0          ; RDX - carry

              mov   [rdi], rax      ; Copy calculated digit

              add   rdi, 8
              dec   rcx
              jnz   .mult_loop      ; repeat until end is not reached

              test  rdx, rdx        ; If carry is not zero yet
              je    .clear_tail     ; then append zero to vector and repeat

              pop   rdi             ; Restore vector address
              mpush rsi, rdx        ; RSI, RDX can be spoiled later

              APPEND_0_AND_POINT_TO_END
              inc   rcx             
              
              mpop  rsi, rdx        
              push  rax             ; Save vector address again
                     
              jmp   .mult_loop
.clear_tail:
              pop   rdi
              call  __clearTail     ; Clear the leading zeroes, if they exist
              ret
               
;; __divByShort -- inner non-cdecl function
;;
;; Divides given BigInt by given uint64_t
;;
;; O(n), where n - size of bigint
;; 
;; @param  RDI -- BigInt address
;; @param  RSI -- uint64_t to divide by
;; @return RDI -- Divided BigInt address
;; @return RDX -- Remainder
;; @spoils RCX, RAX
__divByShort:
              push  rdi
              mov   rcx, [rdi + vector.size]
              dec   rcx
              GET_DATA rdi, rdi
              lea   rdi, [rdi + rcx*8] ; Point RDI to the end of vector 
              inc   rcx

              xor   rdx, rdx        ; Reset carry data
.div_loop:
              mov   rax, [rdi]
              div   rsi             ; RAX - quotient, RDX - remainder
              mov   [rdi], rax      ; Store the quotient of digit to an answer

              sub   rdi, 8
              dec   rcx
              jnz   .div_loop

              pop   rdi
              call  __clearTail     ; Clear the leading zeroes, if they exist
              ret                   ; RDX - uint64_t quotient, RDI - address of bigint remainder


;; @cdecl64
;; __clearTail -- inner function (surprisingly cdecl-compatible)
;; 
;; Clears the leading zeroes (except the least significant)
;;
;; O(n), where n - size of bigint
;;
;; @param  RDI -- BigInt address
;; @spoils RCX

__clearTail:
              push  rdi
              mov   rcx, [rdi + vector.size]          ; Store vector size in RCX
              dec   rcx
              GET_DATA rdi, rdi
              lea   rdi, [rdi + rcx*8]  ; Point RDI to the end
              inc   rcx
.check_loop
              JCOND ne, qword [rdi], 0, .finish ; Finish if current digit isn't zero
              JCOND e, rcx, 1, .finish ; or it's the least significant digit, which means we have zero here

              dec   rcx
              sub   rdi, 8
              jmp   .check_loop

.finish:
              pop   rdi
              mov   [rdi + vector.size], rcx
              ret

;; @cdecl64
;; __validateZero -- inner function (surprisingly cdecl-compatible)
;;
;; Preserves invariant of 0 sign for 0. If RDI is bigint-ish zero, then set 0 sign to it.
;;
;; O(1)
;;
;; @param  RDI -- BigInt address
;; @spoils RAX
__validateZero:
              call  biSign
              test  rax, rax
              jnz   .return

              mov   qword [rdi + vector.sign], 0
.return:      
              ret
