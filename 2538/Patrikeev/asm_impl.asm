default rel

extern calloc
extern free
extern printf

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

section .text

    struc BigInt_t
len:    resq    1
sign:   resq    1
digs:   resq    1
    endstruc

;;Create a BigInt from 64-bit signed integer.
;BigInt biFromInt(int64_t x);
;
;Parameters:
;   1) RDI - value of new BigInt
;Returns:
;   RAX - address of allocated BigInt
biFromInt: 
    push    rdi 

    mov     rdi, 1
    mov     rsi, BigInt_t_size
    call    calloc
    mov     rdx, rax

    pop     rdi

    mov     qword [rdx + sign], 1
    mov     qword [rdx + len], 0
    mov     qword [rdx + digs], 0

    cmp     rdi, 0
    je      .return
    jg      .fill_digs

    mov     qword [rdx + sign], (-1)
    not     rdi
    inc     rdi

.fill_digs:
    push    rdx
    push    rdi

    mov     rdi, 1
    mov     rsi, 8
    call    calloc

    pop     rdi
    pop     rdx

    mov     [rax], rdi
    mov     [rdx + digs], rax
    mov     qword [rdx + len], 1

.return:
    mov     rax, rdx

    ret

;;Prints element using printf
;
;Parameters:
;   1) format_string
;   2) element_to_print
%macro call_printf 2
    push    rdi
    push    rsi
    mov     rdi, %1
    mov     rsi, %2
    xor     rax, rax
    call    printf
    pop     rsi
    pop     rdi
%endmacro

;;Prints content of BigInt to console
;Parameters:
;   1) address of BigInt
%macro dumpBigInt 1
    jmp     %%endstr
%%len_str:      db  "len: %llu", 10, 0
%%sign_str:     db  "sign: %lld", 10, 0
%%format_s:     db  "%s", 10, 0
%%digs_str:     db  "digs: ", 0
%%format_ull:   db  "%llu ", 0
%%format_sll:   db  "%lld", 0  
%%new_line:     db  " ", 10, 0 
%%endstr:
    push    r12
    mov     r12, %1
    call_printf %%len_str, [r12 + len]
    call_printf %%sign_str, [r12 + sign]
    call_printf %%format_s, %%digs_str
    push    rcx
    push    rdx
    mov     rdx, [r12 + digs]
    mov     rcx, [r12 + len]

    %%loop:
        cmp     rcx, 0
        je      %%endloop
        dec     rcx
        push    rcx
        push    rdx
        call_printf %%format_ull, [rdx + rcx * 8]
        pop     rdx
        pop     rcx
        jmp     %%loop
    
    %%endloop: 

    call_printf %%format_s, %%new_line
    
    pop     rdx
    pop     rcx       
    pop     r12
%endmacro

;void* alloc_N_and_copy_M(int n, void * src, int m)
;Parameters:
;   1) N 
;   2) SRC
;   3) M 
;Returns:
;   RAX - address of allocated and filled memory
%macro alloc_N_and_copy_M 3
    push    r12
    push    r13
    push    r14
    mov     r12, %1
    mov     r13, %2
    mov     r14, %3

    mov     rdi, r12
    mov     rsi, 8
    call    calloc

    mov     rdi, rax
    mov     rsi, r13
    mov     rcx, r14
    cld
    repnz   movsq

    pop     r14
    pop     r13
    pop     r12
%endmacro

;void trimZeros(BigInt bi)
;
;Parameters:
;   1) RDI - BigInt
trimZeros:
    mov     rcx, [rdi + len]
    mov     rsi, [rdi + digs]
.loop:
    cmp     rcx, 0
    je      .endloop
    mov     rax, [rsi + rcx * 8 - 8]
    cmp     rax, 0
    jne     .endloop
    dec     rcx
    jmp     .loop

.endloop:
    mov     rdx, [rdi + len]
    cmp     rcx, rdx
    je      .return
    xor     rax, rax
    cmp     rcx, 0
    je      .dealloc_old

    push    rdi
    push    rsi
    push    rcx
    alloc_N_and_copy_M rcx, rsi, rcx 
    pop     rcx
    pop     rsi
    pop     rdi

.dealloc_old:
    push    rax
    push    rcx
    push    rdi
    mov     rdi, [rdi + digs]
    call    free 
    pop     rdi
    pop     rcx
    pop     rax

    mov     [rdi + len], rcx
    mov     [rdi + digs], rax

    cmp     rcx, 0
    jne     .return
    mov     qword [rdi + sign], 1

.return:
    ret

;Parameters:
;   1) N - number of qwords to be allocated
;Returns:
;   RAX - address of allocated memory
%macro alloc_N_qwords 1
    push    rdi
    push    rsi
    mov     rdi, %1
    mov     rsi, 8
    call    calloc
    pop     rsi
    pop     rdi
%endmacro

;Parameters:
;   1) address
%macro dealloc_memory 1
    push    rdi
    mov     rdi, %1
    call    free 
    pop     rdi
%endmacro

;void copy_N_qwords(void * dst, void * src, void * cnt)
;Parameters:
;   1) DST - destination
;   2) SRC - source
;   3) CNT - number of qwords
%macro copy_N_qwords 3
    push    rdi
    push    rsi
    push    rcx
    mov     rdi, %1
    mov     rsi, %2
    mov     rcx, %3
    cld
    repnz   movsq 
    pop     rcx
    pop     rsi
    pop     rdi
%endmacro


;void mulLongShort(BigInt bi, unsigned_int64_t mt)
;Parameters
;   1) RDI - BigInt to be multiplied
;   2) RSI - multiplier
mulLongShort:
    mov     r8, rdi
    mov     rdi, [r8 + digs]
    mov     rcx, [r8 + len]

    cmp     rcx, 0
    je      .return
    
    cmp     rsi, 0
    jne     .multi

    push    r8
    mov     rdi, [r8 + digs]
    call    free 
    pop     r8

    mov     qword [r8 + digs], 0         
    mov     qword [r8 + len], 0
    mov     qword [r8 + sign], 1
    jmp     .return

.multi:
    xor     r9, r9
.loop:
    mov     rax, [rdi]
    mul     rsi
    add     rax, r9
    adc     rdx, 0
    mov     [rdi], rax
    add     rdi, 8
    mov     r9, rdx

    dec     rcx
    jnz     .loop

.endloop:
    cmp     r9, 0
    je      .return

    push    r8
    push    r9
    mov     rax, [r8 + len]
    inc     rax
    mov     rsi, [r8 + digs]
    mov     rcx, [r8 + len]
    alloc_N_and_copy_M rax, rsi, rcx
    pop     r9
    pop     r8

    push    r8
    push    r9
    push    rax
    mov     rdi, [r8 + digs]
    call    free 
    pop     rax
    pop     r9
    pop     r8

    mov     [r8 + digs], rax
    mov     rax, [r8 + len]
    inc     rax
    mov     [r8 + len], rax
    mov     rdi, [r8 + digs]
    mov     [rdi + rax * 8 - 8], r9

.return:
    ret


;void addLongShort(BigInt bi, unsigned_int64_t x)
;
;Parameters:
;   1) RDI - BigInt
;   2) RSI - value to be added
addLongShort: 
    mov     r8, rdi
    mov     rdi, [r8 + digs]
    mov     rcx, [r8 + len]

    cmp     rcx, 0
    jne     .add_ls

    push    r8
    push    rsi
    alloc_N_qwords 1
    pop     rsi
    pop     r8
    
    mov     [rax], rsi
    mov     [r8 + digs], rax    
    mov     qword [r8 + len], 1
    mov     qword [r8 + sign], 1
    jmp     .return

.add_ls:
    xor     rdx, rdx
