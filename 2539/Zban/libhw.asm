section .text

extern malloc
extern calloc
extern free

global biFromInt
global biCopy
global biFromString
global biToString
global biDelete
global biSign
global biAddNew
global biAdd
global biSubNew
global biSub
global biMulNew
global biMul
global biDivRem
global biCmp

;  BigInt:
;
;  int sign (-1 | 0 | 1)
;  int size > 0
;  int64_t* data
;  base is 2^64


; BigInt biFromInt(int64_t x);
; create BigInt from one signed 64-bit integer
; x in rdi
; result in rax
biFromInt:
    push rbx ; save rbx by convention
    push rdi
    mov rdi, 16 ; 4 + 4 + 8 allocate bytes
    call malloc
    mov rbx, rax ; rbx now ptr to BigInt
    mov rdi, 8 ; one 8-byte integer
    call malloc ; rax now ptr to data array
    pop rdi
    
    mov [rbx + 8], rax ; ptr to data is assigned
    mov rax, rbx ; rax -- ptr to BigInt
    mov dword [rax + 4], 1 ; size is 1
    
    mov dword [rax], 1 ; let's initially sign will be +
    cmp rdi, 0
    jne .isNotZero
    mov dword  [rax], 0 ; if x = 0 then sign = 0
    jmp .signReady
.isNotZero
    jnl .signReady
    mov dword [rax], -1 ; if x < 0 then sign = -
    neg rdi
.signReady
    mov rbx, [rax + 8]
    mov [rbx], rdi ; put x in data

    pop rbx    
    ret


; BigInt biFromSignLenArray(int sign, int len, int64_t *a);
; sign in edi
; len in esi
; a in rdx
; result in rax
biFromSignLenArray:
    push rdi
    push rsi
    push rdx
    mov rdi, 16 ; 4 + 4 + 8 allocate bytes
    call malloc
    pop rdx
    pop rsi
    pop rdi
   
    ; rax -- ptr to BigInt
    mov [rax], edi ; sign
    mov [rax + 4], esi ; size
    mov [rax + 8], rdx ; data
   
    ret


; BigInt biCopy(BigInt a);
; copies given BigInt
; a in rdi
; result in rax
biCopy:
    push rbx           ; store rbx (convention)
    
    xor r8, r8
    push rdi
    mov rbx, rdi       ; save rdi
    mov rdi, 16        ; 4 + 4 + 8
    call malloc
    mov r8D, [rbx]
    mov [rax], r8D     ; sign is copied
    mov r8D, [rbx + 4]
    mov [rax + 4], r8D ; size is copied
    mov rbx, rax       ; save pointer to BigInt
    lea rdi, [r8 * 8]
    call malloc        ; rax now is new data array
    pop rdi

    mov [rbx + 8], rax ; data ptr is assigned
    mov rax, rbx       ; rax now 
    mov rdi, [rdi + 8] ; ptr to old data
    mov rsi, [rax + 8] ; ptr to new data

    xor rcx, rcx
    mov ecx, [eax + 4] ; rcx -- counter copying data
    .while
        dec rcx
        mov r8, [rdi + rcx * 8]
        mov [rsi + rcx * 8], r8        
        test rcx, rcx
        jnz .while

    pop rbx
    ret


; BigInt biFromString(char *a);
; a in rdi
; result in rax
biFromString:
    mov r11, 1 ; sign is 1 initially
    mov r10, 0 ; len of string

    cmp byte [rdi], '-'
    jne .isPositive
    mov r11, -1 ; negative number
    inc rdi ; move ptr to a
