extern calloc
extern malloc
extern free

; Improved pop
; Allows to use many pops in one command
%macro pops 1-* 
    %rep %0
        pop %1   
        %rotate 1           
    %endrep
%endmacro

; Improved push
; Allows to use many pushes in one command
%macro pushes 1-* 
    %rep %0
        push %1   
        %rotate 1           
    %endrep
%endmacro

global biFromInt, biFromString, biDelete, biAdd, biSub, biMul, biCmp, biSign, biDivRem, biToString

; results of biSign and biCmp are stored in eax, results of other functions are stored in rax.
; first operand (a) is usually stored in rdi. second operand (b, if it exists) in rsi

;---------------------------------
;-- int biSign(BigInt a); --
;---------------------------------
biSign:
    mov rax, 0
    mov eax, [rdi] ; sign of BigInt
    ret

; BigInt subtraction(BigInt a, BigInt b)
subtraction:
    mov r8, 0
    cmp rdi, rsi ; next step I am going to do - multiply b on -1. so, if a = b, then I need to copy a to another temporary BigInt
    jne .equality
    ; flag if a is copied
    mov r8, 1 
    pushes r8, rdi, rsi
    call copy
    pops rsi, rdi, r8
    ;  a now is copied
    mov rdi, rax 
    .equality
    pushes rdi, rsi, r8
    mov r8D, [rsi]
    ; we are changing b bigInt
    imul r8D, -1 
    mov [rsi], r8D
    pushes rsi, r8
    ; a - b <=> a + (-b) 
    call biAddNew 
    pops r8, rsi  
    ; we should return sign of b
    imul r8D, -1 
    mov [rsi], r8D

    pops r8, rsi, rdi
    push rax
    cmp r8, 1 ; if we copied a, then
    jne .equality_
    call biDelete ; we need to delete it
    .equality_
    pop rax
    ret
    
; BigInt copy(BigInt a);
copy:
    push rbx; store rbx (convention)
    mov r8, 0
    push rdi
    mov rbx, rdi; save rdi
    mov rdi, 16
    test rsp, 15
    jz .malloc_loop
    push rdi
    call malloc
    pop rdi
    jmp end
    .malloc_loop
    call malloc
    end:
    mov r8D, [rbx]
    mov [rax], r8D; sign is copied
    mov r8D, [4 + rbx]
    mov [4 + rax], r8D;size is copied
    mov rbx, rax; save pointer to BigInt
    lea rdi, [r8 * 8]
    test rsp, 15
    jz .malloc_loop
    push rdi
    call malloc
    pop rdi
    jmp l
    .malloc_loop
    call malloc
    l:
    
    ; rax now is new data array
    pop rdi
    mov [8 + rbx], rax ; data ptr is assigned
    mov rax, rbx; rax now is ptr to BigInt
    mov rdi, [8 + rdi] ; ptr to old data
    mov rsi, [8 + rax] ; ptr to new data
    mov rcx, 0
    mov ecx, [4 + rax] ; rcx - counter copying data
    .loop
    sub rcx, 1
    mov r8, [8 * rcx + rdi]
    mov [8 * rcx + rsi], r8        
    test rcx, rcx
    jnz .loop
    pop rbx
    ret

;----------------------------------------------
;-- int biCmp(BigInt a, BigInt b); --
;----------------------------------------------
biCmp:
    call subtraction ; result = biSign(a - b)
    mov rdi, rax
    push rdi
    call biSign
    pop rdi
    push rax
    call biDelete
    pop rax
    ret 
;-------------------------------------------
;-- BigInt biFromInt(int64_t x); --
;-------------------------------------------
biFromInt:
    ; save rbx 
    pushes rbx, rdi 
    mov rdi, 16 ; 4 + 4 + 8 allocate bytes
    test rsp, 15
    jz .malloc_loop
    push rdi
    call malloc
    pop rdi
    jmp m
    .malloc_loop
    call malloc
    m:
    
    mov rbx, rax ; rbx now ptr to BigInt
    mov rdi, 8 ; one 8-byte integer
    test rsp, 15
    jz .malloc_loop
    push rdi
    call malloc
    pop rdi
    jmp mark
    .malloc_loop
    call malloc
    mark:
     ; rax now ptr to data array
    pop rdi
    
    mov [8 + rbx], rax ; ptr to data is assigned
    mov rax, rbx ; rax - ptr to BigInt
    mov dword [4 + rax], 1 ; size is 1
    
    mov dword [rax], 1 ; initially sign will be +
    cmp rdi, 0
    jne .not_zero
    mov dword  [rax], 0 ; x = 0 => sign = 0
    jmp .signReady
