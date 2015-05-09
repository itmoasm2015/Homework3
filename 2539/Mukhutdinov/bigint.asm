;;; bigint.asm
;;; Big Integers implementation.

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


;; Resize operations are so common, so here are this macros
%macro RESIZE 3
              mpush rdi, rsi, rdx
              mov   rdi, %1
              mov   rsi, %2
              mov   rdx, %3
              call  vectorResize
              mpop  rdi, rsi, rdx
%endmacro

%macro APPEND_0_AND_POINT_TO_END 0
              xor   rsi, rsi
              call  vectorAppend    
              
              mov   rdi, [rax + vector.size]
              dec   rdi             ; vector.size() - 1
              lea   rdi, [rax + rdi*8 + vector.data]
%endmacro

section .text

extern vectorNew
extern vectorNewRaw
extern vectorCopy
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
              mov   [rax + vector.data], rdi
              ret

;; @cdecl64
;; BigInt biFromString(char const *s);
;;
;; Makes a BigInt from a string literal.
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
;; @param  RDI bi -- BigInt to delete
biDelete:
              call  vectorDelete
              ret

;; @cdecl64
;; void biToString(BigInt bi, char *buffer, size_t limit);
;;
;; Makes a string representation of BigInt and stores it into buffer.
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
;; @param  RDI bi -- bigint to compare
;; @return RAX -- result of comparison
biSign:
              ;; Check for zero at first
              JCOND ne, qword [rdi + vector.size], 1, .sign_check
              JCOND ne, qword [rdi + vector.data], 0, .sign_check

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
              test  r12, r12          ; Check if sign is zero, this means a and b are both zeroes
              je    .equal

              mov   rcx, [rdi + vector.size] ; Compare sizes now
              ; mov   r14, [rsi + vector.size]

              cmp   rcx, qword [rsi + vector.size]
              jb    .a_abs_lt_b
              ja    .a_abs_gt_b
              
              ;; Here RCX stores the size of a and b
              lea   rdi, [rdi + vector.data]
              lea   rsi, [rsi + vector.data]
.compare_loop:
              mov   rax, [rdi]
              cmp   rax, [rsi]
              jb    .a_abs_lt_b
              ja    .a_abs_gt_b
              add   rdi, 8
              add   rsi, 8
              dec   rcx
              jnz   .compare_loop
              
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
              

;; __addShort -- inner non-cdecl function
;;
;; Adds given uint64_t to given BigInt
;;
;; @param  RDI -- BigInt address
;; @param  RDX -- uint64_t to add
;; @return RDI -- Updated BigInt address
;; @spoils RCX, RSI, RAX
__addShort:
              push  rdi
              mov   rcx, [rdi + vector.size]
              lea   rdi, [rdi + vector.data]

              add   [rdi], rdx      ; Add the RDX to least significant bigint digit
              jnc   .finish         ; and finish, if we have no carry
.carry_loop:
              add   rdi, 8
              dec   rcx
              jnz   .add_carry      ; Append zero to a vector if necessary

              pop   rdi
              
              APPEND_0_AND_POINT_TO_END
              inc   rcx             

              push  rax             ; Save maybe new vector address
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
;; @param  RDI -- BigInt address
;; @param  RSI -- uint64_t to multiply
;; @return RDI -- Multiplied BigInt address
;; @spoils RDX, RCX, RAX
__mulByShort:
              push  rdi
              mov   rcx, [rdi + vector.size]
              lea   rdi, [rdi + vector.data]

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
              push  rax             ; Save maybe new vector address
                     
              jmp   .mult_loop
.clear_tail:
              pop   rdi
              call  __clearTail     ; Clear the leading zeroes, if they exist
              ret
               
;; __divByShort -- inner non-cdecl function
;;
;; Divides given BigInt by given uint64_t
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
              lea   rdi, [rdi + rcx*8 + vector.data] ; Point RDI to the end of vector
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
;; @param  RDI -- BigInt address
;; @spoils RCX

__clearTail:
              push  rdi
              mov   rcx, [rdi + vector.size]          ; Store vector size in RCX
              dec   rcx
              lea   rdi, [rdi + rcx*8 + vector.data]  ; Point RDI to the end
              inc   rcx
.check_loop
              JCOND ne, qword [rdi], 0, .finish ; Finish if current digit isn't zero
              JCOND e, rcx, 1, .finish ; or it's the least significant digit

              dec   rcx
              sub   rdi, 8
              jmp   .check_loop
.finish:
              pop rdi
              mov   [rdi + vector.size], rcx
              ret
