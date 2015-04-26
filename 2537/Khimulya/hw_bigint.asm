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

extern malloc
extern free

struc   bigint
        .len    resb    8           ; size in bytes
        .data   resb    8           ; pointer to data, big-endian
endstruc

; Allocates memory for big integer (data and struct)
;
; corrupts all registers execpt for callee-saved and %1, %2
;
; @arg %1 register with size of bigint in bytes
; @arg %2 register where address of bigit.data will be stored
;
; @return address to bigint struct in rax
; @return %2 address to bigint's data
%macro  NEW_BI 2
        mov     rdi, %1
        push    %1
        call    malloc              ; allocation for data
        push    rax
        mov     rdi, bigint_size
        call    malloc              ; allocation for headers
        pop     %2
        pop     %1
        mov     [rax + bigint.len], %1
        mov     [rax + bigint.data], %2
%endmacro

; Frees memory of bigit
;
; corrupts all registers except for callee-saved
;
; @arg %1 address of bigint struc to be removed
%macro  DEL_BI 1
        push    %1
        mov     rdi, [%1 + bigint.data]
        call    free
        pop     rdi
        call    free
%endmacro

; Copies given bigint and returns new address
;
; @arg %1 address of bigint to be copied
; corrups all registers except for callee-saved and %1
;
; @return %2 address of copy
%macro  COPY_BI 2
        push    %1
        mov     rcx, [%1 + bigint.len]
        NEW_BI  rcx, rdx
        pop     %1
        mov     r8, [%1 + bigint.data]
        %%loop:
                mov     r9, [r8]
                mov     [rdx], r9

                add     r8, 8
                add     rdx, 8
                sub     rcx, 8
                jnz     %%loop
        mov     %2, rax
%endmacro

; returns 0 if given bigint is positive and -1 otherwise
;
; corrupts r11
;
; @arg %1 address of bigint
;
; @return %2 64-bit representation of 0 or -1
%macro  SIGN 2
        push    rax
        mov     rax, [%1 + bigint.len]
        mov     r11, [%1 + bigint.data]
        mov     r11, [r11 + rax - 8]
        test    r11, [MSB]             ; last number
        jnz     %%neg
        mov     %2, 0
        jmp     %%done
     %%neg:
        mov     %2, [MINUS1_64]
     %%done:
        pop     rax
%endmacro

; computes maximum of two general purpose registers
;
; @arg %2 first operand
; @arg %3 second operand
; note: only one of two operands can be memory
;
; @return %1 maxumum of given values
%macro  MAX 3
        sub     %2, %3
        jo      %%second
        mov     %1, %2
        jmp     %%done
    %%second:
        mov     %1, %3
    %%done:
%endmacro

; Shotrens length of bigint with %1 address
; by reducing len property of struc by insignificant quadwords amount.
; Assume most significant quadword is insignificant if it's 0 or -1
; and next quadword's most significant bit is 0 or 1, respectly.
;
; @arg %1 address of bigint to be shorten
; corrupts rax, rcx, rdx
%macro  BI_SHORTEN 1
        mov     rcx, [%1 + bigint.len]
        sub     rcx, 16                         ; next after most significant quadword
        mov     rdx, [%1 + bigint.data]
        %%loop:
                mov     rax, [rdx + rcx + 8]
                cmp     rax, 0
                jne     %%neg                   ; let's try luck with negative sign
                mov     rax, [rdx + rcx]
                test    rax, [MSB]
                jz      %%continue              ; only way to continue if MSB is 0
                jmp     %%done

            %%neg:
                cmp     rax, [MINUS1_64]
                jne     %%done                  ; most significant quadword neither 0 nor -1
                mov     rax, [rdx + rcx]
                test    rax, [MSB]
                jz      %%done                  ; only way to continue if MSB is 1

            %%continue:
                sub     rcx, 8
                cmp     rcx, -8
                jne     %%loop
        %%done:
        add     rcx, 16
        mov     [%1 + bigint.len], rcx
%endmacro

; Performs negate on given bigint.
; At first perform not on all quadwords,
; then add 1 with carry to the least significant quadword
;
; @arg %1 address of bigint to negate
; corrupts rax, rdx, rcx
%macro  NEGATE 1
        push    %1

        mov     rcx, [%1 + bigint.len]
        mov     %1, [%1 + bigint.data]
        lahf
        or      ah, 1                       ; set carry flag
        %%loop:                             ; not and add 1 in single cycle
                mov     rdx, [%1]
                not     rdx
                sahf
                adc     rdx, 0
                lahf
                mov     [%1], rdx

                add     %1, 8
                sub     rcx, 8
                jnz     %%loop

        pop     %1
%endmacro

; Multiplies given bigint with given quadword, result goes to input bigint
; note: doesn't check for bigint's length, so overflow is possible
;
; @arg %1 multiplicand, address of bigint struc
; @arg %2 multiplier
; corrupts rdx, rcx, r8, rax, r11
%macro  MUL_BY_QUAD 2
        mov     rcx, [%1 + bigint.len]
        mov     r11, [%1 + bigint.data]
        xor     rdx, rdx
        %%loop:
                mov     r8, rdx             ; old carry
                mov     rax, [r11]
                mul     %2
                add     rax, r8
                adc     rdx, 0              ; update new carry in case of rax overflow
                mov     [r11], rax

                add     r11, 8
                sub     rcx, 8
                jnz     %%loop
%endmacro

; Adds given quadword to specified bigint.
;
; @arg %1 address of bigint
; @arg %2 quadword
; corrupts r8, rdx, rcx
%macro  ADD_QUAD 2
        mov     rdx, [%1 + bigint.data]
        mov     rcx, [%1 + bigint.len]
        mov     r8, [rdx]
        add     r8, %2
        mov     [rdx], r8
        pushf
        %%loop:
                popf
                mov     r8, [rdx]
                adc     r8, 0
                mov     [rdx], r8
                pushf

                jnc     %%done
                sub     rcx, 8
                jnz     %%loop
    %%done:
        popf
%endmacro

section .rodata
        align   8
    MSB:
        dq      0x8000000000000000  ; only MSB is true
    MINUS1_64:
        dq      0xffffffffffffffff

section .text

;BigInt biFromInt(int64_t x);
;
; @return rax address of brand new bigint struc
biFromInt:
        push    rdi
        mov     rsi, 8
        NEW_BI  rsi, rdx
        pop     rdi
        mov     [rdx], rdi
        ret

;BigInt biFromString(char const *s);
; Determines input's length, creates suitable bigint and write number into it.
biFromString:
        push    rbx

        mov     al, byte [rdi]                  ; at first handle sign
        cmp     al, '-'
        jne     .pos
        inc     rdi
        push    0
        jmp     .neg
    .pos:
        push    1
    .neg:

        mov     rsi, rdi                        ; then omit leading zeros
        .loop1:
                lodsb
                cmp     al, '0'
                je      .loop1
        dec     rsi

        mov     rdi, rsi
        xor     rcx, rcx
        .loop2:                                 ; estimate length of future bigint
                inc     rcx                     ; by counting length of input without sign and zeros
                lodsb
                cmp     al, 0
                jne     .loop2
        dec     rsi
        lea     rax, [rcx * 8 - 8]              ; and multiplying result by 8
        mov     rcx, 18
        xor     rdx, rdx
        div     rcx                             ; then dividing by 18 (10-base digits per quadword)
        add     rax, 8

        push    rdi                             ; begin of significant data
        push    rsi                             ; end of string
        mov     rdi, rax
        NEW_BI  rdi, r9
        mov     rcx, [rax + bigint.len]
        .loop3:                                 ; init new bigint with zeros
                mov     qword [r9], 0
                add     r9, 8
                sub     rcx, 8
                jnz     .loop3

        pop     rsi
        pop     rdi
        mov     r9, rax                         ; brand new bigint
        xor     rax, rax
        mov     rbx, 10
        .loop4:                                 ; multiply bigint by 10 and then add new digit
                MUL_BY_QUAD r9, rbx
                xor     rax, rax
                mov     al, byte [rdi]
                sub     al, '0'
                cmp     rax, 9                  ; if al was less than '0'
                ja      .fail                   ; overflow occurs and new rax > 9
                ADD_QUAD r9, rax

                inc     rdi
                cmp     rsi, rdi
                jne     .loop4

        pop     rdx
        test    rdx, 1
        jnz     .return
        NEGATE  r9

    .return:
        BI_SHORTEN r9
        mov     rax, r9        
        pop     rbx
        ret

    .fail:
        mov     rax, 0
        pop     rbx             ; sign quadword
        pop     rbx
        ret

;void biToString(BigInt bi, char *buffer, size_t limit);
biToString:
        ret

