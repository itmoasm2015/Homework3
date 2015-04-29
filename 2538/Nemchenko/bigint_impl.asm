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
;global main
;main:
    ;ret

extern calloc, free

BASE equ 1 << 64
DEFAULT_SIZE equ 10

;
; stored bigNumber like this:
; struct bigNum {
;   unsigned int capacity;              4 bytes
;   unsigned int size;                  4 bytes
;   int sign;                           4 byte
;   padding 4 bytes to stored "digits" in address multiples 8
;   unsigned int64_t digits[capacity];  8 * capacity bytes
; }
;  
; forall i < capacity: digits[i] < BASE
; sign = 1 | 0 | -1 , more than 0, equal and less respectively

; allocate (%1 + 2) * 8 bytes
; pointer saved to rax
%macro allocate_memory 1
    push rdi
    push rsi

    mov rdi, %1
    add rdi, 2     ; for storing capacity, size, sign. 12 bytes + 4b padding
    mov rsi, 8
    call calloc 

    imul rdi, 8
    mov [rax], rdi ; set capacity = (%1 + 2) * 8

    pop rsi
    pop rdi
%endmacro

; first argument - pointer to the structure bigNum
; second argument - arg::(unsigned long long)  which will be pushed into the "digits"
; pre: "size" have to < "capacity"
%macro push_back 2
    push %1
    push rcx

    xor  rcx, rcx
    add  %1, 4            ; %1 refer to size
    mov  ecx, dword [%1]  ; rcx = size
    imul rcx, 8           ; rcx = size * 8
    add  rcx, 8           ; skip sign field and padding 4 bytes
    inc  dword [%1]       ; size++

    add %1, rcx           ; %1 refer to last free position in digits
    mov qword [%1], %2    ; set first digit to appropriate position

    pop rcx
    pop %1
%endmacro

; BigInt biFromInt(int64_t x);
biFromInt:
    allocate_memory DEFAULT_SIZE
    push_back rax, rdi
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