.not_zero
    jnl .signReady
    mov dword [rax], -1 ; if x < 0 then sign = -
    neg rdi
.signReady
    mov rbx, [8 + rax]
    mov [rbx], rdi ; put x in data
    pop rbx    
    ret
    
; BigInt biFromSignLenArray(int sign, int len, int64_t *a);
biFromSignLenArray:
     ; args - edi, esi, rdx
    pushes rdi, rsi, rdx
    mov rdi, 16 ; 4 + 4 + 8 allocate bytes
    test rsp, 15
    jz .malloc_loop
    push rdi
    call malloc
    pop rdi
    jmp mark1
    .malloc_loop
    call malloc
    mark1:
    pops rdx, rsi, rdi
     ; sign
    mov [rax], edi
     ; size
    mov [4 + rax], esi
     ; data
    mov [8 + rax], rdx
    ret
 
;-------------------------------------------------------
;-- BigInt biFromString(char const *s); --
;-------------------------------------------------------
biFromString:
    mov r11, 1 ; sign (initially 1)
    mov r10, 0 ; len of string
    cmp byte [rdi], '-'
    jne .plus
    mov r11, -1 ; negative number
    add rdi, 1 ; move ptr to a
.plus
    mov r8, 0 ; r8 - counter on a
    .loop ; this loop tests if in string exists non-zero char  
        mov al, [rdi + r10]
        test al, al
        jz .done
        cmp al, '0'
        jl .fail
        cmp al, '9'
        jg .fail
        cmp al, '1'
        jl .isZero
        add r8, 1
        .isZero
        add r10, 1
        jmp .loop
        .fail
        mov rax, 0 ; string contains some prohibited symbols
        ret
    .done

    cmp r8, 0
    jne .not_zero
    cmp r10, 0
    jne .zero
    mov rax, 0
    ret
     .zero
    mov rdi, 0 ; if a = 0 then return immediatly
    call biFromInt
    ret
    .not_zero
    ; r10 - len, r11 - sign
    pushes r10, r11, rdi
    mov rdi, r10
    shr rdi, 4 ; if number consist of x digits then it will be packed in x / 16 + 1 longs
    add rdi, 1
    mov rcx, rdi
    push rcx
    mov rsi, 8
    test rsp, 15
    jz .calloc_loop
    push rdi
    call calloc
    pop rdi
    jmp label
    .calloc_loop
    call calloc
    label:
    ; rax now - array of longs
    ; rcx - len of array of longs
    pops rcx, rdi 
    mov r8, rdi ; ptr to string

    mov r9, 0 ; counter
    .loop_cycle
        mov dl, [r8 + r9]
        test dl, dl
        jz .end ; zero byte => end of string
        ; save all needed registers
        pushes r8, r9, rcx, rax
 
        mov rdi, rax
        mov rsi, rcx
        mov rdx, 10
        call mulThisOnShort ; multiply current number by 10
        pops rax, rcx, r9, r8
        pushes r8, r9, rcx, rax
        mov rdi, rax
        mov rsi, rcx
        mov rdx, 0
        mov dl, [r8 + r9]
        sub dl, '0'
        call addShortToThis ; add s[i] - '0' to current number
        pops rax, rcx, r9, r8
        add r9, 1
        jmp .loop_cycle
    .end
    pops r11, r10

    ; it deletes leading zeroes
    .loop_delete
        cmp rcx, 1
        je .done
        mov rdi, [rax + rcx * 8 - 8]
        cmp rdi, 0
        jne .done
        sub rcx, 1
        jmp .loop_delete
    .done

    ; call constructor of bigint
    mov rdi, r11
    mov rsi, rcx
    mov rdx, rax
    call biFromSignLenArray
    ret

