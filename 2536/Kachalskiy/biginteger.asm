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

;BigInt stored as a structure
;BigInt scale is 2^64, all digits are unsigned 64-bit
;
;Fields:
;   1) len - number of periods in BigInt
;   2) sign - sign(BigInt) = {-1,+1}
;   3) digs - points at stored digits
;BigInt is 0 if len == 0 & sign == 1
;
;Note: len is not necessarily matches real amount of allocated qwords,
;digs may be pointed to more wide area of memory,
;but this memory will still be deallocated via biDelete invocation

    struc BigInt_t
len:    resq    1
sign:   resq    1
digs:   resq    1
    endstruc

;Creation of BigInt from 64-bit signed integer.
;
;Parameters:
;   rdi - 64-bit signed integer
;Returns:
;   rax - address of allocated BigInt
biFromInt: 
    push    rdi 

    mov     rdi, 1              ;Memory allocation for BigInt
    mov     rsi, BigInt_t_size
    call    calloc
    mov     rdx, rax            ;address of allocated BigInt

    pop     rdi

    mov     qword [rdx + sign], 1   ;filling fields
    mov     qword [rdx + len], 0
    mov     qword [rdx + digs], 0

    cmp     rdi, 0      ;if number = 0 then finished.
    je      .return		
    jg      .fill_digs  ;if number > 0

    mov     qword [rdx + sign], (-1)  ;if number < 0
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

    mov     [rax], rdi           ;store given 64-bit int in memory
    mov     [rdx + digs], rax    ;save digit address
    mov     qword [rdx + len], 1 ;set length to 1

.return:
    mov     rax, rdx    ;return address of BigInt

    ret

;Way to copy BigInt
;
;;void* alloc_N_and_copy_M(int n, void * src, int m)
;Parameters:
;   1) n - number of bytes to be allocated
;   2) src - source from where copy should be done
;   3) m - number of copying bytes
;Returns:
;   rax - address of allocated and filled memory
%macro alloc_N_and_copy_M 3
    push    r12
    push    r13
    push    r14
    sub     rsp, 8      ;align stack by 16 bytes
    
    mov     r12, %1     ;move parameters to safe registers
    mov     r13, %2
    mov     r14, %3

    mov     rdi, r12    ;n
    mov     rsi, 8      ;size of qword
    call    calloc

    mov     rdi, rax    ;rdi - destination
    mov     rsi, r13    ;rsi - source
    mov     rcx, r14    ;rcx - m qwords to be copied
    cld                 ;clear direction flag_set
    repnz   movsq       ;copy m qwords

    add     rsp, 8
    pop     r14
    pop     r13
    pop     r12
%endmacro

;Trims digits of BigInt while the last digit equals 0
;this method is used after every operation to store correct len and sign
;
;;void trimZeros(BigInt bi)
;Parameters:
;   1) rdi - BigInt
trimZeros:
    mov     rcx, [rdi + len]    ;rcx = length
    mov     rsi, [rdi + digs]   ;rsi = digits
.loop:
    cmp     rcx, 0              ;while last digit is 0, length-
    je      .endloop
    mov     rax, [rsi + rcx * 8 - 8]    ;store last digit
    cmp     rax, 0  
    jne     .endloop 
    dec     rcx
    jmp     .loop

.endloop:
    mov     rdx, [rdi + len]    ;rdx = old_length
    cmp     rcx, rdx            ;if (new_length = old_length)
    je      .return             ;then return
    xor     rax, rax            ;else deallocat old digits
    cmp     rcx, 0              
    je      .dealloc_old        ;if (new_length = 0) 
								;then deallocate without allocating new digits
    push    rdi
    push    rsi
    push    rcx
    alloc_N_and_copy_M rcx, rsi, rcx    ;allocate rcx qwords and fill them with old qwords
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
    mov     [rdi + digs], rax   ;set allocated digits

    cmp     rcx, 0
    jne     .return
    mov     qword [rdi + sign], 1   ;if (new_length = 0) 
									;then BigInt = 0

.return:
    ret

;Allocate qwords
;;void * alloc_N_qwords(int n)
;
;Parameters:
;   1) n - number of qwords to be allocated
;Returns:
;   rax - address of allocated memory
%macro alloc_N_qwords 1
    push    rdi
    push    rsi
    mov     rdi, %1
    mov     rsi, 8
    call    calloc
    pop     rsi
    pop     rdi
%endmacro

;Multiplies BigInt and unsigned_int64_t
;
;;void mulLongShort(BigInt bi, unsigned_int64_t x)
;
;Parameters
;   1) rdi - BigInt to be multiplied
;   2) rsi - multiplier
mulLongShort:
    mov     r8, rdi             
    mov     rdi, [r8 + digs]    ;rdi = digits
    mov     rcx, [r8 + len]     ;rcx = length

    cmp     rcx, 0
    je      .return             ;length = 0 means that result = 0
    
    cmp     rsi, 0              ;multiplier = 0 means that result = 0
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
    mov     rax, [rdi]  ;rax = digits[i]
    mul     rsi         ;rdx:rax = digits[i] * x
    add     rax, r9     
    adc     rdx, 0      ;digits[i] * x + carry
    mov     [rdi], rax  ;rax = result[i]
    add     rdi, 8      ;move rdi to next digit
    mov     r9, rdx     ;r9 = new_carry

    dec     rcx         ;go to next digit
    jnz     .loop

.endloop:
    cmp     r9, 0
    je      .return     ;if (carry = 0)
						;then return
                        ;else increase length of BigInt by 1
                        ;and place carry as biggest digit
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
    mov     rax, [r8 + len]     ;rax = old_length + 1
    inc     rax
    mov     [r8 + len], rax     ;set new_length
    mov     rdi, [r8 + digs]
    mov     [rdi + rax * 8 - 8], r9 ;store carry as most-significant digit

.return:
    ret


;Adds unsigned_int64_t to BigInt
;
;;void addLongShort(BigInt bi, unsigned_int64_t x)
;
;Parameters:
;   1) rdi - BigInt
;   2) rsi - value to be added
addLongShort: 
    mov     r8, rdi
    mov     rdi, [r8 + digs]    ;rdi = digits
    mov     rcx, [r8 + len]     ;rcx = length

    cmp     rcx, 0      ;if length = 0 then result == x
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
    add     [rdi], rsi  ;digits[i] += old_carry
    adc     rdx, 0      ;new_carry += (digits[i] + old_carry) % (2^64)
    mov     rsi, rdx    ;rsi = new_carry
    xor     rdx, rdx    
    add     rdi, 8      ;move to next digit
    dec     rcx
    jnz     .loop

.endloop:
    cmp     rsi, 0      ;if (carry != 0) after adding 
						;then allocate 1 more digit for carry
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

;Удаляет ранее созданное число
;
;;void biDelete(BigInt bi)
;
;Parameters:
;   1) rdi - BigInt to be deleted
biDelete:
    cmp     rdi, 0      ;if (rdi = NULL)
						;then nothing to delete
    je      .done
    mov     rsi, [rdi + digs] 
    cmp     rsi, 0              ;if (digits = NULL) 
								;then BigInt = 0
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

;Create a BigInt from a string with decimal number representation.
;Return NULL if string is incorrect.
;
;;BigInt biFromString(char const *s)
;
;Parameters:
;   rdi - address of string
;Returns:
;   rax - address of allocated BigInt or NULL on incorrect string
biFromString:
    push    rdi
    xor     rdi, rdi
    call    biFromInt   ;create BigInt = 0
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
    cmp     al, 0           ;if (end of string)
    je      .endloop		;then return
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
    cmp     rcx, 0      ;if (rcx = 0)
    jne     .return		;then string is incorrect

.incorrect:
    mov     rdi, r8
    sub     rsp, 8      ;align stack by 16 bytes
    call    biDelete    ;deallocate memory for BigInt
    add     rsp, 8
    xor     rax, rax    ;result = NULL
    ret

.return:
    mov     rax, r8
    mov     [rax + sign], r9 ;set sign
    push    rax
    mov     rdi, rax
    call    trimZeros   ;trim BigInt of leading zeros
    pop     rax

    ret

;Divides BigInt by unsigned_int64_t and returns result (or -1 if incorrect operation)
;
;;unsigned_int64_t divLongShort(BigInt bi, unsigned_int64_t number)
;
;Parameters:
;   1) rdi - BigInt to be divided
;   2) rsi - unsigned_int64_t divisor
;Returns:
;   rax - remainder of division
divLongShort:
    mov     r8, rdi
    mov     rdi, [r8 + digs]    ;rdi = digits
    mov     rcx, [r8 + len]     ;rcx = length

    cmp     rsi, 0      ;if (divisor = 0)
    je      .incorrect	;then error
    
    xor     rax, rax    ;remainder = 0
    cmp     rcx, 0      ;if (length = 0)
    je      .return		;then result =0

    xor     rdx, rdx    ;(rdx:rax) will hold carry
.loop:
    mov     rdx, rax                    ;carry << 64
    mov     rax, [rdi + rcx * 8 - 8]    ;carry += next digit
    div     rsi                         ;(rdx:rax) /= rsi
    mov     [rdi + rcx * 8 - 8], rax    ;rax is next resulting digit
    mov     rax, rdx                    ;rdx is next carry 
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

; Generate a string with decimal representation from BigInt.
; Writes at most limit bytes to buffer
;
;; void biToString(BigInt bi, char *buffer, size_t limit);
;
;Parameters:
;   1) rdi - BigInt to be printed
;   2) rsi - buffer where resulting representation stored
;   3) rdx - maximum number of chars to print
biToString:
    push    rbp                 ;save stack-frame
    mov     rbp, rsp            ;save RSP

                                ;create room on stack for representation
                                ;base is 2^64 so one digit less than 10^19
                                ;32 * (length + 1) bytes will be enough for representation 
                                ;32 here is for stack alignment

    mov     rax, [rdi + len]    ;rax = length
    inc     rax                 ;rax = length + 1
    shl     rax, 5              ;rax = 32 * (length + 1)
    sub     rsp, rax            ;rsp -= 32 * (length + 1)
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

    mov     [r8 + digs], r9     ;now r8 is a full copy of BigInt

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
    call    divLongShort        ;r8 /= 10
    mov     r9, rax             ;r9 = rax = r8 % 10 =  rightmost decimal digit

    pop     r10
    pop     r10
    pop     r8
    pop     rcx
    pop     rdx
    pop     rsi                 ;rsi = buffer to store result
    pop     rdi

    add     r9, '0'             ;get digit char
    mov     rax, r9             ;store digit in AL
    dec     r10                 ;shift room for next char
    mov     byte [r10], al      ;save next char
    inc     rcx                 ;one more digit placed

    mov     rax, [r8 + len]     ;if (length = 0)
    cmp     rax, 0				;then return
    jnz     .loop

    mov     rax, [rdi + sign]   ;rax = sign   
    cmp     rax, (-1)
    jne     .loop_reverse

    cmp     rdx, 1              ;if (limit <= 1) and (number is negative)
								;can't to print '-'
                                ;but only EOF sign
    jle     .loop_reverse

    mov     byte [rsi], '-'     ;print '-' as first char
    inc     rsi                 ;move buffer position
    dec     rdx                 ;rdx - holds limit

.loop_reverse:                  ;this loop will pop rcx digits from stack to get forward 
                                ;decimal representation of BigInt

    cmp     rcx, 0              ;if (all digits popped)
    je      .print_eof			;then print EOF

    xor     rax, rax
    mov     byte al, [r10]
    inc     r10             ;move to next char
    
    dec     rcx

    cmp     rdx, 0          ;if (limit = 0)
    je      .loop_reverse 	;then pop remaining chars

    cmp     rdx, 1          ;if (limit = 1)
    jg      .print_symbol	;then print EOF

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


;Sums two non-empty vectors of digits
;
;;void * digsAdd(void * v1, void * v2, int n, int m)
;
;Parameters:
;   1) rdi - first vector
;   2) rsi - second vector
;   3) rdx - first vector length
;   4) rcx - second vector length
;Returns:
;   rax - address of resulting vector
;   r9  - size of resulting vector
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
    cmp     r9, rdx     ;i < length_1
    jge     .add_second 
    mov     r11, [rdi + r9 * 8] ;if (i < length_1) digit += a.digits[i]

.add_second:
    cmp     r9, rcx     ;i < length_2
    jge     .add_carry
    add     r11, [rsi + r9 * 8] ;if (i < length_2)  then digit += b.digits[i]
    adc     r12, 0      ;r12 = new_carry (if (a.digits[i] + b.digits[i]) >= 2^64)

.add_carry:
    add     r11, r10    ;carry += old_carry
    adc     r12, 0      ;new_carry += 1 if overflow

    mov     [r8 + r9 * 8], r11 ;r11 holds current digit
    mov     r10, r12           ;carry = new_carry
    inc     r9                 ;move "i" to next digit
    cmp     r9, rax            ;if (i == rax == max(length_1, length_2) + 1)
    jne     .loop			   ;then return

.set_size:
    mov     r9, rax     ;r9 = max(length_1, length_2) + 1
    dec     r9          ;r9 = max(length_1, length_2)
    mov     r10, [r8 + rax * 8 - 8] ;r10 = biggest digit
    cmp     r10, 0      ;if (last carry > 0)
    cmovg   r9, rax     ;then new_size += 1

.return:
    pop     r12         ;restore callee-saved register
    mov     rax, r8     ;resulting vector address
    ret

;Compares two vectors of digits
;
;;int compareDigs(void * v1, void * v2, int n, int m)
;
;Parameters:
;   1) rdi - first vector
;   2) rsi - second vector
;   3) rdx - first vector length
;   4) rcx - second vector length
;Returns:
;   rax - sign of comparison : -1, 0 or 1
compareDigs:
    cmp     rdx, rcx
    jne     .diff_lens  ;check ratio between length_1 and length_2
    
    mov     r9, rdx     ;if (length_1 = length_2) then compare one by one
.loop:
    cmp     r9, 0       ;if (vectors are empty)
    je      .equals		;then vectors are equal
    dec     r9
    mov     rax, [rdi + r9 * 8]     ;load digits from biggest to smallest
    mov     r10, [rsi + r9 * 8]     ;and compare
    cmp     rax, r10
    ja      .first_gt
    jb      .second_gt
    jmp     .loop    

.diff_lens:
    cmp     rdx, rcx    ;if (length_1 != length_2)
    jg      .first_gt	;then compare length_1 and length_2
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

;Subs one non-empty vector of digits from another one
;and returns resulting vector and sign of such subtracting
;
;;void digsSub(void * v1, void * v2, int n, int m)
;
;Parameters:
;   1) rdi - first vector
;   2) rsi - second vector
;   3) rdx - first vector length
;   4) rcx - second vector length
;Returns:
;   1) rax - address of resulting vector
;   2) r9 - size of resulting vector
;   3) r10 - signum of subtracting (-1 or 1): (-1) if v1 < v2 otherwise 1
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

    cmp     r10, 0      ;if (r10 = 0) 
    jne     .maybe_swap ;then vectors are equal
    mov     r10, 1      ;if (r10 > 0)
    jmp     .make_sub	;then v1 > v2, proceed to sub

.maybe_swap:
    cmp     r10, (-1)   ;if (r10 < 0)
    jne     .make_sub	;then swap vectors to correct order
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
    cmp     r9, rcx                 ;i < length2
    jge     .sub_borrow
    sub     r11, [rsi + r9 * 8]     ;if (i < length2) then r11 -= v2.digit[i]
    adc     r12, 0
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


;Сложение. К dst прибавляется src, результат помещается в dst.
;
;;void biAdd(BigInt dst, BigInt src);
;
;Parameters:
;   1) rdi - dst BigInt
;   2) rsi - src BigInt
biAdd:
    mov     rax, [rsi + len]    ;src length
    cmp     rax, 0
    jne     .src_not_zero       ;if (src = 0) then result = dst
    ret
.src_not_zero:
    mov     rax, [rdi + len]
    cmp     rax, 0
    jne     .dst_not_zero       ;if (dst = 0) then result = src

    push    rdi
    push    rsi
    sub     rsp, 8
    alloc_N_and_copy_M [rsi + len], [rsi + digs], [rsi + len] ;copy digits from src to dst
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
    cmp     rax, rdx            ;if (a.signum == b.signum)
								;then result.signum = a.signum
                                ;result.digits = digsAdd(a.digits, b.digits)
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

.diff_signs:                    ;if (a.signum != b.signum)
								;then do digsSub(a.digits, b.digits)
                                ;set appropriate signum of result:
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

    push    rax                 ;rax = resulting digits
    push    r9                  ;r9 = resulting length
    push    r10                 ;r10 = signum of digsSub(a.digits, b.digits)
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
    mov     [rdi + sign], rcx   ;result.signum = a.signum * r10

    sub     rsp, 8
    call trimZeros          ;trim leading zeros
    add     rsp, 8
    ret

;Сравнение. Возвращает ноль, если bi = 0, открицательное число - если bi < 0, положительное число - если bi > 0
;
;;int biSign(BigInt bi);
;
;Parameters:
;   1) rdi - address of BigInt
;Returns:
;   rax - sign (-1, 0 or 1)
biSign:
    mov     rcx, [rdi + len]    ;if (length = 0)
    cmp     rcx, 0				;then BigInt = 0 
    je      .zero
    mov     rax, [rdi + sign]   ;get sign = -1 or 1
    ret
.zero:
    xor     rax, rax
    ret

;Вычитание. Из dst вычитается src, результат помещается в dst.
;
;;void biSub(BigInt dst, BigInt src);
;
;Parameters:
;   1) rdi - dst BigInt
;   2) rsi - src BigInt
biSub:
    mov     rax, [rsi + len]
    cmp     rax, 0
    jne     .src_not_zero       ;if (src = 0) then result = 0
    ret
.src_not_zero:
    mov     rax, [rsi + sign]   ;dst + (-src)
    imul    rax, (-1)
    mov     [rsi + sign], rax   ;invert sign of src
    push    rax
    push    rsi
    sub     rsp, 8
    call    biAdd               ;dst += (-src)
    add     rsp, 8
    pop     rsi
    pop     rax
    
    imul    rax, (-1)
    mov     [rsi + sign], rax   ;restore sign of src
    ret

;Сравнение. Возвращает ноль, если a = b, открицательное число - если a < b, положительное числое - если a > b.
;
;;int biCmp(BigInt a, BigInt b)
;
;Parameters:
;   1) rdi - a BigInt
;   2) rsi - b BigInt
;Returns:
;   rax - sign (-1, 0 or 1)
biCmp:
    mov     rax, [rdi + sign]   ;sign a (-1 or 1)
    mov     rcx, [rsi + sign]   ;sign b (-1 or 1)
    cmp     rax, rcx
    jne     .diff_signs         ;sign a == sign b

    push    rax
    mov     rdx, [rdi + len]
    mov     rcx, [rsi + len]
    mov     rdi, [rdi + digs]
    mov     rsi, [rsi + digs]
    call    compareDigs         ;compare a.digits and b.digits
    mov     r8, rax             ;r8 = result of comparison a.digits and b.digits
    pop     rax

    cmp     r8, 0           ;if(sign a == sign b) and (a.digits == b.digits)
    je      .equals			;then result = 0
    imul    rax, r8         ;if (a.digits != b.digits) then result = (sign a * comparison)
    ret

.diff_signs:                ;sign a == (1 or -1) and sign b == -sign a
    cmp     rax, 1      
    je      .first_gt       ;if (sign a = 1 && sign b = -1) then result = 1
    jmp     .second_gt      ;if (sign a = 1 && sign b = -1) then result = -1

.first_gt:
    mov     rax, 1
    ret
.second_gt:
    mov     rax, (-1)
    ret
.equals:
    xor     rax, rax
    ret

;Helper for biMul
;
;;BigInt digsMul(void * v1, void * v2, int n, int m)
;
;Parameters:
;   1) rdi - first multiplier address
;   2) rsi - second multiplier address
;   3) rdx - length of first BigInt
;   4) rcx - length of second BigInt
;Returns:
;   1) rax - address of resulting vector
;   2) r9 - length of resulting vector
digsMul:
    mov     rax, rdx    ;rax = length of result
    add     rax, rcx    ;rax = (length_1 + length_2)

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
    xor     rdx, rdx    ;(rdx:rax) holds carry
    mov     rax, r13    ;carry = old_carry
    cmp     r10, r11    ;j < length_2
    jge     .add_to_ans
    mov     rax, [rsi + r10 * 8]    ;rax = b.digits[j] 
    mov     rcx, [rdi + r9 * 8]     ;rcx = a.digits[i]
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
    jl      .loop_inner ;if (j < length_2) then continue inner_loop
    cmp     r13, 0
    jne     .loop_inner ;if (carry != 0) then continue inner_loop

    inc     r9          ;"i"++
    cmp     r9, r12     ;
    jne     .loop_outer ;if (i < length_1) then continue outer_loop

    mov     r9, r11     
    add     r9, r12     ;r9 = length_1 + length_2
    mov     rax, r8     ;rax = address of resulting vector

    pop     r13
    pop     r12
    ret

;Умножение. dst умножается на src, результат помещается в dst.
;
;;void biMul(BigInt dst, BigInt src)
;
;Parameters:
;   1) rdi - dst BigInt
;   2) rsi - src BigInt
biMul:
    mov     rax, [rdi + len]
    cmp     rax, 0
    jnz     .dst_not_zero   ;if (dst = 0) then result = 0
    ret
.dst_not_zero:
    mov     rax, [rsi + len]
    cmp     rax, 0
    jnz     .src_not_zero   ;if (src = 0) 
							;then result = 0
							;clear dst

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

    push    rax                 ;rax - address of resulting vector
    push    r9                  ;r9 - size of resulting vector
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

;Push and pop macro to save some time and memory
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


;Shift all digits of BigInt left by 1 (equivalent to dst *= 2^64)
;
;;void shiftLeft(BigInt dst)
;
;Parameters:
;   1) rdi - address of BigInt to shift
shiftLeft:
    mov     rax, [rdi + len]
    cmp     rax, 0
    jne     .not_zero   ;if (dst = 0) then result = 0
    ret
.not_zero:
    mov     rax, [rdi + len]
    inc     rax                 ;rax = old_length + 1
    push_all_regs
    alloc_N_qwords rax          ;allocate (old_length + 1) qwords for result
    pop_all_regs
    mov     r8, rax

    mov     rsi, [rdi + digs]   ;rsi - old digits position
    mov     rcx, [rdi + len]    ;rcx = old_length
    mov     r9, r8              ;r9 - new digits position
    add     r9, 8               ;move r9 to second
.loop:
    cmp     rcx, 0
    je      .endloop            ;copy [i] to [i+1]
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


;Returns quotient of division dst by src
;
;;BigInt getQuotient(BigInt dst, BigInt src)
;
;Parameters:
;   1) rdi - dst BigInt
;   2) rsi - src BigInt
;Returns:
;   rax - address of result
getQuotient:
    push_all_regs   ;save all registers, including callee-saved ones
    sub     rsp, 8  ;make stack unaligned for future convenience

    mov     rax, [rdi + sign]
    mov     r15, [rsi + sign]   ;r15 holds sign of resulting quotient
    imul    r15, rax            ;r15 = dst.sign * src.sign
                                ;if (r15 < 0) and (dst % src != 0)
                                ;then resulting quotient decremented by 1

    mov     rdx, [rdi + len]    ;dst length
    mov     rcx, [rsi + len]    ;src length
    mov     rdi, [rdi + digs]   ;rdi = dst digits
    mov     rsi, [rsi + digs]   ;rsi = src digits

    push_all_regs
    alloc_N_and_copy_M rdx, rdi, rdx    ;copy dst digits
    pop_all_regs
    mov     rdi, rax

    push_all_regs
    alloc_N_and_copy_M rcx, rsi, rcx    ;copy src digits
    pop_all_regs
    mov     rsi, rax
                                        ;let's denote D as copy of src
                                        ;let's denote N as copy of dst
    push_all_regs
    xor     rdi, rdi
    call    biFromInt                   ;create copy of dst
    pop_all_regs
    mov     r10, rax                    ;r10 = dst
    mov     [r10 + digs], rdi
    mov     [r10 + len], rdx
    mov     qword [r10 + sign], 1

    push_all_regs
    xor     rdi, rdi
    call    biFromInt                   ;create copy of src
    pop_all_regs
    mov     r11, rax                    ;r11 = src
    mov     [r11 + digs], rsi
    mov     [r11 + len], rcx
    mov     qword [r11 + sign], 1

                                        ;r9 is normalization, where
                                        ;normalization = BASE / (src.digits[src.length-1] + 1)
                                        ;normalization is needed to make high digit of
                                        ;src >= BASE / 2

    mov     r9, [rsi + rcx * 8 - 8]     ;r9 = src.digits.back()
    inc     r9                          ;r9 += 1
    cmp     r9, 0                       ;if (r9 == 0) then overflow and normalization = 1
    jne     .norm_take                 
    mov     r9, 1
    jmp     .norm_got 

.norm_take:
    push    rdx         
    mov     rdx, 1
    mov     rax, 0      ;rdx:rax = BASE = 2^64
    div     r9          ;rdx:rax = 2 ^ 64 / (b.digits[size - 1] + 1)
    mov     r9, rax     ;r9 = normalization
    pop     rdx

.norm_got:
    push_all_regs
    mov     rdi, r10
    mov     rsi, r9
    call    mulLongShort    ;dst *= normalization
    pop_all_regs

    push_all_regs
    mov     rdi, r11
    mov     rsi, r9
    call    mulLongShort    ;drc *= normalization
    pop_all_regs

    mov     rdi, [r10 + digs]   ;rdi = dst.digits
    mov     rdx, [r10 + len]    ;rdx = dst.length
    mov     rsi, [r11 + digs]   ;rsi = src.digits
    mov     rcx, [r11 + len]    ;rcx = src.length

    push_all_regs
    alloc_N_qwords rdx          ;allocate dst.digits qwords for result
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

    mov     r13, rdx            ;r13 = "i" = dst.length 
.loop:
    cmp     r13, 0
    je      .endloop            ;for "i" = dst.length - 1; "i" >= 0; i--
    dec     r13

    push_all_regs
    mov     rdi, r9
    call    shiftLeft               ;R *= BASE
    pop_all_regs

    mov     rax, [rdi + r13 * 8]     
    push_all_regs
    mov     rdi, r9
    mov     rsi, rax
    call    addLongShort            ;R += dst.digits["i"]
    pop_all_regs

    push_all_regs                   ;save registers
    mov     rdx, [r10 + len]        ;update dst.length
    mov     rcx, [r11 + len]        ;update src.length

    mov     r14, [r11 + digs]
    mov     r14, [r14 + rcx * 8 - 8] ;r14 = src.digits[D.length - 1], last digit of src

    xor     r10, r10                ;r10 = s1
    mov     r12, rcx                ;r12 = src.length
    mov     r8, [r9 + len]          ;r8 = dst.length
    cmp     r12, r8                 ;src.length < R.length
    jge     .s1_set
    
    mov     r10, [r9 + digs]
    mov     r10, [r10 + r12 * 8]    ;src.length < R.length => s1 = R.digits[src.length]

    .s1_set:
    xor     r11, r11                ;r11 = s2
    mov     r12, rcx                ;r12 = src.length
    dec     r12                     ;r12 = src.length - 1
    mov     r8, [r9 + len]          ;r8 = R.length
    cmp     r12, r8                 ;src.length - 1 < R.length
    jge     .s2_set

    mov     r11, [r9 + digs]
    mov     r11, [r11 + r12 * 8]    ;if (src.length - 1 < R.length)
									;then s2 = R.digits[src.length - 1]

    .s2_set:

                                    ;Next digit(Dig) will be 
                                    ;Dig = (s1 * 2^64 + s2) / r14,
                                    ;(r14 = last_digit)
    
    mov     rdx, r10        ;rdx=(s1)
    mov     rax, r11        ;rax=(s2)
                            ;rdx:rax = s1:s2
                            ;r14 = (rdx:rax) / src.last

    cmp     rdx, r14
    jae     .overflow       ;if (rdx >= r14) then overflow and r14 = digit = 2^64 - 1
    div     r14 
    jmp     .got_digit

.overflow:
    mov     rax, (-1)       ;rax = 0x111...111

.got_digit:    
                                    ;rax - current digit, pass it through pop_all_regs
    pop_all_regs                    ;Restore all registers
                                    ;r10 = N(copy of dst), 
                                    ;r11 = D(copy of src), 
                                    ;r9 = R(remainder), 
                                    ;r12 = T(temp)
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
        mov     rdi, r9         ;rdi = R(remainder)
        mov     rsi, r11        ;rsi = D(src)
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
    call    biFromInt               ;create resulting BigInt
    pop_all_regs
    mov     r14, rax

    mov     [r14 + digs], r8        ;set resulting vector
    mov     [r14 + len], rdx        ;set resulting length
    mov     qword [r14 + sign], 1   ;sign is '+'

    push_all_regs
    mov     rdi, r14
    call    trimZeros               ;trim leading zeros
    pop_all_regs

    cmp     r15, 1                  ;if (result.signum == '+') then signum is correct
    je      .sign_set

    xor     rcx, rcx
    mov     rax, [r9 + len]         ;check if R(remainder) != 0
    cmp     rax, 0  
    je      .flag_set
    mov     rcx, 1                  ;if (R(remainder) != 0) then decrement quotient by 1

.flag_set:

    push_all_regs
    mov     rdi, r14
    mov     rsi, rcx                ;rcx = 0 if (dst % src == 0) else 1
    call    addLongShort
    pop_all_regs

    mov     qword [r14 + sign], (-1)    ;set quotient's sign to '-'

.sign_set:
    push_all_regs
    mov     rdi, r9         ;delete R(remainder) BigInt
    call    biDelete
    pop_all_regs

    push_all_regs
    mov     rdi, r10        ;delete N(copy of dst) BigInt
    call    biDelete
    pop_all_regs

    push_all_regs
    mov     rdi, r11        ;delete D(copy of src) BigInt
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

;Copying BigInt
;
;;BigInt copyBigInt(BigInt bi)
;
;Parameters:
;   1) rdi - BigInt
;Returns:
;   rax - copy of given BigInt
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

;Деление с остатком. quotient * denominator + remainder = numerator
;
;;void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
;
;Parameters:
;   1) rdi - quotient address-holder
;   2) rsi - remainder address-holder
;   3) rdx - numerator BigInt
;   4) rcx - denominator BigInt
biDivRem:
    push    rdi         ;save address-holder of quotient
    push    rsi         ;save address-holder of remainder
    mov     rdi, rdx    ;rdi = numerator 
    mov     rsi, rcx    ;rsi = denominator
    
    mov     rax, [rsi + len]    ;denominator = 0
    cmp     rax, 0
    jne     .denom_not_zero

    pop     rsi
    pop     rdi
    mov     qword [rdi], 0      ;if (denominator = 0) then quotient = remainder = NULL
    mov     qword [rsi], 0
    ret

.denom_not_zero:
    mov     rax, [rdi + len]    ;numerator = 0   
    cmp     rax, 0
    jne     .numer_not_zero
                                ;if (numerator = 0) then quotient = remainder = 0
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
    mov     r8, rax             ;r8 = quotient of division

                                ;calculate R(remainder) as R = numerator - quotient * denominator 
    push_all_regs
    mov     rdi, r8
    call    copyBigInt          ;r9 = Q (quotient)
    pop_all_regs
    mov     r9, rax

    push_all_regs
    mov     rdi, r9             ;r9 *= D (denominator)
    call    biMul
    pop_all_regs

    mov     rax, [r9 + sign]    ;r9 = -r9 = -Q * D
    imul    rax, (-1)
    mov     [r9 + sign], rax

    push_all_regs
    mov     rsi, rdi 
    mov     rdi, r9
    call    biAdd               ;r9 = N + (-Q * D) = N - Q * D = R
    pop_all_regs

    pop     rsi                 ;restore address-holders
    pop     rdi

    mov     [rdi], r8           ;write resulting quotient address
    mov     [rsi], r9           ;write resulting remainder address

.return:
    ret