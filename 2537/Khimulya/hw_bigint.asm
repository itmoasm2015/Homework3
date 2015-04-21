default rel

global biFromInt
global biFromString
global biToString
global biDelete
global biSign
global biAdd
global biSub
global biMul
global biDivRem
global biCmp

extern malloc
extern free

struc   bigint
        .len    resb    8           ; size in bytes
        .data   resb    8           ; pointer to data, big-endian
endstruc

; allocates memory for big integer (data and struct)
;
; corrupts all registers execpt for callee-saved and %1, %2
;
; @arg %1 register with size of bigint in bytes
; @arg %2 register where address of bigit.data will be stored
;
; @return address to bigint struct in rax
; @return %2 address to bigint's data
%macro  NEW_BI 2
        mov     rdi, %1
        push    %1
        call    malloc              ; allocation for data
        push    rax
        mov     rdi, bigint_size
        call    malloc              ; allocation for headers
        pop     %2
        pop     %1
        mov     [rax + bigint.len], %1
        mov     [rax + bigint.data], %2
%endmacro

; frees memory of bigit
;
; corrupts all registers execpt for callee-saved
;
; @arg %1 address of bigint struc to be removed
%macro  DEL_BI 1
        push    %1
        mov     rdi, [%1 + bigint.data]
        call    free
        pop     rdi
        call    free
%endmacro

; returns 0 if given bigint is positive and -1 otherwise
;
; corrupts r8, r9
;
; @arg %1 address of bigint
;
; @return %2 64-bit representation of 0 or -1
%macro  SIGN 2
        mov     r8, [%1 + bigint.len]
        mov     r9, [%1 + bigint.data]
        mov     r9, [r9 + r8 - 8]
        test    r9, [MSB]             ; last number
        jnz     %%neg
        mov     %2, 0
        jmp     %%done
     %%neg:
        mov     %2, MINUS1_64
     %%done:
%endmacro

; computes maximum of two general purpose registers
;
; @arg %2 first operand
; @arg %3 second operand
; note: only one of two operands can be memory
;
; @return %1 maxumum of given values
%macro  MAX 3
        sub     %2, %3
        jo      %%second
        mov     %1, %2
        jmp     %%done
    %%second:
        mov     %1, %3
    %%done:
%endmacro

section .rodata
        align   8
    MSB:
        dq      0x8000000000000000  ; only first MSB is true
    MINUS1_64:
        dq      0xffffffffffffffff

section .text

;BigInt biFromInt(int64_t x);
;
; @return rax address of brand new bigint struc
biFromInt:
        push    rdi
        mov     rsi, 8
        NEW_BI  rsi, rdx
        pop     rdi
        mov     [rdx], rdi
        ret

;BigInt biFromString(char const *s);
; TODO:
; lodsb loads next byte from rsi address into al and increments rsi
; movdqa loads an double quadword integer from xmmN to mem128 and vice versa
; pmulhw multiplies packed signed integer and stores high result, pmullw stores low result
biFromString:
        ret

;void biToString(BigInt bi, char *buffer, size_t limit);
biToString:
        ret

;void biDelete(BigInt bi);
biDelete:
        DEL_BI  rdi
        ret

;int biSign(BigInt bi);
; Consider a few clauses and return -1, 0, 1 if number negative, zero or positive, respectly.
; note: SIGN macro isn't applicatable here because it has only two return values
biSign:        
        mov     rcx, [rdi + bigint.len]
        mov     rdx, [rdi + bigint.data]
        mov     rdx, [rdx + rcx - 8]                    ; less significant quadword
        test    rdx, [MSB]                              ; if MSB is set, return -1
        jnz     .neg
        cmp     rcx, 8                                  ; if size == 8 bytes
        jne     .pos                                    ; and only number is zero
        cmp     rdx, 0                                  ; return 0
        jne     .pos
        mov     rax, 0
        ret
    .pos:
        mov     rax, 1                                  ; otherwise return 1
        ret
    .neg:
        mov     rax, -1
        ret

;void biAdd(BigInt dst, BigInt src);
biAdd:
        mov     rdx, [rdi + bigint.len]
        MAX     rcx, rdx, [rsi + bigint.len]
        add     rcx, 8
        NEW_BI  r8, rax                     ; let's allocate memory for the biggest number possible

        mov     rdx, [rdi + bigint.len]
        cmp     rdx, [rsi + bigint.len]
        jae     .done_swap
        xchg    rdi, rsi
     .done_swap:                            ; now the longest number in rdi
        mov     rcx, [rsi + bigint.len]
        shr     rcx, 3                      ; number of iterations for loop1
        mov     rbx, [rdi + bigint.data]
        mov     rdx, [rsi + bigint.data]
        clc
        .loop1:
                mov     r9, [rbx]
                adc     r9, [rdx]
                mov     [rax], r9
                add     rbx, 8
                add     rdx, 8
                add     rax, 8
                loop    .loop1

        ret

;void biSub(BigInt dst, BigInt src);
biSub:
        ret

;void biMul(BigInt dst, BigInt src);
biMul:
        ret

;void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
biDivRem:
        ret

;int biCmp(BigInt a, BigInt b);
biCmp:
        ret

