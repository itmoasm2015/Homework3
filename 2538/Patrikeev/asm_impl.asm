default rel

extern calloc
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

section .text

;BigInt stores in memory as structure with appropriate offsets
;BigInt scale is 2^64, that is every digit is 64-bit unsigned number
;
;Offsets:
;   1) len - number of digits in BigInt
;   2) sign - signum of BigInt: either -1 or 1
;   3) digs - address in memory where digits begin
;      (they are stored from less-significant to most-significant ones)
;BigInt is 0 if and only if (len == 0 && sign == 1)
;
;Note: len is not necessarily equals real amount of allocated qwords,
;that is digs may be pointed to more wide area of memory,
;but in any case this memory will be deallocated via biDelete invocation
    struc BigInt_t
len:    resq    1
sign:   resq    1
digs:   resq    1
    endstruc

;;Create a BigInt from 64-bit signed integer.
;BigInt biFromInt(int64_t number);
;
;Parameters:
;   1) RDI - value of new BigInt
;Returns:
;   RAX - address of allocated BigInt
biFromInt: 
    push    rdi 

    mov     rdi, 1              ;calloc one BigInt structure
    mov     rsi, BigInt_t_size  ;with size of BigInt_t_size
    call    calloc
    mov     rdx, rax            ;address of allocated BigInt

    pop     rdi

    mov     qword [rdx + sign], 1   ;fill fields
    mov     qword [rdx + len], 0    ;number if zero yet
    mov     qword [rdx + digs], 0   ;so no digits are allocated

    cmp     rdi, 0      ;if number == 0 then done.
    je      .return
    jg      .fill_digs  ;number > 0

    mov     qword [rdx + sign], (-1)  ;number < 0
    not     rdi         ;convert to unsigned 64-bit
    inc     rdi

.fill_digs:
    push    rdx
    push    rdi

    mov     rdi, 1
    mov     rsi, 8
    call    calloc      ;calloc one digit

    pop     rdi
    pop     rdx

    mov     [rax], rdi           ;store the only digit in memory
    mov     [rdx + digs], rax    ;save digits address
    mov     qword [rdx + len], 1 ;set length to 1

.return:
    mov     rax, rdx    ;return address of BigInt

    ret

;Allocates N qwords and copies M from SRC to newly allocated
;memory starting from its beginning
;(convenient way in all kinds of copying BigInts)
;
;;void* alloc_N_and_copy_M(int n, void * src, int m)
;
;Parameters:
;   1) N - number of bytes to be allocated
;   2) SRC - source from where copy should be done
;   3) M - number of copying bytes
;Returns:
;   RAX - address of allocated and filled memory
%macro alloc_N_and_copy_M 3
    push    r12
    push    r13
    push    r14
    mov     r12, %1     ;move parameters to callee-saved registers
    mov     r13, %2     ;to preserve them across calloc-invocation
    mov     r14, %3

    mov     rdi, r12    ;N
    mov     rsi, 8      ;size of qword
    call    calloc

    mov     rdi, rax    ;RDI - beginning of destination
    mov     rsi, r13    ;RSI - beginning of source
    mov     rcx, r14    ;RCX - M qwords to be copied
    cld                 ;clear direction flag_set
    repnz   movsq       ;copy M qwords

    pop     r14
    pop     r13
    pop     r12
%endmacro

;Trims digits of specified BigInt while the last digit equals 0
;(this method is applicable after about every arithmetic operation
;to hold correct values of len and sign of BigInt)
;
;;void trimZeros(BigInt bi)
;
;Parameters:
;   1) RDI - BigInt
trimZeros:
    mov     rcx, [rdi + len]    ;RCX = length
    mov     rsi, [rdi + digs]   ;RSI = digits
.loop:
    cmp     rcx, 0      ;while last digit is 0, decrement length
    je      .endloop
    mov     rax, [rsi + rcx * 8 - 8]    ;store last digit
    cmp     rax, 0  
    jne     .endloop 
    dec     rcx
    jmp     .loop

