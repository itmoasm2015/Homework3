;;; This is a library that implements big integer interface
default rel
        struc   bigint
.sign   resd 1                  ; 0xffffffff for <0, 0x00000000 for ≥0
.size   resd 1                  ; .size * 8 is size of .data
.data   resq 1                  ; unsigned long int*
        endstruc

%define bigint_size 16          ; size of structure above

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
global biAddShort
global biMulShort
global biDivShort
global biCutTrailingZeroes
global biAddUnsigned
global biSubUnsigned
global biNegate
global biCmpUnsigned
global biCopy
global biIsZero

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

        ;; check if any trailing zeroes were removed
        .reallocate
        cmp     ecx, 0
        jle     .nullcheck

        ;; allocate array of new size
        push    r8
        push    r9
        mov     edi, dword[r8+bigint.size]
        shl     edi, 3
        sub     rsp, 8          ; align
        call    malloc
        add     rsp, 8
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
        sub     rsp, 8
        call    free
        add     rsp, 8
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

        ;; allocate memory for .data
        push    r8
        push    r9
        mov     rdi, 8
        sub     rsp, 8          ; align
        call    malloc
        add     rsp, 8
        pop     r9
        pop     r8

        ;; fill it and put to .data into struc
        mov     [rax], r8
        mov     [r9+bigint.data], rax

        ;; Remove trailing zeroes if present
        mov     rax, r9
        push    rax
        mov     rdi, r9
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
        sub     rsp, 8
        call    malloc
        add     rsp, 8
        pop     r9
        pop     r8

        ;; fill it and put as a member into struc
        mov     [rax], r8
        mov     [r9+bigint.data], rax

        ;; Remove trailing zeroes if present
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
        push    rbx
        push    r12
        push    r13
        push    r14
        push    r15

        ;; allocate new bigint (0) - BI
        push    rdi
        mov     rdi, 0
        sub     rsp, 8          ; align x7 pushes
        call    biFromUInt
        add     rsp, 8
        pop     rdi
        mov     r12, rax

        ;; set sign
        xor     rbx, rbx        ; the sign is ≥0 by default
        cmp     byte[rdi], '-'
        jne     .nonneg
        mov     ebx, 0xffffffff ; save sign, will assign it later
        inc     rdi
        .nonneg

        ;; process first byte
        xor     rcx, rcx
        ;; first iteration allows no \0
        mov     cl, byte[rdi]
        cmp     cl, '0'         ; data check
        jl      .fail
        cmp     cl, '9'
        jg      .fail
        sub     cl, '0'
        ;; BI += cl
        push    rdi
        mov     rdi, r12
        mov     rsi, rcx
        sub     rsp, 8          ; align
        call    biAddShort
        add     rsp, 8
        pop     rdi
        ;; increment rdi
        inc     rdi

        ;; process till the end of a string
        .loop
        xor     rcx, rcx
        mov     cl, [rdi]
        cmp     cl, 0         ; exit if reached \0
        je      .loop_end
        cmp     cl, '0'
        jl      .fail
        cmp     cl, '9'
        jg      .fail
        sub     cl, '0'
        ;; BI *= 10
        push    rdi
        push    rcx
        mov     rdi, r12
        mov     rsi, 10
        call    biMulShort
        pop     rcx
        pop     rdi
        ;; BI += cl
        push    rdi
        mov     rdi, r12
        mov     rsi, rcx
        sub     rsp, 8
        call    biAddShort
        add     rsp, 8
        pop     rdi
        ;; increment rdi
        inc     rdi
        jmp     .loop
        .loop_end

        ;; set sign (not setting in the start because of leading zeroes --
        ;; if present, BI is set to 0 (BI += 0), and normalized to +0)
        mov     dword[r12+bigint.sign], ebx

        ;; normalize
        mov     rdi, r12
        call    biCutTrailingZeroes
        mov     rax, r12
        jmp     .return
        .fail
        mov     rax, 0
        .return
        pop     r15
        pop     r14
        pop     r13
        pop     r12
        pop     rbx
        ret

