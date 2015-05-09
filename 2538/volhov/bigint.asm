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

;;; void biCutTrailingZeroes(BigInt int)
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
        .nonneg

        ;; set size
        mov     dword[r9+bigint.size], 1

        ;; allocate memory for array
        push    r8
        push    r9
        mov     rdi, 1
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

;;; void biExpand(BigInt a, int new_size);
biExpand:

;;; int biAdd(BigInt dst, BigInt src);
;;; dst += src
biAdd:
        mov     r8, rdi
        mov     r9, rsi

;;; void biSub(BigInt dst, BigInt src);
;;; dst -= src
biSub:

;;; void biMul(BigInt dst, BigInt src);
;;; dst *= src
biMul:

;;; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
;;; Compute quotient and remainder by divising numerator by denominator.
;;; quotient * denominator + remainder = numerator
;;; \param remainder must be in range [0, denominator) if denominator > 0
;;; and (denominator, 0] if denominator < 0.
biDivRem:
