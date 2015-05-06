section .text


%include "vector.i"


extern malloc
extern free
extern vecAlloc
extern vecFree
extern vecResize


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


                    struc   bigint
.negative:          resb    1
.qwords:            resq    1
                    endstruc


%macro              floor_2 1
                    and %1, ~1
%endmacro

%macro              ceil_2 1
                    inc %1
                    and %1, ~1
%endmacro


; bigint biFromInt(int64_t x);
;
; Takes:
;   RDI - int64_t x
; Returns:
;   RAX - pointer to a new bigint

biFromInt:          push rdi
                    xor rdi, rdi
                    inc rdi
                    call vecAlloc
                    push rax
                    mov rdi, bigint_size
                    call malloc
                    pop r8
                    mov byte [rax + bigint.negative], 0
                    mov [rax + bigint.qwords], r8
                    pop rdi
                    test rdi, rdi
                    jns .positive  
                    inc byte [rax + bigint.negative]
                    neg rdi
.positive:          mov [r8 + vector.data], rdi
                    ret


biFromString:       ret

; void biDelete(bigint bi);
;
; Takes:
;   RDI - bigint bi

biDelete:           mov r8, [rdi + bigint.qwords]
                    push r8
                    call free
                    pop rdi
                    call vecFree
                    ret

; internal vector add(vector dst, vector src);
; Adds two unsigned bigints and returns the resulting vector.
;
; Takes:
;   RDI - vector dst
;   RSI - vector src

_add:               push rsi
                    mov rsi, [rsi + vector.size]
                    inc rsi                         ; to make sure that even with carry
                    push rsi                        ; the result will fill into `data`.
                    call vecResize
                    pop rcx
                    pop rsi
                    mov rdi, rax
                    add rdi, vector.data
                    add rsi, vector.data
                    clc
.add_numbers:       mov rdx, [rsi]
                    adc [rdi], rdx
                    lea rdi, [rdi + 8]
                    lea rsi, [rsi + 8]
                    dec rcx
                    jnz .add_numbers
.propagate_carry:   adc qword [rdi], 0
                    lea rdi, [rdi + 8]
                    jc .propagate_carry
                    ret

; void biAdd(bigint dst, bigint src);
;
; Takes:
;   RDI - bigint dst
;   RSI - bigint src

biAdd:              ret


biSub:              ret
biMul:              ret
biCmp:              ret

; int biSign(bigint bi);
;
; Takes:
;   RDI - bigint bi
; Returns:
;   RAX - 0 if bi == 0, bi / abs(bi) otherwise.

biSign:             xor rax, rax
                    mov r8, [rdi + bigint.qwords]
                    cmp qword [r8 + vector.data], 0
                    je .zero
                    cmp byte [rdi + bigint.negative], 0
                    je .positive
                    dec rax
                    dec rax
.positive:          inc rax 
.zero:              ret

biDivRem:           ret
biToString:         ret