.isPositive
    mov r8, 0 ; r8 -- counter on a
    .while ; this while tests if in string exists non-zero char  
        mov al, [rdi + r10]
        test al, al
        jz .break
        cmp al, '0'
        jl .isBad
        cmp al, '9'
        jg .isBad
        cmp al, '1'
        jl .isZero
        inc r8
        .isZero
        inc r10
        jmp .while
        .isBad
        mov rax, 0 ; string contains some prohibited symbols
        ret
    .break

    cmp r8, 0
    jne .isNotZero
        mov rdi, 0 ; if a = 0 then return immediatly
        call biFromInt
        ret
    .isNotZero

    push r10 ; len
    push r11 ; sign

    push rdi
    mov rdi, r10
    shr rdi, 4 ; if number consist of x digits then it will be packed in x / 16 + 1 longs
    inc rdi
    mov rcx, rdi
    push rcx
    mov rsi, 8
    call calloc ; rax now -- array of longs
    pop rcx ; len of array of longs
    pop rdi
    mov r8, rdi ; ptr to string

    xor r9, r9 ; counter
    .while2
        mov dl, [r8 + r9]
        test dl, dl
        jz .break2 ; zero byte -> end of string

        push r8 ; save all needed registers
        push r9
        push rcx
        push rax
        mov rdi, rax
        mov rsi, rcx
        mov rdx, 10
        call mulThisOnShort ; multiply current number by 10
        pop rax
        pop rcx 
        pop r9
        pop r8

        push r8
        push r9
        push rcx
        push rax
        mov rdi, rax
        mov rsi, rcx
        xor rdx, rdx
        mov dl, [r8 + r9]
        sub dl, '0'
        call addShortToThis ; add s[i] - '0' to current number
        pop rax
        pop rcx 
        pop r9
        pop r8

        inc r9
        jmp .while2
    .break2

    pop r11
    pop r10

    ; this while deletes leading zeroes
    .while3
        cmp rcx, 1
        je .break3
        mov rdi, [rax + rcx * 8 - 8]
        cmp rdi, 0
        jne .break3
        dec rcx
        jmp .while3
    .break3

    ; call constructor of bigint
    mov rdi, r11
    mov rsi, rcx
    mov rdx, rax
    call biFromSignLenArray
    ret


; int cmpWithZero(int *a, int size);
; return 0 if a is array of zeroes and 1 else
; a in rdi
; size in rsi
; result in rax
cmpWithZero:
    .while ; rsi is while-counter
        dec rsi
        mov r8, [rdi + rsi * 8]
        test r8, r8
        jz .notOk
        mov rax, 1 ; if found non-zero element return 1
        ret
        .notOk
        test rsi, rsi
        jnz .while ; end of cycle
    mov rax, 0        
    ret


; void biToString(BigInt a, char *s, size_t limit);
; a in rdi
; s in rsi
; limit in rdx
biToString:
    cmp rdx, 1
    jg .greaterThanOne
    mov [rsi], byte 0 ; if limit <= 1 then return zero string immediatly
    ret
    .greaterThanOne
    push rsi
    push rdx
    push rdi
    xor r8, r8
    mov r8D, [rdi + 4]
    imul r8, 21 ; if BigInt consists of x 64-bit fields than it will be approximately ~21 * x chars long in decimal representation
    mov rdi, r8
    call malloc ; rax -- ptr to string representation of BigInt
    pop rdi 
    push rdi
    push rax
    call biCopy ; copy array to modify it
    mov r11, rax ; r11 -- ptr to copy of BigInt
    pop rax
    pop rdi    
    pop rdx
    pop rsi
    mov rcx, [r11 + 8] ; rcx now is ptr to array which wi divide by 10

    push rax
    push r11
    push rdi
    push rsi
    push rdx
    mov rdi, rcx
    xor rsi, rsi
    mov esi, [r11 + 4]
    call cmpWithZero ; if zero then we can put '0' and return immediatly
    pop rdx
    pop rsi
    pop rdi
    pop r11
    test rax, rax
    pop rax
    jnz .notZero
    mov [rsi], byte '0'
    mov [rsi + 1], byte 0
    push r11
    mov rdi, rax
    call free ; free temp array
    pop r11
    mov rdi, r11
    call biDelete ; free copied BigInt
    ret
    .notZero

    mov r9D, [rdi]
    cmp r9D, -1
    jne .isPositive ; if BigInt is negative then first char is '-'
    mov [rsi], byte '-'
    inc rsi
    dec rdx
    .isPositive
 
    ; r9 -- counter to pos in rax
    xor r9, r9 ; fill rax (decimal representation)
    .while
        push rax
        push r11
        push rdi
        push rsi
        push rdx
        mov rdi, rcx
        xor rsi, rsi
        mov esi, [r11 + 4]
        call cmpWithZero ; if zero then break
        pop rdx
        pop rsi
        pop rdi
        pop r11
        test rax, rax
        pop rax
        jz .break
        
        push rcx
        push rax
        push r11
        push rdi
        push rsi
        push rdx
        mov rdi, rcx
        xor rsi, rsi
        mov esi, [r11 + 4]
        mov rdx, 10
        call divThisOnShort ; divide by 10
        mov r8, rdx
        pop rdx
        pop rsi
        pop rdi
        pop r11
        pop rax
        pop rcx

        push rcx
        mov rcx, r8
        add cl, '0'
        mov [rax + r9], cl ; x mod 10 is writen
        pop rcx
   
        inc r9
        jmp .while
    .break

    ; copy limit (rdx) symbols from rax to rsi
    .while2
        cmp rdx, 1
        je .break2 ; break if only 0 char is left
        dec r9
        push rdx
        mov dl, [rax + r9]
        mov [rsi], dl ; copy current char
        inc rsi
        pop rdx
        dec rdx
        test r9, r9 ; break if decimal representation is ended
        jz .break2
        jmp .while2
    .break2
    mov [rsi], byte 0 ; terminal symbol

    push r11
    mov rdi, rax
    call free ; free temp array
    pop r11    

    mov rdi, r11
    call biDelete ; free BigInt copy
    ret


