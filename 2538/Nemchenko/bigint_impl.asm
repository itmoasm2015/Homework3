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

; call_fun_2(f::x->y->z, x, y)::z
; %1 - name of function
; %2 - first argument
; %3 - second argument
%macro call_fun_2 3
    push rdi
    push rsi

    mov  rdi, %2
    mov  rsi, %3
    call %1

    pop  rsi
    pop  rdi
%endmacro

; call_fun_1(f::x->z, x)::z
; %1 - name of function
; %2 - first argument
%macro call_fun_1 2
    push rdi
    mov  rdi, %2
    call %1
    pop  rdi
%endmacro

%macro abs 2
    cmp qword %1, 0
    jge .abs_end_%2
    neg qword %1
    .abs_end_%2
%endmacro

; call fun <- %1 with stack 16 byte alligned 
%macro call_fun_with_stack_aligned 1
    push r15
    mov r15, rsp
    and rsp, -16   
    call %1
    mov rsp, r15
    pop r15
%endmacro

; call free with stack 16 byte alligned 
%macro mycalloc 0
    call_fun_with_stack_aligned calloc
%endmacro

; call free with stack 16 byte alligned 
%macro myfree 0
    call_fun_with_stack_aligned free
%endmacro

; call_fun_2(f::x->y->z, x, y)::z
; %1 - name of function
; %2 - first argument
; %3 - second argument
%macro call_fun_2_aligned 3
    push rdi
    push rsi

    mov  rdi, %2
    mov  rsi, %3
    call_fun_with_stack_aligned %1

    pop  rsi
    pop  rdi
%endmacro

extern calloc, free

BASE         equ 1 << 64
DEFAULT_SIZE equ 1
SIZE_FIELD   equ 8
SIGN_FIELD   equ 16
DATA_FIELD   equ 24
SIZEOF_FLD   equ 8
INPUT_BASE   equ 10

;
; stored bigNumber like this:
; struct BigInt {
;   unsigned long long capacity;   8 bytes
;   unsigned long long size;       8 bytes
;   long long sign;                8 byte
;   unsigned long long *data   
; }
;  
; forall i < size: data[i] < BASE
; sign = 1 | 0 | -1 , more than 0, equal and less respectively

section .text
; BigInt biFromInt(int64_t x);
biFromInt:
    call_fun_1 createBigInt, DEFAULT_SIZE
    ;ret

    cmp  rdi, 0
    je  .end                             ; x == 0 -> sign = 0
    jg  .greater_0

    mov qword [rax + SIGN_FIELD], -1     ; x < 0  -> sign = -1
    neg rdi                              ;   x = -x; 
    jmp .end 
    
    .greater_0
        mov qword [rax + SIGN_FIELD], 1  ; x > 0  -> sign = 1

    .end
    mov  r10, rdi                        ; temp variable
    push rax
    call_fun_2 push_back, rax, r10
    pop rax
    ret

; BigInt biFromString(char const *s);
biFromString:
    call_fun_1 createBigInt, DEFAULT_SIZE
    mov rsi, rdi                           ; rsi = s
    mov rdi, rax                           ; rdi = new bigInt(0)
    mov qword [rdi + SIZE_FIELD], 1        ; rdi->size = 1
    mov qword [rdi + SIGN_FIELD], 1        ; rdi->sign = 1

    mov al, [rsi]                          ; ax = s[0]

    sub al, '-'                            ; if (s[0] == '-') {
    jne .next                              ;    rdi->sign = -1
    mov qword [rdi + SIGN_FIELD], -1       ;    rsi++;
    inc rsi                                ; }

    .next:
    cmp byte [rsi], 0
    jle .error
    xor rax, rax
    .loop:
        lodsb                              ; ax = *(rsi++)
        cmp al, 0                          ; if (*rsi == '\0')
        je .end                            ;    return ..;
        cmp al, '0'                        ; if (ax < '0' or ax > '9') return NULL;
        jl .error
        cmp al, '9'
        jg .error
        sub al, '0'
        push rax
        call_fun_2 mul_short, rdi, 10      ; rdi *= 10
        pop  rax
        call_fun_2 add_short, rdi, rax     ; rdi += ax - '0'
        jmp .loop

    jmp .end
    .error:
        call biDelete
        mov rax, 0
        ret

    .end:

    push rax
    call clear_leader_zero
    pop rax
    mov rax, rdi
    ret

; void biToString(BigInt bi, char *buffer, size_t limit);
;   rdi = bi
;   rsi = buffer
;   rdx = limit
biToString:
    cmp rdx, 1                                       ; if (limit == 1) {
    jne .limit_greater_1                             ;   buffer[0] = 0;
    mov byte [rsi], 0                                ;   return;
    ret                                              ; }

    .limit_greater_1
    push r12
    push r13

    mov r12, rdx                                     ; r12 = limit
    dec r12                                          ; limit--; for save 0 
    cmp qword [rdi + SIGN_FIELD], 0
    jge .next                                        ; if (bi < 0) {
    mov byte [rsi], '-'                              ;   buffer[0] = '-'
    inc rsi                                          ;   buffer++
    sub r12, 1                                       ;   limit--
    jne .next                                        ;   if (limit == 0) {
    mov byte [rsi], 0                                ;     *buffer = 0
    ret                                              ;     return
                                                     ; }
    .next:                                           
    call_fun_2 createBigInt, [rdi + SIZE_FIELD], rsi ; rax = new BigInt();
    xchg rdi, rax
    call_fun_2 copy_BigInt, rdi, rax                 ; deep_copy: rax = rdi
    xor r13, r13                                     ; r13 = 0, count converted digits
    mov rdi, rax                                     ; rdi = deep copy of bi
    .loop:
        call_fun_2 div_short, rdi, INPUT_BASE        ; rax = bi % INPUT_BASE
        add al, '0'                                  ; al = '0' + bi % INPUT_BASE
        mov [rsi + r13], al                          ; buf[r13]  = bi % INPUT_BASE
        inc r13                                      ; r13++
        cmp qword [rdi + SIGN_FIELD], 0              ; if (bi == 0) break;
        je .end_loop 
        cmp r13, r12                                 ; if (r13 >= limit) break;
        jl .loop
    .end_loop

    push rsi
    call biDelete                                    ; delete copy of bi
    pop rsi
    mov byte [rsi + r13], 0                          ; buf[r13] = 0

    ; reverse buffer
    sub r13, 1                                       ; if count converted digits == 1 do nothing
    jz .end_while_reverse
    mov r12, r13
    mov r13, rsi                                     ; r13 = buf + r12
    add r13, r12                                     ; r13 point to last digit
    .while_reverse
        mov bl, [rsi]                                ; ~swap(buf[i], buf[size - i - 1])
        xchg bl, [r13]                               ;
        mov [rsi], bl                                ;

        inc rsi                                      ; if (fst_pointer == last_pointer || fst_pointer + 1 == last_pointer) break
        cmp rsi, r13
        je .end_while_reverse
        dec r13
        cmp rsi, r13
        je .end_while_reverse
        jmp .while_reverse
    .end_while_reverse

    pop r13
    pop r12
    ret

; void biDelete(BigInt bi);
; pointer to bi saved in rdi, free will be called with this pointer
biDelete:
    push rdi
    mov rdi, [rdi + DATA_FIELD]
    myfree
    pop rdi
    ;call_fun_1 free, [rdi + DATA_FIELD] ; free(bi->data)
    myfree                               ; free(bi)
    ret

; int biSign(BigInt bi);
biSign:
    mov rax, [rdi + SIZE_FIELD]    
    ret

; void biAdd(BigInt dst, BigInt src);
;   dst += src
;   rdi = dst
;   rsi = src
biAdd:
    ;call biDelete
    ;ret
    push r12
    push r13

    mov  r12, [rdi + SIGN_FIELD]        ; r12 = dst->sign
    mov  rdx, [rsi + SIGN_FIELD]        ; rdx = src->sign
    xor  rdx, r12                       ; if one bigInt < 0 and another > 0 {
    cmp rdx, -2                         ;    dst->sign = abs(dst->sign)
    jne .just_add                       ;    src->sign = abs(src->sign)
    push qword [rsi + SIGN_FIELD]
    abs [rdi + SIGN_FIELD], 1           ;    dst -= src 
    abs [rsi + SIGN_FIELD], 2           ;    dst->sign *= r12; // dst was > 0, dst - src
    call_fun_2 biSub, rdi, rsi          ;    // if dst was < 0, -(dst - src) -> change sign
    pop qword [rsi + SIGN_FIELD]
    mov  rdx, [rdi + SIGN_FIELD]        ;
    imul rdx, r12                       ; 
    mov  [rdi + SIGN_FIELD], rdx        ; }
    jmp .before_ret

    .just_add:

    call get_max_size                  ; rax = max(dst->size, src->size)
    push rax

    mov r13, [rdi + SIZE_FIELD]        ; r13 = dst->size
    cmp r13, [rsi + SIZE_FIELD]
    jg .add_bignum                     ; if (dst->size <= src->size) { 
    shl rax, 1                         ;   rax *= 2
    call_fun_2 realloc_data, rdi, rax  ;   reallocate dst->data
                                       ; }

    ; dst->capcity > src->size + dst->size
    .add_bignum:
    pop rax                            ; rax = max_size
    mov [rdi + SIZE_FIELD], rax        ; dst->size = max_size

    mov r10, 0                         ; i = 0;
    mov r11, [rdi + DATA_FIELD]        ; r11 = dst->data
    mov r12, [rsi + DATA_FIELD]        ; r12 = src->data
    clc                                ; clear carry flag
    pushfq                             ; store eflags
    .while_add:                        ; while (i < max_size || carry)
        mov r13, 0                     ; val = 0
        cmp r10, [rsi + SIZE_FIELD]    ; 
        jge .skip_set_val              ; if (i < src->size) {
        mov r13, [r12]                 ;   val = src->data[i]
        add r12, SIZEOF_FLD            ; }
        .skip_set_val:
            popfq                      ; restore eflags
            adc [r11], r13             ; dst->data[i] += val + carry
            pushfq                     ; store eflags
            add r11, SIZEOF_FLD        ; r11 = next(dst)

            inc r10                    ; i++
            cmp r10, rax               ; i < max_size or carry -> continue
            jl .while_add              ; else break
            popfq                      ; restore eflags
            pushfq                     ; store eflags
            jc .while_add                  
    popfq                              ; restore eflags
    cmp  r10, rax                      ; cmp(i, max_size)
    je  .end_add
    add qword [rdi + SIZE_FIELD], 1    ; increase size if last operation was carry

    .end_add:
    cmp qword [rdi + SIGN_FIELD], 0    ; if (dst->sign == 0) {
    jne .before_ret                    ;   dst->sign = src->sign;
    mov r12, [rsi + SIGN_FIELD]        ; 
    mov [rdi + SIGN_FIELD], r12        ; }

    .before_ret
    pop r13
    pop r12
    ret

; void biSub(BigInt dst, BigInt src);
;   rdi = dst
;   rsi = src
biSub:
    push r12
    push r13

    mov  r12, [rdi + SIGN_FIELD]       ; r12 = dst->sign
    mov  rdx, [rsi + SIGN_FIELD]       ; rdx = src->sign
    xor  rdx, r12                      ; if one bigInt < 0 and another > 0 {
    cmp  rdx, -2                       ;    
    jne .just_sub                      ;    src->sign = -src->sign
    neg qword [rsi + SIGN_FIELD]       ;    dst += src
    call_fun_2 biAdd, rdi, rsi         ;    return; 
    neg qword [rsi + SIGN_FIELD]       ;    
    jmp .before_ret                    ; }

    .just_sub:
    ; rax = 1, if abs(dst) < abs(src), save rsi, rdi
    call ensure_first_greater

    mov rdx, [rdi + SIZE_FIELD]        ; rdx = dst->size

    mov r10, 0                         ; i = 0;
    mov r11, [rdi + DATA_FIELD]        ; r11 = dst->data
    mov r12, [rsi + DATA_FIELD]        ; r12 = src->data
    clc                                ; clear carry flag
    pushfq                             ; store eflags
    .while_sub:                        ; while (i < max_size || carry)
        mov r13, 0                     ; val = 0
        cmp r10, [rsi + SIZE_FIELD]    ; 
        jge .skip_set_val              ; if (i < src->size) {
        mov r13, [r12]                 ;   val = src->data[i]
        add r12, SIZEOF_FLD            ; }
        .skip_set_val:
            popfq                      ; restore eflags
            sbb [r11], r13             ; dst->data[i] -= val + carry
            pushfq                     ; store eflags
            add r11, SIZEOF_FLD        ; r11 = next(dst)

            inc r10                    ; i++
            cmp r10, rdx               ; i < max_size or carry -> continue
            jl .while_sub              ; else break
            popfq                      ; restore eflags
            pushfq                     ; store eflags
            jc .while_sub                  
    popfq                              ; restore eflags

    cmp rax, 1                         ; if (abs(dst) was < abs(src)) {
    jne .before_ret                    ;   dst->sign = -src->sign;
    xchg rsi, rdi
    call_fun_2 move_bigInt, rdi, rsi   ; 
    mov r12, [rdi + SIGN_FIELD]        ;   delete old instance of BigInt 
    neg r12                            ;   which hold in rsi
    mov [rdi + SIGN_FIELD], r12        ; } 

    .before_ret:
    call_fun_1 clear_leader_zero, rdi
    pop r13
    pop r12
    ret

; void biMul(BigInt dst, BigInt src);
;   rdi = dst
;   rsi = src
biMul:
    push r12

    mov  r12, [rdi + SIZE_FIELD]
    add  r12, [rsi + SIZE_FIELD]       ; r12 = src->size + dst->size
    
    ; allocate new bigInt, capacity = dst->size + src->size
    call_fun_2 createBigInt, r12, rsi  ; rax = new BigInt

    mov  rdx, [rdi + SIGN_FIELD]       
    mov  r10, [rsi + SIGN_FIELD]
    imul r10, rdx                      ; r10 = src->sign * dst->sign

    mov  [rax + SIGN_FIELD], r10       ; new_BI->sign = src->sign * dst->sign
    mov  [rax + SIZE_FIELD], r12       ; new_BI->size = src->size + dst->size

    mov r12, rax                       ; r12 = rax
    push r12
    push rdi
    mov rcx, [rdi + SIZE_FIELD]        ; rcx = dst->size
    mov r10, [rsi + SIZE_FIELD]        ; r10 = src->size

    mov rdi, [rdi + DATA_FIELD]        ; rdi = src->data
    mov rsi, [rsi + DATA_FIELD]        ; rsi = dst->data
    mov r12, [r12 + DATA_FIELD]        ; r12 = new_BI->data
    xor r8, r8
    .while_r8                          ; while (r8 < dst->size)
        xor r11, r11
        xor r9, r9
        .while_r9                      ; while (r9 < src->size || carry)
            mov  rax, [rdi + r8 * SIZE_FIELD]       ; rax = dst->data[r8]
            xor  rdx, rdx              ; rdx = 0
            cmp  r9,  r10              ; if (r9 < src->size) {
            jge .next                  ;   rdx = src->data[r9]
            mov  rdx, [rsi + r9 * SIZE_FIELD]       ; }

            .next:
            mul  rdx                    ; dst->data[r8] * src->data[r9] = rdx * BASE + rax
            xchg r11, rdx               ; r11 = new carry
            add  rax, rdx               ; rax += previous carry
            adc  r11, 0                 ; r11 += carry after addition
            mov  rdx, r9
            add  rdx, r8                ; rdx = r8 + r9
            add  [r12 + rdx * SIZE_FIELD], rax       ; newBI->data[r8 + r9] += rax 
            adc  r11, 0                 ; r11 += carry after addition
            inc  r9                     ; r9++
            cmp  r9, r10                ; if (r9 < src->size
            jl .while_r9                ;   or r11(new carry) != 0) continue
            cmp  r11, 0
            jne .while_r9
        inc r8                          ; r8++
        cmp r8, rcx                     ; if (r8 < dst.size) continue
        jl .while_r8
    pop rdi
    pop r12
    call_fun_2 move_bigInt, rdi, r12    ; deep move: rdi = r12
    call clear_leader_zero 
    
    pop r12 
    ret

; Compute quotient and remainder by divising numerator by denominator.
; quotient * denominator + remainder = numerator
;
; param remainder must be in range [0, denominator) if denominator > 0
;                               and (denominator, 0] if denominator < 0.
; explanation: http://en.wikipedia.org/wiki/Division_algorithm#Integer_division_.28unsigned.29_with_remainder
;
; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
;   rdi = pointer to quotient
;   rsi = pointer to remainder
;   rdx = numerator
;   rcx = denominator
; result:
;   
biDivRem:
    cmp qword [rcx + SIGN_FIELD], 0      ; if (denomirator == 0) {
    jne .next                            ;   *quotient = NULL
    mov qword [rdi], 0                   ;   *remainder = NULL
    mov qword [rsi], 0                   ;   return
    ret                                  ; }

    .next
    push r12 
    push r13 
    push r14 
    push r15 

    push qword [rdx + SIGN_FIELD]        ; save signs of numerator and denomirator
    push qword [rcx + SIGN_FIELD]        ; numerator = abs(numerator)
    push rcx
    push rdx

    abs [rdx + SIGN_FIELD], 1            ; denominator = abs(denominator)
    abs [rcx + SIGN_FIELD], 2

    mov r14, [rdx + SIZE_FIELD]          ; r14 = numerator->size
    mov r15, rcx                         ; r15 = denominator

    push rdx
    call_fun_1 createBigInt, r14         ; rax = new bigInt with capacity == denominator->capacity

    mov [rdi], rax                       ; *quotient = rax
    mov qword [rax + SIZE_FIELD], r14    ; quotient = 0; quotient->size = numerator->size; fixing size at the end
    mov qword [rax + SIGN_FIELD], 1      ; quotient->sign = 1; fixing sign at the end
    mov r12, [rax + DATA_FIELD]          ; r12 = quotient->data

    call_fun_1 createBigInt, r14         ; rax = new bigInt with capacity == denominator->capacity
    mov r13, rax                         ; remainder: r13
    mov [rsi], r13                       ; *remainder = r13
    mov qword [r13 + SIZE_FIELD], 1      ; remainder = 0; remainder->size = 1

    mov r9, [r13 + DATA_FIELD]           ; r9  = remainder->data
    pop rdx
    dec r14                              ; r14 = numerator->size - 1
    mov rdx, [rdx + DATA_FIELD]          ; rdx = numerator->data

    ; for (int I = count_bits - 1; I > = 0; --I)
    ; equivalent to
    ; for (int i = size - 1; i >= 0; --i) {
    ;   for (int j = 63; j >= 0; --j) {
    ;      numerator[i] & (1 << j) <--> numerator[I] 
    .loop_r14:
        mov cl, 63
        ;mov cl, 4 
        .loop_cl:
            push rcx
            push r9
            push rdx
            call_fun_2 mul_short, r13, 2          ; remainder <<= 1
            pop rdx
            pop r9
            pop rcx

            mov r8, 1
            shl r8, cl
            and r8, [rdx + r14 * SIZEOF_FLD]      ; r8 = numerator->data[r14] & (1 << cl)
            jz .without_set_bit
            or qword [r9], 1                      ; set first bit in remainder = 1
            cmp qword [r13 + SIGN_FIELD], 0
            jne .without_set_bit
            mov qword [r13 + SIGN_FIELD], 1

            .without_set_bit

            push rcx
            push r9
            push rdx

            call_fun_2 biCmp, r13, r15            ; cmp(remainder, denominator)
            cmp rax, 0
            jl .continue_pop_loop_cl              ; if (remainder >= denominator) {
            call_fun_2 biSub, r13, r15            ;   remainder -= denominator;

            pop rdx
            pop r9
            pop rcx

            ; set bit; 
            mov r8, 1
            shl r8, cl
            or r8, [r12 + r14 * SIZEOF_FLD]       ;   r8 = quotient->data[r14] | (1 << cl)
            mov [r12 + r14 * SIZEOF_FLD], r8      ;   quotient->data[r14] = r8
            jmp .continue_loop_cl                 ; }

            .continue_pop_loop_cl
            pop rdx
            pop r9
            pop rcx
            .continue_loop_cl
            sub cl, 1
            jge .loop_cl

        sub r14, 1
        jge .loop_r14

        mov rdi, [rdi]                   ; rdi = *quotient
        mov rsi, [rsi]                   ; rsi = *remainder
        call_fun_2 clear_leader_zero, rdi, rsi
        call_fun_2 clear_leader_zero, rsi, rdi
        
        pop rdx                             ; rdx = numerator
        pop rcx                             ; rcx = denominator
        pop qword [rcx + SIGN_FIELD]        ; restore signs
        pop qword [rdx + SIGN_FIELD]

        ; d - denominator; n - numerator; q - quotient; r - remainder
        ; analysis of the sign:
        ; currently i suppose that d > 0 and n > 0, and get this equality: n = q * d + r 
        ; next cases are very easy:
        ; n > 0, d < 0: n = (-(q + 1)) * d + (r + d)
        ; n < 0, d > 0: n = (-(q + 1)) * d + (d - r)
        ; n < 0, d < 0: n = q * d + (-r)
        ; 
        cmp qword [rdx + SIGN_FIELD], 0
        jg .numerator_greater_0
        jl .numerator_less_0
        je .end

        ; numerator < 0
        .numerator_less_0:
            cmp qword [rcx + SIGN_FIELD], 0
            jg .l_denominator_greater_0
            ; numerator < 0, denominator < 0
            neg qword [rsi + SIGN_FIELD]
            jmp .end

        ; numerator < 0, denominator > 0
        .l_denominator_greater_0:
            push rcx
            call_fun_2 add_short, rdi, 1
            pop  rcx
            neg qword [rdi + SIGN_FIELD]
            call_fun_2 biSub, rsi, rcx
            neg qword [rsi + SIGN_FIELD]
            jmp .end

        ; numerator > 0 
        .numerator_greater_0:
            cmp qword [rcx + SIGN_FIELD], 0
            jg .end                             ; if (n > 0 && d > 0) return
            ; numerator > 0, denominator < 0
            push rcx
            call_fun_2 add_short, rdi, 1
            pop  rcx
            neg qword [rdi + SIGN_FIELD]
            call_fun_2 biAdd, rsi, rcx
        
        .end
        pop r15 
        pop r14 
        pop r13 
        pop r12 
    ret

; int biCmp(BigInt a, BigInt b);
;   rdi = a
;   rsi = b
biCmp:
    mov rax, [rdi + SIGN_FIELD]     ; rax = a->sign
    mov rcx, [rsi + SIGN_FIELD]     ; rcx = b->sign
    cmp rax, rcx
    je .size_cmp                    ; if (a->sign < b.sign) {
    jg .ret_1                       ;   return -1;
    mov rax, -1                     ;
    ret                             ; }

    .size_cmp:                      ; a->sign == b->sign
    mov rdx, [rdi + SIZE_FIELD]     ; rdx = a->size
    mov rcx, [rsi + SIZE_FIELD]     ; rcx = b->size
    cmp rdx, rcx
    je .number_cmp                  ; if (a->size > b.size) {
    jl .ret_neg_sign                ;   return (rax == a->sign)
    ret                             ; }

    ; rcx = a->size = b->size; 
    .number_cmp:
        std
        xchg rdi, rsi               ; swap(rdi, rsi)
        mov rdi, [rdi + DATA_FIELD] ; rdi = b->data
        mov rsi, [rsi + DATA_FIELD] ; rsi = a->data

        shl rcx, 3                  ; rcx = a->size * 8
        add rdi, rcx                ; rdi = b->data[b->size - 1] 
        sub rdi, 8

        add rsi, rcx                ; rsi = a->data[a->size - 1] 
        sub rsi, 8
        shr rcx, 3                  ; rcx = a->size

        repz cmpsq                  ; while (a->data[i] - b->data[i] == 0);
        je .ret_0                   ; a == b -> return 0
        ja .end_biCmp               ; a > b -> return rax = a->sign
        jmp .ret_neg_sign           ; a < b -> return -rax

    .ret_neg_sign:                  ; if (a->size < b.size) {
        neg rax                     ;   return -a->sign;
        jmp .end_biCmp              ; }
    .ret_1:                         ; if (a->sign > b.sign) 
        mov rax, 1                  ;   return 1
        jmp .end_biCmp
    .ret_0:
        mov rax, 0
    .end_biCmp:
    cld                             ; fu***ng direction flag, why i have to clear it??
    ret

; **reallocate memory for data with apropriate size
; void realloc_data(BigInt src, long long new_capacity)
realloc_data:
    call_fun_2_aligned calloc, rsi, SIZEOF_FLD       ; calloc(new_capacity, 8)

    push rax
    push rdi
    push rsi

    mov rcx, [rdi + SIZE_FIELD]                      ; rcx = src->size
    mov rsi, [rdi + DATA_FIELD]                      ; rsi = src->data
    mov rdi, rax                                     ; rdi = new allocated data
    repnz movsq                                      ; copy src->size qwords from src->data to data

    pop rsi
    pop rdi

    call_fun_2_aligned free, [rdi + DATA_FIELD], rsi ; free(src->data) and save rsi

    pop rax
    mov [rdi], rsi                                   ; src->capacity = new_capacity
    mov [rdi + DATA_FIELD], rax                      ; src->data = rax
    ret

; realloc data, if needed, to src->size * 2
; void ensure_capacity(BigInt src)
; rdi = src
ensure_capacity:
    mov  rcx, [rdi + SIZE_FIELD]   ; rcx = src->size
    cmp  rcx, [rdi]                ; cmp(src->size, src->capacity)
    jl .end_ensure                 ; src->size < src->capacity then return

    mov rsi, [rdi + SIZE_FIELD]    ; rsi = "src"->size
    shl rsi, 1                     ; rsi = "src"->size * 2
    call realloc_data 

    .end_ensure:
    ret

; void copy_BigInt(BigInt dest, BigInt src)
;   rdi = destination pointer to BigInt
;   rsi = source pointer to BigInt
copy_BigInt:
    ;copy size, sign from src to dest
    push rsi
    push rdi

    add rdi, SIZEOF_FLD      ; rdi = &dest->size
    add rsi, SIZEOF_FLD      ; rsi = &src->size
    mov rcx, 2               ; count of copy fields
    repnz movsq              ; copy fields size and sign

    pop rdi
    pop rsi
    
    call copy_data
    ret

; deep copy data from src to dest
; void copy_data(BigInt dest, BigInt src)
;   rdi = destination pointer to BigInt
;   rsi = source pointer to BigInt
copy_data:
    mov rcx, [rsi + SIZE_FIELD] ; rcx = src->size

    mov rdi, [rdi + DATA_FIELD] ; rdi = dest->data
    mov rsi, [rsi + DATA_FIELD] ; rsi = src->data

    repnz movsq                 ; copy src->size of src->data to dest->data
    ret

; if (position < src->size)
;   src->data[position] = new_value
; else
;   push_back(src, new_value)
;
; void set_or_push_back(BigInt src, long long new_value, long long position)
; rdi = src
; rsi = new_value
; rdx = position 
set_or_push_back:
    mov rcx, [rdi + SIZE_FIELD]    ; rcx = src->size
    cmp rdx, rcx                   ; position < src->size
    jl .just_set
    call_fun_2 push_back, rdi, rsi
    jmp .end_set_or

    .just_set:
    mov  rdi, [rdi + DATA_FIELD]   ; rdi = src->data
    imul rdx, SIZEOF_FLD           ; position *= 8, in bytes
    add  rdi, rdx                  ; rdi = src->data + position
    mov  [rdi], rsi                ; *(src->data + position) = new_value

    .end_set_or:
    ret

; allocate BigInt and allocate BigInt->data, which contain "cnt" qwords. 
; BigInt createBigInt(long long num_dig)
;   rdi - number of data
; return value:
;   rax = pointer to allocated BigInt
createBigInt:
    ; allocate memory for: capacity, size, sign, data
    call_fun_2_aligned calloc, 4, SIZEOF_FLD

    mov  [rax], rdi                     ; set capacity
    push rax
    call_fun_2_aligned calloc, rdi, SIZEOF_FLD
    mov rdi, rax                        ; rdi = new allocated data
    pop rax
    mov [rax + DATA_FIELD], rdi


    ret

; void move_bigInt(BigInt dest, BigInt src)
;   rdi = destination pointer to BigInt
;   rsi = source pointer to BigInt
move_bigInt:
    ;copy size, sign from src to dest
    push rsi
    push rdi

    mov rcx, 3           ; count of copy fields
    repnz movsq          ; copy fields size and sign

    mov rdi, [rdi]       ; now rdi == dest->data
    myfree

    pop rdi
    pop rsi
    mov rcx, [rsi + DATA_FIELD]
    mov [rdi + DATA_FIELD], rcx
    ret

; void push_back(BigInt src, long long arg);
;
;   rdi - pointer to the structure BigInt
;   rsi - arg::(unsigned long long)  which will be pushed into the "data"
push_back:
    call_fun_2 ensure_capacity, rdi, rsi ; ensure capacity and save register rsi
    
    mov  rcx, [rdi + SIZE_FIELD]  ; rcx = src->size
    imul rcx, SIZEOF_FLD          ; rcx = src->size * 8
    inc  qword [rdi + SIZE_FIELD] ; src->size++

    mov rdi, [rdi + DATA_FIELD]   ; rdi = src->data
    add rdi, rcx                  ; rdi refer to last free position in data
    mov [rdi], rsi                ; put arg to appropriate position

    ret

; long long get_max_size(BigInt first, BigInt second)
;   rdi = first
;   rsi = second
;
; return value:
;   rax = max(rdi->size, rsi->size)
get_max_size:
    mov rax, [rdi + SIZE_FIELD]        ; rax = first->size

    cmp [rsi + SIZE_FIELD], rax        ; second->size - first->size
    jle .end_max_size                
    mov rax, [rsi + SIZE_FIELD]        ; second->size > first->size -> rax = second->size

    .end_max_size:
    ret

; void mul_short(BigInt src, unsigned long long num)
;   rdi = src
;   rsi = num
; result:
;     src *= num
mul_short:
    mov  rcx, [rdi + SIZE_FIELD]    ; rcx = src->size
    mov  r10, [rdi + DATA_FIELD]    ; r10 = src->data

    xor r11, r11
    .while_carry:
        mov  rax, [r10]             ; rax = src->data[i]
        mul  rsi                    ; src->data[i] * num = rdx * BASE + rax
        xchg r11, rdx               ; r11 = new carry
        add  rax, rdx               ; rax += previous carry
        adc  r11, 0                 ; r11 += carry after addition
        mov  [r10], rax             ; src->data[i] = rax
        add  r10, SIZEOF_FLD
        sub  rcx, 1
        jg   .while_carry

    push rsi
    cmp  r11, 0                     ; if (carry == 0) return
    je .end                         ; else push_back(src, carry)
    call_fun_2 push_back, rdi, r11

    .end
    pop rsi
    cmp rsi, 0                      ; if (num == 0) {
    jne .end_mul                    ;   src->sign = 0;
    mov qword [rdi + SIGN_FIELD], 0 ; }
    .end_mul
    ret

; src > 0, num > 0 
; void add_short(BigInt src, int64_t num)
;   rdi = src
;   rsi = num
; result:
;   src += num
add_short:
    mov  rcx, [rdi + SIZE_FIELD]      ; rcx = src->size
    mov  r10, [rdi + DATA_FIELD]      ; r10 = src->data
    .while_carry:
        add [r10], rsi                ; src->data[0] += num
        jnc .end
        mov rsi, 0                    ; carry = 0
        adc rsi, 0                    ; carry = get_carry()
        add r10, SIZEOF_FLD
        sub rcx, 1
        jg .while_carry

    cmp  rsi, 0                       ; if (carry == 0) return
    je .end                           ; else push_back(src, carry)
    call_fun_2 push_back, rdi, rsi

    .end
    ret

; void ensure_first_greater(BigInt fst, BigInt scd)
;   rdi = fst
;   rsi = scd
; result:
;   if (abs(fst) > abs(scd)) {
;      rax = 0;
;   } else {
;      temp = new BigInt(scd->size);
;      temp = deep_copy(scd)
;      scd = fst;
;      fst = temp
;      rax = 1
;   }
ensure_first_greater:
    push qword [rdi + SIGN_FIELD]
    push qword [rsi + SIGN_FIELD]

    abs [rdi + SIGN_FIELD], 1                        ; fst = abs(fst)
    abs [rsi + SIGN_FIELD], 2                        ; scd = abs(scd)
    call_fun_2 biCmp, rdi, rsi                       ; save rdi, rsi
    cmp rax, 0                                       ; if ( abs(fst) > abs(scd) ) return
    jge .end_ensure                                  ; else {
    pop qword [rsi + SIGN_FIELD]
    pop qword [rdi + SIGN_FIELD]                     ;   restore signs 

    push qword [rsi + SIZE_FIELD]
    call_fun_2 createBigInt, [rsi + SIZE_FIELD], rsi ; rax = new BigInt();
                                                     ; rax->capacity = scd->size 
    call_fun_2 copy_BigInt, rax, rsi                 ; deep_copy: rax = rsi
    mov rsi, rdi                                     ; scd = fst
    mov rdi, rax                                     ; fst = new_bigInt, copy of scd
    pop rax                                          ; rax = previous scd->size
    call_fun_2 realloc_data, rsi, rax                ; ensure that second number
                                                     ; have at least rax capacity
    mov rax, 1
    
    ret                                              ;
                                                     ; }

    .end_ensure
    pop qword [rsi + SIGN_FIELD]
    pop qword [rdi + SIGN_FIELD]                     ;   restore signs 
    mov rax, 0
    ret

; void clear_leader_zero(BigInt src)
;   rdi = src
; result:
;   clear leader zero in src, and set sign appropriately
clear_leader_zero:
    mov rcx, [rdi + SIZE_FIELD]                      ; rcx = src->size
    mov rax, [rdi + DATA_FIELD]                      ; rax = src->data
    .loop:
        cmp qword [rax + rcx * SIZEOF_FLD - 8], 0    ; if (src->data[rcx - 1] == 0) {
        jne .end                                     ;   rcx--;
        sub rcx, 1                                   ; }
        jnz .loop
    .end
    mov [rdi + SIZE_FIELD], rcx                      ; src->size = rcx
    cmp rcx, 0                                       ; if (rcx == 0) {
    jne .before_ret                                  ;   src->sign = 0;
    mov qword [rdi + SIGN_FIELD], 0                  ;   src->size = 1;
    mov qword [rdi + SIZE_FIELD], 1                  ; }
    .before_ret
    ret

; unsigned long long div_short(BigInt numerator, int64_t denominator);
;   rdi = numerator
;   rsi = denominator
; result
;   numerator /= denominator
;   return remainder after numerator / denominator
; 
div_short:
    push rdi
    xor rdx, rdx
    mov r11, [rdi + SIZE_FIELD]           
    dec r11                               ; r11 = numerator->size - 1
    mov rdi, [rdi + DATA_FIELD]
    .loop:
        mov rax, [rdi + r11 * SIZEOF_FLD] ; rax = carry + numerator->data[r11]
        div rsi
        mov [rdi + r11 * SIZEOF_FLD], rax ; numerator->data[r11] = (carry + n->data[r11]) / denominator
        ; rdx = (carry + n->data[r11]) % denominator
        ; so how rdx:rax / rdi, therefore carry automatically * base
        sub r11, 1                        ; r11--
        jge .loop
    .end_ 
    pop rdi
    push rdx                              ; result already saved in rax
    call_fun_1 clear_leader_zero, rdi
    pop  rax
    ret