;;; void biToString(BigInt bi, char *buffer, size_t limit)
;;; Generate a decimal string representation from a BigInt.
;;; Writes at most limit bytes to buffer.
biToString:
        ;; reserve place for last \0
        dec     rdx
        jz      .return

        ;; layout minus; if there's no place left, exit
        cmp     dword[rdi+bigint.sign], 0xffffffff
        jne     .non_neg
        mov     byte[rsi], '-'
        inc     rsi
        dec     rdx
        jz      .return
        .non_neg

        ;; create a copy of dest, to dest
        push    rsi
        push    rdx
        sub     rsp, 8          ; align
        call    biCopy
        add     rsp, 8
        pop     rdx
        pop     rsi
        mov     rdi, rax

        xor     rcx, rcx
        ;; divide current on 10, get remainder, push it, increment rcx
        .loop
        push    rdi
        push    rsi
        push    rdx
        push    rcx
        mov     rsi, 10
        call    biDivShort
        pop     rcx
        pop     rdx
        pop     rsi
        pop     rdi

        add     al, '0'
        push    rax
        inc     rcx

        ;; biIsZero makes no calls to extern functions
        call    biIsZero        ; check if current number is not 0

        cmp     rax, 0x0
        jne     .loop           ; end loop

        ;; while rcx != 0 || rdx != 0, pop bytes from stack and write them
        ;; rcx -- number of chars pushed, rdx -- bytes allowed to write
        .loop_writeback
        cmp     rcx, 0
        je      .loop_writeback_end
        cmp     rdx, 0
        je      .loop_writeback_end
        pop     rax
        mov     byte[rsi], al
        inc     rsi
        dec     rdx
        dec     rcx
        jmp     .loop_writeback
        .loop_writeback_end

        ;; restore stack (if rdx == 0, but rcx != 0 -- we still have bytes pushed)
        shl     rcx, 3          ; *8 for bytes
        add     rsp, rcx

        ;; delete copy of rdi
        push    rsi
        call    biDelete
        pop     rsi

        .return
        mov     byte[rsi], 0
        ret

;;; void biDelete(BigInt bi);
;;; Destroy a BigInt.
biDelete:
        cmp     dword[rdi+bigint.size], 0 ; if size is 0, inner array was deleted
        je      .outer
        ;; inner part (.data)
        push    rdi
        mov     rdi, [rdi+bigint.data]
        call    free
        pop     rdi
        .outer
        sub     rsp, 8
        call    free
        add     rsp, 8
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
        ;; error of emacs-gdb
        ;; left here just to remember (4.5 hours debugging spent)
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
        sub     rsp, 8          ; align
        call    malloc
        add     rsp, 8
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
;;; previous a .data is free'd
biAssign:
        ;; free a.data
        push    rsi
        push    rdi
        mov     rdi, [rdi+bigint.data]
        sub     rsp, 8
        call    free
        add     rsp, 8
        pop     rdi
        pop     rsi

        ;; malloc b.size*8 bytes space and place it to a.data
        push    rsi
        push    rdi
        xor     rdi, rdi
        mov     edi, dword[rsi+bigint.size]
        shl     rdi, 3
        sub     rsp, 8          ; align
        call    malloc
        add     rsp, 8
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
;;; returns .data section
;;; used to debug
;;; spoiled: rax
biDump:
        mov     rax, [rdi+bigint.data]
        ret

;;; size_t biSize(BigInt x);
;;; returns size
;;; spoiled: rax
biSize:
        mov     eax, dword[rdi+bigint.size]
        ret

;;; size_t biIsZero(BigInt x);
;;; returns 0xffffffff if not zero
;;; else 0
;;; spoiled: ∅
biIsZero:
        ;; size > 1 ⇒ not zero
        cmp     dword[rdi+bigint.size], 1
        jg      .nonzero
        ;; size == 1, data[0] != 0 ⇒ not zero
        push    r8
        mov     r8d, dword[rdi+bigint.data]
        cmp     qword[r8d], 0
        pop     r8
        jne     .nonzero

        xor     rax, rax
        ret
        .nonzero
        mov     rax, 0xffffffff
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

        ;; if both are negative, than swap
        add     eax, dword[rsi+bigint.sign]
        cmp     eax, 0xfffffffe
        jne     .noswap
        mov     rax, rdi
        mov     rdi, rsi
        mov     rsi, rax
        .noswap

        ;; cmp unsigned if sign is equal
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
        ja      .gt
        jb      .lt

        ;; compare by-digit starting from higher bits
        ;; kind of self-explanatory code
        xor     rcx, rcx
        mov     ecx, eax        ; eax holds size now
        dec     ecx
        mov     r8, [rdi+bigint.data]
        mov     r9, [rsi+bigint.data]
        .loop
        mov     rax, [r8+rcx*8]
        cmp     rax, [r9+rcx*8]
        ja      .gt
        jb      .lt
        cmp     ecx, 0
        je      .loop_end
        dec     ecx
        jmp     .loop
        .loop_end

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

        ;; TODO remove this block
        cmp     r9d, dword[r8+bigint.size] ; fail if new size ≤ old size
        jle     fail

        ;; allocate memory for new array
        push    r8
        push    r9
        mov     rdi, r9
        shl     rdi, 3
        sub     rsp, 8          ; align
        call    malloc
        add     rsp, 8
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