; void biDelete(BigInt a);
; a in rdi
biDelete:
    push rdi
    mov rdi, [rdi + 8]
    call free ; free data array
    pop rdi
    call free ; free ptr to BigInt
    ret


; int biSign(BigInt a);
; return sign of a
; a in rdi
; result in eax
biSign:
    xor rax, rax
    mov eax, [rdi] ; sign of BigInt
    ret


; void biSwapAndDelete(BigInt a, BigInt b) {
;   a = b;
;   delete b;
; }
; a in rdi
; b in rsi
biSwapAndDelete:
    mov r8D, [rsi]
    mov [rdi], r8D ; swap sign
    mov r8D, [rsi + 4]
    mov [rdi + 4], r8D ; swap len
    mov r8, [rsi + 8]
    mov [rdi + 8], r8 ; swap data
    mov rdi, rsi
    call free ; free ptr to b
    ret


; int64_t* addUnsigned(int64_t *a, int len_a, int64_t *b, int len_b);
; a in rdi
; len_a in rsi
; b in rdx
; len_b in rcx
; result in rax
; len of array in r8!
addUnsigned:
    cmp rsi, rcx
    jnl .aIsBigger
    xchg rdi, rdx
    xchg rsi, rcx
.aIsBigger
    push rdi
    push rsi
    push rdx
    push rcx
    lea rdi, [rsi + 1]
    imul rdi, 8
    call malloc ; new array will be sizeof(unsigned long long) * (a.size + 1) bytes long
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    
    xor r8, r8 ; r8 -- counter on current data element
    xor r11, r11 ; r11 will be carry
    .while
        cmp r8, rsi
        jng .whileIsNotEnded
        jmp .endWhile
        .whileIsNotEnded

        mov qword [rax + r8 * 8], 0
        mov r9, 0 ; r9 = a[i], if i < a.length, and 0 otherwise
        cmp r8, rsi
        jnl .isOutOfBorderA
        mov r9, [rdi + r8 * 8]
        .isOutOfBorderA
        mov r10, 0 ; r10 = b[i], if i < b.length, and 0 otherwise
        cmp r8, rcx
        jnl .isOutOfBorderB
        mov r10, [rdx + r8 * 8]
        .isOutOfBorderB
        add [rax + r8 * 8], r11 ; c[i] = a[i] (r9) + b[i] (r10) + carry (r11)
        xor r11, r11 ; carry := 0, and see for carry on next iteration
        adc r11, 0
        add [rax + r8 * 8], r9
        adc r11, 0
        add [rax + r8 * 8], r10
        adc r11, 0
        inc r8
        jmp .while
    .endWhile

    ; delete leading zeroes in number
    lea r8, [rsi + 1]
    .while2
        cmp r8, 1
        je .while2End
        cmp qword [rax + r8 * 8 - 8], 0
        jne .while2End
        dec r8
        jmp .while2
    .while2End
    ret

; int64_t* mulUnsigned(int64_t *a, int len_a, int64_t *b, int len_b);
; a in rdi
; len_a in rsi
; b in rdx
; len_b in rcx
; result in rax
; len of array in r8!
; for i = 0; i < len_a; i++
;   for j = 0; i + j < len_a + len_b; j++
;     c[i + j] += carry
;     carry = ^overflow
;     c[i + j] += a[i] * b[j] mod base
;     carry = a[i] * b[j] div base + ^overflow
mulUnsigned:
    cmp rsi, rcx
    jnl .aIsBigger
    xchg rdi, rdx
    xchg rsi, rcx
.aIsBigger
    push rbx
    mov rbx, rdx

    push rdi
    push rsi
    push rbx
    push rcx
    mov r8, 0
    add r8D, esi
    add r8D, ecx
    mov rdi, r8
    mov rsi, 8
    call calloc ; 8 * (a.length + b.length) bytes
    pop rcx
    pop rbx
    pop rsi
    pop rdi
    ; rax -- result array
    ; r8 -- i
    ; r9 -- j
    ; rdx -- carry

    xor r8, r8 ; i counter
    .whileI
        cmp r8, rsi
        je .breakI

        xor r9, r9 ; j counter
        xor rdx, rdx ; carry
        .whileJ
            mov r10, rsi
            add r10, rcx
            sub r10, r8
            cmp r9, r10
            je .breakJ ; i + j < len_a + len_b
            mov r10, r9
            add r10, r8 ; r10 = i + j
            add [rax + 8 * r10], rdx
            pushf ; remember carry from this step not to forget
            xor rdx, rdx
            push rax
            mov rax, [rdi + r8 * 8] ; a[i]
            mov r11, 0
            cmp r9, rcx
            jnl .r9IsZero
            mov r11, [rbx + r9 * 8] ; b[j]
            .r9IsZero
            mul r11
            mov r11, rax
            pop rax
            add [rax + 8 * r10], r11 ; += a[i] * b[j] mod base
            adc rdx, 0 ; += a[i] * b[j] div base
            popf
            adc rdx, 0 ; += carry

            inc r9
            jmp .whileJ
        .breakJ
        inc r8
        jmp .whileI
    .breakI    

    ; delete leading zeroes
    lea r8, [rsi + rcx]
    .while2
        cmp r8, 1
        je .while2End
        cmp qword [rax + r8 * 8 - 8], 0
        jne .while2End
        dec r8
        jmp .while2
    .while2End

    pop rbx
    ret

; int cmpUnsigned(int64_t *a, int len_a, int64_t *b, int len_b)
cmpUnsigned:
    cmp rsi, rcx ; if len_a != len_b then we know which is less
    je .equals
        jl .aIsLess
            mov rax, 1
            ret
        .aIsLess
            mov rax, -1
            ret 
    .equals
    
    mov r8, rsi ; r8 -- index from high data elements to low
    .while
        dec r8
        mov r9, [rdi + r8 * 8]
        mov r10, [rdx + r8 * 8]
        cmp r9, r10
        je .equals2 ; if a[i] != b[i] then we know which is less
            jl .aIsLess2
                mov rax, 1
                ret
            .aIsLess2
                mov rax, -1
                ret             
        .equals2
        test r8, r8
        jnz .while
    mov rax, 0
    ret


; int64_t* subUnsigned(int64_t *a, int len_a, int64_t *b, int len_b);
; a in rdi
; len_a in rsi
; b in rdx
; len_b in rcx
; result in rax
; len of array in r8!
; sign to multiply in r11!
subUnsigned:
    call cmpUnsigned
    mov r11, 1
    cmp rax, 0
    jne .isNotZero ; if a=b then return 0
        mov rdi, 8
        call malloc
        mov r8, 1
        mov r11, 0
        ret
.isNotZero
    jg .aIsBigger ; a should be greater
    xchg rdi, rdx
    xchg rsi, rcx
    mov r11, -1 