; int compare_z(int *a, int size);
; return 0 if a is array of zeroes and 1 else
compare_z:
    .loop ; rsi is loop-counter
        sub rsi, 1
        mov r8, [rdi + rsi * 8]
        test r8, r8
        jz .notOk
        mov rax, 1 ; if found non-zero element return 1
        ret
        .notOk
        test rsi, rsi
        jnz .loop ; end of cycle
    mov rax, 0        
    ret

;----------------------------------------------------------------------
;-- void biToString(BigInt a, char *s, size_t limit); --
;----------------------------------------------------------------------
biToString:
    ; limit in rdx
    cmp rdx, 1
    jg .greaterThanOne
    mov [rsi], byte 0 ; if limit <= 1 then return zero string immediatly
    ret
    .greaterThanOne
    pushes rsi, rdx, rdi
    mov r8, 0
    mov r8D, [rdi + 4]
    imul r8, 21 ; if BigInt consists of x 64-bit fields than it will be approximately ~21 * x chars long in decimal representation
    mov rdi, r8
    ; rax - ptr to string representation of BigInt
    test rsp, 15
    jz .malloc_loop
    push rdi
    call malloc
    pop rdi
    jmp done
    .malloc_loop
    call malloc
    done:
    
    pop rdi 
    pushes rdi, rax
    call copy ; copy array to modify it
    mov r11, rax ; r11 - ptr to copy of BigInt
    pops rax, rdi, rdx, rsi
    mov rcx, [r11 + 8] ; rcx now is ptr to array which we divide by 10
    pushes rax, r11, rdi, rsi, rdx, rcx
    mov rdi, rcx
    mov rsi, 0
    mov esi, [r11 + 4]
    call compare_z ; if zero then we can put '0' and return immediatly
    pops rcx, rdx, rsi, rdi, r11
    test rax, rax
    pop rax
    jnz .notZero
    mov byte [rsi], '0'
    mov byte [rsi + 1], 0
    push r11
    mov rdi, rax
    ; free temp array
    test rsp, 15
    jz .free_loop1
    push rdi
    call free
    pop rdi
    jmp .go
    .free_loop1
    call free
    .go
    pop r11
    mov rdi, r11
    call biDelete ; free copied BigInt
    ret
    .notZero

    mov r9D, [rdi]
    cmp r9D, -1
    jne .plus ; if BigInt is negative then first char is '-'
    mov [rsi], byte '-'
    add rsi, 1
    add rdx, -1
    .plus
 
    ; r9 - counter to pos in rax
    mov r9, 0 ; fill rax (decimal representation)
    .loop
        pushes rax, r11, rdi, rsi, rdx
        mov rdi, rcx
        mov rsi, 0
        mov esi, [r11 + 4]
        call compare_z ; if zero then done
        pops rdx, rsi, rdi, r11
        test rax, rax
        pop rax
        jz .done
        
        pushes rcx, rax, r11, rdi, rsi, rdx
        mov rdi, rcx
        mov rsi, 0
        mov esi, [r11 + 4]
        mov rdx, 10
        call divThisOnShort ; divide by 10
        mov r8, rdx
        pops rdx, rsi, rdi, r11, rax, rcx

        push rcx
        mov rcx, r8
        add cl, '0'
        mov [rax + r9], cl ; x mod 10 is writen
        pop rcx
        add r9, 1
        jmp .loop
    .done

    ; copy limit (rdx) symbols from rax to rsi
    .loop2
        cmp rdx, 1
        je .done2 ; done if only 0 char is left
        sub r9, 1
        push rdx
        mov dl, [rax + r9]
        mov [rsi], dl ; copy current char
        add rsi, 1
        pop rdx
        add rdx, -1
        test r9, r9 ; done if decimal representation is ended
        jz .done2
        jmp .loop2
    .done2
    mov [rsi], byte 0 ; terminal symbol

    push r11
    mov rdi, rax
    ; free temp array
    test rsp, 15
    jz .free_loop
    push rdi
    call free
    pop rdi
    jmp m1
    .free_loop
    call free
    m1:
    pop r11    
    mov rdi, r11
    call biDelete ; free BigInt copy
    ret
    
