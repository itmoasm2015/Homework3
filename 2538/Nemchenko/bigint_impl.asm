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


extern calloc, free

BASE equ 1 << 64
MIN_LL equ 1 << 63
DEFAULT_SIZE equ 10

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

; BigInt biFromInt(int64_t x);
biFromInt:
    call_fun_1 createBigInt, DEFAULT_SIZE

    push rax                           ; save pointer to BigInt
    add  rax, 16                       ; rax refer to field "sign"
    cmp  rdi, 0
    je  .end                           ; x == 0 -> sign = 0
    jg  .greater_0

    mov qword [rax], -1                ; x < 0  -> sign = -1
    mov rsi, MIN_LL
    cmp rdi, rsi
    je  .create_min_ll                 ; if (x != MIN_LONG_LONG) {
    neg rdi                            ;   x = -x; 
    jmp .end                           ; } else {
                                       ; 
    .create_min_ll:                    ;   -2 ^ 64 <-> sign = -1 && 0 + 1 * BASE  
        mov rax, [rsp]                 ;   rax = pointer to the begin of BigInt
        call_fun_2 push_back, rax, 0   ;   BigInt->data[0] = 0;
        mov rdi, 1                     ;   BigInt->data[1] = 1;
    jmp .end                           ; }
    
    .greater_0:
        mov qword [rax], 1             ; x > 0  -> sign = 1
    .end:

    pop rax
    mov  r10, rdi                      ; temp variable
    call_fun_2 push_back, rax, r10
    ret

; BigInt biFromString(char const *s);
biFromString:
    ret

; void biToString(BigInt bi, char *buffer, size_t limit);
biToString:
    ret

; void biDelete(BigInt bi);
; pointer to bi saved in rdi, free will be called with this pointer
biDelete:
    call_fun_1 free, [rdi + 24] ; free(bi->data)
    call free                   ; free(bi)
    ret

; int biSign(BigInt bi);
biSign:
    mov rax, [rdi + 8]    
    ret

; void biAdd(BigInt* dst, BigInt* src);
; dst += src
; rdi = dst
; rsi = src
biAdd:
    ;mov  rax, [rdi + 16]                ; rax = dst->sign
    ;mov  rdx, [rsi + 16]                ; rdx = src->sign
    ;xor  rax, rdx
    ;test rax, -2                        ; if only one bigInt < 0
    ;jne  .next_add
    ;call 
    ;ret
    ;.next_add
    push r10
    push r11
    push r12
    push r13
    push r14


    call_fun_2 get_max_size, rdi, rsi  ; rax = max(dst->size, src->size)
    push rax

    mov r13, [rdi + 8]                 ; r13 = dst->size
    cmp r13, [rsi + 8]
    jg .add_bignum                     ; if (dst->size <= src->size) { 
    shl rax, 1                         ;   rax *= 2
    call_fun_2 realloc_data, rdi, rax  ;   reallocate dst->data
                                       ; }
    ; dst->capcity > src->size + dst->size
    .add_bignum:
    pop rax                            ; rax = max_size
    mov [rdi + 8], rax                 ; dst->size = max_size

    mov r10, 0                         ; i = 0;
    mov r11, [rdi + 24]                ; r11 = dst->data
    mov r12, [rsi + 24]                ; r12 = src->data
    clc                                ; clear carry flag
    pushfq                             ; store eflags
    .while_add:                        ; while (i < max_size || carry)
        mov r13, 0                     ; val = 0
        cmp r10, [rsi + 8]             ; 
        jge .skip_set_val              ; if (i < src->size) {
        mov r13, [r12]                 ;   val = src->data[i]
        add r12, 8                     ; }
        .skip_set_val:
            popfq                      ; restore eflags
            adc [r11], r13             ; dst->data[i] += val + carry
            pushfq                     ; store eflags
            add r11, 8

            inc r10                    ; i++
            cmp r10, rax               ; i < max_size or carry -> continue
            jl .while_add              ; else break
            popfq                      ; restore eflags
            pushfq                     ; store eflags
            jc .while_add                  
    popfq                              ; restore eflags
    cmp  r10, rax                      ; cmp(i, max_size)
    je  .end_add
    add qword [rdi + 8], 1             ; increase size if last operation was carry

    .end_add:
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    ret

