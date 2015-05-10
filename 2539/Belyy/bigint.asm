default rel

section .text


%include "vector.i"


extern allocAlign
extern freeAlign
extern vecAlloc
extern vecFree
extern vecCopy
extern vecResize


global biFromInt
global biFromBigInt
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


%macro              negate_bigint 1
                    mov cl, [%1 + bigint.negative]
                    neg cl
                    inc cl
                    mov [%1 + bigint.negative], cl
%endmacro


; bigint biFromInt(int64_t x);
;
; Takes:
;   RDI - int64_t x
; Returns:
;   RAX - pointer to a new bigint

biFromInt:          push rdi
    ; allocate vector of size 1
                    xor rdi, rdi
                    inc rdi
                    call vecAlloc
                    push rax
                    mov rdi, bigint_size
    ; allocate bigint
    ; and set negative = false, qwords[0] = x
                    call allocAlign
                    pop r8
                    mov byte [rax + bigint.negative], 0
                    mov [rax + bigint.qwords], r8
                    pop rdi
                    test rdi, rdi
                    jns .positive
    ; if x < 0, set negative = true
                    inc byte [rax + bigint.negative]
                    neg rdi
.positive:          mov [r8 + vector.data], rdi
                    ret

; bigint biFromBigInt(bigint bi);
; Clones existing bigint.
;
; Takes:
;   RDI - bigint bi
; Returns:
;   RAX - new bigint

biFromBigInt:       mov cl, [rdi + bigint.negative]
                    push rcx
    ; create a new vector of size `bi.qwords.size`
                    mov rdi, [rdi + bigint.qwords]
                    push rdi
                    mov rdi, [rdi + vector.size]
                    call vecAlloc
    ; copy the contents of old vector to new
                    mov rdi, rax
                    pop rsi
                    push rdi
                    call vecCopy
    ; create a new bigint
                    mov rdi, bigint_size
                    call allocAlign
                    pop rdi
                    pop rcx
                    mov [rax + bigint.negative], cl
                    mov [rax + bigint.qwords], rdi
                    ret

; bigint biFromString(char * s);
;
; Takes:
;   RDI - char * s
; Returns:
;   RAX - new bigint

biFromString:       push rbx
                    push r12
                    push r13
                    push r14
                    push rdi
    ; r13 = biFromInt(0), accumulator bigint
                    xor rdi, rdi
                    call biFromInt
                    xor r12w, r12w
                    mov r13, rax
    ; r14 = biFromInt(0), helper bigint 
                    xor rdi, rdi
                    call biFromInt
                    mov r14, rax
                    pop rbx
                    cmp byte [rbx], '-'
                    je .negative
    ; R12W - parser state:
    ;   bits 0..7 - current symbol
    ;   bits 8..9 - flags:
    ;       8 - number is negative
    ;       9 - at least one digit read
.parse_loop:        mov r12b, [rbx]
                    test r12b, r12b
                    jz .end_read
    ; check input correctness
                    cmp r12b, '0'
                    jb .failure
                    cmp r12b, '9'
                    ja .failure
                    sub r12b, '0'
    ; multiply accumulator by 10
                    or r12w, 512
                    mov rdi, r13
                    mov rsi, 10
                    call _mul
    ; set helper bigint to value of r12b
    ; add add it to accumulator bigint
                    mov rdi, [r14 + bigint.qwords]
                    mov [rdi + vector.data], r12b
                    mov rdi, r13
                    mov rsi, r14
                    call _add
                    inc rbx
                    jmp .parse_loop
.negative:          or r12w, 256
                    inc rbx
                    jmp .parse_loop
.end_read:          test r12w, 512
                    jz .failure
                    mov rax, r13
    ; set negative flag
                    mov cx, r12w
                    shr cx, 8
                    and cl, 1
                    mov [rax + bigint.negative], cl
    ; remove leading zeros
                    mov rdi, rax
                    push rax
                    call _normalize
                    jmp .cleanup
.failure:           mov rdi, r13
    ; input was incorrect
                    call biDelete
                    xor rax, rax
                    push rax
.cleanup:           mov rdi, r14
    ; free helper bigint
                    call biDelete
                    pop rax
    ; restore sysv registers
                    pop r14
                    pop r13
                    pop r12
                    pop rbx
                    ret

; void biDelete(bigint bi);
;
; Takes:
;   RDI - bigint bi