;;; void biAddShort(BigInt dst, unsigned long int a);
;;; dst += src
biAddShort:
        ;; allocate +1 length if needed
        push    rdi
        push    rsi
        mov     esi, dword[rdi+bigint.size]
        inc     esi
        sub     rsp, 8          ; align
        call    biExpand
        add     rsp, 8
        pop     rsi
        pop     rdi
        mov     r8, rax

        ;; r9 -- data
        mov     r9, [rdi+bigint.data]

        ;; adding (naive solution);
        ;; pushf/popf used to save carry from adc, as it gets spoiled by cmp
        xor     rcx, rcx
        clc
        pushf
        .loop
        popf
        adc     [r9], rsi
        pushf
        xor     rsi, rsi          ; we need rsi only on 0 iteration
        add     r9, 8
        inc     ecx
        cmp     ecx, dword[rdi+bigint.size]
        jl      .loop
        popf

        ;; normalizing
        sub     rsp, 8
        call    biCutTrailingZeroes
        add     rsp, 8
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
        sub     rsp, 8          ; align
        call    biExpand
        add     rsp, 8
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
        sub     rsp, 8
        call    biCutTrailingZeroes
        add     rsp, 8

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
        sub     rsp, 8          ; align
        call    biAddUnsigned
        add     rsp, 8
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
        sub     rsp, 8
        call    biNegate
        add     rsp, 8
        pop     rsi
        pop     rdi

        ;; subtract dst src
        push    rsi
        call    biSub
        pop     rsi

        ;; negate src back
        mov     rdi, rsi
        call    biNegate

        ret

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
        sub     rsp, 8          ; align
        call    biCopy
        add     rsp, 8
        pop     rsi
        pop     rdi
        mov     r8, rax

        ;; assign rdi := rsi
        push    rdi
        push    r8
        sub     rsp, 8          ; align
        call    biAssign
        add     rsp, 8
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
        sub     rsp, 8          ; align
        call    biCmpUnsigned
        add     rsp, 8
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
        sub     rsp, 8
        call    biExpand
        add     rsp, 8
        pop     rsi
        pop     rdi

        .after_expand
        ;; r10d holds vector size
        mov     r10d, dword[rdi+bigint.size]

        ;; save data pointers
        mov     r8, [rdi+bigint.data]
        mov     r9, [rsi+bigint.data]

        ;; process subtracting (naive solution with carry)
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
        sub     rsp, 8
        call    biCutTrailingZeroes
        add     rsp, 8

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
        sub     rsp, 8          ; align
        call    biCmpUnsigned
        add     rsp, 8
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
        sub     rsp, 8          ; align
        call    biCopy
        add     rsp, 8
        pop     rsi
        pop     rdi
        mov     r8, rax

        ;; assign rdi := rsi
        push    rdi
        push    r8
        sub     rsp, 8          ; align
        call    biAssign
        add     rsp, 8
        pop     r8
        pop     rdi

        ;; rsi = r8
        mov     rsi, r8

        ;; negate rdi
        push    rdi
        push    rsi
        sub     rsp, 8          ; align
        call    biNegate
        add     rsp, 8
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
        sub     rsp, 8          ; align
        call    biSubUnsigned
        add     rsp, 8
        ret

        ;; (-dst) - src; negate src, biAdd them (-dst + (-src)), restore src sign then
        ;; dst - (-src); same actions
        .different_sign
        ;; negate src
        push    rdi
        push    rsi
        mov     rdi, rsi
        sub     rsp, 8
        call    biNegate
        add     rsp, 8
        pop     rsi
        pop     rdi

        ;; sum (-)dst, (-)src
        push    rsi
        call    biAdd
        pop     rsi

        ;; negate src back
        mov     rdi, rsi
        sub     rsp, 8          ; align
        call    biNegate
        add     rsp, 8
        ret