;void biDelete(BigInt bi);
biDelete:
        DEL_BI  rdi
        ret

;int biSign(BigInt bi);
; Consider a few clauses and return -1, 0, 1 if number negative, zero or positive, respectly.
; note: SIGN macro isn't applicatable here because it has only two return values
biSign:        
        mov     rcx, [rdi + bigint.len]
        mov     rdx, [rdi + bigint.data]
        mov     rdx, [rdx + rcx - 8]                    ; less significant quadword
        test    rdx, [MSB]                              ; if MSB is set, return -1
        jnz     .neg
        cmp     rcx, 8                                  ; if size == 8 bytes
        jne     .pos                                    ; and only number is zero
        cmp     rdx, 0                                  ; return 0
        jne     .pos
        mov     rax, 0
        ret
    .pos:
        mov     rax, 1                                  ; otherwise return 1
        ret
    .neg:
        mov     rax, -1
        ret

;void biAdd(BigInt dst, BigInt src);
; Performs addition in two's compliment.
; Extends dst.size and src.size to max(dst.size, src.size) + 8 bytes
; by pushing 0 or -1 quadwords for positive and negative numbers, respectly.
; So arithmetic overflow will never happen.
; In the end reduce number length by dropping not significant quadwords.
biAdd:
        push    r13                         ; System V AMD64 ABI routine
        push    r12                         ; rdi and rsi may be swapped later, remember dest
        push    rdi                         ; stack: r13, r12, dest

        mov     rdx, [rdi + bigint.len]
        cmp     rdx, [rsi + bigint.len]
        jae     .done_swap
        xchg    rdi, rsi
     .done_swap:                            ; now the longest number in rdi
        mov     rcx, [rdi + bigint.len]
        add     rcx, 8                      ; allocate memory for the biggest number possible
        push    rdi
        push    rsi                         ; stack: r13, r12, dest, greater, less
        call    malloc
        mov     r8, rax
        pop     rsi
        pop     rdi
        push    r8                          ; stack: r13, r12, dest, result.data

        mov     r12, [rdi + bigint.data]    ; pointer to greater's data
        mov     r13, [rsi + bigint.data]    ; pointer to less's data
        mov     rcx, [rsi + bigint.len]
        clc
        lahf
        .loop1:                             ; first loop until less number ends
                sahf                        ; restore carry flag
                mov     r9, [r12]
                adc     r9, [r13]
                mov     [r8], r9
                lahf                        ; save carry flag

                add     r8, 8
                add     r12, 8
                add     r13, 8
                sub     rcx, 8
                jnz     .loop1

        SIGN    rsi, r10                    ; assume the rest of less number quadwords either 0 or -1
        mov     rcx, [rdi + bigint.len]
        sub     rcx, [rsi + bigint.len]
        jz      .loop2_end
        .loop2:                             ; second loop until greater number ends
                sahf
                mov     r9, [r12]
                adc     r9, r10
                mov     [r8], r9
                lahf

                add     r8, 8
                add     r12, 8
                sub     rcx, 8
                jnz     .loop2

    .loop2_end:
        SIGN    rdi, r9                    ; now add greater[greater.size] to less[less.size]
        sahf
        adc     r9, r10                    ; i.e. greater's and less's signs and carry
        mov     [r8], r9

        ; replace dst data with new one
        mov     rax, [rdi + bigint.len]    ; max(dst.size, src.size)
        add     rax, 8
        mov     rdi, [rsp + 8]             ; stack: r13, r12, dst, result.data
        mov     [rdi + bigint.len], rax
        mov     rdi, [rdi + bigint.data]
        call    free
        pop     r8                         ; stack: r13, r12, dst
        pop     rdi                        ; stack: r13, r12
        mov     [rdi + bigint.data], r8

        BI_SHORTEN rdi

        pop     r12                         ; System V AMD64 ABI routine
        pop     r13
        ret

;void biSub(BigInt dst, BigInt src);
; Copies src, negates it and performs addition.
; Have to do copy in order to handle calls with same dst and src.
biSub:
        push    rdi
        COPY_BI rsi, rax
        pop     rdi
        mov     rsi, rax
        push    rsi
        NEGATE  rsi
        call    biAdd
        pop     rsi
        DEL_BI  rsi
        ret

;void biMul(BigInt dst, BigInt src);
biMul:
        ret

;void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
biDivRem:
        ret

;int biCmp(BigInt a, BigInt b);
biCmp:
        ret

