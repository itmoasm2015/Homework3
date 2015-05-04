; calee-save RBX, RBP, R12-R15
; rdi , rsi ,
; rdx , rcx , r8 ,
; r9 , zmm0 - 7 default rel

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

extern calloc, free

BASE equ 1 << 64
DEFAULT_SIZE equ 10

;
; stored bigNumber like this:
; struct BigInt {
;   unsigned long long capacity;   8 bytes
;   unsigned long long size;       8 bytes
;   unsigned long long sign;       8 byte
;   unsigned long long *digits   
; }
;  
; forall i < capacity: digits[i] < BASE
; sign = 1 | 0 | -1 , more than 0, equal and less respectively

; void alloc_digits(BigInt* src, long long num_dig)
; rdi = pointer to src
; rsi = num_dig
alloc_digits:
    push rdi

    mov  rdi, rsi          ; rdi = num_dig
    mov  rsi, 8            ; 8 bytes for each field
    call calloc 

    pop rdi

    mov [rdi + 24], rax    ; rdi->digits = rax
    ret

; void extend_vector(bigInt* src)
; rdi = pointer to BigInt
; realloc digits to src->size * 2
extend_vector:
    push rdi
    mov  rdi, [rdi + 24] ; rdi = "src"->digits
    call free
    pop rdi

    mov rsi, [rdi + 8]   ; rsi = "src"->size
    shr rsi, 1           ; rsi = "src"->size * 2
    call alloc_digits 
    ret

; BigInt* createBigInt(long long num_dig)
; rdi - number of digits
; allocate BigInt and allocate BigInt->digits, which contain "cnt" qwords. 
; return value:
;   rax = pointer to allocated BigInt
createBigInt:
    push rdi
    mov  rdi, 4            ; capacity, size, sign, digits
    mov  rsi, 8            ; 8 bytes for each field
    call calloc 
    pop  rdi

    push rax
    mov  qword [rax], rdi  ; set capacity
    mov  rsi, rdi          ; rsi = num_dig
    mov  rdi, rax          ; rdi = pointer to BigInt
    call alloc_digits      ; allocate memory for digits, and set rax->digits 
    pop  rax

    ret

; void move_bigNum(BigInt* dest, BigInt* src)
; rdi = destination pointer to BigInt
; rsi = source pointer to BigInt
move_bigNum:
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

    mov rcx, qword [rsi + 8] ; rcx = src->size

    mov rdi, [rdi + 24]      ; rdi = dest->digits
    mov rsi, [rsi + 24]      ; rsi = src->digits

    repnz movsq              ; copy src->size of src->digits to dest->digits
    ret

; void push_back(BigInt* src, long long arg);
;
; rdi - pointer to the structure BigInt
; rsi - arg::(unsigned long long)  which will be pushed into the "digits"
push_back:
    mov  rcx, qword [rdi + 8]    ; rcx = src->size
    cmp  rcx, [rdi]              ; cmp(src->size, src->capacity)
    jl .next_push_back
    call extend_vector 
    
    .next_push_back:
    imul rcx, 8                  ; rcx = src->size * 8
    inc  qword [rdi + 8]         ; src->size++

    mov rdi, qword [rdi + 24]    ; rdi = src->digits
    add rdi, rcx                 ; rdi refer to last free position in digits
    mov qword [rdi], rsi         ; put arg to appropriate position

    ret

; long long get_max_size(BigInt* first, BigInt* second)
; rdi = first
; rsi = second
;
; return value:
;   rax = max(rdi->size, rsi->size)
get_max_size:
    add rdi, 8           ; rdi refer to first->size
    add rsi, 8           ; rsi refer to second->size
    mov rax, qword [rdi] ; rax = first->size

    cmp qword [rsi], rax ; second->size - first->size
    jle .end_max_size            
    mov rax, qword [rsi] ; second->size > first->size -> rax = second->size

    .end_max_size:
    ret

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

; BigInt biFromInt(int64_t x);
biFromInt:
    call_fun_1 createBigInt, DEFAULT_SIZE

    push rax               ; save pointer to BigInt
    mov  r10, rdi          ; temp variable
    call_fun_2 push_back, rax, r10

    mov  rax, [rsp]
    add  rax, 16           ; rax refer to field "sign"
    cmp  rdi, 0
    je  .end               ; x == 0 -> sign = 0
    jg  .greater_0

    mov qword [rax], -1    ; x < 0  -> sign = -1
    jmp .end

    
    .greater_0:
        mov qword [rax], 1 ; x > 0  -> sign = 1
    .end:
    pop rax
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
    call_fun_1 free, [rdi + 24] ; free(bi->digits)
    call free                   ; free(bi)
    ret

; int biSign(BigInt bi);
biSign:
    mov rax, qword [rdi + 8]    
    ret

; void biAdd(BigInt dst, BigInt src);
; dst += src
biAdd:
    
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
; void alloc_data(BigInt* src, long long new_capacity)
alloc_data:
    call_fun_2 calloc, rsi, 8 ; calloc(new_capacity, 8)

    mov [rdi + 24], rax       ; rdi->data = rax
    ret

; 
; void ensure_capcity(BigInt* src)
; rdi = src
; realloc data to src->size * 2
ensure_capcity:
    mov  rcx, qword [rdi + 8]    ; rcx = src->size
    cmp  rcx, [rdi]              ; cmp(src->size, src->capacity)
    jl .end_ensure               ; src->size < src->capacity then return

    push rdi
    mov  rdi, [rdi + 24]         ; rdi = "src"->data
    call free
    pop rdi

    mov rsi, [rdi + 8]           ; rsi = "src"->size
    shr rsi, 1                   ; rsi = "src"->size * 2
    call alloc_data 

    .end_ensure:
    ret

; void move_BigInt(BigInt* dest, BigInt* src)
; rdi = destination pointer to BigInt
; rsi = source pointer to BigInt
move_BigInt:
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

    ;deep copy digits from src to dest
    push rsi
    mov rcx, qword [rsi + 8] ; rcx = src->size

    mov rdi, [rdi + 24]      ; rdi = dest->data
    mov rsi, [rsi + 24]      ; rsi = src->data

    repnz movsq              ; copy src->size of src->data to dest->data
    ret

; void push_back(BigInt* src, long long arg);
;
; rdi - pointer to the structure BigInt
; rsi - arg::(unsigned long long)  which will be pushed into the "data"
push_back:
    call_fun_2 ensure_capcity, rdi, rdi
    
    mov  rcx, qword [rdi + 8]    ; rcx = src->size
    imul rcx, 8                  ; rcx = src->size * 8
    inc  qword [rdi + 8]         ; src->size++

    mov rdi, qword [rdi + 24]    ; rdi = src->data
    add rdi, rcx                 ; rdi refer to last free position in data
    mov qword [rdi], rsi         ; put arg to appropriate position

    ret

