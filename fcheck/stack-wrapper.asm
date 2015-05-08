default rel
extern fprintf, stderr, exit

extern malloc, calloc, strlen, free, memcpy, realloc, memmove, abort

global biFromInt
global biFromString
global biDelete
global biToString
global biSign
global biCmp
global biAdd
global biSub
global biMul
global biDivRem

global hw_malloc
global hw_calloc
global hw_strlen
global hw_free
global hw_memcpy
global hw_realloc
global hw_abort
global hw_memmove

extern hw_biFromInt
extern hw_biFromString
extern hw_biDelete
extern hw_biToString
extern hw_biSign
extern hw_biCmp
extern hw_biAdd
extern hw_biSub
extern hw_biMul
extern hw_biDivRem

section .text

biFromInt: jmp hw_biFromInt
biFromString: jmp hw_biFromString
biDelete: jmp hw_biDelete
biToString: jmp hw_biToString
biSign: jmp hw_biSign
biCmp: jmp hw_biCmp
biAdd: jmp hw_biAdd
biSub: jmp hw_biSub
biMul: jmp hw_biMul
biDivRem: jmp hw_biDivRem

%macro WRAP 1
hw_ %+ %1:
    lea r11, [s %+ %1]
    lea r10, [rsp + 8]
    test r10, 0xf
    jne fail
    jmp %1
%endmacro

WRAP malloc

WRAP calloc

WRAP strlen

WRAP free

WRAP memcpy

WRAP realloc

WRAP memmove

WRAP abort

fail:
    mov rdi, [stderr]
    mov rsi, r11
    call fprintf
    mov rdi, 1
    call exit


section .data
smalloc: db "Misaligned stack in malloc call", 10, 0
scalloc: db "Misaligned stack in calloc call", 10, 0
sstrlen: db "Misaligned stack in strlen call", 10, 0
sfree: db "Misaligned stack in free call", 10, 0
smemcpy: db "Misaligned stack in memcpy call", 10, 0
srealloc: db "Misaligned stack in realloc call", 10, 0
smemmove: db "Misaligned stack in memmove call", 10, 0
sabort: db "Misaligned stack in abort call", 10, 0