.aIsBigger
    push rdi
    push rsi
    push rdx
    push rcx
    push r11
    mov rdi, rsi
    imul rdi, 8
    call malloc ; result will be 8 * a.length bytes
    pop r11
    pop rcx
    pop rdx
    pop rsi
    pop rdi

    push r11
    xor r8, r8 ; r8 -- counter to cur element
    xor r11, r11 ; r11 will be carry
    .while
        cmp r8, rsi
        jng .whileIsNotEnded
        jmp .endWhile
        .whileIsNotEnded

        mov qword [rax + r8 * 8], 0
        mov r9, 0
        cmp r8, rsi
        jnl .isOutOfBorderA
        mov r9, [rdi + r8 * 8] ; a[i]
        .isOutOfBorderA
        mov r10, 0
        cmp r8, rcx
        jnl .isOutOfBorderB
        mov r10, [rdx + r8 * 8] ; b[i]
        .isOutOfBorderB
        mov [rax + r8 * 8], r9 ; c[i] = a[i] - b[i] - carry
        sub [rax + r8 * 8], r11
        xor r11, r11
        adc r11, 0
        sub [rax + r8 * 8], r10
        adc r11, 0
        inc r8
        jmp .while
    .endWhile
    pop r11

    ; remove leading zeroes
    mov r8, rsi
    .while2
        cmp r8, 1
        je .while2End
        cmp qword [rax + r8 * 8 - 8], 0
        jne .while2End
        dec r8
        jmp .while2
    .while2End
    ret


; void mulThisOnShort(int64_t *a, int size, int64_t x);
; it is considered that a is big enough to contain result
; a in rdi
; size in esi
; x in rdx
mulThisOnShort:
    mov rcx, rdx

    xor r8, r8 ; r8 is index i on current element
    xor rdx, rdx ; rdx is carry
    .while
        cmp r8D, esi
        je .break
        mov rax, [rdi + r8 * 8]
        mov qword [rdi + r8 * 8], rdx
        mul rcx
        add [rdi + r8 * 8], rax
        adc rdx, 0
        inc r8
        jmp .while
    .break
    ret


; void divThisOnShort(int64_t *a, int size, int64_t x);
; a in rdi
; size in esi
; x in rdx
; remainder at rdx!
divThisOnShort:
    mov rcx, rdx

    xor r8, r8 ; r8 is counter on current element
    mov r8D, esi
    xor rdx, rdx ; rdx -- carry
    .while
        dec r8
        mov rax, [rdi + r8 * 8]
        div rcx
        mov [rdi + r8 * 8], rax
        test r8, r8
        jnz .while
    ret


; void addShortToThis(int64_t *a, int size, int64_t x);
; it is considered that a is big enough to contain result
; a in rdi
; size in esi
; x in rdx
addShortToThis:
    xor r8, r8 ; counter to cur element
    .while
        cmp r8D, esi
        je .break
        mov rax, [rdi + r8 * 8]
        mov qword [rdi + r8 * 8], rdx
        add [rdi + r8 * 8], rax
        mov rdx, 0
        adc rdx, 0 ; rdx is initially x to add, and later is carry
        inc r8
        jmp .while
    .break
    ret


; BigInt biAddNew(BigInt a, BigInt b) return a + b;
; a in rdi
; b in rsi
; result in rax
biAddNew:
    cmp dword [rdi], 0
    jnz .aIsNotZero
    mov rdi, rsi
    call biCopy ; if a is zero return b
    ret
.aIsNotZero
    cmp dword [rsi], 0
    jnz .bIsNotZero
    call biCopy ; if b is zero return a
    ret
.bIsNotZero
    mov r8D, [rdi]
    mov r9D, [rsi]
    cmp r8D, r9D
    jne .differentSigns
        push rdi ; if signs are equal then add
        push rsi

        xor rcx, rcx
        mov ecx, [rsi + 4] ; len of b array
        mov rdx, [rsi + 8] ; ptr to b array

        xor rsi, rsi
        mov esi, [rdi + 4] ; len of a array
        mov rdi, [rdi + 8] ; ptr to a array
        
        call addUnsigned

        pop rsi
        pop rdi
        
        mov edi, [rdi]
        mov rsi, r8
        mov rdx, rax
        call biFromSignLenArray ; constructor of bigint
        ret
        
.differentSigns
        push rdi
        push rsi

        xor rcx, rcx
        mov ecx, [rsi + 4] ; len of b array
        mov rdx, [rsi + 8] ; ptr to b array

        xor rsi, rsi
        mov esi, [rdi + 4] ; len of a array
        mov rdi, [rdi + 8] ; ptr to a array
        
        call subUnsigned

        pop rsi
        pop rdi
        
        mov edi, [rdi]
        imul edi, r11D
        mov rsi, r8
        mov rdx, rax
        call biFromSignLenArray ; constructor of bigint
        ret


