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
extern vectorAppend
extern vectorResize
              
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
              jg    .positive       ; Set the sign and invert given int if it's negative

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
              JCOND e, dl, 0, .return_null ; Check for empty or single minus ('-') string.
              xchg  rax, rdi        ; now RDI points to bigint, RAX - to string
.main_loop:
              JCOND e, dl, 0,  .return      ; If it's the end of the string - return 
              JCOND l, dl, 48, .return_null ; Check if current symbol is digit,
              JCOND g, dl, 57, .return_null ; and return NULL otherwise

              mpush rax, rdx

              mov   rsi, 10         ; Multiply bigint by 10
              call  __mulByShort

              pop   rdx
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
              call  vectorDelete    ; Clear allocated bigint (assume that we have it in RDI now)
              xor   rax, rax        ; Return NULL
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
              
              

;; __addShort -- inner non-cdecl function
;;
;; Adds given uint64_t to given BigInt
;;
;; @param  RDI -- BigInt address
;; @param  RDX -- uint64_t to add
;; @return RDI -- Updated BigInt address
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

              push  rax             ; Save maybe new vector address
.add_carry:
              adc   [rdi], 0
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
__mulByShort:
              push  rdi
              mov   rcx, [rdi + vector.size]
              lea   rdi, [rdi + vector.data]

              xor   rdx, rdx        ; Reset carry data
.mult_loop:
              mov   rax, [rdi]
              mul   rsi
              add   rax, rdx        ; RAX - uint64-digit of result
              adc   rdx, 0          ; RDX - carry

              mov   [rdi], rax      ; Copy calculated digit

              add   rdi, 8
              dec   rcx
              jnz   .mult_loop      ; repeat until end is not reached

              test  rdx, rdx        ; If carry is not zero yet
              je    .clear_tail     ; then append zero to vector and repeat

              pop   rdi             ; Restore vector address
              push  rsi

              APPEND_0_AND_POINT_TO_END
              
              pop   rsi
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
__divByShort:
              push  rdi
              mov   rcx, [rdi + vector.size]
              dec   rcx
              lea   rdi, [rdi + rcx*8 + vector.data] ; Point RDI to the end of vector
              inc rcx

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

__clearTail:
              push  rdi
              mov   rcx, [rdi + vector.size]          ; Store vector size in RCX
              lea   rdi, [rdi + rcx*8 + vector.data]  ; Point RDI to the end
.check_loop
              JCOND ne, qword [rdi], 0, .finish ; Finish if current digit isn't zero
              JCOND e, rcx, 1, .finish ; or it's the least significant digit

              dec   rcx
              sub   rdi, 8
              jmp   .check_loop
.finish:
              pop rdi
              ret