; void biSub(BigInt dst, BigInt src);
; rdi = dst
biSub:
    cmp rdi, rsi
    je .ret_zero

    .ret_zero:
        call biDelete
    ret

; void biMul(BigInt dst, BigInt src);
biMul:
    ret

; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
biDivRem:
    ret

; int biCmp(BigInt a, BigInt b);
biCmp:
    ret

; **reallocate memory for data with apropriate size
; void realloc_data(BigInt* src, long long new_capacity)
realloc_data:
    call_fun_2 calloc, rsi, 8  ; calloc(new_capacity, 8)

    push rax
    push rdi
    push rsi

    mov rcx, [rdi + 8]         ; rcx = src->size
    mov rsi, [rdi + 24]        ; rsi = src->data
    mov rdi, rax               ; rdi = new allocated data
    repnz movsq                ; copy src->size qwords from src->data to data

    pop rsi
    pop rdi

    call_fun_2 free, [rdi + 24], rsi ; free(src->data) and save rsi

    pop rax
    mov [rdi], rsi                   ; src->capacity = new_capacity
    mov [rdi + 24], rax              ; src->data = rax
    ret

; realloc data, if needed, to src->size * 2
; void ensure_capacity(BigInt* src)
; rdi = src
ensure_capacity:
    mov  rcx, [rdi + 8]   ; rcx = src->size
    cmp  rcx, [rdi]       ; cmp(src->size, src->capacity)
    jl .end_ensure        ; src->size < src->capacity then return

    mov rsi, [rdi + 8]    ; rsi = "src"->size
    shr rsi, 1            ; rsi = "src"->size * 2
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

    add rdi, 8               ; rdi = &dest->size
    add rsi, 8               ; rsi = &src->size
    mov rcx, 2               ; count of copy fields
    cld                      ; DF = 0
    repnz movsq              ; copy fields size and sign

    pop rdi
    pop rsi
    
    call copy_data
    ret

; deep copy data from src to dest
; void copy_BigInt(BigInt* dest, BigInt* src)
;   rdi = destination pointer to BigInt
;   rsi = source pointer to BigInt
copy_data:
    mov rcx, [rsi + 8]  ; rcx = src->size

    mov rdi, [rdi + 24] ; rdi = dest->data
    mov rsi, [rsi + 24] ; rsi = src->data

    repnz movsq         ; copy src->size of src->data to dest->data
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
    mov rcx, [rdi + 8]   ; rcx = src->size
    cmp rdx, rcx         ; position < src->size
    jl .just_set
    call_fun_2 push_back, rdi, rsi
    jmp .end_set_or

    .just_set:
    mov  rdi, [rdi + 24] ; rdi = src->data
    imul rdx, 8          ; position *= 8, in bytes
    add  rdi, rdx        ; rdi = src->data + position
    mov  [rdi], rsi      ; *(src->data + position) = new_value

    .end_set_or:
    ret

; BigInt* createBigInt(long long num_dig)
; rdi - number of data
; allocate BigInt and allocate BigInt->data, which contain "cnt" qwords. 
; return value:
;   rax = pointer to allocated BigInt
createBigInt:
    push rdi
    mov  rdi, 4       ; capacity, size, sign, data
    mov  rsi, 8       ; 8 bytes for each field
    call calloc 
    pop  rdi

    push rax
    mov  [rax], rdi   ; set capacity
    mov  rsi, rdi     ; rsi = capacity of data
    mov  rdi, rax     ; rdi = pointer to BigInt
    call realloc_data ; allocate memory for data, and set rax->data 
    pop  rax

    ret

