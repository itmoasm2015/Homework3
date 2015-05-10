;;; This is a library that implements big integer interface

        struc   bigint
.sign   resd 1                  ; 0xffffffff for -, 0x00000000 for +
.size   resd 1
.data   resq 1
        endstruc
%define bigint_size 16
%define trailing_removed_after 0

extern malloc
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

global biDump
global biSize
global biExpand
global biMulShort
global biDivShort
global biCutTrailingZeroes
global biAddUnsigned

;;; void biCutTrailingZeroes(BigInt a)
;;; removes trailing zeroes, if the whole bigint is zero, frees .data
;;; reallocates .data section of bigint if more than trailing_removed_after
;;; trailing zeroes were removed
biCutTrailingZeroes:
        mov     r8, rdi

        ;; return if it's 0

        ;; ecx -- number of trailing zeroes removed
        xor     ecx, ecx
        xor     rdi, rdi

        ;; loop for removing trailing zeroes
        mov     r9, [r8+bigint.data]       ; data
        .loop
        mov     eax, dword[r8+bigint.size] ; current size
        cmp     eax, 0
        je      .free                      ; return if size is 0

        mov     edi, eax
        dec     edi                        ; indexing from 0
        cmp     qword[r9+8*rdi], 0         ; return if last portion of data non-null
        jne     .reallocate
        dec     dword[r8+bigint.size]
        inc     ecx
        jmp     .loop

        .reallocate
        cmp     ecx, trailing_removed_after
        jle     .return

        ;; allocate array of new size
        push    r8
        push    r9
        mov     edi, dword[r8+bigint.size]
        shl     edi, 3
        call    malloc
        pop     r9
        pop     r8
        mov     r10, rax

        ;; copy old data to new array
        xor     ecx, ecx
        .loop_copy
        mov     rdi, [r9+8*rcx]
        mov     [r10+8*rcx], rdi
        inc     ecx
        cmp     ecx, dword[r8+bigint.size]
        jl      .loop_copy

        ;; free current array, mov new array address into structure
        push    r8
        push    r10
        mov     rdi, [r8+bigint.data]
        call    free
        pop     r10
        pop     r8
        mov     [r8+bigint.data], r10
        jmp     .return
        .free
        mov     dword[r8+bigint.sign], 0
        mov     rdi, r9
        call    free
        .return
        ret

;;; BigInt biFromInt(int64_t x)
;;; Create a BigInt from 64-bit signed integer.
biFromInt:
        mov     r8, rdi

        ;; get space for bigint struc, put the pointer into r9
        push    r8
        mov     rdi, bigint_size
        call    malloc
        pop     r8
        mov     r9, rax

        ;; set proper sign
        mov     dword[r9+bigint.sign], 0
        bt      r8, 63
        jnc     .nonneg
        mov     dword[r9+bigint.sign], 0xffffffff
        neg     r8
        .nonneg

        ;; set size
        mov     dword[r9+bigint.size], 1

        ;; allocate memory for array
        push    r8
        push    r9
        mov     rdi, 8
        call    malloc
        pop     r9
        pop     r8

        ;; fill it and put as a member into struc
        mov     [rax], r8
        mov     [r9+bigint.data], rax

        mov     rax, r9
        push    rax
        mov     rdi, r9

        ;; Remove trailing zeroes if present
        call    biCutTrailingZeroes
        pop     rax
        ret


;;; NEEDS MUL AND ADD
;;; BigInt biFromString(char const *s)
;;; Create a BigInt from a decimal string representation.
;;; Returns NULL on incorrect string.
biFromString:
        mov     r8, rdi

        ;; allocate place for new structure
        push    r8
        mov     rdi, bigint_size
        call    malloc
        pop     r8
        mov     r9, rax

        cmp     byte[r8], '-'
        jne     .nonneg
        mov     dword[r9+bigint.sign], 0xffffffff
        inc     r8
        .nonneg

        .loop

        mov     rax, r9
        jmp .return
        .fail
        mov     rax, 0
        .return
        ret

;;; void biToString(BigInt bi, char *buffer, size_t limit)
;;; Generate a decimal string representation from a BigInt.
;;; Writes at most limit bytes to buffer.
biToString:


;;; void biDelete(BigInt bi);
;;; Destroy a BigInt.
biDelete:
        cmp     dword[rdi+bigint.size], 0 ; if size is 0, inner array was deleted
        je      .outer
        ;; inner part
        push    rdi
        mov     rdi, [rdi+bigint.data]
        call    free
        pop     rdi
        .outer
        call    free
        ret

;;; unsigned long int* biDump(BigInt x);
biDump:
        mov     rax, [rdi+bigint.data]
        ret
;;; size_t biSize(BigInt x);
biSize:
        mov     eax, dword[rdi+bigint.size]
        ret

;;; int biSign(BigInt bi);
;;; Get sign of given BigInt.
;;; return 0 if bi is 0, positive if bi is positive, negative if bi is negative.
biSign:
        mov     r8, rdi
        mov     eax, dword[r8+bigint.sign]
        cmp     dword[r8+bigint.size], 0
        je      .return
        cmp     eax, 0xffffffff
        je      .return
        inc     eax
        .return
        ret