biDelete:           mov r8, [rdi + bigint.qwords]
                    push r8
    ; free bigint
                    call freeAlign
                    pop rdi
    ; free bigint's vector
                    call vecFree
                    ret

; internal void add(bigint a, bigint b);
; Adds two unsigned bigints.
;
; Takes:
;   RDI - bigint a
;   RSI - bigint b

_add:               push rdi
                    mov rdi, [rdi + bigint.qwords]
                    mov rsi, [rsi + bigint.qwords]
                    push rsi
                    mov rsi, [rsi + vector.size]
                    cmp rsi, [rdi + vector.size]
                    cmovb rsi, [rdi + vector.size]
    ; make sure that even with carry
    ; the result will fit into `a`
                    push rsi
                    inc rsi
                    call vecResize
                    pop rcx
                    pop rsi
                    pop r8
                    mov [r8 + bigint.qwords], rax
                    mov rdi, rax
                    add rdi, vector.data
                    add rsi, vector.data
                    clc
                    lahf
.add_numbers:       mov rdx, [rsi]
                    sahf
                    adc [rdi], rdx
                    lahf
                    add rdi, 8
                    add rsi, 8
                    dec rcx
                    jnz .add_numbers
                    sahf
.propagate_carry:   adc qword [rdi], 0
                    lea rdi, [rdi + 8]
                    jc .propagate_carry
                    ret

; internal void sub(bigint a, bigint b);
; Subtracts two unsigned bigints.
;
; Takes:
;   RDI - bigint a
;   RSI - bigint b

_sub:               mov rdi, [rdi + bigint.qwords]
                    mov rsi, [rsi + bigint.qwords]
                    mov rcx, [rsi + vector.size]
                    add rdi, vector.data
                    add rsi, vector.data
                    clc
                    lahf
.sub_numbers:       mov rdx, [rsi]
                    sahf
                    sbb [rdi], rdx
                    lahf
                    add rdi, 8
                    add rsi, 8
                    dec rcx
                    jnz .sub_numbers
                    sahf
                    jc .subtract_carry
                    ret
.subtract_carry:    sbb qword [rdi], 0
                    lea rdi, [rdi + 8]
                    jc .subtract_carry
                    ret

; internal int abs_compare(bigint a, bigint b);
; Compares absolute values of two bigints.
;
; Takes:
;   RDI - bigint a
;   RSI - bigint b

_abs_compare:       mov rdi, [rdi + bigint.qwords]
                    mov rsi, [rsi + bigint.qwords]
                    mov r8, [rdi + vector.size]
                    xor rax, rax
                    cmp r8, [rsi + vector.size]
    ; compare bigint lengths
                    jl .less
                    jg .greater
                    add rdi, vector.data
                    add rsi, vector.data
.compare_loop:      dec r8
                    mov rdx, [rsi + 8 * r8]
                    cmp [rdi + 8 * r8], rdx
    ; compare bigint digits
                    jl .less
                    jg .greater
                    test r8, r8
                    jnz .compare_loop
    ; bigints are equal
                    ret
.less:              dec rax
                    ret
.greater:           inc rax
                    ret

; internal void normalize(bigint bi);
; Removes leading zero digits from bigint.
;
; Takes:
;   RDI - bigint bi

_normalize:         push rdi
                    mov rdi, [rdi + bigint.qwords]
                    mov rsi, [rdi + vector.size]
.calculate_size:    cmp qword [rdi + 8 * (rsi - 1) + vector.data], 0
                    jne .break
                    dec rsi
                    jz .zero
                    jmp .calculate_size
.break:             call vecResize
    ; first non-zero digit found
                    pop rdi
                    mov [rdi + bigint.qwords], rax
                    ret
.zero:              pop rdi
    ; no non-zero digits were found -- set bigint to zero
                    call _set_zero
                    ret

; internal void set_zero(bigint bi);
; Sets number to zero.
;
; Takes:
;   RDI - bigint bi

_set_zero:          push rdi
    ; set `bi` size to 1
                    mov rdi, [rdi + bigint.qwords]
                    xor rsi, rsi
                    inc rsi
                    call vecResize
                    pop rdi
    ; set negative = false and qwords[0] = 0
                    mov byte [rdi + bigint.negative], 0
                    mov [rdi + bigint.qwords], rax
                    mov qword [rax + vector.data], 0
                    ret