.loop:
    add     [rdi], rsi
    adc     rdx, 0
    mov     rsi, rdx
    xor     rdx, rdx
    add     rdi, 8
    dec     rcx
    jnz     .loop

.endloop:
    cmp     rsi, 0
    je      .return

    push    r8
    push    rsi
    mov     rax, [r8 + len]
    inc     rax
    mov     rdx, [r8 + digs]
    mov     rcx, [r8 + len]
    alloc_N_and_copy_M rax, rdx, rcx
    pop     rsi
    pop     r8

    push    rax
    push    rsi    
    push    r8
    mov     rdi, [r8 + digs]
    call    free 
    pop     r8
    pop     rsi
    pop     rax

    mov     [r8 + digs], rax
    mov     rax, [r8 + len]
    inc     rax
    mov     [r8 + len], rax
    mov     rdi, [r8 + digs]
    mov     [rdi + rax * 8 - 8], rsi

.return:
    ret

;; Destroy a BigInt.
; void biDelete(BigInt bi)
;
;Parameters:
;   1) RDI - BigInt to be deleted
biDelete:
    cmp     rdi, 0
    je      .done
    mov     rsi, [rdi + digs]
    cmp     rsi, 0
    je      .digs_done
    push    rdi
    mov     rdi, [rdi + digs]
    call    free
    pop     rdi
.digs_done: 
    call free
.done:
    ret

;;Create a BigInt from a decimal string representation.
;; Returns NULL on incorrect string.
; BigInt biFromString(char const *s)
;
;Parameters:
;   1) RDI - address of string
;Returns:
;   RAX - address of allocated BigInt or NULL on incorrect string
biFromString:
    push    rdi
    xor     rdi, rdi
    call    biFromInt
    mov     r8, rax
    pop     rdi

    xor     rax, rax
    mov     r9, 1
    mov     byte al, [rdi]
    cmp     byte al, '-'
    jne     .read_digs
    inc     rdi
    mov     r9, (-1)

.read_digs:
    xor     rcx, rcx
.loop:
    mov     byte al, [rdi]
    cmp     al, 0
    je      .endloop
    inc     rdi

    cmp     byte al, '0'
    jl      .incorrect
    cmp     byte al, '9'
    jg      .incorrect
    
    sub     rax, '0'
    inc     rcx

    push    rax
    push    rcx
    push    rdi
    push    r8
    push    r9

    mov     rdi, r8
    mov     rsi, 10
    call    mulLongShort

    pop     r9
    pop     r8
    pop     rdi
    pop     rcx
    pop     rax

    push    rax
    push    rcx
    push    rdi
    push    r8
    push    r9

    mov     rdi, r8
    mov     rsi, rax
    call    addLongShort

    pop     r9
    pop     r8
    pop     rdi
    pop     rcx
    pop     rax

    jmp     .loop

.endloop:
    cmp     rcx, 0
    jne     .return

.incorrect:
    mov     rdi, r8
    call    biDelete
    xor     rax, rax
    ret

.return:
    mov     rax, r8
    mov     [rax + sign], r9
    push    rax
    mov     rdi, rax
    call    trimZeros
    pop     rax

    ret

;;unsigned_int64_t divLongShort(BigInt bi, unsigned_int64_t x)
;
;Parameters:
;   1) RDI - BigInt to be divided
;   2) RSI - divisor
;Returns:
;   RAX - remainder of division (or -1 if error)
divLongShort:
    mov     r8, rdi
    mov     rdi, [r8 + digs]
    mov     rcx, [r8 + len]

    cmp     rsi, 0
    je      .incorrect
    
    xor     rax, rax
    cmp     rcx, 0
    je      .return

    xor     rdx, rdx
.loop:
    mov     rdx, rax
    mov     rax, [rdi + rcx * 8 - 8]
    div     rsi
    mov     [rdi + rcx * 8 - 8], rax
    mov     rax, rdx
    xor     rdx, rdx
    dec     rcx
    jnz     .loop

    push    rax
    mov     rdi, r8
    call    trimZeros
    pop     rax
    jmp     .return

