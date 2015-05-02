; calee-save RBX, RBP, R12-R15
; rdi , rsi ,
; rdx , rcx , r8 ,
; r9 , zmm0 - 7
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
;global main
;main:
    ;ret

extern calloc, free, memcpy

BASE equ 1 << 64
DEFAULT_SIZE equ 10

;
; stored bigNumber like this:
; struct bigNum {
;   unsigned long long capacity;              8 bytes
;   unsigned long long size;                  8 bytes
;   long long sign;                           8 byte
;   unsigned int64_t digits[capacity];  8 * capacity bytes
; }
;  
; forall i < capacity: digits[i] < BASE
; sign = 1 | 0 | -1 , more than 0, equal and less respectively

; void createBigInt(long long cnt)
; rdi - number of digits
; allocate (%1 + 2) * 8 bytes
; return value:
;   rax = pointer to allocated memory
createBigInt:

    push rdi
    mov  rdi, 3
    mov  rsi, 8            ; 8 bytes for each field
    call calloc 
    pop  rdi

    mov qword [rax], rdi   ; set capacity

    mov  rsi, 8            ; 8 bytes for each field
    push rax
    call calloc 
    mov  rsi, rax          ; rsi = bigInt->digits
    pop  rax

    mov [rax + 24], rsi         ; rax->digits = rsi
    
    ret


; void put_back(BigInt*, long long arg);
; pre: size < capacity
;
; rdi - pointer to the structure bigNum
; rsi - arg::(unsigned long long)  which will be pushed into the "digits"
put_back:
    add  rdi, 8                  ; rdi refer to size
    mov  rcx, qword [rdi]        ; rcx = size
    imul rcx, 8                  ; rcx = size * 8
    inc  qword [rdi]             ; size++

    mov rdi, qword [rdi + 16]    ; rdi = digits
    add rdi, rcx                 ; rdi refer to last free position in digits
    mov qword [rdi], rsi         ; put arg to appropriate position

    ret

; long long get_max_size(BigInt*, BigInt*)
; rdi - pointer to the first bigNum
; rsi - pointer to the second bigNum
;
; return value:
;   rax = max(rdi->size, rsi->size)
get_max_size:
    add rdi, 8           ; rdi refer to rdi.size
    add rsi, 8           ; rsi refer to rsi.size
    mov rax, qword [rdi] ; rax = rdi.size

    cmp qword [rsi], rax
    jle .end
    mov rax, qword [rsi] ; rsi.size > rdi.size -> rax = rsi.size

    .end:
    ret

; BigInt biFromInt(int64_t x);
biFromInt:
    push rdi
    mov  rdi, DEFAULT_SIZE
    call createBigInt
    pop  rdi

    push rdi
    mov  rsi, rdi          ; rsi = x
    mov  rdi, rax          ; rdi = pointer to bigInt
    call put_back 
    pop rdi

    push rax               ; pointer to bigInt
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
    push rdi
    mov rdi, [rdi + 24]
    call free
    pop rdi
    call free
    ret

; int biSign(BigInt bi);
biSign:
    mov rax, qword [rdi + 8]    
    ret

; void biAdd(BigInt dst, BigInt src);
; dst += src
biAdd:
    push rdi
    push rsi
    call get_max_size
    pop rdi
    pop rsi

    inc rax                    ; rax = max(dst.size, src.size) + 1
    cmp rax, qword [rdi]       ; cmp(max_sz, dst.capacity)
    jle .add_bigNum

    ; allocate new bigNum and copy dst to it
    shr  rax, 1
    imul rax, 3                ; rax = rax * 1.5, new capacity

    push rdx
    mov  rdi, rax
    call createBigInt
    pop rdx


    xor  rcx, rcx
    mov  rcx, qword [rdi]      ; rcx = old_capcity
    add  rcx, 2                ; rcx = old_capacity + 2

    push rsi
    push rdi

    mov rsi, rdi               ;  src = rdi,  old bigNum
    mov rdi, rax               ;  dest = rax, new memory
    cld                        ;  DF = 0
    add rsi, 8                 ;  to skip capacity 
    add rdi, 8                 ;  to skip capacity 
    repnz movsq
    
    pop rdi
    pop rsi

    push rax
    call free
    pop  rax

    .add_bigNum


    
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

