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
;  int sign
;  int size
;  int64_t* data
;  base is 2^64


; BigInt biFromInt(int64_t x);
; create BigInt from one signed 64-bit integer
; x in rdi
; result in rax
biFromInt:
    push rbx
    push rdi
    mov rdi, 16 ; 4 + 4 + 8
    call malloc
    mov rbx, rax
    mov rdi, 8 ; one 8-byte integer
    call malloc
    pop rdi
    
    mov [rbx + 8], rax
    mov rax, rbx
    mov dword [rax + 4], 1
    
    mov dword [rax], 1 ; let's initially sign will be +
    cmp rdi, 0
    jne .isNotZero
    mov dword  [rax], 0
    jmp .signReady
.isNotZero
    jnl .signReady
    mov dword [rax], -1
    neg rdi
.signReady
    mov rbx, [rax + 8]
    mov [rbx], rdi

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
    mov rdi, 16 ; 4 + 4 + 8
    call malloc
    pop rdx
    pop rsi
    pop rdi
   
    mov [rax], edi
    mov [rax + 4], esi
    mov [rax + 8], rdx
   
    ret


; BigInt biCopy(BigInt a);
; copy BigInt in rdi
; a in rdi
; result in rax
biCopy:
    push rbx
    
    xor r8, r8
    push rdi
    mov rbx, rdi ; save rdi
    mov rdi, 16 ; 4 + 4 + 8
    call malloc
    mov r8D, [rbx]
    mov [rax], r8D ; sign is copied
    mov r8D, [rbx + 4]
    mov [rax + 4], r8D ; size is copied
    mov rbx, rax ; save pointer to BigInt
    lea rdi, [r8 * 8]
    call malloc
    pop rdi

    mov [rbx + 8], rax
    mov rax, rbx
    mov rdi, [rdi + 8] ; ptr to old data
    mov rsi, [rax + 8] ; ptr to new data

    xor rcx, rcx
    mov ecx, [eax + 4]
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
    mov r11, 1 ; sign
    mov r10, 0 ; len of string

    cmp byte [rdi], '-'
    jne .isPositive
    mov r11, -1
    inc rdi
.isPositive
    mov r8, 0
    .while
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
        mov rax, 0
        ret
    .break

    cmp r8, 0
    jne .isNotZero
        mov rdi, 0
        call biFromInt
        ret
    .isNotZero

    push r10
    push r11

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
        jz .break2

        push r8
        push r9
        push rcx
        push rax
        mov rdi, rax
        mov rsi, rcx
        mov rdx, 10
        call mulThisOnShort
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
        call addShortToThis
        pop rax
        pop rcx 
        pop r9
        pop r8

        inc r9
        jmp .while2
    .break2

    pop r11
    pop r10

    .while3
        cmp rcx, 1
        je .break3
        mov rdi, [rax + rcx * 8 - 8]
        cmp rdi, 0
        jne .break3
        dec rcx
        jmp .while3
    .break3

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
    .while
        dec rsi
        mov r8, [rdi + rsi * 8]
        test r8, r8
        jz .notOk
        mov rax, 1
        ret
        .notOk
        test rsi, rsi
        jnz .while
        mov rax, 0        
        ret


; void biToString(BigInt a, char *s, size_t limit);
; a in rdi
; s in rsi
; limit in rdx
biToString:
    cmp rdx, 1
    jg .greaterThanOne
    mov [rsi], byte 0
    ret
    .greaterThanOne
    push rsi
    push rdx
    push rdi
    xor r8, r8
    mov r8D, [rdi + 4]
    imul r8, 21
    mov rdi, r8
    call malloc ; rax -- ptr to string representation of BigInt
    pop rdi
    push rdi
    push rax
    call biCopy
    mov r11, rax ; r11 -- ptr to copy of BigInt
    pop rax
    pop rdi    
    pop rdx
    pop rsi
    mov rcx, [r11 + 8]

    push rax
    push r11
    push rdi
    push rsi
    push rdx
    mov rdi, rcx
    xor rsi, rsi
    mov esi, [r11 + 4]
    call cmpWithZero
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
    call free
    pop r11
    mov rdi, r11
    call biDelete
    ret
    .notZero

    mov r9D, [rdi]
    cmp r9D, -1
    jne .isPositive
    mov [rsi], byte '-'
    inc rsi
    dec rdx
    .isPositive

    ; r9 -- counter to pos in rax
    xor r9, r9
    .while
        push rax
        push r11
        push rdi
        push rsi
        push rdx
        mov rdi, rcx
        xor rsi, rsi
        mov esi, [r11 + 4]
        call cmpWithZero
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
        call divThisOnShort
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
        mov [rax + r9], cl
        pop rcx
   
        inc r9
        jmp .while
    .break

    .while2
        cmp rdx, 1
        je .break2
        dec r9
        push rdx
        mov dl, [rax + r9]
        mov [rsi], dl
        inc rsi
        pop rdx
        dec rdx
        test r9, r9
        jz .break2
        jmp .while2
    .break2
    mov [rsi], byte 0

    push r11
    mov rdi, rax
    call free
    pop r11    

    mov rdi, r11
    call biDelete
    ret