; void biAdd(BigInt a, BigInt b) { a += b }
; a in rdi
; b in rsi
biAdd:
    push rdi
    call biAddNew ; return new a + b
    pop rdi
    mov rsi, rax
    call biSwapAndDelete ; delete old a
    ret

; BigInt biSubNew(BigInt a, BigInt b) return a - b;
; a in rdi
; b in rsi
; result in rax
biSubNew:

    xor r8, r8
    cmp rdi, rsi ; next step I am going to do -- multiply b on -1. so, if a = b, then I need to copy a to another temporary BigInt
    jne .areNotEqual
    mov r8, 1 ; flag if a is copied
    push r8
    push rdi
    push rsi
    call biCopy
    pop rsi
    pop rdi
    pop r8
    mov rdi, rax ; a now is copied
    .areNotEqual
    push rdi
    push rsi
    push r8


    mov r8D, [rsi]
    imul r8D, -1 ; we are changing b bigInt
    mov [rsi], r8D
    push rsi
    push r8
    call biAddNew ; a - b is a + (-b) in fact
    pop r8    
    pop rsi
    imul r8D, -1 ; so we should return sign of b
    mov [rsi], r8D

    pop r8
    pop rsi
    pop rdi
    push rax
    cmp r8, 1 ; if we copied a, then
    jne .areNotEqual2
    call biDelete ; we need to delete it
    .areNotEqual2
    pop rax

    ret


; void biSub(BigInt a, BigInt b) { a -= b }
; a in rdi
; b in rsi
biSub:
    push rdi
    call biSubNew ; return new a - b
    pop rdi
    mov rsi, rax
    call biSwapAndDelete ; delete old a
    ret


; BigInt biMulNew(BigInt a, BigInt b) return a * b;
; a in rdi
; b in rsi
; result in rax
biMulNew:
    cmp dword [rdi], 0
    jnz .aIsNotZero
    mov rdi, 0 ; a = 0 -> result = 0
    call biFromInt
    ret
.aIsNotZero
    cmp dword [rsi], 0
    jnz .bIsNotZero
    mov rdi, 0 ; b = 0 -> result = 0
    call biFromInt
    ret
.bIsNotZero

    push rdi
    push rsi
    mov rdi, 16
    call malloc
    pop rsi
    pop rdi

    mov r8D, [rdi]
    mov [rax], r8D
    mov r8D, [rsi]
    mov r9D, [rax]
    imul r9D, r8D
    mov [rax], r9D ; rax now is correct sign
    
    xor rcx, rcx
    mov ecx, [rsi + 4] ; len of b array
    mov rdx, [rsi + 8] ; ptr to b array

    xor rsi, rsi
    mov esi, [rdi + 4] ; len of a array
    mov rdi, [rdi + 8] ; ptr to a array

    push rax
    call mulUnsigned
    mov r9, rax
    pop rax
    mov [rax + 4], r8 ; len
    mov [rax + 8], r9 ; ptr to data

    ret


; void biMul(BigInt a, BigInt b) { a *= b }
; a in rdi
; b in rsi
biMul:
    push rdi
    call biMulNew ; return new a * b
    pop rdi
    mov rsi, rax
    call biSwapAndDelete ; delete old a
    ret


; void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
; *quotient in rdi
; *remainder in rsi
; numerator in rdx
; denominator in rcx
biDivRem: ; it has not done yet
    ;push rdi
    ;push rsi
    ;xor rsi, rsi
    ;mov esi, [rcx + 4]
    ;mov rdi, [rcx + 8]
    ;call cmpWithZero
    ;pop rsi
    ;pop rdi
    ;test rax, rax
    ;jnz .isNotZero
    ;mov qword [rdi], 0
    ;mov qword [rsi], 0
    ;ret
    ;.isNotZero
    ret


; int biCmp(BigInt a, BigInt b);
; compares 2 BigInt's
; a in rdi
; b in rsi
; result in eax
biCmp:
    call biSubNew ; biCmp is equal to biSign(biSubNew(a - b))
    mov rdi, rax
    push rdi
    call biSign
    pop rdi
    push rax
    call biDelete
    pop rax
    ret