; void move_bigNum(BigInt* dest, BigInt* src)
; rdi = destination pointer to BigInt
; rsi = source pointer to BigInt
move_bigNum:
    ;copy size, sign from src to dest
    push rsi
    push rdi

    add rdi, 8           ; rdi = &dest->size
    add rsi, 8           ; rsi = &src->size
    mov rcx, 2           ; count of copy fields
    cld                  ; DF = 0
    repnz movsq          ; copy fields size and sign

    pop rdi
    pop rsi

    mov rcx, [rsi + 8]   ; rcx = src->size

    mov rdi, [rdi + 24]  ; rdi = dest->data
    mov rsi, [rsi + 24]  ; rsi = src->data

    repnz movsq          ; copy src->size of src->data to dest->data
    ret

; void push_back(BigInt* src, long long arg);
;
; rdi - pointer to the structure BigInt
; rsi - arg::(unsigned long long)  which will be pushed into the "data"
push_back:
    call_fun_2 ensure_capacity, rdi, rsi ; ensure capacity and save register rsi
    
    mov  rcx, [rdi + 8]           ; rcx = src->size
    imul rcx, 8                   ; rcx = src->size * 8
    inc  qword [rdi + 8]          ; src->size++

    mov rdi, [rdi + 24]           ; rdi = src->data
    add rdi, rcx                  ; rdi refer to last free position in data
    mov [rdi], rsi                ; put arg to appropriate position

    ret

; long long get_max_size(BigInt* first, BigInt* second)
; rdi = first
; rsi = second
;
; return value:
;   rax = max(rdi->size, rsi->size)
get_max_size:
    add rdi, 8        ; rdi refer to first->size
    add rsi, 8        ; rsi refer to second->size
    mov rax, [rdi]    ; rax = first->size

    cmp [rsi], rax    ; second->size - first->size
    jle .end_max_size            
    mov rax, [rsi]    ; second->size > first->size -> rax = second->size

    .end_max_size:
    ret

; void mul_short(BigInt* src, int64_t num)
;   rdi = src
;   rsi = num
; result:
;     src *= num
mul_short:
    mov  rcx, [rdi + 8]       ; rcx = src->size
    mov  r10, [rdi + 24]      ; r10 = src->data

    xor r11, r11
    .while_carry:
        mov  rax, [r10]        ; rax = src->data[i]
        mul  rsi               ; src->data[i] * num = rdx * BASE + rax
        xchg r11, rdx          ; r11 = new carry
        add  rax, rdx          ; rax += previous carry
        adc  r11, 0            ; r11 += carry after addition
        mov  [r10], rax        ; src->data[i] = rax
        add  r10, 8
        sub  rcx, 1
        jg   .while_carry
        cmp  r11, 0            ; if new carry != 0
        jne  .while_carry

    sub  r10, [rdi + 24]       ; rsi = distanse between current digit and first, in bytes
    mov  rcx, [rdi + 8]        ; rcx = src->size
    imul rcx, 8                ; rcx = size in bytes
    cmp  r10, rcx              ; working cell was last, then increase size
    jle  .end
    inc  qword [rdi + 8]       ; src->size++

    .end
    ret

; src > 0, num > 0 
; void add_short(BigInt* src, int64_t num)
;   rdi = src
;   rsi = num
; result:
;   src += num
add_short:
    mov  rcx, [rdi + 8]       ; rcx = src->size
    imul rcx, 8               ; rcx = src->size * 8
    mov  r10, [rdi + 24]      ; r10 = src->data
    add  [r10], rsi           ; src->data[0] += num
    jnc .next
    pushfq                    ; save carry
    .while_carry:
        add r10, 8
        popfq                 ; restore carry
        adc qword [r10], 0    ; src->data[i] += carry
        pushfq                ; save carry
        jc .while_carry
    popfq
    .next
    sub r10, [rdi + 24]       ; r10 = distanse between current digit and first, in bytes
    cmp r10, rcx              ; working cell is last then increase size
    jne .end
    inc qword [rdi + 8]       ; src->size++

    .end
    ret