;;; void biMulShort(BigInt dst, unsigned long int src);
biMulShort:
        ;; extend size of dst by 1
        push    rdi
        push    rsi
        mov     esi, dword[rdi+bigint.size]
        inc     esi
        sub     rsp, 8          ; align
        call    biExpand
        add     rsp, 8
        pop     rsi
        pop     rdi

        ;; perform multiplication (mul each digit with carry adding)
        mov     r9, [rdi+bigint.data]
        xor     r8, r8          ; saving carry here (that's in rdx after mul)
        xor     rcx, rcx
        clc
        .loop
        mov     rax, [r9]
        mul     rsi
        add     rax, r8         ; add carry to rax:rdx
        adc     rdx, 0
        mov     r8, rdx
        mov     [r9], rax
        add     r9, 8
        inc     ecx
        cmp     ecx, [rdi+bigint.size]
        jl      .loop

        ;; normalize
        sub     rsp, 8
        call    biCutTrailingZeroes
        add     rsp, 8
        ret

;;; void biMul(BigInt dst, BigInt src);
;;; dst *= src
biMul:
        push    r12
        push    r13
        push    r14
        push    r15

        ;; copy rdi to r8
        push    rsi
        push    rdi
        mov     rdi, 0
        sub     rsp, 8
        call    biFromUInt
        add     rsp, 8
        pop     rdi
        pop     rsi
        mov     r8, rax

        ;; set sign of r8 (sign(a) XOR sign(b) as ≥0 is 0x0, <0 is -1)
        mov     eax, dword[rsi+bigint.sign]
        xor     eax, dword[rdi+bigint.sign]
        mov     dword[r8+bigint.sign], eax

        ;; expand r8 to src.length + dest.length + 1
        push    rsi
        push    rdi
        push    r8
        mov     esi, dword[rsi+bigint.size]
        add     esi, dword[rdi+bigint.size]
        inc     esi
        mov     rdi, r8
        call    biExpand
        pop     r8
        pop     rdi
        pop     rsi

        ;; expand src by 1
        push    rsi
        push    rdi
        push    r8
        mov     rdi, rsi
        mov     esi, dword[rsi+bigint.size]
        inc     esi
        call    biExpand
        pop     r8
        pop     rdi
        pop     rsi

        ;; save data of three bigints
        mov     r9,  [rdi+bigint.data]
        mov     r10, [rsi+bigint.data]
        mov     r11, [r8+bigint.data]

        ;; preparing data for loop
        xor     rcx, rcx        ; first loop iterator
        xor     r12, r12        ; second loop iterator
        xor     r13, r13        ; carry
        mov     r15d, dword[rsi+bigint.size]
        dec     r15d

        ;; multiplying loop
        .loop
        mov     rax, [r9+8*rcx]
        mul     qword[r10+8*r12]
        add     rax, r13         ; add carry
        adc     rdx, 0
        mov     r14, rcx         ; calculate r11+8*rcx
        shl     r14, 3
        add     r14, r11
        add     rax, [r14+8*r12]
        adc     rdx, 0
        mov     [r14+8*r12], rax ; write to r8
        mov     r13, rdx         ; save carry
        inc     r12d

        cmp     r12d, r15d      ; r15d holds esi size - 1 (real size before expand)
        jl      .loop
        cmp     r13, 0
        jne     .loop           ; end of inner loop

        xor     r12d, r12d      ; xor second iterator and carry
        xor     r13, r13
        inc     ecx
        cmp     ecx, dword[rdi+bigint.size]
        jl      .loop           ; end of outer loop

        ;; dst := r8
        push    r8
        push    rdi
        push    rsi
        mov     rsi, r8
        call    biAssign
        pop     rsi
        pop     rdi
        pop     r8

        ;; delete r8
        push    rdi
        push    rsi
        mov     rdi, r8
        sub     rsp, 8          ; align
        call    biDelete
        add     rsp, 8
        pop     rsi
        pop     rdi

        ;; normalize rsi
        push    rdi
        mov     rdi, rsi
        call    biCutTrailingZeroes
        pop     rdi

        ;; normalize rdi
        mov     rax, rdi
        push    rax
        call    biCutTrailingZeroes
        pop     rax

        pop     r15
        pop     r14
        pop     r13
        pop     r12
        ret

;;; unsigned long int biDivShort(BigInt a, unsigned long int b);
;;; a /= b, returns carry
;;; algorithm from e-maxx
biDivShort:
        xor     r8, r8          ; r8 holds carry

        ;; iterate from rdi.size - 1 downto 0
        xor     rcx, rcx
        mov     ecx, dword[rdi+bigint.size]
        dec     rcx
        mov     r9, [rdi+bigint.data]
        lea     r9, [r9+8*rcx]
        inc     rcx
        .loop
        mov     rdx, r8
        mov     rax, [r9]
        div     rsi
        mov     [r9], rax
        mov     r8, rdx
        sub     r9, 8
        dec     rcx
        jnz     .loop

        ;; align stack
        mov     rax, rsp
        xor     rdx, rdx
        mov     rcx, 16
        div     rcx
        cmp     rdx, 0
        jz      .extra_align

        mov     rax, r8
        push    rax
        call    biCutTrailingZeroes
        pop     rax
        ret

        .extra_align
        ;; save carry and normalize dst
        mov     rax, r8
        push    rax
        sub     rsp, 8
        call    biCutTrailingZeroes
        add     rsp, 8
        pop     rax
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

section .data
        not_available:  db 'NA', 0