.incorrect:
    mov     rax, (-1)

.return:
    ret

;; Generate a decimal string representation from a BigInt.
;;  Writes at most limit bytes to buffer
; void biToString(BigInt bi, char *buffer, size_t limit);
;
;Parameters:
;   1) RDI - bi
;   2) RSI - buffer
;   3) RDX - limit
biToString:
    push    rdi
    push    rsi
    push    rdx
    xor     rdi, rdi
    call    biFromInt
    mov     r8, rax
    pop     rdx
    pop     rsi
    pop     rdi

    mov     rcx, [rdi + len]
    mov     [r8 + len], rcx
    mov     qword [r8 + sign], 1

    push    r8
    push    rdi
    push    rsi
    push    rdx

    alloc_N_and_copy_M [rdi + len], [rdi + digs], [rdi + len]
    mov     r9, rax

    pop     rdx
    pop     rsi
    pop     rdi
    pop     r8

    mov     [r8 + digs], r9

    xor     rcx, rcx
.loop:  
    push    rdi
    push    rsi
    push    rdx
    push    rcx
    push    r8

    mov     rdi, r8
    mov     rsi, 10
    call    divLongShort
    mov     r9, rax

    pop     r8
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi

    add     r9, '0'
    push    r9
    inc     rcx

    mov     rax, [r8 + len]
    cmp     rax, 0
    jnz     .loop

    mov     rax, [rdi + sign]
    cmp     rax, (-1)
    jne     .loop_reverse

    cmp     rdx, 1
    jle     .loop_reverse

    mov     byte [rsi], '-'
    inc     rsi
    dec     rdx

.loop_reverse:
    cmp     rcx, 0
    je      .print_eof
    pop     rax
    dec     rcx

    cmp     rdx, 0
    je      .loop_reverse

    cmp     rdx, 1
    jg      .print_symbol

    mov     byte [rsi], 0
    xor     rdx, rdx
    jmp     .loop_reverse

.print_symbol:
    mov     byte [rsi], al 
    inc     rsi
    dec     rdx
    jmp     .loop_reverse

.print_eof:
    mov     byte [rsi], 0

.return:
    ret

;void * digsAdd(void * v1, void * v2, int n, int m)
;
;Parameters:
;   1) RDI - summand #1 address
;   2) RSI - summand #2 address
;   3) RDX - summand #1 size
;   4) RCX - summand #2 size
;Returns:
;   RAX - address of resulting vector
;   R9  - size of resulting vector
digsAdd:
    mov     rax, rdx
    cmp     rax, rcx
    cmovl   rax, rcx
    inc     rax

    push    rdi
    push    rsi
    push    rdx
    push    rcx
    push    rax
    alloc_N_qwords rax
    mov     r8, rax
    pop     rax
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi

    push    r12

    xor     r9, r9
    xor     r10, r10
.loop:
    xor     r11, r11
    xor     r12, r12
    cmp     r9, rdx
    jge     .add_second
    mov     r11, [rdi + r9 * 8]

.add_second:
    cmp     r9, rcx
    jge     .add_carry
    add     r11, [rsi + r9 * 8]
    adc     r12, 0

.add_carry:
    add     r11, r10
    adc     r12, 0

    mov     [r8 + r9 * 8], r11
    mov     r10, r12
    inc     r9
    cmp     r9, rax
    jne     .loop

.set_size:
    mov     r9, rax
    dec     r9
    mov     r10, [r8 + rax * 8 - 8]
    cmp     r10, 0
    cmovg   r9, rax

.return:
    pop     r12
    mov     rax, r8
    ret

