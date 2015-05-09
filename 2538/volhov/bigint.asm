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
        bt      r8, 0
        jnc     .nonneg
        mov     dword[r9+bigint.sign], 0xffffffff
        .nonneg

        ;; set length
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
        call    biCutTrailingZeroes
        pop     rax
        ret

;;; BigInt biFromString(char const *s)
;;; Create a BigInt from a decimal string representation.
;;; Returns NULL on incorrect string.
biFromString:


;;; void biToString(BigInt bi, char *buffer, size_t limit)
;;; Generate a decimal string representation from a BigInt.
;;; Writes at most limit bytes to buffer.
biToString:


;;; void biDelete(BigInt bi);
;;; Destroy a BigInt.
biDelete:

;;; int biSign(BigInt bi);
;;; Get sign of given BigInt.
;;; return 0 if bi is 0, positive if bi is positive, negative if bi is negative.
biSign:

;;; int biAdd(BigInt dst, BigInt src);
;;; dst += src
biAdd:

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

;;; int biCmp(BigInt a, BigInt b);
;;; Compare two BitInts.
;;; returns sign(a - b)
biCmp:
