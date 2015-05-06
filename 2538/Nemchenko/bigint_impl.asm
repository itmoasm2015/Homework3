; calee-save RBX, RBP, R12-R15
; rdi , rsi ,
; rdx , rcx , r8 ,
; r9 , zmm0 - 7 default rel

global mul_short
global add_short
;

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
;global main
;main:
    ;ret

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

%macro check_bigInt_zero 1
    push rsi
    push rax

    mov rax, [%1 + SIZE_FIELD]       ; rax = %1->size
    cmp rax, 1                       ; if (%1->size == 1) {
    jg .end_check_bigInt             ;   rsi = %1->data[0]
    mov rsi, [%1 + DATA_FIELD]       ;   if (rsi == 0) {
    cmp qword [rsi], 0               ;     %1->sign = 0
    jne .end_check_bigInt            ;   }
    mov qword [%1 + SIGN_FIELD], 0   ; }

    .end_check_bigInt:
    pop rax
    pop rsi
%endmacro
extern calloc, free, strlen

BASE         equ 1 << 64
MIN_LL       equ 1 << 63
DEFAULT_SIZE equ 1
SIZE_FIELD   equ 8
SIGN_FIELD   equ 16
DATA_FIELD   equ 24
SIZEOF_FLD   equ 8

section .bss
   ;minus: resb 1 

;
; stored bigNumber like this:
; struct BigInt {
;   unsigned long long capacity;   8 bytes
;   unsigned long long size;       8 bytes
;   long long sign;                8 byte
;   unsigned long long *data   
; }
;  
; forall i < capacity: data[i] < BASE
; sign = 1 | 0 | -1 , more than 0, equal and less respectively

section .text
; BigInt biFromInt(int64_t x);
biFromInt:
    call_fun_1 createBigInt, DEFAULT_SIZE

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
    cld                                    ; DF = false
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
    check_bigInt_zero rdi
    mov rax, rdi
    ret

; void biToString(BigInt bi, char *buffer, size_t limit);
biToString:
     
    ret

; void biDelete(BigInt bi);
; pointer to bi saved in rdi, free will be called with this pointer
biDelete:
    call_fun_1 free, [rdi + DATA_FIELD] ; free(bi->data)
    call free                           ; free(bi)
    ret

; int biSign(BigInt bi);
biSign:
    mov rax, [rdi + SIZE_FIELD]    
    ret

; void biAdd(BigInt* dst, BigInt* src);
;   dst += src
;   rdi = dst
;   rsi = src
biAdd:
    push r12
    push r13

    mov  r12, [rdi + SIGN_FIELD]        ; r12 = dst->sign
    mov  rdx, [rsi + SIGN_FIELD]        ; rdx = src->sign
    xor  rdx, r12                       ; if one bigInt < 0 and another > 0 {
    cmp rdx, -2                         ;    dst->sign = abs(dst->sign)
    jne .just_add                       ;    src->sign = abs(src->sign)
    abs [rdi + SIGN_FIELD], 1           ;    dst -= src 
    abs [rsi + SIGN_FIELD], 2           ;    dst->sign *= r12; // dst was > 0, dst - src
    call_fun_2 biSub, rdi, rsi          ;    // if dst was < 0, -(dst - src) -> change sign
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
    mov r12, [rsi + SIGN_FIELD]        ;   delete old instance of BigInt 
    neg r12                            ;   which hold in rsi
    mov [rdi + SIGN_FIELD], r12        ; 
    call_fun_1 biDelete, rsi           ; }

    .before_ret:
    call_fun_1 clear_leader_zero, rdi
    pop r13
    pop r12
    ret

; void biMul(BigInt dst, BigInt src);
biMul:
    ret

; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
biDivRem:
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
        jg .end_biCmp               ; a > b -> return rax = a->sign
        jl .ret_neg_sign            ; a < b -> return -rax

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
; void realloc_data(BigInt* src, long long new_capacity)
realloc_data:
    call_fun_2 calloc, rsi, SIZEOF_FLD  ; calloc(new_capacity, 8)

    push rax
    push rdi
    push rsi

    mov rcx, [rdi + SIZE_FIELD]              ; rcx = src->size
    mov rsi, [rdi + DATA_FIELD]              ; rsi = src->data
    mov rdi, rax                             ; rdi = new allocated data
    repnz movsq                              ; copy src->size qwords from src->data to data

    pop rsi
    pop rdi

    call_fun_2 free, [rdi + DATA_FIELD], rsi ; free(src->data) and save rsi

    pop rax
    mov [rdi], rsi                           ; src->capacity = new_capacity
    mov [rdi + DATA_FIELD], rax              ; src->data = rax
    ret

; realloc data, if needed, to src->size * 2
; void ensure_capacity(BigInt* src)
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

; void copy_BigInt(BigInt* dest, BigInt* src)
;   rdi = destination pointer to BigInt
;   rsi = source pointer to BigInt
copy_BigInt:
    ;copy size, sign from src to dest
    push rsi
    push rdi

    add rdi, SIZEOF_FLD      ; rdi = &dest->size
    add rsi, SIZEOF_FLD      ; rsi = &src->size
    mov rcx, 2               ; count of copy fields
    cld                      ; DF = 0
    repnz movsq              ; copy fields size and sign

    pop rdi
    pop rsi
    
    call copy_data
    ret

; deep copy data from src to dest
; void copy_data(BigInt* dest, BigInt* src)
;   rdi = destination pointer to BigInt
;   rsi = source pointer to BigInt
copy_data:
    mov rcx, [rsi + SIZE_FIELD]  ; rcx = src->size

    mov rdi, [rdi + DATA_FIELD] ; rdi = dest->data
    mov rsi, [rsi + DATA_FIELD] ; rsi = src->data

    cld
    repnz movsq                 ; copy src->size of src->data to dest->data
    ret

; if (position < src->size)
;   src->data[position] = new_value
; else
;   push_back(src, new_value)
;
; void set_or_push_back(BigInt* src, long long new_value, long long position)
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
; BigInt* createBigInt(long long num_dig)
;   rdi - number of data
; return value:
;   rax = pointer to allocated BigInt
createBigInt:
    ; allocate memory for: capacity, size, sign, data
    call_fun_2 calloc, 4, SIZEOF_FLD

    push rax
    mov  [rax], rdi       ; set capacity
    mov  rsi, rdi         ; rsi = capacity of data
    mov  rdi, rax         ; rdi = pointer to BigInt
    call realloc_data     ; allocate memory for data, and set rax->data 
    pop  rax

    ret

; void move_bigNum(BigInt* dest, BigInt* src)
;   rdi = destination pointer to BigInt
;   rsi = source pointer to BigInt
move_bigNum:
    ;copy size, sign from src to dest
    push rsi
    push rdi

    add rdi, SIZEOF_FLD  ; rdi = &dest->size
    add rsi, SIZEOF_FLD  ; rsi = &src->size
    mov rcx, 2           ; count of copy fields
    cld                  ; DF = 0
    repnz movsq          ; copy fields size and sign

    pop rdi
    pop rsi

    mov rcx, [rsi + SIZE_FIELD]  ; rcx = src->size

    mov rdi, [rdi + DATA_FIELD]  ; rdi = dest->data
    mov rsi, [rsi + DATA_FIELD]  ; rsi = src->data

    repnz movsq                  ; copy src->size of src->data to dest->data
    ret

; void push_back(BigInt* src, long long arg);
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

; long long get_max_size(BigInt* first, BigInt* second)
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

; void mul_short(BigInt* src, unsigned long long num)
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
; void add_short(BigInt* src, int64_t num)
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
    ;cmp qword [rdi + SIGN_FIELD], 0   ; if (src->sign == 0) {
    ;jne .end_add                      ;    
    ;mov r10, [rdi + DATA_FIELD]       ;   r10 = src->data
    ;cmp qword [r10], 0                ;   if (src->data[0] != 0) {
    ;je .end_add                       ;      src->sign = 1;
    ;mov qword [rdi + SIGN_FIELD], 1   ;   }
                                      ;; }
    .end_add
    ret

; void ensure_first_greater(BigInt* fst, BigInt* scd)
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
    call_fun_2 biCmp, rdi, rsi                        ; save rdi, rsi
    cmp rax, 0                                       ; if ( abs(fst) > abs(scd) ) return
    jge .end_ensure                                  ; else {
    pop qword [rdi + SIGN_FIELD]                     ;   restore signs 
    pop qword [rsi + SIGN_FIELD]

    call_fun_2 createBigInt, [rsi + SIZE_FIELD], rsi ;   rax = new BigInt();
                                                     ;   rax->capacity = scd->size 
    call_fun_2 copy_BigInt, rax, rsi                 ;   deep_copy: rax = rsi
    mov rsi, rdi                                     ;   scd = fst
    mov rdi, rax                                     ;   fst = rax
    mov rax, 1
    ret                                              ;
                                                     ; }

    .end_ensure
    pop qword [rdi + SIGN_FIELD]                     ;   restore signs 
    pop qword [rsi + SIGN_FIELD]
    mov rax, 0
    ret

; void clear_leader_zero(BigInt* src)
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