; void biDelete(BigInt a);
; a in rdi
biDelete:
    push rdi
    mov rdi, [rdi + 8]
    call free
    pop rdi
    call free
    ret


; int biSign(BigInt a);
; return sign of a
; a in rdi
; result in eax
biSign:
    xor rax, rax
    mov eax, [rdi]
    ret


; void biSwapAndDelete(BigInt a, BigInt b) {
;   a = b;
;   delete b;
; }
; a in rdi
; b in rsi
biSwapAndDelete:
    mov r8D, [rsi]
    mov [rdi], r8D
    mov r8D, [rsi + 4]
    mov [rdi + 4], r8D
    mov r8, [rsi + 8]
    mov [rdi + 8], r8
    mov rdi, rsi
    call free
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
    call malloc
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    
    xor r8, r8
    .while
        pushf
        cmp r8, rsi
        jng .whileIsNotEnded
        popf
        jmp .endWhile
        .whileIsNotEnded
        popf

        pushf
        mov qword [rax + r8 * 8], 0
        mov r9, 0
        cmp r8, rsi
        jnl .isOutOfBorderA
        mov r9, [rdi + r8 * 8]
        .isOutOfBorderA
        mov r10, 0
        cmp r8, rcx
        jnl .isOutOfBorderB
        mov r10, [rdx + r8 * 8]
        .isOutOfBorderB
        popf
        adc [rax + r8 * 8], r9
        adc [rax + r8 * 8], r10
        inc r8
        jmp .while
    .endWhile

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
    call calloc
    pop rcx
    pop rbx
    pop rsi
    pop rdi
    ; rax -- result array
    ; r8 -- i
    ; r9 -- j

    xor r8, r8
    .whileI
        cmp r8, rsi
        je .breakI

        xor r9, r9
        xor rdx, rdx
        .whileJ
            mov r10, rsi
            add r10, rcx
            sub r10, r8
            cmp r9, r10
            je .breakJ
            mov r10, r9
            add r10, r8
            add [rax + 8 * r10], rdx
            pushf
            xor rdx, rdx
            push rax
            mov rax, [rdi + r8 * 8]
            mov r11, 0
            cmp r9, rcx
            jnl .r9IsZero
            mov r11, [rbx + r9 * 8]
            .r9IsZero
            mul r11
            mov r11, rax       
            pop rax
            add [rax + 8 * r10], r11
            adc rdx, 0
            popf
            adc rdx, 0

            inc r9
            jmp .whileJ
        .breakJ
        inc r8
        jmp .whileI
    .breakI    

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
    cmp rsi, rcx
    je .equals
        jl .aIsLess
            mov rax, 1
            ret
        .aIsLess
            mov rax, -1
            ret 
    .equals
    
    mov r8, rsi
    .while
        dec r8
        mov r9, [rdi + r8 * 8]
        mov r10, [rdx + r8 * 8]
        cmp r9, r10
        je .equals2
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
    jne .isNotZero
        mov rdi, 0
        call biFromInt
        mov r8, 1
        mov r11, 0
        ret
.isNotZero
    jg .aIsBigger
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
    call malloc
    pop r11
    pop rcx
    pop rdx
    pop rsi
    pop rdi

    xor r8, r8
    .while
        pushf
        cmp r8, rsi
        jng .whileIsNotEnded
        popf
        jmp .endWhile
        .whileIsNotEnded
        popf

        pushf
        mov qword [rax + r8 * 8], 0
        mov r9, 0
        cmp r8, rsi
        jnl .isOutOfBorderA
        mov r9, [rdi + r8 * 8]
        .isOutOfBorderA
        mov r10, 0
        cmp r8, rcx
        jnl .isOutOfBorderB
        mov r10, [rdx + r8 * 8]
        .isOutOfBorderB
        mov [rax + r8 * 8], r9
        popf
        sbb [rax + r8 * 8], r10
        inc r8
        jmp .while
    .endWhile

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

    xor r8, r8
    xor rdx, rdx
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

    xor r8, r8
    mov r8D, esi
    xor rdx, rdx
    .while
        dec r8
        mov rax, [rdi + r8 * 8]
        div rcx
        mov [rdi + r8 * 8], rax
        test r8, r8
        jnz .while
    ret


; void addShortToThis(int64_t *a, int size, int64_t x);
; it consider that a is big enough to contain result
; a in rdi
; size in esi
; x in rdx
addShortToThis:
    xor r8, r8
    .while
        cmp r8D, esi
        je .break
        clc
        mov rax, [rdi + r8 * 8]
        mov qword [rdi + r8 * 8], rdx
        adc [rdi + r8 * 8], rax
        mov rdx, 0
        adc rdx, 0
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
    call biCopy
    ret
.aIsNotZero
    cmp dword [rsi], 0
    jnz .bIsNotZero
    call biCopy
    ret
.bIsNotZero
    mov r8D, [rdi]
    mov r9D, [rsi]
    cmp r8D, r9D
    jne .differentSigns
        push rdi
        push rsi

        xor rcx, rcx
        mov ecx, [rsi + 4]
        mov rdx, [rsi + 8]

        xor rsi, rsi
        mov esi, [rdi + 4]
        mov rdi, [rdi + 8]
        
        call addUnsigned

        pop rsi
        pop rdi
        
        mov edi, [rdi]
        mov rsi, r8
        mov rdx, rax
        call biFromSignLenArray
        ret
        
.differentSigns
        push rdi
        push rsi

        xor rcx, rcx
        mov ecx, [rsi + 4]
        mov rdx, [rsi + 8]

        xor rsi, rsi
        mov esi, [rdi + 4]
        mov rdi, [rdi + 8]
        
        call subUnsigned

        pop rsi
        pop rdi
        
        mov edi, [rdi]
        imul edi, r11D
        mov rsi, r8
        mov rdx, rax
        call biFromSignLenArray
        ret


; void biAdd(BigInt a, BigInt b) { a += b }
; a in rdi
; b in rsi
biAdd:
    push rdi
    call biAddNew
    pop rdi
    mov rsi, rax
    call biSwapAndDelete
    ret

; BigInt biSubNew(BigInt a, BigInt b) return a - b;
; a in rdi
; b in rsi
; result in rax
biSubNew:
    mov r8D, [rsi]
    imul r8D, -1
    mov [rsi], r8D
    push rsi
    push r8
    call biAddNew
    pop r8    
    pop rsi
    imul r8D, -1
    mov [rsi], r8D
    ret


; void biSub(BigInt a, BigInt b) { a -= b }
; a in rdi
; b in rsi
biSub:
    push rdi
    call biSubNew
    pop rdi
    mov rsi, rax
    call biSwapAndDelete
    ret


; BigInt biMulNew(BigInt a, BigInt b) return a * b;
; a in rdi
; b in rsi
; result in rax
biMulNew:
    cmp dword [rdi], 0
    jnz .aIsNotZero
    mov rdi, 0
    call biFromInt
    ret
.aIsNotZero
    cmp dword [rsi], 0
    jnz .bIsNotZero
    mov rdi, 0
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
    mov [rax], r9D
    
    xor rcx, rcx
    mov ecx, [rsi + 4]
    mov rdx, [rsi + 8]

    xor rsi, rsi
    mov esi, [rdi + 4]
    mov rdi, [rdi + 8]

    push rax
    call mulUnsigned
    mov r9, rax
    pop rax
    mov [rax + 4], r8
    mov [rax + 8], r9

    ret


; void biMul(BigInt a, BigInt b) { a *= b }
; a in rdi
; b in rsi
biMul:
    push rdi
    call biMulNew
    pop rdi
    mov rsi, rax
    call biSwapAndDelete
    ret


biDivRem:
    ret


; int biCmp(BigInt a, BigInt b);
; compares 2 BigInt's
; a in rdi
; b in rsi
; result in eax
biCmp:
    call biSubNew
    mov rdi, rax
    push rdi
    call biSign
    pop rdi
    push rax
    call biDelete
    pop rax
    ret
