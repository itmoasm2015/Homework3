default rel

extern calloc
extern free

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

section .text

    struc BigInt_t
size:   resq    1
sign:   resq    1
data:   resq    1
    endstruc

;;Create a BigInt from 64-bit signed integer.
;BigInt biFromInt(int64_t x);
;
;Parameters:
;   1) RDI - x
;Returns:
;   RAX - address of allocated BigInt
biFromInt: 
    push    rdi 

    mov     rdi, 1
    mov     rsi, BigInt_t_size
    call    calloc
    mov     rdx, rax

    pop     rdi

    mov     [rdx + sign], 0
    mov     [rdx + size], 0

    cmp     rdi, 0
    je      .return
    jg      .sign_set

    mov     [rdx + sign], 1
    not     rdi
    inc     rdi

.sign_set:
    push    rdx
    push    rdi

    mov     rdi, 1
    mov     rsi, 8
    call    calloc

    pop     rdi
    pop     rdx

    mov     [rax], rdi
    mov     [rdx + data], rax

.return:
    mov     rax, rdx

    ret


;;Create a BigInt from a decimal string representation.
;; Returns NULL on incorrect string.
BigInt biFromString(char const *s)

;; Generate a decimal string representation from a BigInt.
;;  Writes at most limit bytes to buffer
void biToString(BigInt bi, char *buffer, size_t limit);

;; Destroy a BigInt.
void biDelete(BigInt bi);

;; Get sign of given BigInt.
int biSign(BigInt bi);

;; dst += src
void biAdd(BigInt dst, BigInt src);

;; dst -= src
void biSub(BigInt dst, BigInt src);

;; dst *= src */
void biMul(BigInt dst, BigInt src);

;; Compute quotient and remainder by divising numerator by denominator.
;;   quotient * denominator + remainder = numerator
void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);

;; Compare two BitInts. Returns sign(a - b)
int biCmp(BigInt a, BigInt b)