; void biAdd(bigint dst, bigint src);
;
; Takes:
;   RDI - bigint dst
;   RSI - bigint src

biAdd:
    ; rdi == rsi?
                    cmp rdi, rsi
                    je .clone_src
                    push 0
    ; state is stored in the following flags:
    ; al == sgn(abs(dst) - abs(src))
    ; cl == dst.negative
    ; ch == src.negative
.entry:             mov cl, [rdi + bigint.negative]
                    mov ch, [rsi + bigint.negative]
                    push rdi
                    push rsi
                    push rcx
    ; compare numbers' magnitudes
                    call _abs_compare
                    pop rcx
                    pop rsi
    ; consider different relations between `dst` and `src`
                    cmp cl, ch
                    je .a_plus_b
                    test rax, rax
                    js .b_minus_a
    ; in other cases it's (a - b)
.a_minus_b:         mov rdi, [rsp]
                    call _sub
                    jmp .finally
.a_plus_b:          mov rdi, [rsp]
                    mov [rdi + bigint.negative], cl
                    call _add
                    jmp .finally
.b_minus_a:         mov rdi, rsi
                    call biFromBigInt
                    mov rsi, rax
                    mov rdi, [rsp]
    ; exchange contents of [rdi] and [rsi] bigints
                    mov cl, [rsi + bigint.negative]
                    xchg cl, [rdi + bigint.negative]
                    mov [rsi + bigint.negative], cl
                    mov rcx, [rsi + bigint.qwords]
                    xchg rcx, [rdi + bigint.qwords]
                    mov [rsi + bigint.qwords], rcx
                    push rsi
                    call _sub
                    pop rdi
                    call biDelete
.finally:           pop rdi
    ; remove leading zeros
                    call _normalize
    ; were dst == src?
                    pop rax
                    test rax, rax
                    jnz .free_src
                    ret
.clone_src:         push rdi
                    mov rdi, rsi
                    call biFromBigInt
                    pop rdi
                    mov rsi, rax
                    push rsi
                    push 1
                    jmp .entry
.free_src:          pop rdi
                    call biDelete
                    ret

; void biSub(bigint dst, bigint src);
;
; Takes:
;   RDI - bigint dst
;   RSI - bigint src

; a - b = a + (-b)
biSub:              negate_bigint rsi
                    push rsi
                    call biAdd
                    pop rsi
                    negate_bigint rsi
                    ret

; internal void mul(bigint bi, uint64_t k);
; Multiplies bigint by an integer.
;
; Takes:
;   RDI - bigint bi
;   RSI - uint64_t k

_mul:               push rdi
                    mov rdi, [rdi + bigint.qwords]
                    push rsi
                    mov rsi, [rdi + vector.size]
    ; make sure that even with carry
    ; the result will fit into `bi`
                    push rsi
                    inc rsi
                    call vecResize
                    pop rcx
                    pop rsi
                    pop rdi
                    mov [rdi + bigint.qwords], rax
                    lea r8, [rax + vector.data]
                    xor r9, r9
.mul_loop:          mov rax, [r8]
                    mul rsi
    ; res = bi[i] * k + carry
    ; carry = res >> 32
                    add rax, r9
                    adc rdx, 0
                    mov [r8], rax
                    mov r9, rdx
                    add r8, 8
                    dec rcx
                    jnz .mul_loop
    ; bi[size] = carry
                    mov [r8], r9
    ; remove leading zeros
                    call _normalize
                    ret

; void biMul(bigint a, bigint b);
;
; Takes:
;   RDI - bigint a
;   RSI - bigint b

biMul:
    ; rdi == rsi?
                    cmp rdi, rsi
                    je .clone_src
                    push 0
    ; save sysv registers
