default rel

extern calloc
extern printf
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

;Note: as far as it's required to align stack by 16 bytes before invocation
;any external function I would like to accept the agreement that all macros
;are called after alignment of stack (simply as functions) and that's why at
;the beginning of every macros stack is already aligned(unlike functions)

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
    sub     rsp, 8      ;align stack by 16 bytes

    mov     rdi, 1
    mov     rsi, 8
    call    calloc      ;calloc one digit
    
    add     rsp, 8      ;restore stack
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
    sub     rsp, 8      ;align stack by 16 bytes
    
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

    add     rsp, 8
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
    cmp     rcx, 0              ;while last digit is 0, decrement length
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
    sub     rsp, 8              ;align stack by 16 bytes

    mov     rax, [r8 + len]     ;length
    inc     rax                 ;length + 1
    mov     rsi, [r8 + digs]
    mov     rcx, [r8 + len]
    alloc_N_and_copy_M rax, rsi, rcx    ;allocate (length + 1) qwords and fill first (length)
                                        ;with old digits
    add     rsp, 8
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
    sub     rsp, 8      ;align stack by 16 bytes
    alloc_N_qwords 1    ;allocate 1 digit
    add     rsp, 8
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
    sub     rsp, 8      ;align stack by 16 bytes

    mov     rax, [r8 + len]
    inc     rax
    mov     rdx, [r8 + digs]
    mov     rcx, [r8 + len]
    alloc_N_and_copy_M rax, rdx, rcx    ;allocate (length + 1) digits and fill first (length) of them
                                        ;with old digits
    
    add     rsp, 8
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
    sub     rsp, 8      ;align stack by 16 bytes 
    call free           ;deallocate BigInt structure
    add     rsp, 8
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
    sub     rsp, 8      ;align stack by 16 bytes
    call    biDelete    ;deallocate memory for BigInt
    add     rsp, 8
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
    
    xor     rax, rax    ;remainder = 0
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

%macro printValue 1
    jmp     %%endstr
%%form:   db  "%llu ", 10, 0
%%endstr:
    push    r12
    mov     r12, %1
    call_printf %%form, r12
    pop     r12
%endmacro

;; Generate a decimal string representation from a BigInt.
;;  Writes at most limit bytes to buffer
; void biToString(BigInt bi, char *buffer, size_t limit);
;
;Parameters:
;   1) RDI - BigInt number to be printed
;   2) RSI - buffer where to store resulting representation
;   3) RDX - maximum number of chars to be printed
biToString:
    push    rbp                 ;save stack-frame
    mov     rbp, rsp            ;save RSP

                                ;create room on stack for representation
                                ;BASE is 2^64 => one digit less than 10^19 =>
                                ;32 * (length + 1) bytes will be enough for representation 
                                ;32 here is for stack alignment

    mov     rax, [rdi + len]    ;RAX = length
    inc     rax                 ;RAX = length + 1
    shl     rax, 5              ;RAX = 32 * (length + 1)
    sub     rsp, rax            ;RSP -= 32 * (length + 1)
    sub     rsp, 8              ;make stack unaligned for convenience

    push    rdi
    push    rsi
    push    rdx
    xor     rdi, rdi
    call    biFromInt   ;create copy of BigInt to divide it by 10 and print remainder every time
    mov     r8, rax
    pop     rdx
    pop     rsi
    pop     rdi

    mov     rcx, [rdi + len]        
    mov     [r8 + len], rcx         ;copy length
    mov     qword [r8 + sign], 1    ;sign is processed separately

    push    r8
    push    rdi
    push    rsi
    push    rdx
    sub     rsp, 8

    alloc_N_and_copy_M [rdi + len], [rdi + digs], [rdi + len]   ;copy digits
    mov     r9, rax

    add     rsp, 8
    pop     rdx
    pop     rsi
    pop     rdi
    pop     r8

    mov     [r8 + digs], r9     ;now R8 is a full copy of given BigInt

    mov     r10, rbp            ;r10 - where to store next digit
    xor     rcx, rcx            ;number of digits in decimal representation
.loop:  
    push    rdi
    push    rsi
    push    rdx
    push    rcx
    push    r8
    push    r10
    push    r10

    mov     rdi, r8
    mov     rsi, 10
    call    divLongShort        ;R8 /= 10
    mov     r9, rax             ;R9 = RAX = R8 % 10 =  rightmost decimal digit

    pop     r10
    pop     r10
    pop     r8
    pop     rcx
    pop     rdx
    pop     rsi                 ;RSI = buffer where to store resulting representation
    pop     rdi

    add     r9, '0'             ;get digit char
    mov     rax, r9             ;store digit in AL
    dec     r10                 ;shift room for next char
    mov     byte [r10], al      ;save next char
    inc     rcx                 ;one more digit placed

    mov     rax, [r8 + len]     ;if length == 0 => BigInt == 0 => done
    cmp     rax, 0
    jnz     .loop

    mov     rax, [rdi + sign]   ;RAX = signum   
    cmp     rax, (-1)           ;check if negative number
    jne     .loop_reverse

    cmp     rdx, 1              ;if limit <= 1 and number if negative => no possibility to print '-'
                                ;but only EOF sign
    jle     .loop_reverse

    mov     byte [rsi], '-'     ;print '-' as first char
    inc     rsi                 ;move buffer position
    dec     rdx                 ;RDX - holds limit

.loop_reverse:                  ;this loop will pop RCX digits from stack to get forward 
                                ;decimal representation of BigInt

    cmp     rcx, 0              ;if all digits popped => print EOF
    je      .print_eof

    xor     rax, rax
    mov     byte al, [r10]
    inc     r10             ;move to next char
    
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
    mov     rsp, rbp    ;restore stack
    pop     rbp         ;restore stack-frame
    ret


;Sums two non-empty vectors of digits as they were positive BigInts
;and returns resulting vector
;void * digsAdd(void * v1, void * v2, int n, int m)
;
;Parameters:
;   1) RDI - summand #1 vector
;   2) RSI - summand #2 vector
;   3) RDX - vector #1 length
;   4) RCX - vector #2 length
;Returns:
;   RAX - address of resulting vector
;   R9  - size of resulting vector
digsAdd:
    mov     rax, rdx
    cmp     rax, rcx    ;rax = rcx
    cmovl   rax, rcx    ;rax = max(rcx, rdx) = max(length_1, length_2)
    inc     rax         ;rax = max(length_1, length_2) + 1

    push    rdi
    push    rsi
    push    rdx
    push    rcx
    push    rax
    alloc_N_qwords rax  ;allocate max(length_1, length_2) + 1 qwords to hold result
    mov     r8, rax
    pop     rax
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi

    push    r12     ;save callee-saved register

    xor     r9, r9      ;"i"
    xor     r10, r10    ;carry
.loop:
    xor     r11, r11    ;current digit
    xor     r12, r12    ;new_carry
    cmp     r9, rdx     ;i < length_1 ???
    jge     .add_second 
    mov     r11, [rdi + r9 * 8] ;if (i < length_1) digit += a.digits[i]

.add_second:
    cmp     r9, rcx     ;i < length_2 ???
    jge     .add_carry
    add     r11, [rsi + r9 * 8] ;if (i < length_2) digit += b.digits[i]
    adc     r12, 0      ;r12 = new_carry (if a.digits[i] + b.digits[i] >= 2^64)

.add_carry:
    add     r11, r10    ;carry += old_carry
    adc     r12, 0      ;new_carry += 1 if overflow

    mov     [r8 + r9 * 8], r11 ;r11 holds current digit
    mov     r10, r12           ;carry = new_carry
    inc     r9                 ;move "i" to next digit
    cmp     r9, rax            ;if (i == RAX == max(length_1, length_2) + 1) => adding is done
    jne     .loop

.set_size:
    mov     r9, rax     ;r9 = max(length_1, length_2) + 1
    dec     r9          ;r9 = max(length_1, length_2)
    mov     r10, [r8 + rax * 8 - 8] ;r10 = most-significant digit (if carry of a.digits + b.digits != 0)
    cmp     r10, 0      ;if (last carry > 0)
    cmovg   r9, rax     ;then new_size += 1 (because last carry != 0)

.return:
    pop     r12         ;restore callee-saved register
    mov     rax, r8     ;resulting vector address
    ret

;Compares two vectors of digits (maybe of zero-length) as they were non-negative BigInts
;int compareDigs(void * v1, void * v2, int n, int m)
;
;Parameters:
;   1) RDI - vector of digits #1
;   2) RSI - vector of digits #2
;   3) RDX - length of vector #1
;   4) RCX - length of vector #2
;Returns:
;   RAX - sign of comparison v1 and v2 : -1, 0 or 1
compareDigs:
    cmp     rdx, rcx
    jne     .diff_lens  ;check if different lengths
    
    mov     r9, rdx     ;if length_1 == length_2 => compare one by one
.loop:
    cmp     r9, 0       ;if empty vectors => equals
    je      .equals
    dec     r9
    mov     rax, [rdi + r9 * 8]     ;load digits from most-significant to less-significant
    mov     r10, [rsi + r9 * 8]     ;and compare accordingly
    cmp     rax, r10
    ja      .first_gt
    jb      .second_gt
    jmp     .loop    

.diff_lens:
    cmp     rdx, rcx    ;if different length => compare length_1 and length_2
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

;Subs one non-empty vector of digits from another one as they were non-negative BigInts
;and returns resulting vector and sign of such subtracting
;
;;void digsSub(void * v1, void * v2, int n, int m)
;
;Parameters:
;   1) RDI - 1st vector
;   2) RSI - 2nd vector
;   3) RDX - length of 1st vector
;   4) RCX - length of 2nd vector
;Returns:
;   1) RAX - address of resulting vector
;   2) R9 - size of resulting vector
;   3) R10 - signum of subtracting (-1 or 1): (-1) if v1 < v2 and 1 otherwise
digsSub:
    push    rdi
    push    rsi
    push    rdx
    push    rcx
    sub     rsp, 8
    call compareDigs    ;get sign of comparison
    mov     r10, rax    ;r10 = sign of comparison
    add     rsp, 8
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi

    cmp     r10, 0      ;if r10 == 0 => equal vectors
    jne     .maybe_swap ;
    mov     r10, 1      ;if r10 > 0 => v1 > v2 => good order
    jmp     .make_sub

.maybe_swap:
    cmp     r10, (-1)   ;if r10 < 0 => swap vectors to get convenient order
    jne     .make_sub   ;(that is subtracting will be performed as (v1 - v2)
    xchg    rdi, rsi    ;swap vectors
    xchg    rdx, rcx    ;swap lengths

.make_sub:
    mov     rax, rdx
    cmp     rax, rcx
    cmovl   rax, rcx    ;rax = max(length_1, length_2)

    push    rdi
    push    rsi
    push    rdx
    push    rcx
    push    r10
    push    rax
    sub     rsp, 8
    alloc_N_qwords rax  ;allocate max(length_1, length_2) of qwords for resulting vector
    mov     r8, rax
    add     rsp, 8
    pop     rax
    pop     r10
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi

    push    r10     ;callee-saved registers
    push    r12

    xor     r9, r9      ;"i"
    xor     r10, r10    ;borrow
.loop:
    xor     r12, r12    ;new borrow

    mov     r11, [rdi + r9 * 8]     ;load v1.digit[i]
    cmp     r9, rcx                 ;i < length2 ???
    jge     .sub_borrow
    sub     r11, [rsi + r9 * 8]     ;if (i < length2) => r11 -= v2.digit[i]
    adc     r12, 0                  ;maybe borrow?
.sub_borrow:
    sub     r11, r10                ;r11 -= borrow (from previous step)
    adc     r12, 0                  ;r12 = new_borrow

    mov     [r8 + r9 * 8], r11      ;r11 = current digit
    mov     r10, r12
    inc     r9
    cmp     r9, rax                 ;move to next digits
    jne     .loop

    mov     r9, rax     ;r9 = max(length_1, length_2)
    mov     rax, r8     ;rax = address of resulting vector
    pop     r12         ;restore callee-saved registers
    pop     r10

    ret


;; dst += src
; void biAdd(BigInt dst, BigInt src);
;
;Parameters:
;   1) RDI - dst BigInt
;   2) RSI - src BigInt
biAdd:
    mov     rax, [rsi + len]    ;src length
    cmp     rax, 0
    jne     .src_not_zero       ;src == 0 => result == dst
    ret
.src_not_zero:
    mov     rax, [rdi + len]
    cmp     rax, 0
    jne     .dst_not_zero       ;if dst == 0 => result = src => copy BigInt

    push    rdi
    push    rsi
    sub     rsp, 8
    alloc_N_and_copy_M [rsi + len], [rsi + digs], [rsi + len] ;copy digits from SRC to DST
    add     rsp, 8
    pop     rsi
    pop     rdi
    
    mov     [rdi + digs], rax   ;copy length
    mov     rax, [rsi + len]
    mov     [rdi + len], rax
    mov     rax, [rsi + sign]   ;copy sign
    mov     [rdi + sign], rax
    ret

.dst_not_zero:
    mov     rax, [rdi + sign]   ;a.signum
    mov     rdx, [rsi + sign]   ;b.signum
    cmp     rax, rdx            ;if (a.signum == b.signum) => result.signum = a.signum
                                ;and result.digits = digsAdd(a.digits, b.digits)
    jne     .diff_signs

    push    rdi
    push    rsi
    sub     rsp, 8
    mov     rdx, [rdi + len]
    mov     rcx, [rsi + len]
    mov     rdi, [rdi + digs]
    mov     rsi, [rsi + digs]
    call    digsAdd             ;result.digits = digsAdd(a.digits, b.digits)
    add     rsp, 8
    pop     rsi
    pop     rdi

    push    rax
    push    r9
    push    rdi
    mov     rdi, [rdi + digs]   ;deallocate old digits of dst
    call    free 
    pop     rdi
    pop     r9
    pop     rax

    mov     [rdi + digs], rax   ;set new length
    mov     [rdi + len], r9     ;set new digits

    call    trimZeros           ;trim leading zeros
    ret

.diff_signs:                    ;a.signum != b.signum => we should do digsSub(a.digits, b.digits)
                                ;and set appropriate signum of result:
                                ;result.signum = a.signum * signum_of_digsSub(a.digits, b.digits)
    push    rdi
    push    rsi
    sub     rsp, 8
    mov     rdx, [rdi + len]
    mov     rcx, [rsi + len]
    mov     rdi, [rdi + digs]
    mov     rsi, [rsi + digs]
    call    digsSub             ;result.digits = digsSub(a.signum, b.signum)
    add     rsp, 8
    pop     rsi
    pop     rdi

    push    rax                 ;RAX = resulting digits
    push    r9                  ;R9 = resulting length
    push    r10                 ;R10 = signum of digsSub(a.digits, b.digits)
    push    rdi
    sub     rsp, 8
    mov     rdi, [rdi + digs]   ;deallocate old digits
    call    free 
    add     rsp, 8
    pop     rdi
    pop     r10
    pop     r9
    pop     rax

    mov     [rdi + digs], rax   ;set new digits
    mov     [rdi + len], r9     ;set new length
    mov     rcx, [rdi + sign]   
    imul    rcx, r10
    mov     [rdi + sign], rcx   ;result.signum = a.signum * R10

    sub     rsp, 8
    call trimZeros          ;trim leading zeros
    add     rsp, 8
    ret

;; Get sign of given BigInt.
; int biSign(BigInt bi);
;
;Parameters:
;   1) RDI - address of BigInt
;Returns:
;   RAX - sign (-1, 0 or 1)
biSign:
    mov     rcx, [rdi + len]    ;length == 0 => BigInt == 0
    cmp     rcx, 0
    je      .zero
    mov     rax, [rdi + sign]   ;get signum == -1 or 1
    ret
.zero:
    xor     rax, rax
    ret

;; dst -= src
; void biSub(BigInt dst, BigInt src);
;
;Parameters:
;   1) RDI - dst BigInt
;   2) RSI - src BigInt
biSub:
    mov     rax, [rsi + len]
    cmp     rax, 0
    jne     .src_not_zero       ;src == 0 => result == 0
    ret
.src_not_zero:
    mov     rax, [rsi + sign]   ;a - b = a + (-b)
    imul    rax, (-1)
    mov     [rsi + sign], rax   ;invert signum of src (-b)
    push    rax
    push    rsi
    sub     rsp, 8
    call    biAdd               ;a += (-b)
    add     rsp, 8
    pop     rsi
    pop     rax
    
    imul    rax, (-1)
    mov     [rsi + sign], rax   ;restore signum of src (b)
    ret

;; Compare two BigInts. Returns sign(a - b)
; int biCmp(BigInt a, BigInt b)
;
;Parameters:
;   1) RDI - 1-st BigInt
;   2) RSI - 2-nd BigInt
;Returns:
;   RAX - sign (-1, 0 or 1)
biCmp:
    mov     rax, [rdi + sign]   ;signum_1 (-1 or 1)
    mov     rcx, [rsi + sign]   ;signum_2 (-1 or 1)
    cmp     rax, rcx
    jne     .diff_signs         ;signum_1 == signum_2 ???

    push    rax
    mov     rdx, [rdi + len]
    mov     rcx, [rsi + len]
    mov     rdi, [rdi + digs]
    mov     rsi, [rsi + digs]
    call    compareDigs         ;compare a.digits and b.digits
    mov     r8, rax             ;R8 = result of comparison a.digits and b.digits
    pop     rax

    cmp     r8, 0           ;signum_1 == signum_2 && a.digits == b.digits => result = 0
    je      .equals
    imul    rax, r8         ;a.digits != b.digits => result == (signum_1 * comparison)
    ret

.diff_signs:                ;signum_1 == (1 or -1) and signum_2 == -signum_1
    cmp     rax, 1      
    je      .first_gt       ;signum_1 = 1 && signum_2 == -1 => result = 1
    jmp     .second_gt      ;signum_1 = 1 && signum_2 == -1 => result = -1

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
;   3) RDX - length of #1 BigInt
;   4) RCX - length of #2 BigInt
;Returns:
;   1) RAX - address of resulting vector
;   2) R9 - length of resulting vector
digsMul:
    mov     rax, rdx    ;RAX = length of result
    add     rax, rcx    ;RAX = (length_1 + length_2)

    push    rdi
    push    rsi
    push    rdx
    push    rcx
    sub     rsp, 8
    alloc_N_qwords rax  ;allocate (length_1 + length_2) qwords for result
    mov     r8, rax
    add     rsp, 8
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi

    push    r12         ;callee-saved registers
    push    r13
    mov     r11, rcx    ;r11 == length_2
    mov     r12, rdx    ;r12 == length_1

    xor     r9, r9      ;"i"
.loop_outer:
    xor     r10, r10    ;"j"
    xor     r13, r13    ;old_carry

.loop_inner:
    xor     rdx, rdx    ;(RDX:RAX) holds carry
    mov     rax, r13    ;carry = old_carry
    cmp     r10, r11    ;j < length_2 ???
    jge     .add_to_ans
    mov     rax, [rsi + r10 * 8]    ;RAX = b.digits[j] 
    mov     rcx, [rdi + r9 * 8]     ;RCX = a.digits[i]
    mul     rcx                     ;carry = a.digits[i] * b.digits[j]
    add     rax, r13                ;
    adc     rdx, 0                  ;carry += old_carry

.add_to_ans:
    mov     rcx, r9     ;rcx = "i"
    add     rcx, r10    ;rcx = "i" + "j"
    add     rax, [r8 + rcx * 8]     ;
    adc     rdx, 0                  ;carry += result.digits[i + j]
    mov     [r8 + rcx * 8], rax     ;result.digits[i + j] = carry & (2^64 - 1)
    mov     r13, rdx                ;next_carry = carry

    inc     r10         ;"j"++
    cmp     r10, r11    ;
    jl      .loop_inner ;j < length2 => continue inner_loop
    cmp     r13, 0
    jne     .loop_inner ;carry != 0 => continue inner_loop

    inc     r9          ;"i"++
    cmp     r9, r12     ;
    jne     .loop_outer ;i < length_1 => continue outer_loop

    mov     r9, r11     
    add     r9, r12     ;r9 = length_1 + length_2
    mov     rax, r8     ;rax = address of resulting vector

    pop     r13
    pop     r12
    ret

;; dst *= src
; void biMul(BigInt dst, BigInt src)
;
;Parameters:
;   1) RDI - dst BigInt
;   2) RSI - src BigInt
biMul:
    mov     rax, [rdi + len]
    cmp     rax, 0
    jnz     .dst_not_zero   ;dst == 0 => result == 0
    ret
.dst_not_zero:
    mov     rax, [rsi + len]
    cmp     rax, 0
    jnz     .src_not_zero   ;src == 0 => result == 0 => emptify dst

    push    rdi
    mov     rdi, [rdi + digs]   ;deallocate dst digits
    call    free
    pop     rdi

    mov     qword [rdi + digs], 0   ;set BigInt to 0
    mov     qword [rdi + sign], 1
    mov     qword [rdi + len], 0
    ret

.src_not_zero:
    push    rdi
    push    rsi
    sub     rsp, 8

    mov     rdx, [rdi + len]
    mov     rcx, [rsi + len]
    mov     rdi, [rdi + digs]
    mov     rsi, [rsi + digs]
    call    digsMul             ;multiply dst.digits * src.digits

    add     rsp, 8
    pop     rsi
    pop     rdi

    push    rax                 ;RAX - address of resulting vector
    push    r9                  ;R9 - size of resulting vector
    push    rdi
    push    rsi
    sub     rsp, 8
    mov     rdi, [rdi + digs]
    call    free                ;deallocate old digits
    add     rsp, 8
    pop     rsi
    pop     rdi
    pop     r9
    pop     rax

    mov     [rdi + digs], rax   ;set new digits
    mov     [rdi + len], r9     ;set new length

    mov     rax, [rdi + sign]
    mov     rcx, [rsi + sign]   ;result.signum = a.signum * b.signum
    imul    rax, rcx
    mov     [rdi + sign], rax

    push    rdi
    call    trimZeros           ;trim leading zeros
    pop     rdi

    ret

;While I was writing the division I realized that saving over 9000 registers before
;every function call is painful, so further I will use such convenient macros:
;NOTE: they don't save RAX, because RAX is used to push result through these macros

;totally 13 regs are pushed, so alignment changes from 8 to 16 and counterwise
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


;Shifts all digits of given BigInt left by 1 position
;So it's equivalent to dst *= 2^64
;void shiftLeft(BigInt dst)
;
;Parameters:
;   1) RDI - address of BigInt to be shifted one digit left
shiftLeft:
    mov     rax, [rdi + len]
    cmp     rax, 0
    jne     .not_zero   ;dst == 0 => result == 0
    ret
.not_zero:
    mov     rax, [rdi + len]
    inc     rax                 ;rax = old_length + 1
    push_all_regs
    alloc_N_qwords rax          ;allocate (old_length + 1) qwords for result
    pop_all_regs
    mov     r8, rax

    mov     rsi, [rdi + digs]   ;RSI - old digits position
    mov     rcx, [rdi + len]    ;RCX = old_length
    mov     r9, r8              ;R9 - new digits position
    add     r9, 8               ;move R9 to second right away
.loop:
    cmp     rcx, 0
    je      .endloop            ;simply copy [i] to [i+1]
    dec     rcx
    mov     rax, [rsi]
    mov     [r9], rax
    add     rsi, 8
    add     r9, 8
    jmp     .loop 
.endloop:
    
    push_all_regs
    mov     rdi, [rdi + digs]   ;deallocate old digits
    call    free
    pop_all_regs

    mov     [rdi + digs], r8    ;set new digits
    mov     rax, [rdi + len]    ;set new length 
    inc     rax
    mov     [rdi + len], rax
    ret

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


;Takes two BigInt and returns quotient of division 
;1st of them by 2nd one. Initial BigInts are not affected.
;Quotient's signum is set appropriately.
;
;BigInt getQuotient(BigInt numerator, BigInt denominator)
;
;Parameters:
;   1) RDI - numerator BigInt
;   2) RSI - denominator BigInt
;Returns:
;   RAX - address of resultion quotient BigInt
getQuotient:
    push_all_regs   ;save all registers, including callee-saved ones
    sub     rsp, 8  ;make stack unaligned for future convenience

    mov     rax, [rdi + sign]
    mov     r15, [rsi + sign]   ;R15 holds signum of resulting quotient
    imul    r15, rax            ;R15 = numerator.signum * denominator.signum
                                ;if (R15 < 0 and numerator % denominator != 0)
                                ;then resulting quotient will be decremented by 1

    mov     rdx, [rdi + len]    ;numerator length
    mov     rcx, [rsi + len]    ;denominator length
    mov     rdi, [rdi + digs]   ;RDI = numerator digits
    mov     rsi, [rsi + digs]   ;RSI = denominator digits

    push_all_regs
    alloc_N_and_copy_M rdx, rdi, rdx    ;copy numerator digits
    pop_all_regs
    mov     rdi, rax

    push_all_regs
    alloc_N_and_copy_M rcx, rsi, rcx    ;copy denominator digits
    pop_all_regs
    mov     rsi, rax

                                        ;let's denote D as copy of denominator
                                        ;let's denote N as copy of numerator

    push_all_regs
    xor     rdi, rdi
    call    biFromInt                   ;create copy of numerator
    pop_all_regs
    mov     r10, rax                    ;R10 = N
    mov     [r10 + digs], rdi
    mov     [r10 + len], rdx
    mov     qword [r10 + sign], 1

    push_all_regs
    xor     rdi, rdi
    call    biFromInt                   ;create copy of denominator
    pop_all_regs
    mov     r11, rax                    ;R11 = D
    mov     [r11 + digs], rsi
    mov     [r11 + len], rcx
    mov     qword [r11 + sign], 1

                                        ;R9 will be normalization, where
                                        ;normalization = BASE / (den.digits[den.length-1] + 1)
                                        ;normalization is needed to make high digit of
                                        ;denominator >= BASE / 2

    mov     r9, [rsi + rcx * 8 - 8]     ;R9 = denominator.digits.back()
    inc     r9                          ;R9 += 1
    cmp     r9, 0                       ;if (r9 == 0) => overflow => normalization == 1
    jne     .norm_take                 
    mov     r9, 1
    jmp     .norm_got 

.norm_take:
    push    rdx         
    mov     rdx, 1
    mov     rax, 0      ;RDX:RAX = BASE = 2^64
    div     r9          ;RDX:RAX = 2 ^ 64 / (b.digits[size - 1] + 1)
    mov     r9, rax     ;R9 = normalization
    pop     rdx

.norm_got:
    push_all_regs
    mov     rdi, r10
    mov     rsi, r9
    call    mulLongShort    ;N *= normalization
    pop_all_regs

    push_all_regs
    mov     rdi, r11
    mov     rsi, r9
    call    mulLongShort    ;D *= normalization
    pop_all_regs

    mov     rdi, [r10 + digs]   ;RDI = N.digits
    mov     rdx, [r10 + len]    ;RDX = N.length
    mov     rsi, [r11 + digs]   ;RSI = D.digits
    mov     rcx, [r11 + len]    ;RCX = D.length

    push_all_regs
    alloc_N_qwords rdx          ;allocate N.digits qwords for result
    pop_all_regs
    mov     r8, rax

    push_all_regs
    xor     rdi, rdi
    call    biFromInt           ;create BigInt R(remainder): R = 0
    pop_all_regs
    mov     r9, rax

    push_all_regs
    xor     rdi, rdi
    call    biFromInt           ;create BigInt T(temp): T = 0
    pop_all_regs
    mov     r12, rax

    mov     r13, rdx            ;R13 = "i" = N.length 
.loop:
    cmp     r13, 0
    je      .endloop            ;for "i" = N.length - 1; "i" >= 0; i--
    dec     r13

    push_all_regs
    mov     rdi, r9
    call    shiftLeft               ;R *= BASE
    pop_all_regs

    mov     rax, [rdi + r13 * 8]     
    push_all_regs
    mov     rdi, r9
    mov     rsi, rax
    call    addLongShort            ;R += N.digits["i"]
    pop_all_regs

    push_all_regs                   ;save registers for arithmetic magic
    mov     rdx, [r10 + len]        ;update N.length
    mov     rcx, [r11 + len]        ;update D.length

    mov     r14, [r11 + digs]
    mov     r14, [r14 + rcx * 8 - 8] ;R14 = D.digits[D.length - 1], that is last digit of D

    xor     r10, r10                ;R10 = s1
    mov     r12, rcx                ;R12 = D.length
    mov     r8, [r9 + len]          ;R8 = R.length
    cmp     r12, r8                 ;D.length < R.length ???
    jge     .s1_set
    
    mov     r10, [r9 + digs]
    mov     r10, [r10 + r12 * 8]    ;D.length < R.length => s1 = R.digits[D.length]

    .s1_set:
    xor     r11, r11                ;R11 = s2
    mov     r12, rcx                ;R12 = D.length
    dec     r12                     ;R12 = D.length - 1
    mov     r8, [r9 + len]          ;R8 = R.length
    cmp     r12, r8                 ;D.length - 1 < R.length ???
    jge     .s2_set

    mov     r11, [r9 + digs]
    mov     r11, [r11 + r12 * 8]    ;D.length - 1 < R.length => s2 = R.digits[D.length - 1]

    .s2_set:

                                    ;Next digit(Dig) will be 
                                    ;Dig = (s1 * 2^64 + s2) / R14,
                                    ;where R14 = last_digit
    
    mov     rdx, r10        ;RDX=(s1)
    mov     rax, r11        ;RAX=(s2)
                            ;RDX:RAX = s1:s2
                            ;R14 = (RDX:RAX) / D.last

    cmp     rdx, r14
    jae     .overflow       ;RDX >= R14 => overflow => R14 = digit = 2^64 - 1
    div     r14 
    jmp     .got_digit

.overflow:
    mov     rax, (-1)       ;RAX = 0x111...111

.got_digit:    
                                    ;RAX - current digit, pass it through pop_all_regs
    pop_all_regs                    ;Restore all registers
                                    ;R10 = N(copy of numerator), 
                                    ;R11 = D(copy of denominator), 
                                    ;R9 = R(remainder), 
                                    ;R12 = T(temp)
    mov     r14, rax

    push_all_regs
    mov     rdi, [r12 + digs]       
    call    free                    ;deallocate digits of T (temp)
    pop_all_regs

    push_all_regs
    alloc_N_and_copy_M [r11 + len], [r11 + digs], [r11 + len] 
    pop_all_regs
    mov     [r12 + digs], rax       ;now T(temp) = D
    mov     [r12 + len], rcx
    mov     qword [r12 + sign], 1

    push_all_regs
    mov     rdi, r12
    mov     rsi, r14
    call    mulLongShort            ;T *= Dig
    pop_all_regs

    push_all_regs
    mov     rdi, r9
    mov     rsi, r12                ;R(remainder) -= T(temp)
    call    biSub
    pop_all_regs

    .while_neg_loop:                ;while (R < 0) {
                                    ;   R += D 
                                    ;   Dig--
                                    ;}
        mov     rax, [r9 + sign]
        cmp     rax, 1
        je      .end_while_neg_loop
        
        push_all_regs
        mov     rdi, r9         ;RDI = R(remainder)
        mov     rsi, r11        ;RSI = D(denominator)
        call    biAdd           ;R += D
        pop_all_regs
        
        dec     r14             ;Dig--
        jmp     .while_neg_loop
    .end_while_neg_loop:

    mov     [r8 + r13 * 8], r14 ;Move current digit to answer
    jmp     .loop

.endloop:
    push_all_regs
    xor     rdi, rdi
    call    biFromInt           ;create resulting BigInt
    pop_all_regs
    mov     r14, rax

    mov     [r14 + digs], r8        ;set resulting vector
    mov     [r14 + len], rdx        ;set resulting length
    mov     qword [r14 + sign], 1   ;sign is '+' yet...

    push_all_regs
    mov     rdi, r14
    call    trimZeros               ;trim leading zeros
    pop_all_regs

    cmp     r15, 1                  ;if (result.signum == '+') => signum is correct already
    je      .sign_set

    xor     rcx, rcx
    mov     rax, [r9 + len]         ;check if R(remainder) != 0
    cmp     rax, 0  
    je      .flag_set
    mov     rcx, 1                  ;R(remainder) != 0 => we should decrement quotient by 1

.flag_set:

    push_all_regs
    mov     rdi, r14
    mov     rsi, rcx                ;RCX = 0 if (numerator % denominator == 0) and 1 otherwise
    call    addLongShort            ;calibrate quotient
    pop_all_regs

    mov     qword [r14 + sign], (-1)    ;set quotient's sign to '-'

.sign_set:
    push_all_regs
    mov     rdi, r9         ;delete R(remainder) BigInt
    call    biDelete
    pop_all_regs

    push_all_regs
    mov     rdi, r10        ;delete N(copy of numerator) BigInt
    call    biDelete
    pop_all_regs

    push_all_regs
    mov     rdi, r11        ;delete D(copy of denominator) BigInt
    call    biDelete
    pop_all_regs

    push_all_regs
    mov     rdi, r12        ;delete T(temp) BigInt
    call    biDelete
    pop_all_regs

    mov     rax, r14

    add     rsp, 8      ;restore stack
    pop_all_regs        ;restore callee-saved registers
    ret

;obvious
;BigInt copyBigInt(BigInt bi)
;
;Parameters:
;   1) RDI - BigInt to be copied
;Returns:
;   RAX - copy of given BigInt
copyBigInt:
    push_all_regs
    alloc_N_and_copy_M [rdi + len], [rdi + digs], [rdi + len]   ;allocate copy of digits
    pop_all_regs
    mov     r8, rax

    push_all_regs
    xor     rdi, rdi
    call    biFromInt   ;create resulting BigInt
    pop_all_regs
    mov     r9, rax

    mov     [r9 + digs], r8     ;set fields
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
;   4) RCX - denominfator BigInt
biDivRem:
    push    rdi         ;save address-holder of quotient
    push    rsi         ;save address-holder of remainder
    mov     rdi, rdx    ;RDI = numerator 
    mov     rsi, rcx    ;RSI = denominator
    
    mov     rax, [rsi + len]    ;denominator == 0 ???
    cmp     rax, 0
    jne     .denom_not_zero

    pop     rsi
    pop     rdi
    mov     qword [rdi], 0      ;denominator == 0 => quotient = remainder = NULL
    mov     qword [rsi], 0
    ret

.denom_not_zero:
    mov     rax, [rdi + len]    ;numerator == 0 ???   
    cmp     rax, 0
    jne     .numer_not_zero
                                ;numerator == 0 => quotient = remainder = 0
    xor     rdi, rdi
    sub     rsp, 8
    call    biFromInt           ;allocate BigInt 0
    add     rsp, 8
    pop     rsi
    mov     [rsi], rax

    xor     rdi, rdi
    call    biFromInt           ;allocate BigInt 0
    pop     rdi
    mov     [rdi], rax
    ret

.numer_not_zero:
    push_all_regs
    call    getQuotient
    pop_all_regs
    mov     r8, rax             ;R8 = quotient of division

                                ;calculate R(remainder) as 
                                ;R = numerator - quotient * denominator

    push_all_regs
    mov     rdi, r8
    call    copyBigInt          ;R9 = Q (quotient)
    pop_all_regs
    mov     r9, rax

    push_all_regs
    mov     rdi, r9             ;R9 *= D (denominator)
    call    biMul
    pop_all_regs

    mov     rax, [r9 + sign]    ;R9 = -R9 = -Q * D
    imul    rax, (-1)
    mov     [r9 + sign], rax

    push_all_regs
    mov     rsi, rdi 
    mov     rdi, r9
    call    biAdd               ;R9 = N + (-Q * D) = N - Q * D = R
    pop_all_regs

    pop     rsi                 ;restore address-holders
    pop     rdi

    mov     [rdi], r8           ;write resulting quotient address
    mov     [rsi], r9           ;write resulting remainder address
.return:
    ret