.endloop:
    mov     rdx, [rdi + len]    ;RDX = old_length
    cmp     rcx, rdx            ;compare new_length and old_length
    je      .return             ;if no changes, then return
    xor     rax, rax            ;else we should deallocated old digits
    cmp     rcx, 0              
    je      .dealloc_old        ;if new_length == 0, then simply deallocate
                                ;without allocating new digits
    push    rdi
    push    rsi
    push    rcx
    alloc_N_and_copy_M rcx, rsi, rcx    ;allocate RCX qwords and fill them with
                                        ;RCX qwords from old memory
    pop     rcx
    pop     rsi
    pop     rdi

.dealloc_old:
    push    rax
    push    rcx
    push    rdi
    mov     rdi, [rdi + digs]   ;deallocate old digits
    call    free 
    pop     rdi
    pop     rcx
    pop     rax

    mov     [rdi + len], rcx    ;set new_length
    mov     [rdi + digs], rax   ;set newly allocated digits

    cmp     rcx, 0
    jne     .return
    mov     qword [rdi + sign], 1   ;if (new_length == 0) then BigInt == 0

.return:
    ret

;This macro simplifies allocating qwords
;void * alloc_N_qwords(int n)

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

;Multiplies given BigInt by given unsigned_int64_t number

;void mulLongShort(BigInt bi, unsigned_int64_t x)
;Parameters
;   1) RDI - BigInt to be multiplied
;   2) RSI - multiplier
mulLongShort:
    mov     r8, rdi             
    mov     rdi, [r8 + digs]    ;RDI = digits
    mov     rcx, [r8 + len]     ;RCX = length

    cmp     rcx, 0
    je      .return             ;length == 0 => BigInt == 0 => result == 0
    
    cmp     rsi, 0              ;multiplier == 0 => result == 0
    jne     .multi

    push    r8
    mov     rdi, [r8 + digs]    ;deallocate digits
    call    free 
    pop     r8

    mov     qword [r8 + digs], 0    ;set BigInt to 0        
    mov     qword [r8 + len], 0
    mov     qword [r8 + sign], 1
    jmp     .return

.multi:
    xor     r9, r9      ;carry
.loop:
    mov     rax, [rdi]  ;RAX = digits[i]
    mul     rsi         ;RDX:RAX = digits[i] * x
    add     rax, r9     
    adc     rdx, 0      ;digits[i] * x + carry
    mov     [rdi], rax  ;RAX = i-th digit of result
    add     rdi, 8      ;move RDI to next digit
    mov     r9, rdx     ;R9 = new_carry

    dec     rcx         ;go to next digit
    jnz     .loop

.endloop:
    cmp     r9, 0
    je      .return     ;if carry == 0 => done
                        ;else we should increase length of BigInt by 1
                        ;and place carry as most-significant digit
    push    r8
    push    r9
    mov     rax, [r8 + len]     ;length
    inc     rax                 ;length + 1
    mov     rsi, [r8 + digs]
    mov     rcx, [r8 + len]
    alloc_N_and_copy_M rax, rsi, rcx    ;allocate (length + 1) qwords and fill first (length)
                                        ;with old digits
    pop     r9
    pop     r8

    push    r8
    push    r9
    push    rax
    mov     rdi, [r8 + digs]    ;deallocate old digits
    call    free 
    pop     rax
    pop     r9
    pop     r8

    mov     [r8 + digs], rax
    mov     rax, [r8 + len]     ;RAX = old_length + 1
    inc     rax
    mov     [r8 + len], rax     ;set new_length
    mov     rdi, [r8 + digs]
    mov     [rdi + rax * 8 - 8], r9 ;store carry as most-significant digit

.return:
    ret


;Adds specified unsigned_int64_t number to BigInt
;void addLongShort(BigInt bi, unsigned_int64_t x)
;
;Parameters:
;   1) RDI - BigInt
;   2) RSI - value to be added
addLongShort: 
    mov     r8, rdi
    mov     rdi, [r8 + digs]    ;RDI = digits
    mov     rcx, [r8 + len]     ;RCX = length

    cmp     rcx, 0      ;if length == 0 => BigInt == 0 => result == x
    jne     .add_ls

    push    r8
    push    rsi
    alloc_N_qwords 1    ;allocate 1 digit
    pop     rsi
    pop     r8
    
    mov     [rax], rsi
    mov     [r8 + digs], rax        ;save this digit
    mov     qword [r8 + len], 1     ;set length
    mov     qword [r8 + sign], 1    ;and sign
    jmp     .return

.add_ls:
    xor     rdx, rdx    ;new_carry = 0
.loop:
    add     [rdi], rsi  ;digits[i] += old_carry (== x on 1-st iteration)
    adc     rdx, 0      ;new_carry += (digits[i] + old_carry) % (2^64)
    mov     rsi, rdx    ;RSI = new_carry
    xor     rdx, rdx    
    add     rdi, 8      ;move to next digit
    dec     rcx
    jnz     .loop

.endloop:
    cmp     rsi, 0      ;if carry != 0 after adding => we should allocate 1 more digit for carry
    je      .return

    push    r8
    push    rsi
    mov     rax, [r8 + len]
    inc     rax
    mov     rdx, [r8 + digs]
    mov     rcx, [r8 + len]
    alloc_N_and_copy_M rax, rdx, rcx    ;allocate (length + 1) digits and fill first (length) of them
                                        ;with old digits
    pop     rsi
    pop     r8

    push    rax
    push    rsi    
    push    r8
    mov     rdi, [r8 + digs]    ;deallocate old digits
    call    free 
    pop     r8
    pop     rsi
    pop     rax

    mov     [r8 + digs], rax    ;set new digits
    mov     rax, [r8 + len]     ;set new_length
    inc     rax
    mov     [r8 + len], rax
    mov     rdi, [r8 + digs]    ;set digits
    mov     [rdi + rax * 8 - 8], rsi    ;set most-significant digit to carry

.return:
    ret

;; Destroy a BigInt.
; void biDelete(BigInt bi)
;
;Parameters:
;   1) RDI - BigInt to be deleted
biDelete:
    cmp     rdi, 0      ;if RDI == NULL => nothing to delete
    je      .done
    mov     rsi, [rdi + digs] 
    cmp     rsi, 0              ;if digits == NULL => nothing to delete (i.e. BigInt == 0)
    je      .digs_done
    push    rdi
    mov     rdi, [rdi + digs]
    call    free                ;deallocate digits
    pop     rdi
.digs_done: 
    call free       ;deallocate BigInt structure
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
    call    biFromInt   ;create BigInt == 0
    mov     r8, rax
    pop     rdi

    xor     rax, rax
    mov     r9, 1           ;r9 = 1 (sign)
    mov     byte al, [rdi]  ;if '-' => r9 = (-1)
    cmp     byte al, '-'
    jne     .read_digs
    inc     rdi
    mov     r9, (-1)

.read_digs:
    xor     rcx, rcx        ;number of read digits
.loop:
    mov     byte al, [rdi]  ;load next char
    cmp     al, 0           ;if EOF => exit
    je      .endloop
    inc     rdi

    cmp     byte al, '0'
    jl      .incorrect
    cmp     byte al, '9'
    jg      .incorrect
    
    sub     rax, '0'    ;rax == next digit
    inc     rcx         ;one more digit

    push    rax         ;save important regs
    push    rcx
    push    rdi
    push    r8
    push    r9

    mov     rdi, r8
    mov     rsi, 10
    call    mulLongShort    ;BigInt *= 10

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

    mov     rdi, r8         ;r8 = BigInt
    mov     rsi, rax        ;rax = digit
    call    addLongShort    ;BigInt += digit

    pop     r9
    pop     r8
    pop     rdi
    pop     rcx
    pop     rax

    jmp     .loop

.endloop:
    cmp     rcx, 0      ;if RCX == 0 => no digits are read => incorrect
    jne     .return

.incorrect:
    mov     rdi, r8
    call    biDelete    ;deallocate memory for BigInt
    xor     rax, rax    ;result = NULL
    ret

.return:
    mov     rax, r8
    mov     [rax + sign], r9 ;set sign 1 or (-1) depends on '-' char in beginning
    push    rax
    mov     rdi, rax
    call    trimZeros   ;trim BigInt of leading zeros
    pop     rax

    ret

;;Divides given BigInt by given unsigned_int64_t number and returns remainder of operation
;;unsigned_int64_t divLongShort(BigInt bi, unsigned_int64_t number)
;
;Parameters:
;   1) RDI - BigInt to be divided
;   2) RSI - unsigned_int64_t divisor
;Returns:
;   RAX - remainder of division (or -1 if number was 0)
divLongShort:
    mov     r8, rdi
    mov     rdi, [r8 + digs]    ;RDI = digits
    mov     rcx, [r8 + len]     ;RCX = length

    cmp     rsi, 0      ;if divisor == 0 => error
    je      .incorrect
    
    xor     rax, rax
    cmp     rcx, 0      ;if length == 0 => result = 0
    je      .return

    xor     rdx, rdx    ;(RDX:RAX) will hold carry
.loop:
    mov     rdx, rax                    ;carry << 64
    mov     rax, [rdi + rcx * 8 - 8]    ;carry += next digit
    div     rsi                         ;(RDX:RAX) /= RSI
    mov     [rdi + rcx * 8 - 8], rax    ;RAX is next resulting digit
    mov     rax, rdx                    ;RDX is next carry 
    xor     rdx, rdx
    dec     rcx
    jnz     .loop

    push    rax
    mov     rdi, r8
    call    trimZeros   ;trim BigInt of leading zeros
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
;   1) RDI - BigInt number to be printed
;   2) RSI - buffer where to store resulting representation
;   3) RDX - maximum number of chars to be printed
biToString:
    push    rdi
    push    rsi
    push    rdx
    xor     rdi, rdi
    call    biFromInt   ;create copy of bi to divide it by 10 and print remainder every time
    mov     r8, rax
    pop     rdx
    pop     rsi
    pop     rdi

    mov     rcx, [rdi + len]        ;copy length
    mov     [r8 + len], rcx
    mov     qword [r8 + sign], 1    ;copy sign

    push    r8
    push    rdi
    push    rsi
    push    rdx

    alloc_N_and_copy_M [rdi + len], [rdi + digs], [rdi + len]   ;copy digits
    mov     r9, rax

    pop     rdx
    pop     rsi
    pop     rdi
    pop     r8

    mov     [r8 + digs], r9     ;now R8 is full copy of given BigInt

    xor     rcx, rcx    ;number of digits pushed onto stack
.loop:  
    push    rdi
    push    rsi
    push    rdx
    push    rcx
    push    r8

    mov     rdi, r8
    mov     rsi, 10
    call    divLongShort        ;R8 /= 10
    mov     r9, rax             ;R9 = R8 % 10 == rightmost decimal digit

    pop     r8
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi

    add     r9, '0'     ;set r9 to be char of digit
    push    r9          ;push r9 onto stack to be popped in future
    inc     rcx         ;one more digit pushed

    mov     rax, [r8 + len]     ;if length == 0 => BigInt == 0 => done
    cmp     rax, 0
    jnz     .loop

    mov     rax, [rdi + sign]   
    cmp     rax, (-1)
    jne     .loop_reverse       ;check if negative number

    cmp     rdx, 1
    jle     .loop_reverse

    mov     byte [rsi], '-'     ;print '-' as first char
    inc     rsi
    dec     rdx             ;RDX - holds limit

.loop_reverse:              ;this loop will pop RCX digits from stack to get forward 
                            ;decimal representation of BigInt
    cmp     rcx, 0          ;if all digits popped => print EOF
    je      .print_eof
    pop     rax             ;pop next digit
    dec     rcx

    cmp     rdx, 0          ;if limit == 0 => simply pop remaining chars
    je      .loop_reverse 

    cmp     rdx, 1          ;if limit == 1 => print EOF
    jg      .print_symbol

    mov     byte [rsi], 0
    xor     rdx, rdx        ;print EOF and set limit to 0
    jmp     .loop_reverse

.print_symbol:
    mov     byte [rsi], al  ;print next digit
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

%macro push_all_regs 0
    push    rdi
    push    rsi
    push    rdx
    push    rcx
    push    rbx
    push    r8
    push    r9
    push    r10
    push    r11
    push    r12
    push    r13
    push    r14
    push    r15
%endmacro

%macro pop_all_regs 0
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    pop     rbx
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi
%endmacro

;void shiftLeft(BigInt bi)
;
;Parameters:
;   1) RDI - address of BigInt to be shifted one digit left (that is *= BASE)
shiftLeft:
    mov     rax, [rdi + len]
    cmp     rax, 0
    jne     .not_zero
    ret
.not_zero:
    mov     rax, [rdi + len]
    inc     rax
    push_all_regs
    alloc_N_qwords rax
    pop_all_regs
    mov     r8, rax

    mov     rsi, [rdi + digs]
    mov     rcx, [rdi + len]
    mov     r9, r8
    add     r9, 8
.loop:
    cmp     rcx, 0
    je      .endloop
    dec     rcx
    mov     rax, [rsi]
    mov     [r9], rax
    add     rsi, 8
    add     r9, 8
    jmp     .loop 
.endloop:
    
    push_all_regs
    mov     rdi, [rdi + digs]
    call    free
    pop_all_regs

    mov     [rdi + digs], r8
    mov     rax, [rdi + len]
    inc     rax
    mov     [rdi + len], rax
    ret


;BigInt getQuotient(BigInt numerator, BigInt denominator)
;
;Parameters:
;   1) RDI - numerator BigInt
;   2) RSI - denominator BigInt
;Returns:
;   RAX - address of resultion quotient BigInt
getQuotient:
    push_all_regs

    mov     rax, [rdi + sign]
    mov     r15, [rsi + sign]
    imul    r15, rax

    mov     rdx, [rdi + len]
    mov     rcx, [rsi + len]
    mov     rdi, [rdi + digs]
    mov     rsi, [rsi + digs]

    push_all_regs
    alloc_N_and_copy_M rdx, rdi, rdx
    pop_all_regs
    mov     rdi, rax

    push_all_regs
    alloc_N_and_copy_M rcx, rsi, rcx
    pop_all_regs
    mov     rsi, rax

    push_all_regs
    xor     rdi, rdi
    call    biFromInt
    pop_all_regs
    mov     r10, rax
    mov     [r10 + digs], rdi
    mov     [r10 + len], rdx
    mov     qword [r10 + sign], 1

    push_all_regs
    xor     rdi, rdi
    call    biFromInt
    pop_all_regs
    mov     r11, rax
    mov     [r11 + digs], rsi
    mov     [r11 + len], rcx
    mov     qword [r11 + sign], 1

    mov     r9, [rsi + rcx * 8 - 8]
    inc     r9
    cmp     r9, 0
    jne     .norm_take
    mov     r9, 1
    jmp     .norm_got 

.norm_take:
    push    rdx
    mov     rdx, 1
    mov     rax, 0
    div     r9
    mov     r9, rax
    pop     rdx

.norm_got:
    push_all_regs
    mov     rdi, r10
    mov     rsi, r9
    call    mulLongShort
    pop_all_regs

    push_all_regs
    mov     rdi, r11
    mov     rsi, r9
    call    mulLongShort
    pop_all_regs

    mov     rdi, [r10 + digs]
    mov     rdx, [r10 + len]
    mov     rsi, [r11 + digs]
    mov     rcx, [r11 + len]

    push_all_regs
    alloc_N_qwords rdx
    pop_all_regs
    mov     r8, rax

    push_all_regs
    xor     rdi, rdi
    call    biFromInt
    pop_all_regs
    mov     r9, rax

    push_all_regs
    xor     rdi, rdi
    call    biFromInt
    pop_all_regs
    mov     r12, rax

    mov     r13, rdx
.loop:
    cmp     r13, 0
    je      .endloop
    dec     r13

    push_all_regs
    mov     rdi, r9
    call    shiftLeft
    pop_all_regs

    mov     rax, [rdi + r13 * 8]    
    push_all_regs
    mov     rdi, r9
    mov     rsi, rax
    call    addLongShort
    pop_all_regs

    push_all_regs
    mov     rdx, [r10 + len]
    mov     rcx, [r11 + len]

    mov     r14, [r11 + digs]
    mov     r14, [r14 + rcx * 8 - 8]

    xor     r10, r10
    mov     r12, rcx
    mov     r8, [r9 + len]
    cmp     r12, r8
    jge     .s1_set
    
    mov     r10, [r9 + digs]
    mov     r10, [r10 + r12 * 8]

    .s1_set:
    xor     r11, r11
    mov     r12, rcx
    dec     r12
    mov     r8, [r9 + len]
    cmp     r12, r8
    jge     .s2_set

    mov     r11, [r9 + digs]
    mov     r11, [r11 + r12 * 8]

    .s2_set:
    mov     rdx, r10
    mov     rax, r11
    div     r14
    pop_all_regs
    mov     r14, rax

    push_all_regs
    mov     rdi, [r12 + digs]
    call    free 
    pop_all_regs

    push_all_regs
    alloc_N_and_copy_M [r11 + len], [r11 + digs], [r11 + len]
    pop_all_regs
    mov     [r12 + digs], rax
    mov     [r12 + len], rcx
    mov     qword [r12 + sign], 1

    push_all_regs
    mov     rdi, r12
    mov     rsi, r14
    call    mulLongShort
    pop_all_regs

    push_all_regs
    mov     rdi, r9
    mov     rsi, r12
    call    biSub
    pop_all_regs

    .while_neg_loop:
        mov     rax, [r9 + sign]
        cmp     rax, 1
        je      .end_while_neg_loop
        
        push_all_regs
        mov     rdi, r9
        mov     rsi, r11
        call    biAdd
        pop_all_regs
        
        dec     r14
        jmp     .while_neg_loop
    .end_while_neg_loop:

    mov     [r8 + r13 * 8], r14
    jmp     .loop

.endloop:
    push_all_regs
    xor     rdi, rdi
    call    biFromInt
    pop_all_regs
    mov     r14, rax

    mov     [r14 + digs], r8
    mov     [r14 + len], rdx
    mov     qword [r14 + sign], 1

    push_all_regs
    mov     rdi, r14
    call    trimZeros
    pop_all_regs

    cmp     r15, 1
    je      .sign_set

    xor     rcx, rcx
    mov     rax, [r9 + len]
    cmp     rax, 0
    je      .flag_set
    mov     rcx, 1

.flag_set:

    push_all_regs
    mov     rdi, r14
    mov     rsi, rcx
    call    addLongShort
    pop_all_regs

    mov     qword [r14 + sign], (-1)

.sign_set:
    push_all_regs
    mov     rdi, r9
    call    biDelete
    pop_all_regs

    push_all_regs
    mov     rdi, r10
    call    biDelete
    pop_all_regs

    push_all_regs
    mov     rdi, r11
    call    biDelete
    pop_all_regs

    push_all_regs
    mov     rdi, r12
    call    biDelete
    pop_all_regs

    mov     rax, r14
    pop_all_regs    

    ret

;BigInt copyBigInt(BigInt bi)
;
;Parameters:
;   1) RDI - BigInt to be copied
;Returns:
;   RAX - copy of given BigInt
copyBigInt:
    push_all_regs
    alloc_N_and_copy_M [rdi + len], [rdi + digs], [rdi + len]
    pop_all_regs
    mov     r8, rax

    push_all_regs
    xor     rdi, rdi
    call    biFromInt
    pop_all_regs
    mov     r9, rax

    mov     [r9 + digs], r8
    mov     rax, [rdi + len]
    mov     [r9 + len], rax
    mov     rax, [rdi + sign]
    mov     [r9 + sign], rax
    mov     rax, r9
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
    push_all_regs
    call    getQuotient
    pop_all_regs
    mov     r8, rax 

    push_all_regs
    mov     rdi, r8
    call    copyBigInt
    pop_all_regs
    mov     r9, rax

    push_all_regs
    mov     rdi, r9
    call    biMul
    pop_all_regs

    mov     rax, [r9 + sign]
    imul    rax, (-1)
    mov     [r9 + sign], rax

    push_all_regs
    mov     rsi, rdi
    mov     rdi, r9
    call    biAdd
    pop_all_regs

    pop     rsi
    pop     rdi

    mov     [rdi], r8
    mov     [rsi], r9
.return:
    ret