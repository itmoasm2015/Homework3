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
    je      .return
    pop     rax
    dec     rcx

    cmp     rdx, 0
    je      .loop_reverse

    cmp     rdx, 1
    jg      .print_symbol

    mov     byte [rsi], 0
    inc     rsi
    dec     rdx
    jmp     .loop_reverse

.print_symbol:
    mov     byte [rsi], al 
    inc     rsi
    dec     rdx
    jmp     .loop_reverse

.return:
    ret

;; Get sign of given BigInt.
; int biSign(BigInt bi);
;
;Parameters:
;   1) RDI - address of BigInt
;Returns:
;   RAX - sign
biSign:
    push    rdi
    mov     rsi, 10
    call divLongShort
    pop     rdi

    push    rax
    dumpBigInt rdi
    pop     rax
    ret

;; dst += src
; void biAdd(BigInt dst, BigInt src);
biAdd:
    ret

;; dst -= src
; void biSub(BigInt dst, BigInt src);
biSub:
    ret

;; dst *= src */
; void biMul(BigInt dst, BigInt src);
biMul:
    ret

;; Compute quotient and remainder by divising numerator by denominator.
;;   quotient * denominator + remainder = numerator
; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
biDivRem:
    ret

;; Compare two BitInts. Returns sign(a - b)
; int biCmp(BigInt a, BigInt b)
biCmp:
    ret