;;; int biCmp(BigInt a, BigInt b);
;;; Compare two BitInts.
;;; returns sign(a - b)
biCmp:
        ;; compare by length first
        mov     eax, dword[rdi+bigint.size]
        cmp     eax, dword[rsi+bigint.size]
        jg      .gt
        jl      .lt

        ;; compare by-digit
        xor     rcx, rcx
        mov     r8, [rdi+bigint.data]
        mov     r9, [rsi+bigint.data]
        .loop
        mov     rax, [r8+rcx*8]
        cmp     rax, [r9+rcx*8]
        jg      .gt
        jl      .lt
        inc     ecx
        cmp     ecx, dword[rsi+bigint.size]
        jl      .loop

        jmp     .eq

        .gt
        mov     rax, 1
        jmp     .return

        .lt
        mov     rax, -1
        jmp     .return

        .eq
        mov     rax, 0

        .return
        ret

;;; void biExpand(BigInt a, size_t new_size);
;;; copies all data to bigger array, filling higher integers with zeroes
biExpand:
        mov     r8, rdi
        mov     r9, rsi
        cmp     r9d, dword[r8+bigint.size] ; fail if new size ≤ old size
        jle     .fail

        ;; allocate memory for new array
        push    r8
        push    r9
        mov     rdi, r9
        shl     rdi, 3
        call    malloc
        pop     r9
        pop     r8
        mov     r10, rax

        ;; save new array position
        push    r10

        ;; copy old array
        mov     r11, [r8+bigint.data] ; r11 holds old array
        xor     rcx, rcx
        .loop1
        cmp     ecx, dword[r8+bigint.size]
        jge     .loop1_end
        mov     rax, [r11+rcx*8]
        mov     [r10], rax
        add     r10, 8
        inc     ecx
        jmp     .loop1
        .loop1_end

        ;; fill residual with zeroes
        push    r9
        sub     r9d, dword[r8+bigint.size]
        xor     rcx, rcx
        .loop2
        cmp     ecx, r9d
        jge     .loop2_end
        mov     qword[r10], 0
        add     r10, 8
        inc     ecx
        jmp     .loop2
        .loop2_end
        pop     r9

        ;; restore new array position
        pop     r10

        ;; free old array
        push    r8
        push    r9
        push    r10
        mov     rdi, [r8+bigint.data]
        call    free
        pop     r10
        pop     r9
        pop     r8

        ;; replace .data, .size section with expanded array
        mov     qword[r8+bigint.data], r10
        mov     dword[r8+bigint.size], r9d

        jmp     .return
        .fail
        mov     rax, [0]
        .return
        ret

;;; int biAddUnsigned(BigInt dst, BigInt src);
;;; ! dst ≠ src
;;; dst = |dst| + |src|
biAddUnsigned:
        ;; expand destination or source to get equal size()
        mov     eax, dword[rdi+bigint.size]
        cmp     eax, dword[rsi+bigint.size]
        jle      .expand_dst
        jg      .expand_src
        .expand_dst
        push    rdi
        push    rsi
        mov     esi, dword[rsi+bigint.size]
        inc     esi             ; we reserve one extra cell to save last carry
        call    biExpand
        pop     rsi
        pop     rdi
        jmp     .after_expand
        .expand_src
        push    rdi
        push    rsi
        mov     rax, rdi
        mov     rdi, rsi
        mov     esi, dword[rax+bigint.size]
        inc     esi
        call    biExpand
        pop     rsi
        pop     rdi

        ;; save data pointers
        .after_expand
        mov     r8, [rdi+bigint.data]
        mov     r9, [rsi+bigint.data]

        ;; process adding
        clc
        xor     rcx, rcx
        pushf
        .loop
        cmp     ecx, dword[rsi+bigint.size]
        jge     .loop_end
        popf
        mov     rax, [r9+8*rcx]
        adc     [r8+8*rcx], rax
        pushf
        inc     rcx
        jmp     .loop
        .loop_end
        popf

        ;; if there was carry on last addition, add it too
        jnc     .no_last_bit
        mov     qword[r8+8*rcx], 1
        .no_last_bit

        ;; removes redundant zeroes
        push    rsi
        call    biCutTrailingZeroes
        pop     rsi
        mov     rdi, rsi
        call    biCutTrailingZeroes

        ret

;;; int biAdd(BigInt dst, BigInt src);
;;; dst += src
biAdd:

;;; void biSub(BigInt dst, BigInt src);
;;; dst -= src
biSub:

;;; void biMulShort(BigInt dst, unsigned long int src);
biMulShort:

;;; void biMul(BigInt dst, BigInt src);
;;; dst *= src
biMul:

biDivShort:

;;; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
;;; Compute quotient and remainder by divising numerator by denominator.
;;; quotient * denominator + remainder = numerator
;;; \param remainder must be in range [0, denominator) if denominator > 0
;;; and (denominator, 0] if denominator < 0.
biDivRem:
