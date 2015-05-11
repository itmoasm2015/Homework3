;;; This is a library that implements big integer interface
        struc   bigint
.sign   resd 1                  ; 0xffffffff for <0, 0x00000000 for ≥0
.size   resd 1                  ; .size * 8 is size of .data
.data   resq 1                  ; unsigned long int*
        endstruc

%define bigint_size 16
%define trailing_removed_after 0

extern malloc
extern free

;;; Required
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

;;; Custom
global biFromUInt
global biDump
global biSize
global biExpand
global biMulShort
global biDivShort
global biCutTrailingZeroes
global biAddUnsigned
global biSubUnsigned
global biNegate
global biCmpUnsigned
global biCopy

;;; void biCutTrailingZeroes(BigInt a)
;;; removes trailing zeroes (except the last one);
;;; reallocates .data section of bigint if more than trailing_removed_after
;;; trailing zeroes were removed
;;; never free's .data
biCutTrailingZeroes:
        mov     r8, rdi

        ;; ecx -- number of trailing zeroes removed
        xor     rcx, rcx
        xor     rax, rax

        ;; loop for removing trailing zeroes
        mov     r9, [r8+bigint.data]       ; data
        .loop
        mov     eax, dword[r8+bigint.size] ; current size
        cmp     eax, 1
        jle     .reallocate                ; proceed if size ≤ 1
        dec     eax                        ; indexing from 0
        cmp     qword[r9+8*rax], 0         ; return if last portion of data non-null
        jne     .reallocate
        dec     dword[r8+bigint.size]
        inc     ecx
        jmp     .loop

        .reallocate
        cmp     ecx, trailing_removed_after
        jle     .nullcheck

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
        jmp     .nullcheck
        .free
        mov     dword[r8+bigint.sign], 0
        mov     rdi, r9
        push    r8
        call    free
        pop     r8

        ;; set sign 0 if zero
        .nullcheck
        cmp     dword[r8+bigint.size], 1
        jg      .return
        mov     r9, qword[r8+bigint.data]
        cmp     qword[r9], 0
        jne     .return
        mov     dword[r8+bigint.sign], 0

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

;;; BigInt biFromUInt(unsigned long int);
biFromUInt:
        mov     r8, rdi

        ;; get space for bigint struc, put the pointer into r9
        push    r8
        mov     rdi, bigint_size
        call    malloc
        pop     r8
        mov     r9, rax

        ;; set proper sign
        mov     dword[r9+bigint.sign], 0

        ;; set size
        mov     dword[r9+bigint.size], 1

        ;; allocate memory for array of size 1*8
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

;;; BigInt biCopy(BigInt a);
;;; get the deep copy of bigint
biCopy:
        ;; allocate memory for copy
        push    rdi
        mov     rdi, 16
        call    malloc
        ;; without this nop, rsp suddenly changes
        ;; from 0x7fffffffdf10 to 0x7fffffffdf48
        ;; (I suspect gdb to have bugs or something)
        nop
        pop     rdi
        mov     r8, rax

        ;; copy sign and size
        mov     rax, qword[rdi]
        mov     qword[r8], rax

        ;; allocate the place for new array
        push    rdi
        push    r8
        mov     r8, rdi
        xor     rdi, rdi
        mov     edi, dword[r8+bigint.size]
        shl     rdi, 3
        call    malloc
        pop     r8
        pop     rdi
        mov     r10, rax

        ;; place new .data to new bigint
        mov     qword[r8+bigint.data], r10

        ;; copy the data
        mov     r9, [rdi+bigint.data]
        xor     ecx, ecx
        .loop
        cmp     ecx, [rdi+bigint.size]
        jge     .loop_end
        mov     rax, qword[r9]
        mov     qword[r10], rax
        add     r9, 8
        add     r10, 8
        inc     ecx
        jmp     .loop
        .loop_end

        mov     rax, r8
        ret


;;; void biAssign(BigInt a, BigInt b);
;;; a := b
biAssign:
        ;; free a.data
        push    rsi
        push    rdi
        mov     rdi, [rdi+bigint.data]
        call    free
        pop     rdi
        pop     rsi

        ;; malloc b.size*8 bytes space and place it to a.data
        push    rsi
        push    rdi
        xor     rdi, rdi
        mov     edi, dword[rsi+bigint.size]
        shl     rdi, 3
        call    malloc
        pop     rdi
        pop     rsi
        mov     r10, rax

        ;; place new .data to new bigint
        mov     qword[rdi+bigint.data], r10

        ;; copy sign and size
        mov     rax, qword[rsi]
        mov     qword[rdi], rax

        ;; copy the data
        mov     r9, [rsi+bigint.data]
        xor     ecx, ecx
        .loop
        cmp     ecx, dword[rsi+bigint.size]
        jge     .loop_end
        mov     rax, qword[r9]
        mov     qword[r10], rax
        add     r9, 8
        add     r10, 8
        inc     ecx
        jmp     .loop
        .loop_end

        ret

;;; unsigned long int* biDump(BigInt x);
;;; spoiled: rax
biDump:
        mov     rax, [rdi+bigint.data]
        ret

;;; size_t biSize(BigInt x);
;;; spoiled: rax
biSize:
        mov     eax, dword[rdi+bigint.size]
        ret

;;; void biNegate(BigInt x);
;;; spoiled: ∅
biNegate:
        ;; if size > 1 just negate sign
        cmp     dword[rdi+bigint.size], 1
        jge     .nonzero

        ;; if size == 1 && [data] != 0 negate sign
        push    r8
        mov     r8d, dword[rdi+bigint.data]
        cmp     qword[r8d], 0
        pop     r8
        jne     .nonzero

        ;; set sign = 0 otherwise
        mov     dword[rdi+bigint.sign], 0
        ret

        ;; negate sign if nonzero
        .nonzero
        not     dword[rdi+bigint.sign]
        ret

;;; int biSign(BigInt bi);
;;; Get sign of given BigInt.
;;; return 0 if bi is 0, positive if bi is positive, negative if bi is negative.
biSign:
        mov     r8, rdi
        cmp     dword[r8+bigint.size], 0
        je      fail
        ;; if negative, the sign is ok
        mov     eax, dword[r8+bigint.sign]
        cmp     eax, 0xffffffff
        je      .return
        ;; if positive, it may be zero
        cmp     dword[r8+bigint.size], 1
        jne     .positive       ; positive if size > 1
        mov     r8, qword[r8+bigint.data]
        cmp     qword[r8], 0    ; positive if size == 1 && .data[0] == 0
        je      .return
        .positive
        inc     eax
        .return
        ret

;;; int biCmp(BigInt a, BigInt b);
;;; Compare two BitInts.
;;; returns sign(a - b)
biCmp:
        ;; cmp by sign first
        mov     eax, dword[rdi+bigint.sign]
        cmp     eax, dword[rsi+bigint.sign]
        jg      .gt
        jl      .lt

        call    biCmpUnsigned
        jmp     .return

        .gt
        mov     rax, 1
        jmp     .return

        .lt
        mov     rax, -1
        jmp     .return

        .return
        ret

;;; int biCmp(BigInt a, BigInt b);
;;; Compare two abs of BitInts.
;;; returns sign(|a| - |b|)
biCmpUnsigned:
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
        jle     fail

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

        .return
        ret

;;; int biAddUnsigned(BigInt dst, BigInt src);
;;; ! dst ≠ src
;;; dst = |dst| + |src|
biAddUnsigned:
        ;; expand destination or source to get equal .size (dst should have dst.size + 1)
        mov     eax, dword[rdi+bigint.size]
        cmp     eax, dword[rsi+bigint.size]
        jle      .expand_dst
        jg      .expand_src
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

        .expand_dst
        push    rdi
        push    rsi
        mov     esi, dword[rsi+bigint.size]
        mov     r11d, esi       ; r11d will hold size of src (in case dst == src and they both will expand)
        inc     esi             ; we reserve one extra cell to save last carry
        push    r11
        call    biExpand
        pop     r11
        pop     rsi
        pop     rdi
        jmp     .after_expand

        ;; save data pointers
        .after_expand
        mov     r8, [rdi+bigint.data]
        mov     r9, [rsi+bigint.data]

        ;; process adding
        clc
        xor     rcx, rcx
        pushf
        .loop
        cmp     ecx, r11d
        jge     .loop_end
        popf
        mov     rax, [r9+8*rcx]
        adc     qword[r8+8*rcx], rax
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
        mov     eax, dword[rdi+bigint.sign]
        add     eax, dword[rsi+bigint.sign]
        cmp     eax, 0
        je      .same_sign
        cmp     eax, 0xfffffffe
        je      .same_sign
        ;; There should be .min_plus and .plus_min implemented by biSubUnsigned
        jmp     .different_sign

        .same_sign              ; if dst and src are the same sign, <sign(dst);|dst|+|src|> is what we need
        call    biAddUnsigned
        ret

        ;; choose the type of addition: [(-dst) + src] or [dst + (-src)]
        .different_sign
        cmp     dword[rsi+bigint.sign], 0xffffffff
        je      .plus_minus
        jne     .minus_plus

        ;; dst + (-src)
        .plus_minus
        ;; negate src
        push    rdi
        push    rsi
        mov     rdi, rsi
        call    biNegate
        pop     rsi
        pop     rdi

        ;; subtract dst src
        push    rsi
        call    biSub
        pop     rsi

        ;; negate src back
        mov     rdi, rsi
        call    biNegate

        ;; -dst + src
        ;; temp = dst
        ;; dst := src
        ;; rax := dst - temp
        ;; free temp
        ;; return rax
        .minus_plus
        ;; copy destination to r8
        push    rdi
        push    rsi
        call    biCopy
        pop     rsi
        pop     rdi
        mov     r8, rax

        ;; assign rdi := rsi
        push    rdi
        push    r8
        call    biAssign
        pop     r8
        pop     rdi

        ;; rsi = r8
        mov     rsi, r8

        ;; negate rsi
        push    rdi
        push    rsi
        mov     rdi, rsi
        call    biNegate
        pop     rsi
        pop     rdi

        ;; perform subtraction
        push    r8
        call    biSub
        pop     r8

        ;; free temp
        push    rax
        mov     rdi, r8
        call    biDelete
        pop     rax
        ret


;;; void biSubUnsigned(BigInt dst, BigInt src);
;;; should be true: |dst| > |src|
;;; |dst| -= |src|
biSubUnsigned:
        ;; delete this block after debug
        ;; fail if |dst| < |src|
        push    rdi
        push    rsi
        call    biCmpUnsigned
        pop     rsi
        pop     rdi
        cmp     rax, 0
        jl      fail

         ;; if needed, expand source to get equal .size with dst
        mov     eax, dword[rdi+bigint.size]
        cmp     eax, dword[rsi+bigint.size]
        jg      .expand_src
        jle     .after_expand
        .expand_src
        push    rdi
        push    rsi
        mov     rax, rdi        ; swap rsi and rdi
        mov     rdi, rsi
        mov     esi, dword[rax+bigint.size]
        inc     esi
        call    biExpand
        pop     rsi
        pop     rdi

        .after_expand
        ;; r10d holds vector size
        mov     r10d, dword[rdi+bigint.size]

        ;; save data pointers
        mov     r8, [rdi+bigint.data]
        mov     r9, [rsi+bigint.data]

        ;; process subtracting
        clc
        xor     rcx, rcx
        pushf
        .loop
        cmp     ecx, r10d
        jge     .loop_end
        popf
        mov     rax, [r9+8*rcx]
        sbb     qword[r8+8*rcx], rax
        pushf
        inc     rcx
        jmp     .loop
        .loop_end
        popf

        ;; removes redundant zeroes
        push    rsi
        call    biCutTrailingZeroes
        pop     rsi
        mov     rdi, rsi
        call    biCutTrailingZeroes

        ret


;;; void biSub(BigInt dst, BigInt src);
;;; dst -= src
biSub:
        mov     eax, dword[rdi+bigint.sign]
        add     eax, dword[rsi+bigint.sign]
        cmp     eax, 0
        je      .same_sign
        cmp     eax, 0xfffffffe
        je      .same_sign
        jmp     .different_sign

        ;; if the sign is same, than compare; if |dst| < |src|, swap with temp var
        .same_sign
        push    rsi
        push    rdi
        call    biCmpUnsigned
        pop     rdi
        pop     rsi
        cmp     rax, 0
        jl      .same_sign_l
        jge     .same_sign_ge
        ;; copy dst to temp, dst=src, dst = neg(dst), dst -= temp
        .same_sign_l
        ;; copy destination to r8
        push    rdi
        push    rsi
        call    biCopy
        pop     rsi
        pop     rdi
        mov     r8, rax

        ;; assign rdi := rsi
        push    rdi
        push    r8
        call    biAssign
        pop     r8
        pop     rdi

        ;; rsi = r8
        mov     rsi, r8

        ;; negate rdi
        push    rdi
        push    rsi
        call    biNegate
        pop     rsi
        pop     rdi

        ;; perform subtraction
        push    r8
        call    biSubUnsigned
        pop     r8

        ;; free temp
        push    rax
        mov     rdi, r8
        call    biDelete
        pop     rax

        ret
        ;; if sign is the same, just perform subtraction
        .same_sign_ge
        call    biSubUnsigned
        ret

        ;; (-dst) - src; negate src, biAdd them (-dst + (-src)), restore src sign then
        ;; dst - (-src); same actions
        .different_sign
        ;; negate src
        push    rdi
        push    rsi
        mov     rdi, rsi
        call    biNegate
        pop     rsi
        pop     rdi

        ;; sum (-)dst, (-)src
        push    rsi
        call    biAdd
        pop     rsi

        ;; negate src back
        mov     rdi, rsi
        call    biNegate
        ret

;;; void biMulShort(BigInt dst, unsigned long int src);
biMulShort:
        ;; extend size of dst by 1
        push    rdi
        push    rsi
        mov     esi, dword[rdi+bigint.size]
        inc     esi
        call    biExpand
        pop     rsi
        pop     rdi

        ;; perform multiplication
        mov     r9, [rdi+bigint.data]
        xor     r8, r8          ; saving carry here (that's in rdx after mul)
        xor     rcx, rcx
        clc
        .loop
        mov     rax, [r9]
        mul     rsi
        add     rax, r8         ; add carry
        mov     r8, rdx
        mov     [r9], rax
        add     r9, 8
        inc     ecx
        cmp     ecx, [rdi+bigint.size]
        jl      .loop

        ;; normalize
        call    biCutTrailingZeroes

        ret

;;; void biMul(BigInt dst, BigInt src);
;;; dst *= src
biMul:
        ret

biDivShort:
        ret
;;; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
;;; Compute quotient and remainder by divising numerator by denominator.
;;; quotient * denominator + remainder = numerator
;;; \param remainder must be in range [0, denominator) if denominator > 0
;;; and (denominator, 0] if denominator < 0.
biDivRem:
        ret

fail:
        mov     dword[0], 0