;int compareDigs(void * v1, void * v2, int n, int m)
;
;Parameters:
;   1) RDI - 1st vector
;   2) RSI - 2nd vector
;   3) RDX - length of 1st vector
;   4) RCX - length of 2nd vector
;Returns:
;   RAX - sign of comparison (v1 - v2) : -1, 0, 1
compareDigs:
    cmp     rdx, rcx
    jne     .diff_lens
    
    mov     r9, rdx
.loop:
    cmp     r9, 0
    je      .equals
    dec     r9
    mov     rax, [rdi + r9 * 8]
    mov     r10, [rsi + r9 * 8]
    cmp     rax, r10
    ja      .first_gt
    jb      .second_gt
    jmp     .loop    

.diff_lens:
    cmp     rdx, rcx
    jg      .first_gt
    jmp     .second_gt

.first_gt:
    mov     rax, 1
    ret

.second_gt:
    mov     rax, (-1)
    ret

.equals:
    xor     rax, rax
    ret

;void digsSub(void * v1, void * v2, int n, int m)
;
;Parameters:
;   1) RDI - 1st vector
;   2) RSI - 2nd vector
;   3) RDX - length of 1st vector
;   4) RCX - length of 2nd vector
;Returns:
;   1) RAX - address of resulting vector
;   2) R9 - size of resulting vector
;   3) R10 - signum of subtracting (-1 or 1)
digsSub:
    push    rdi
    push    rsi
    push    rdx
    push    rcx
    call compareDigs
    mov     r10, rax
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi

    cmp     r10, 0
    jne     .maybe_swap
    mov     r10, 1
    jmp     .make_sub

.maybe_swap:
    cmp     r10, (-1)
    jne     .make_sub
    xchg    rdi, rsi
    xchg    rdx, rcx

.make_sub:
    mov     rax, rdx
    cmp     rax, rcx
    cmovl   rax, rcx

    push    rdi
    push    rsi
    push    rdx
    push    rcx
    push    r10
    push    rax
    alloc_N_qwords rax
    mov     r8, rax
    pop     rax
    pop     r10
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi

    push    r10
    push    r12

    xor     r9, r9
    xor     r10, r10
.loop:
    xor     r12, r12

    mov     r11, [rdi + r9 * 8]
    cmp     r9, rcx
    jge     .sub_borrow
    sub     r11, [rsi + r9 * 8]
    adc     r12, 0
.sub_borrow:
    sub     r11, r10
    adc     r12, 0

    mov     [r8 + r9 * 8], r11
    mov     r10, r12
    inc     r9
    cmp     r9, rax
    jne     .loop

    mov     r9, rax
    mov     rax, r8
    pop     r12
    pop     r10

    ret


;; dst += src
; void biAdd(BigInt dst, BigInt src);
;
;Parameters:
;   1) RDI - dst BigInt
;   2) RSI - src BigInt
biAdd:
    mov     rax, [rsi + len]
    cmp     rax, 0
    jne     .src_not_zero
    ret
.src_not_zero:
    mov     rax, [rdi + len]
    cmp     rax, 0
    jne     .dst_not_zero

    push    rdi
    push    rsi
    alloc_N_and_copy_M [rsi + len], [rsi + digs], [rsi + len]
    pop     rsi
    pop     rdi
    mov     [rdi + digs], rax
    mov     rax, [rsi + len]
    mov     [rdi + len], rax
    mov     rax, [rsi + sign]
    mov     [rdi + sign], rax
    ret
.dst_not_zero:
    mov     rax, [rdi + sign]
    mov     rdx, [rsi + sign]
    cmp     rax, rdx
    jne     .diff_signs

    push    rdi
    push    rsi
    mov     rdx, [rdi + len]
    mov     rcx, [rsi + len]
    mov     rdi, [rdi + digs]
    mov     rsi, [rsi + digs]
    call    digsAdd
    pop     rsi
    pop     rdi

    push    rax
    push    r9
    push    rdi
    mov     rdi, [rdi + digs]
    call    free 
    pop     rdi
    pop     r9
    pop     rax

    mov     [rdi + digs], rax
    mov     [rdi + len], r9

    call    trimZeros
    ret