;---------------------------------------
;-- void biDelete(BigInt a); --
;---------------------------------------
biDelete:
    push rdi
    mov rdi, [rdi + 8]
    ; free data array
    test rsp, 15
    jz .free_loop
    push rdi
    call free
    pop rdi
    jmp m2
    .free_loop
    call free
    m2:
    pop rdi
    ; free ptr to BigInt
    test rsp, 15
    jz .free_loop
    push rdi
    call free
    pop rdi
    jmp m3
    .free_loop
    call free
    m3:
    ret


; void biSwapAndDelete(BigInt a, BigInt b) 
biSwapAndDelete:
    mov r8D, [rsi]
    mov [rdi], r8D ; swap sign
    mov r8D, [rsi + 4]
    mov [rdi + 4], r8D ; swap len
    pushes rdi, rsi
    mov rdi, [rdi + 8]
    ; free old array
    test rsp, 15
    jz .free_loop
    push rdi
    call free
    pop rdi
    jmp m4
    .free_loop
    call free
    m4:
    pops rsi, rdi

    mov r8, [rsi + 8]
    mov [rdi + 8], r8 ; swap data
    mov rdi, rsi
    ; free ptr to b
    test rsp, 15
    jz .free_loop
    push rdi
    call free
    pop rdi
    jmp m5
    .free_loop
    call free
    m5:
    ret


; int64_t* addUnsigned(int64_t *a, int len_a, int64_t *b, int len_b);
; args - rdi (a), rsi (len_a), rdx(b), rcx(len_b)
addUnsigned:
    cmp rsi, rcx
    jnl .first_greater
    xchg rdi, rdx
    xchg rsi, rcx
.first_greater
    pushes rdi, rsi, rdx, rcx
    lea rdi, [rsi + 1]
    imul rdi, 8
    ; new array - sizeof(unsigned long long) * (a.size + 1) bytes
    test rsp, 15
    jz .malloc_loop
    push rdi
    call malloc
    pop rdi
    jmp finish
    .malloc_loop
    call malloc
    finish:
    pops rcx, rdx, rsi, rdi
    ; r8 - counter on current data element. r11 - carry.
    mov r8, 0 
    mov r11, 0 
    .loop
        cmp r8, rsi
        jng .continue
        jmp .endloop
        .continue
        mov qword [8 * r8 + rax], 0
         ; r9 = a[i], if i < a.length, and 0 otherwise
        xor r9, r9
        cmp r8, rsi
        jnl .over_a
        mov r9, [8 * r8 + rdi]
        .over_a
        ; r10 = b[i], if i < b.length, and 0 otherwise
        mov r10, 0 
        cmp r8, rcx
        jnl .over_b
        mov r10, [8 * r8 + rdx]
        .over_b
         ; c[i] = a[i] (r9) + b[i] (r10) + carry (r11)
        add [8 * r8 + rax], r11
        pushf
        ; carry := 0, and see for carry on next iteration
        mov r11, 0 
        popf
        adc r11, 0
        add [8 * r8 + rax], r9
        adc r11, 0
        add [8 * r8 + rax], r10
        adc r11, 0
        add r8, 1
        jmp .loop
    .endloop

    ; delete leading zeroes in number
    lea r8, [rsi + 1]
    .loop2
        cmp r8, 1
        je .loop2End
        cmp qword [rax + r8 * 8 - 8], 0
        jne .loop2End
        add r8, -1
        jmp .loop2
    .loop2End
    ret

; int64_t* mulUnsigned(int64_t *a, int len_a, int64_t *b, int len_b);
; args - rdi (a) , rsi (len_a), rdx (b), rcx (len_b). r8, r9 - registers for counters. carry - rdx
; for r8 = 0; r8 < len_a; r8++
;   for r9 = 0; r8 + r9 < len_a + len_b; r9++
;     c[r8 + r9] := c[r8 + r9] + carry
;     carry := ^overflow
;     base = 2^64
;     c[r8 + r9] := c[r8 + r9] + a[r8]*b[r9] % 2^64 
;     carry = a[r8] * b[r9] / 2^64 + ^overflow
mulUnsigned:
    cmp rsi, rcx
    jnl .first_greater
    xchg rdi, rdx
    xchg rsi, rcx