.entry:             push rbx
                    push r12
                    push r13
    ; clone `dst` bigint
                    push rdi
                    push rsi
                    call biFromBigInt
                    mov rbx, rax
                    pop rsi
                    push rbx
                    push rsi
    ; set `dst` bigint to zero
                    mov rdi, [rsp + 16]
                    call _set_zero
    ; set negative flag of `dst`
                    mov rdi, [rsp + 16]
                    mov rsi, [rsp]
                    mov al, [rbx + bigint.negative]
                    xor al, [rsi + bigint.negative]
                    mov [rdi + bigint.negative], al
    ; resize `dst` to contain the result
                    mov r12, [rbx + bigint.qwords]
                    mov r12, [r12 + vector.size]
                    mov r13, [rsi + bigint.qwords]
                    mov r13, [r13 + vector.size]
                    mov rdi, [rdi + bigint.qwords]
                    lea rsi, [r12 + r13]
                    call vecResize
                    mov rdi, [rsp + 16]
                    pop rsi
                    mov [rdi + bigint.qwords], rax
                    mov rdi, [rdi + bigint.qwords]
                    mov rbx, [rbx + bigint.qwords]
                    mov rsi, [rsi + bigint.qwords]
    ; `dst` (rdi) = cloned `dst` (rbx) * `src` (rsi)
                    xor r8, r8
.mul_loop_1:        xor rcx, rcx
                    xor r9, r9
.mul_loop_2:        mov rax, [rbx + 8 * r8 + vector.data]
                    mul qword [rsi + 8 * r9 + vector.data]
                    add rax, rcx
                    adc rdx, 0
                    lea r10, [r8 + r9]
                    add rax, [rdi + 8 * r10 + vector.data]
                    adc rdx, 0
                    mov rcx, rdx
    ; dst.qwords[r8 + r9] = rax
                    mov [rdi + 8 * r10 + vector.data], rax
                    inc r9
                    cmp r9, r13
                    jne .mul_loop_2
    ; dst.qwords[r8 + r13] = rcx
                    lea r10, [r8 + r13]
                    mov [rdi + 8 * r10 + vector.data], rcx
                    inc r8
                    cmp r8, r12
                    jne .mul_loop_1
    ; free `rbx` bigint
                    pop rdi
                    call biDelete
    ; remove leading zeros
                    pop rdi
                    call _normalize
    ; restore sysv registers
                    pop r13
                    pop r12
                    pop rbx
    ; were dst == src?
                    pop rax
                    test rax, rax
                    jnz .free_src
                    ret
.clone_src:         push rdi
                    mov rdi, rsi
                    call biFromBigInt
                    pop rdi
                    mov rsi, rax
                    push rsi
                    push 1
                    jmp .entry
.free_src:          pop rdi
                    call biDelete
                    ret

; int biCmp(bigint a, bigint b);
;
; Takes:
;   RDI - bigint a
;   RSI - bigint b
; Returns:
;   RAX - biSign(a - b)

biCmp:              mov cl, [rdi + bigint.negative]
                    mov ch, [rsi + bigint.negative]
                    push rcx
    ; compare numbers' magnitudes
                    call _abs_compare
                    pop rcx
    ; consider different relations between `a` and `b`
                    test rax, rax
                    js .less
                    jnz .greater
.equal:             cmp cl, ch
                    jne .greater
                    ret
.less:              test ch, ch
                    jnz .return_greater
.return_less:       xor rax, rax
                    dec rax
                    ret
.greater:           test cl, cl
                    jnz .return_less
.return_greater:    xor rax, rax
                    inc rax
                    ret

; int biSign(bigint bi);
;
; Takes:
;   RDI - bigint bi
; Returns:
;   RAX - 0 if bi == 0, bi / abs(bi) otherwise.

biSign:             xor rax, rax
                    cmp byte [rdi + bigint.negative], 0
    ; if negative == true, `bi` definitely < 0
                    jne .negative
                    mov r8, [rdi + bigint.qwords]
                    cmp qword [r8 + vector.data], 0
                    jne .positive
    ; if qwords[0] == 0 and qwords.size == 1, `bi` == 0
                    cmp qword [r8  + vector.size], 1
                    je .zero
.positive:          inc rax 
.zero:              ret
.negative:          dec rax
                    ret

; void biDivRem(bigint * quotient, bigint * remainder, bigint numerator, bigint denominator);
;
; Takes:
;   RDI - bigint * quotient
;   RSI - bigint * remainder
;   RDX - bigint numerator
;   RDX - bigint denominator

biDivRem:           ret

; void biToString(bigint bi, char * buffer, size_t limit);
;
; Takes:
;   RDI - bigint bi
;   RSI - char * buffer
;   RDX - size_t limit

biToString:         mov byte [rsi + 0], 'N'
                    mov byte [rsi + 1], 'A'
                    mov byte [rsi + 2], 0
                    ret