.diff_signs:
    push    rdi
    push    rsi
    mov     rdx, [rdi + len]
    mov     rcx, [rsi + len]
    mov     rdi, [rdi + digs]
    mov     rsi, [rsi + digs]
    call    digsSub
    pop     rsi
    pop     rdi

    push    rax
    push    r9
    push    r10
    push    rdi
    mov     rdi, [rdi + digs]
    call    free 
    pop     rdi
    pop     r10
    pop     r9
    pop     rax

    mov     [rdi + digs], rax
    mov     [rdi + len], r9
    mov     rcx, [rdi + sign]
    imul    rcx, r10
    mov     [rdi + sign], rcx

    call trimZeros
    ret

;; Get sign of given BigInt.
; int biSign(BigInt bi);
;
;Parameters:
;   1) RDI - address of BigInt
;Returns:
;   RAX - sign
biSign:
    mov     rcx, [rdi + len]
    cmp     rcx, 0
    je      .zero
    mov     rax, [rdi + sign]
    ret
.zero:
    xor     rax, rax
    ret

;; dst -= src
; void biSub(BigInt dst, BigInt src);
;
;Parameters:
;   1) RDI - dst
;   2) RSI - src
biSub:
    mov     rax, [rsi + len]
    cmp     rax, 0
    jne     .src_not_zero
    ret
.src_not_zero:
    mov     rax, [rsi + sign]
    imul    rax, (-1)
    mov     [rsi + sign], rax
    push    rax
    push    rsi
    call    biAdd
    pop     rsi
    pop     rax
    
    imul    rax, (-1)
    mov     [rsi + sign], rax
    ret

;; Compare two BigInts. Returns sign(a - b)
; int biCmp(BigInt a, BigInt b)
;
;Parameters:
;   1) RDI - 1st BigInt
;   2) RSI - 2nd BigInt
;Returns:
;   RAX - sign
biCmp:
    mov     rax, [rdi + sign]
    mov     rcx, [rsi + sign]
    cmp     rax, rcx
    jne     .diff_signs

    push    rax
    mov     rdx, [rdi + len]
    mov     rcx, [rsi + len]
    mov     rdi, [rdi + digs]
    mov     rsi, [rsi + digs]
    call    compareDigs
    mov     r8, rax
    pop     rax

    cmp     r8, 0
    je      .equals
    imul    rax, r8
    ret

.diff_signs:
    cmp     rax, 1
    je      .first_gt
    jmp     .second_gt

.first_gt:
    mov     rax, 1
    ret
.second_gt:
    mov     rax, (-1)
    ret
.equals:
    xor     rax, rax
    ret

;BigInt digsMul(void * v1, void * v2, int n, int m)
;
;Parameters:
;   1) RDI - multiplier #1 address
;   2) RSI - multiplier #2 address
;   3) RDX - length of #1
;   4) RCX - length of #2
;Returns:
;   1) RAX - address of resulting vector
;   2) R9 - length of resulting vector
digsMul:
    mov     rax, rdx
    add     rax, rcx

    push    rdi
    push    rsi
    push    rdx
    push    rcx
    alloc_N_qwords rax
    mov     r8, rax
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi

    push    r12
    push    r13
    mov     r11, rcx
    mov     r12, rdx

    xor     r9, r9
.loop_outer:
    xor     r10, r10
    xor     r13, r13

.loop_inner:
    xor     rdx, rdx
    mov     rax, r13
    cmp     r10, r11
    jge     .add_to_ans
    mov     rax, [rsi + r10 * 8]
    mov     rcx, [rdi + r9 * 8]
    mul     rcx
    add     rax, r13
    adc     rdx, 0

