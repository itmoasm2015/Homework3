; calee-save RBX, RBP, R12-R15
; rdi , rsi ,
; rdx , rcx , r8 ,
; r9 , zmm0 - 7
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

extern calloc
extern free


; BigInt biFromInt(int64_t x);
biFromInt:
    mov rax, rdi
    ret

; BigInt biFromString(char const *s);
biFromString:
    ret

; void biToString(BigInt bi, char *buffer, size_t limit);
biToString:
    ret

; void biDelete(BigInt bi);
biDelete:
    ret

; int biSign(BigInt bi);
biSign:
    ret

; void biAdd(BigInt dst, BigInt src);
biAdd:
    ret

; void biSub(BigInt dst, BigInt src);
biSub:
    ret

; void biMul(BigInt dst, BigInt src);
biMul:
    ret

; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
biDivRem:
    ret

; int biCmp(BigInt a, BigInt b);
biCmp:
    ret

