section .text

extern malloc
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


biFromString:
    ret


biToString:
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
    mov r11, 1
    call cmpUnsigned
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
    mov rdi, rsi
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


biMulNew:
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