.add_to_ans:
    mov     rcx, r9
    add     rcx, r10
    add     rax, [r8 + rcx * 8]
    adc     rdx, 0
    mov     [r8 + rcx * 8], rax
    mov     r13, rdx

    inc     r10
    cmp     r10, r11
    jl      .loop_inner
    cmp     r13, 0
    jne     .loop_inner

    inc     r9
    cmp     r9, r12
    jne     .loop_outer

    mov     r9, r11
    add     r9, r12
    mov     rax, r8

    pop     r13
    pop     r12
    ret

;; dst *= src */
; void biMul(BigInt dst, BigInt src)
;
;Parameters:
;   1) RDI - dst
;   2) RSI - src
biMul:
    mov     rax, [rdi + len]
    cmp     rax, 0
    jnz     .dst_not_zero
    ret
.dst_not_zero:
    mov     rax, [rsi + len]
    cmp     rax, 0
    jnz     .src_not_zero

    push    rdi
    mov     rdi, [rdi + digs]
    call    free
    pop     rdi

    mov     qword [rdi + digs], 0
    mov     qword [rdi + sign], 1
    mov     qword [rdi + len], 0
    ret

.src_not_zero:
    push    rdi
    push    rsi

    mov     rdx, [rdi + len]
    mov     rcx, [rsi + len]
    mov     rdi, [rdi + digs]
    mov     rsi, [rsi + digs]
    call    digsMul

    pop     rsi
    pop     rdi

    push    rax
    push    r9
    push    rdi
    push    rsi
    mov     rdi, [rdi + digs]
    call    free 
    pop     rsi
    pop     rdi
    pop     r9
    pop     rax

    mov     [rdi + digs], rax
    mov     [rdi + len], r9

    mov     rax, [rdi + sign]
    mov     rcx, [rsi + sign]
    imul    rax, rcx
    mov     [rdi + sign], rax

    push    rdi
    call    trimZeros
    pop     rdi

    ret

;pair<void*, void*> digsDiv(void * v1, void * v2, int n, int m)
;
;Parameters:
;   1) RDI - address of numerator digs vector
;   2) RSI - address of remainder digs vector
;   3) RDX - size of #1
;   4) RCX - size of #2
;Returns:
;   1) RAX - address of quotient resulting vector
;   2) RDX - address of remainder resulting vector
digsDiv:
    push    rdi
    push    rsi
    push    rdx
    push    rcx
    mov     rax, [rdi + len]
    alloc_N_qwords rax
    mov     r8, rax
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi

    mov     r9, [rsi + rcx * 8 - 8]
    inc     r9
    
    push    rdx
    mov     rdx, 1
    xor     rax, rax
    div     r9
    mov     r9, rax
    pop     rdx

    push    rdi
    push    rsi
    push    rdx
    push    rcx
    push    r8
    push    r9
    xor     rdi, rdi
    call    biFromInt
    pop     r9
    pop     r8
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi

    ret

;; Compute quotient and remainder by divising numerator by denominator.
;;   quotient * denominator + remainder = numerator
; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
;
;Parameters:
;   1) RDI - quotient address-holder
;   2) RSI - remainder address-holder
;   3) RDX - numerator BigInt
;   4) RCX - denominator BigInt
biDivRem:
    push    rdi
    push    rsi
    mov     rdi, rdx
    mov     rsi, rcx
    
    mov     rax, [rsi + len]
    cmp     rax, 0
    jne     .denom_not_zero

    pop     rsi
    pop     rdi
    mov     qword [rdi], 0
    mov     qword [rsi], 0
    ret

.denom_not_zero:
    mov     rax, [rdi + len]
    cmp     rax, 0
    jne     .numer_not_zero

    xor     rdi, rdi
    call    biFromInt
    pop     rsi
    mov     [rsi], rax

    xor     rdi, rdi
    call    biFromInt
    pop     rdi
    mov     [rdi], rax
    ret

.numer_not_zero:
    ;TODO: write digsDiv

.return:
    ret