.first_greater
    push rbx
    mov rbx, rdx
    pushes rdi, rsi, rbx, rcx
    mov r8, 0
    add r8D, esi
    add r8D, ecx
    mov rdi, r8
    mov rsi, 8
    ; 8 * (a.length + b.length) bytes
    test rsp, 15
    jz .calloc_loop
    push rdi
    call calloc
    pop rdi
    jmp close
    .calloc_loop
    call calloc
    close:
    pops rcx, rbx, rsi, rdi
    ; counter initialization
    mov r8, 0 
    .loopI
        cmp r8, rsi
        je .doneI
        ; counter initialization
        mov r9, 0 ; 
        ; carry initialization
        mov rdx, 0 
        .loopJ
            mov r10, rsi
            add r10, rcx
            sub r10, r8
            cmp r9, r10
            je .doneJ ; r8 + r9 < len_a + len_b
            mov r10, r9
            add r10, r8 ; r10 = r8 + r9
            add [rax + 8 * r10], rdx
            ; remember carry from this step not to forget
            pushf 
            mov rdx, 0
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
            add [rax + 8 * r10], r11 ; += a[r8] * b[r9] % 2^64
            adc rdx, 0 ; += a[r8] * b[r9] / 2^64
            popf
            adc rdx, 0 ; += carry
            add r9, 1
            jmp .loopJ
        .doneJ
        add r8, 1
        jmp .loopI
    .doneI    

    ; delete leading zeroes
    lea r8, [rcx + rsi]
    .loop2
        cmp r8, 1
        je .loop2End
        cmp qword [8 * r8 + rax - 8], 0
        jne .loop2End
        add r8, -1
        jmp .loop2
    .loop2End
    pop rbx
    ret

; int64_t* subUnsigned(int64_t *a, int len_a, int64_t *b, int len_b);
; args - rdi, rsi, rdx, rcx
subUnsigned:
    call cmpUnsigned
     ; len of array in r8
     ; sign to multiply in r11
    mov r11, 1
    cmp rax, 0
    jne .not_zero ; if a=b then return 0
        mov rdi, 8
        test rsp, 15
        jz .malloc_loop1
        push rdi
        call malloc
        pop rdi
        jmp .continue
         .malloc_loop1
        call malloc
         .continue
        mov qword [rax], 0
        mov r11, 0
        mov r8, 1
        ret
.not_zero
    ; a should be greater
    jg .first_greater
    xchg rdi, rdx
    xchg rsi, rcx
    mov r11, -1 
.first_greater
    pushes rdi, rsi, rdx, rcx, r11
    mov rdi, rsi
    imul rdi, 8
    ; result will be 8 * a.length bytes
    test rsp, 15
    jz .malloc_loop
    push rdi
    call malloc
    pop rdi
    jmp tail
     .malloc_loop
    call malloc
    tail:
    pops r11, rcx, rdx, rsi, rdi
    push r11
     ; r8 - counter to cur element
    mov r8, 0
    ; r11 will be carry
    mov r11, 0 
    .loop
        cmp r8, rsi
        jl .loopIsNotEnded
        jmp .endloop
        .loopIsNotEnded

        mov qword [8 * r8 + rax], 0
        mov r9, 0
        cmp r8, rsi
        jnl .over_a
        ; a[i]
        mov r9, [8 * r8 + rdi] 
        .over_a
        mov r10, 0
        cmp r8, rcx
        jnl .over_b
        ; b[i]
        mov r10, [8 * r8 + rdx] 
        .over_b
         ; c[i] = a[i] - b[i] - carry
        mov [8 * r8 + rax], r9
        sub [8 * r8 + rax], r11
        pushf
        mov r11, 0
        popf
        adc r11, 0
        sub [rax + r8 * 8], r10
        adc r11, 0
        add r8, 1
        jmp .loop
    .endloop
    pop r11

    ; remove leading zeroes
    mov r8, rsi
    .loop2
        cmp r8, 1
        je .loop2End
        cmp qword [r8 * 8 + rax - 8], 0
        jne .loop2End
        sub r8, 1
        jmp .loop2
    .loop2End
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
    
    mov r8, rsi ; r8 - index from high data elements to low
    .loop
        sub r8, 1
        mov r9, [r8 * 8 + rdi]
        mov r10, [r8 * 8 + rdx]
        cmp r9, r10
        je .equals2 ; if a[i] != b[i] then we know which is less
            jb .aIsLess2
                mov rax, 1
                ret
            .aIsLess2
                mov rax, -1
                ret             
        .equals2
        test r8, r8
        jnz .loop
    mov rax, 0
    ret

    
    
