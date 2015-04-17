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

;BigInt biFromInt(int64_t x);
;
; @return rax address of brand new bigint struc
biFromInt:
        mov     rsi, 8
        push    rdi
        NEW_BI  rsi, rdx
        pop     rcx
        mov     [rdx], rcx
        ret

;BigInt biFromString(char const *s);
; TODO:
; lodsb loads next byte from rsi address into al and increments rsi
; movdqa loads an double quadword integer from xmmN to mem128 and vice versa
; pmulhw multiplies packed signed integer and stores hight result, pmullw stores low result
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
biSign:
        ret

;void biAdd(BigInt dst, BigInt src);
biAdd:
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