;-------------------------------------------------------------------------------------------------------------------------------------    
;-- void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator); --
;------------------------------------------------------------------------------------------------------------------------------------- 
biDivRem: 
     ; args - rdi, rsi, rdx, rcx
    pushes rdi, rsi, rdx, rcx
    mov rsi, 0
    mov rdi, [8 + rcx]
    mov esi, [4 + rcx]
    call compare_z
    pops rcx, rdx, rsi, rdi
    test rax, rax
    ; if denominator is 0 => return (NULL, NULL)
    jnz .compare 
        mov qword [rsi], 0
        mov qword [rdi], 0
        ret
    .compare
    cmp rdx, rcx
    jne .equality ; I will temporary modify num and denom, so their ptr should'n be equal
        pushes rdi, rsi
        mov rdi, 1
        call biFromInt ; quotient = 1
        push rax
        mov rdi, 0
        call biFromInt ; remainder = 0
        mov r9, rax
        pop rax
        mov r8, rax
        pops rsi, rdi
        mov [rdi], r8
        mov [rsi], r9
        ret 
    .equality
    
    ; if denom < 0
    cmp dword [rcx], 0
    jnl .loop_d
         ; nom *= -1
        neg dword [rdx]
         ; denom *= -1
        neg dword [rcx]
        pushes rsi, rdi, rcx, rdx
         ; a/b unsigned
        call biDivRem 
        pops rdx, rcx, rdi, rsi
         ; restore signs
        neg dword [rdx] 
        neg dword [rcx]
        mov r8, [rsi]
        ; remainder is actual negative
        neg dword [r8]
        ret        
    
    ; denominator > 0
    .loop_d
    ; if nom is < 0
    cmp dword [rdx], 0
    jnl .loop_n
         ; nom *= -1	
        neg dword [rdx]
        pushes rsi, rdi, rcx, rdx
         ; a/b unsigned
        call biDivRem 
        pops rdx, rcx, rdi, rsi
         ; nom *= -1	
        neg dword [rdx]
        ; restore signs
        mov r8, [rdi] 
        ; quotient *= -1	
        neg dword [r8]
        ; restore signs
        mov r8, [rsi] 
        pushes rdi, rsi, rdx, rcx
        mov rsi, 0
        mov esi, [r8 + 4]
        mov rdi, [r8 + 8]
         ; if remainder is 0, no need for next step
        call compare_z 
        pops rcx, rdx, rsi, rdi
        test rax, rax
        jz .entirely
        mov r8, [rsi]
        pushes rdi, rsi, rdx, rcx
        mov rdi, r8
        mov rsi, rcx
        call biSub
        pops rcx, rdx, rsi, rdi
        mov r8, [rsi]
        neg dword [r8]
        push rdi
        mov rdi, 1
        call biFromInt
        mov rsi, rax
        pop rdi
        push rax
        mov rdi, [rdi]
        call biSub
        pop rax
        mov rdi, rax
        call biDelete
         .entirely
        ret
    .loop_n
    ; let's find c = a / b, d = a % b
    ; let's find min r12 >= 0 that a < b * 2^r12. and
    ; b *= 2^(r12)
    ; r15 = 2^(r12)
    ; for (i = r12; i > 0; i--, b/=2, (r15)/=2) 
    ;   if (a >= b) 
    ;     a := a - b
    ;     c := c + r15
    ; d := a - c * b
    ; store all registers. 
    pushes rdi, rsi, rdx, rcx, r12, r13, r14, r15, rbx, rdx, rcx
    ; r13, r14 - copied values of a and b 
    mov r13, rdx
    mov r14, rcx

    mov rdi, r13
    call copy ; a
    mov r13, rax
    mov rdi, r14
    call copy ; b
    mov r14, rax
    mov r12, 0 ; k
    mov rdi, 1
    call biFromInt ; toAdd
    mov r15, rax
    mov rdi, 2
    call biFromInt ; 2
    mov rbx, rax

    .loop
        mov rdi, r13
        mov rsi, r14
        call biCmp
        cmp eax, 0
        jl .done ; done when a < b*2^k
        mov rdi, r14
        mov rsi, rbx
        call biMul ; b *= 2
        mov rdi, r15
        mov rsi, rbx
        call biMul ; toAdd *= 2
        add r12, 1
        jmp .loop
    .done
    mov r8, [rbx + 8]
    mov qword [r8], 0 ; rbx: 2 => 0, now it is c (quotient)
    
    .loop2
        add r12, -1
        cmp r12, -1
        je .done2 ; done if k = -1

        mov rdi, r14
         ; b >>= 1
        call biShrUnsignedPartBy1
        mov rdi, r15
        ; toAdd >>= 1
        call biShrUnsignedPartBy1 
        mov rdi, r13
        mov rsi, r14
        ; (a>=b) => a -= b, ans += toAdd
        call biCmp 
        cmp eax, 0
        jl .aIsLess
            mov rdi, r13
            mov rsi, r14
            call biSub
            mov rdi, rbx
            mov rsi, r15
            call biAdd
        .aIsLess

        jmp .loop2
    .done2
    ; rbx now is quotient

    mov rdi, r13
    call biDelete
    mov rdi, r14
    call biDelete 
    mov rdi, r15
    call biDelete

    pops rcx, rdx
    ; new copying of a and b
    mov r14, rcx
    mov r13, rdx 
    mov rdi, r13
    call copy ; copy a
    mov r13, rax
    mov rdi, r14
    call copy ; copy b
    mov r14, rax
    mov rdi, r14
    mov rsi, rbx
    ; remainder = a - quotient * b
    call biMul ; b * quotient
    mov rdi, r13
    mov rsi, r14
    call biSub ; r13 now is remainder
    mov rdi, r14
    call biDelete
    mov r8, rbx ; quotient
    mov r9, r13 ; remainder
    pops rbx, r15, r14, r13, r12, rcx, rdx, rsi, rdi
    mov [rdi], r8
    mov [rsi], r9
    ret

; void mulThisOnShort(int64_t *a, int size, int64_t x);
; args - rdi, esi, rdx
mulThisOnShort:
    mov rcx, rdx
    mov r8, 0 ; r8 is index i on current element
    mov rdx, 0 ; rdx is carry
    .loop
    cmp r8D, esi
    je .done
    mov rax, [r8 * 8 + rdi]
    mov qword [r8 * 8 + rdi], rdx
    mul rcx
    add [r8 * 8 + rdi], rax
    adc rdx, 0
    add r8, 1
    jmp .loop
    .done
    ret

; void divThisOnShort(int64_t *a, int size, int64_t x);
; args - rdi, esi, rdx
divThisOnShort:
     ; remainder at rdx
    mov rcx, rdx
    ; r8 is counter on current element
    mov r8, 0 
    mov r8D, esi
    mov rdx, 0 ; rdx - carry
    .loop
        sub r8, 1
        mov rax, [r8 * 8 + rdi]
        div rcx
        mov [r8 * 8 + rdi], rax
        test r8, r8
        jnz .loop
    ret


; void addShortToThis(int64_t *a, int size, int64_t x);
; args - rdi, esi, rdx 
addShortToThis:
    mov r8, 0 ; counter to cur element
    .loop
        cmp r8D, esi
        je .done
        mov rax, [rdi + r8 * 8]
        mov qword [8 * r8 + rdi], rdx
        add [r8 * 8 + rdi], rax
        mov rdx, 0
        adc rdx, 0 ; rdx is initially x to add, and later is carry
        add r8, 1
        jmp .loop
    .done
    ret


; BigInt biAddNew(BigInt a, BigInt b) return a + b;
biAddNew:
    cmp dword [rdi], 0
    jnz .anot_zero
    mov rdi, rsi
    call copy ; if a is zero return b
    ret
.anot_zero
    cmp dword [rsi], 0
    jnz .bnot_zero
    call copy ; if b is zero return a
    ret
.bnot_zero
    mov r8D, [rdi]
    mov r9D, [rsi]
    cmp r8D, r9D
    jne .differentSigns
        pushes rdi, rsi ; if signs are equal then add
        mov rcx, 0
        mov ecx, [rsi + 4] ; len of b array
        mov rdx, [rsi + 8] ; ptr to b array

        mov rsi, 0
        mov esi, [rdi + 4] ; len of a array
        mov rdi, [rdi + 8] ; ptr to a array
        call addUnsigned
        pops rsi, rdi
        
        mov edi, [rdi]
        mov rsi, r8
        mov rdx, rax
        call biFromSignLenArray ; constructor of bigint
        ret
        
.differentSigns
        pushes rdi, rsi
        mov rcx, 0
        ; len of b array
        mov ecx, [4 + rsi] 
        ; ptr to b array
        mov rdx, [8 + rsi] 
        mov rsi, 0
        ; len of a array
        mov esi, [4 + rdi] 
         ; ptr to a array
        mov rdi, [8 + rdi]  
        call subUnsigned
        pops rsi, rdi
        
        mov edi, [rdi]
        imul edi, r11D
        mov rsi, r8
        mov rdx, rax
        call biFromSignLenArray ; constructor of bigint
        ret

;-------------------------------------------
; void biMul(BigInt a, BigInt b) -
;-------------------------------------------
biMul:
    push rdi
    call biMulNew ; return new a * b
    pop rdi
    mov rsi, rax
    call biSwapAndDelete ; delete old a
    ret

biMulNew:
    cmp dword [rdi], 0
    jnz .not_zero_first
    ; a = 0 => result = 0
    mov rdi, 0 
    call biFromInt
    ret
.not_zero_first
    cmp dword [rsi], 0
    jnz .not_zero_second
    ; b = 0 => result = 0
    mov rdi, 0 
    call biFromInt
    ret
.not_zero_second
    pushes rdi, rsi
    mov rdi, 16
    test rsp, 15
    jz .malloc_loop
    push rdi
    call malloc
    pop rdi
    jmp stop
     .malloc_loop
    call malloc
    stop:
    pops rsi, rdi
    mov r8D, [rdi]
    mov [rax], r8D
    mov r8D, [rsi]
    mov r9D, [rax]
    imul r9D, r8D
     ; rax now is correct sign
    mov [rax], r9D
    mov rcx, 0
    ; len of b array
    mov ecx, [4 + rsi] 
    ; ptr to b array
    mov rdx, [8 + rsi] 
    mov rsi, 0
    ; len of a array
    mov esi, [4 + rdi] 
     ; ptr to a array
    mov rdi, [8 + rdi]
    push rax
    call mulUnsigned
    mov r9, rax
    pop rax
     ; len
    mov [4 + rax], r8
     ; ptr to data
    mov [8 + rax], r9 
    ret    
;----------------------------------------------
;-- void biAdd(BigInt a, BigInt b) --
;----------------------------------------------
biAdd:
    push rdi
    call biAddNew ; return new a + b
    pop rdi
    mov rsi, rax
    call biSwapAndDelete ; delete old a
    ret
;----------------------------------------------    
;-- void biSub(BigInt a, BigInt b) --
;----------------------------------------------
biSub:
    push rdi
    call subtraction ; return new a - b
    pop rdi
    mov rsi, rax
    call biSwapAndDelete ; delete old a
    ret

; void biShrUnsignedPartBy1(BigInt a)
; shr data by 1
biShrUnsignedPartBy1:
    push rdi
    mov rsi, 0
    mov esi, [4 + rdi]
    mov rdi, [8 + rdi]
    mov rdx, 2
    call divThisOnShort ; divide by 2 is equal to shr 1
    pop rdi
    mov rax, [8 + rdi]
    mov r8, 0
    mov r8D, [4 + rdi]    
    ; remove leading zeroes, because library depends on it
    .loop2
        cmp r8, 1
        je .loop2End
        cmp qword [r8 * 8 + rax - 8], 0
        jne .loop2End
        add r8, -1
        jmp .loop2
    .loop2End
    mov [4 + rdi], r8D
    ret
