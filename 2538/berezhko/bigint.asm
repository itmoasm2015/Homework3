default rel

section .text

extern malloc, calloc, strlen, free, memcpy

global biFromInt
global biFromString
global biDelete
global biToString
global biSign
global biCmp
global biAdd
global biSub
global biMul

BASE equ 1000000000

; BigInt:
;   1 64bit number - address to values array
;
; values:
;   values[0] - sign
;   values[1] - bigdigits count
;   values[2..values[1]+1] - bigdigits
;
; Bigdigit is 32bit number with BASE = 10**9
; Sign = -1 if BigInt < 0
;      =  1 if BigInt > 0
;      =  0 if BigInt == 0


; Create BigInt with one memory cell for address to values
;
; Output:
;   rax - address of BigInt
%macro biCreate 0
        push rdi
        push rsi
        mov rdi, 8   ; size of address to values
        call malloc
        pop rsi
        pop rdi
%endmacro

; Divide rax by BASE and write reminder to [%1+4*%2]
;
; Output:
;   rax = rax/BASE
%macro remToI 2
        xor rdx, rdx        ; rdx = 0
        mov r10, BASE
        div r10             ; rax = x/BASE, rdx = x%BASE
        mov [%1+4*%2], edx
%endmacro

; Delete leading nils from BigInt
;
; Input:
;   %1 - BigInt.values
%macro deleteNils 1
        mov ecx, [%1+4] ; ecx = size
        %%loop:
        sub ecx, 1
        cmp ecx, 0
        je %%overit

        xor rdx, rdx
        cmp [%1+(2+rcx)*4], edx ; compare with 0
        jne %%overit

        mov edx, [%1+4]         ; edx = size
        sub edx, 1              ; edx--
        mov [%1+4], edx         ; decrease digit count

        jmp %%loop
        %%overit:
%endmacro

; Check BigInt equals to
;
; Input:
;   %1 - BigInt.values
; Output:
;   rax = 1 if %1 equals to 0
;   rax = 0 otherwise
%macro isNull 1
        mov eax, [%1+4] ; eax = size
        cmp eax, 1
        jne %%ret_false ; size != 1
        mov eax, [%1+8] ; eax = first bigdigit
        cmp eax, 0
        jne %%ret_false ; if isn't 0, return false
        mov eax, 0
        mov [%1], eax   ; update sign
        mov rax, 1
        jmp %%finish
        %%ret_false:
        xor rax, rax
        %%finish:
%endmacro

; Subtract 9 from %1 and put result to %1. If result is less than 0, then result = 0
%macro sub9 1
        sub %1, 9
        cmp %1, 0
        jge %%finish
        mov %1, 0
        %%finish:
%endmacro

; Allocate memory for BigInt.values with %1 bigdigits
%macro callocNDigits 1
        push rdi
        push rsi
        mov rdi, %1     ; rdi = numbers count
        add rdi, 2      ; for sign and bigdigits count
        mov rsi, 4      ; 32bit
        call calloc
        pop rsi
        pop rdi
%endmacro

; Calc digits count
;
; Input:
;   %1 - number for calc
; Output:
;   rax - digits count of %1
%macro getDigitsCount 1
        push rbx
        mov rax, %1     ; rax = %1
        xor r9, r9
        %%loop:
        inc r9          ; cnt++
        mov ebx, 10
        xor rdx, rdx
        div ebx         ; rax /= 10
        cmp rax, 0      ; if rax == 0, break
        je %%finish
        jmp %%loop
        %%finish:
        mov rax, r9     ; rax = cnt
        pop rbx
%endmacro

; Raise 10 to the power of %1
;
; Input:
;   %1 - power of
; Output:
;   rax = 10 ** %1
%macro power10 1
        push r12
        push rbx
        mov r12, %1     ; r12 = power
        xor rax, rax    ; rax = 0
        mov eax, 1      ; eax = 1
        %%loop:
        cmp r12, 0
        je %%finish
        sub r12, 1      ; power--
        mov ebx, 10
        mul ebx         ; eax *= 10
        jmp %%loop
        %%finish:
        pop rbx
        pop r12
%endmacro

; Create a BigInt from 64-bit signed integer.
;
; Input:
;   rdi - int64_t x
; Output:
;   rax - BigInt result
biFromInt:
    push rbx

    mov esi, 1      ; sign = 1

    cmp rdi, 0      ; x ? 0
    jge .positive

    mov esi, -1     ; set sign flag
    mov rax, rdi    ; rax = x
    mov rbx, -1     ; rbx = -1
    mul rbx         ; x = abs(x)
    mov rdi, rax    ; rdi = abs(x)

    .positive:

    callocNDigits 3
    mov r9, rax         ; r9 - void *values

    mov rax, rdi
    remToI r9, 2
    remToI r9, 3
    remToI r9, 4

    mov [r9], esi       ; bigint[0] = sign
    mov eax, 3
    mov [r9+4], eax     ; bigint[1] = 3

    deleteNils r9       ; delete leading nils
    isNull r9           ; check is 0 for sign

    push r9
    biCreate            ; rax - empty BigInt
    pop r9

    mov [rax], r9       ; rax[0] = address of values
    pop rbx
    ret


; Create a BigInt from a decimal string representation.
; Returns NULL on incorrect string.
;
; Input:
;   rdi - string
; Output:
;   rax - BigInt result or NULL if string has bad format
biFromString:
    push r12
    push rbx

    mov r12, 1          ; for sign
    cmp byte[rdi], '-'
    jne .after_sign
    inc rdi
    mov r12, -1         ; r12 = sign
    .after_sign:

    ; Ignore leading zeros
    .nil_loop:
    cmp byte[rdi], '0'
    jne .end_nil_loop   ; if cur_symbol != '0' then break
    inc rdi             ; s++
    cmp byte[rdi], 0    ; check we are at the end of string
    je .too_much_iters  ; if we are, then fix it
    jmp .nil_loop
    .too_much_iters     ; if s contains only '0', then we are at the end of s
    sub rdi, 1          ; to the last '0'
    .end_nil_loop:

    push rdi
    call strlen
    mov r10, rax    ; r10 = strlen(s)
    pop rdi
    cmp r10, 0      ; if there is no digits
    je .no_digits

    xor rdx, rdx
    mov rax, r10    ;
    add rax, 8      ; rax = (strlen(s)+8)
    mov ebx, 9
    div ebx         ; rax = floor(strlen(s)/9) = (strlen(s)+8)/9 = digits count
    mov r11, rax    ; r11 = digits count

    push r10
    push r11
    callocNDigits r11 ; allocate memory for BigInt
    pop r11
    pop r10

    mov rsi, rax
    mov rax, r12
    mov [rsi], eax      ; sign
    mov rax, r11
    mov [rsi+4], eax    ; count of big_digits

    xor r12, r12    ; index of big_digit
    .loop:
    mov r11, r10
    sub9 r10

    xor r9, r9      ; r9 - cur_big_digit
    .inner_loop:
        xor rbx, rbx            ;
        mov bl, byte[rdi+r10]   ; bl = cur_digit as character

        mov rax, 0              ; if bad format, the result = 0
        cmp bl, '0'             ;
        jl .bad_format          ; bl < '0' |=> bad format
        cmp bl, '9'             ;
        jg .bad_format          ; bl > '9' |=> bad format

        sub bl, '0'             ; rbx - cur_digit of big_digit

        mov rax, r9             ; rax = cur_big_digit
        mov rcx, 10             ; rcx = 10
        mul rcx                 ; rax = cur_big_digit * 10
        add rax, rbx            ; rax = cur_big_digit * 10 + cur_digit
        mov r9, rax             ; cur_big_digit = cur_big_digit * 10 + cur_digit

        inc r10
        cmp r11, r10

        jne .inner_loop
    sub9 r10

    mov rax, r9
    mov [rsi+(r12+2)*4], eax     ; BigInt[r12+2] = cur_big_digit
    inc r12                      ; BigInt_index++

    cmp r10, 0
    jne .loop

    .finish:
    isNull rsi
    biCreate        ; rax - empty BigInt
    mov [rax], rsi  ; rax[0] = address of values
    pop rbx
    pop r12
    ret

    .bad_format:
    push rdi
    mov rdi, rsi
    call free       ; delete allocated memory
    pop rdi

    xor rax, rax    ; return NULL
    pop rbx
    pop r12
    ret

    .no_digits:
    xor rax, rax    ; return NULL
    pop rbx
    pop r12
    ret

; Delete BigInt
;
; Input:
;   rdi - BigInt
%macro biDelteMacro 0
        push rdi
        mov rdi, [rdi]  ; rdi = BigInt.values
        call free       ; delete BigInt.values
        pop rdi
        call free       ; delete BigInt
%endmacro

; Delete BigInt
;
; Input:
;   rdi - BigInt
biDelete:
    biDeleteMacro
    ret

; Generate a decimal string representation from a BigInt.
; Writes at most limit bytes to buffer.
;
; Input:
;   rdi - BigInt
;   rsi - string
;   rdx - limit
biToString:
    push r13
    push r14
    push r15
    push rbx

    mov rdi, [rdi]  ; rdi = BigInt.values

    mov r13, rdx    ; r13 - limit
    cmp r13, 1
    jle .finish

    mov eax, [rdi]
    cmp eax, -1             ; check BigInt is negative
    jne .start_converting
    mov byte[rsi], '-'      ; put '-' to string
    inc rsi
    sub r13, 1              ; limit--, because of we've writed '-'
    cmp r13, 1
    je .finish

    .start_converting:
    ; Calc string size to put BigInt to it:
    mov eax, [rdi+4]
    sub eax, 1
    mov ebx, 9
    mul ebx
    mov ecx, [rdi+4]
    xor rbx, rbx
    mov ebx, [rdi+(rcx+1)*4]
    getDigitsCount rbx          ; rax - digits count of first_big_digit

    ; Writes rax/r8 to [rsi] and compare r13 with limit
    ;       (r8 - power of 10, r8 > rax)
    %macro helper 0
        xor r15, r15
        mov r15d, eax   ; save old value
        xor rdx, rdx    ; divider only in eax
        div r8d         ; eax = cur_digit
        mov rbx, rax
        add bl, '0'         ; bl - cur_digit as char
        mov byte[rsi], bl
        inc rsi             ; s++
        sub r13, 1          ; limit--
        cmp r13, 1          ; check limit
        je .finish
        mul r8d         ; eax = cur_digit * 10^(...)
        sub r15d, eax    ; remove cur_digit
        mov rax, r15
    %endmacro

    ; first big_digit:
    sub rax, 1              ; first_big_digit.length - 1
    power10 rax
    mov r8d, eax            ; r8 - 10 ** (first_big_digit.length-1)
    mov r14d, [rdi+4]        ; r9 = digits_count
    mov eax, [rdi+(r14+1)*4] ; rax - first_big_digit

    .loop_dig:
        helper

        push rax
        mov eax, r8d        ;
        mov ebx, 10         ;
        div ebx             ;
        mov r8d, eax        ; r8 /= 10 for next big_digit
        pop rax

        cmp r8, 0           ; r8 = 0 => we've write first big_digit
        jne .loop_dig
        .end_loop_dig:

    .loop:
        sub r14d, 1
        cmp r14d, 0
        je .end_loop
        mov eax, [rdi+(r14+1)*4] ; rax - big_digit
        mov r8d, 100000000
        helper
        mov r8d, 10000000
        helper
        mov r8d, 1000000
        helper
        mov r8d, 100000
        helper
        mov r8d, 10000
        helper
        mov r8d, 1000
        helper
        mov r8d, 100
        helper
        mov r8d, 10
        helper
        mov r8d, 1
        helper
        jmp .loop
    .end_loop:

    .finish
    mov byte[rsi], 0    ; *s = '\0'
    pop rbx
    pop r15
    pop r14
    pop r13
    ret

; Get sign of given BigInt.
; Input:
;   rdi - BigInt
; Output:
;   rax - 0 if bi is 0, 1 if bi is positive, -1 if bi is negative.
biSign:
    mov rdi, [rdi] ; rdi = BigInt.values
    mov eax, [rdi]
    ret

; Compare two BigInts
;
; Input:
;   rdi - a.values
;   rsi - b.values
; Output:
;   rax - result   (result =  0 if a = b
;                   result = -1 if a < b
;                   result =  1 if a > b)
%macro biCmpMacro 0
        push r12
        push r13
        push rbx

        ; r12 for mask of signs:
        ; r12 = 0 - first condition is FALSE, second condition is FALSE
        ;     = 1 - TRUE  FALSE
        ;     = 2 - FALSE TRUE
        ;     = 3 - TRUE  TRUE

        ;;;;;;;;;;;;;;;;;;;;;;
        ;; a == 0 && b == 0 ;;
        ;;;;;;;;;;;;;;;;;;;;;;
        xor r12, r12
        xor rax, rax
        cmp [rdi], eax
        jne %%continue1
        add r12, 1
        %%continue1:
        xor rax, rax
        cmp [rsi], eax
        jne %%continue2
        add r12, 2
        %%continue2:

        xor rax, rax    ; res = 0, if below is true
        cmp r12, 3      ; a == 0 && b == 0
        je %%finish

        ;;;;;;;;;;;;;;;;;;;;;;
        ;; a <= 0 && b >= 0 ;;
        ;;;;;;;;;;;;;;;;;;;;;;
        xor r12, r12
        xor rax, rax
        cmp [rdi], eax
        jg %%continue3
        add r12, 1
        %%continue3:
        xor rax, rax
        cmp [rsi], eax
        jl %%continue4
        add r12, 2
        %%continue4:

        mov rax, -1     ; res = -1, if below is true
        cmp r12, 3      ; a <= 0 && b >= 0
        je %%finish

        ;;;;;;;;;;;;;;;;;;;;;;
        ;; a >= 0 && b <= 0 ;;
        ;;;;;;;;;;;;;;;;;;;;;;
        xor r12, r12
        xor rax, rax
        cmp [rdi], eax
        jl %%continue5
        add r12, 1
        %%continue5:
        xor rax, rax
        cmp [rsi], eax
        jg %%continue6
        add r12, 2
        %%continue6:

        mov rax, 1     ; res = 1, if below is true
        cmp r12, 3      ; a >= 0 && b <= 0
        je %%finish

        ;;;;;;;;;;;;;;;;;;;;
        ;; a > 0 && b > 0 ;;
        ;;       or       ;;
        ;; a < 0 && b < 0 ;;
        ;;;;;;;;;;;;;;;;;;;;
        ;; We comapre absolute values, r13 for sign (res*r13 at the end)
        mov eax, [rdi]
        mov r13d, eax            ; r13 - sign of a and b

        mov eax, [rdi+4]        ; rax = a.length
        mov ebx, [rsi+4]        ; rbx = b.length
        cmp eax, ebx
        je %%start_compare       ; if a.length != b.length, then start hard comparing
        mov eax, r13d            ; if a.length > b.length, then res = 1 * sign
        jg %%finish
        mov rcx, -1
        mul rcx                 ; else res = -1 * sign
        jmp %%finish

        %%start_compare:

        xor r12, r12
        mov eax, [rdi+4]    ; start from the end
        mov r12d, eax
        %%loop:
            xor rax, rax    ; res = 0 if we've compared all big_digits
            cmp r12, 0      ; check if we've compared all big_digits
            je %%finish
            sub r12, 1
            xor rax, rax
            xor rbx, rbx
            mov eax, [rdi+(r12+2)*4] ; cur_big_digit of a
            mov ebx, [rsi+(r12+2)*4] ; cur_big_digit of b
            cmp eax, ebx
            je %%loop

        mov eax, r13d    ; res = sign if abs(a) > abs(b)
        jg %%finish
        mov rcx, -1     ;
        mul rcx         ; else res = -sign
        jmp %%finish

        %%finish:
        pop rbx
        pop r13
        pop r12
%endmacro

; Compare two BigInts
;
; Input:
;   rdi - a
;   rsi - b
; Output:
;   rax - result   (result =  0 if a = b
;                   result = -1 if a < b
;                   result =  1 if a > b)
biCmp:
    mov rdi, [rdi] ; rdi = a.values
    mov rsi, [rsi] ; rsi = b.values
    biCmpMacro
    ret

; Copy b.values to a.values
; Input:
;   rdi - a.values
;   rsi - b.values
%macro biCopy 0
        push rbx
            ;;;;; DELETING ;;;;;
        push rsi
        call free   ; delete a
        pop rsi
            ;;;;; ALLOCATION ;;;;;
        push rsi
        push rbx
        xor rbx, rbx
        mov ebx, [rsi+4]
        callocNDigits rbx   ; allocate new BigInt.values
        mov rdi, rax
        pop rbx
        pop rsi
            ;;;;; COPYING ;;;;;
        xor rdx, rdx
        mov edx, [rsi+4]    ; rdx - b.length
        add edx, 2          ; for sign and length
        shl edx, 2          ; rdx = rdx * sizeof(int) (rdx * 4)
        call memcpy
        pop rbx
%endmacro

; Get ith bigdigit from BigInt.values
;
; Input:
;   %1 - i
;   %2 - BigInt.values
; Output:
;   eax - ith bigdigit
%macro getIth 2
    xor rax, rax    ; res = 0 if i >= BigInt.values.size
    cmp %1, [%2+4]  ; check borders
    jge %%too_big
    push r8
    xor r8, r8
    mov r8d, %1
    mov eax, [%2+(r8+2)*4]
    pop r8
    %%too_big:
%endmacro

; Input:
;   rdi - a != 0
;   rsi - b != 0
; Output:
;   r12 for mask of signs:
;   r12 = 0 - a > 0 is FALSE, b > 0 is FALSE (a < 0 && b < 0)
;       = 1 - TRUE  FALSE (a > 0 && b < 0)
;       = 2 - FALSE TRUE  (a < 0 && b > 0)
;       = 3 - TRUE  TRUE  (a > 0 && b > 0)
%macro getSignsMask 0
        xor r12, r12
        xor rax, rax
        cmp [rdi], eax  ; a.sign ? 0
        jl %%al0
        add r12, 1      ; a > 0
        %%al0:
        xor rax, rax
        cmp [rsi], eax  ; b.sign ? 0
        jl %%bl0
        add r12, 2      ; b > 0
        %%bl0:
%endmacro

; b += rst (b.sign = a.sign)
;
; Input:
;   rdi - b.values
;   rsi - a.values
; Output:
;   a.values = (a + b).values
%macro addSameSigns 0
        push rbx
        push r12
        push r13

        xor rbx, rbx
        mov ebx, [rdi+4]    ; eax = a.size
        cmp ebx, [rsi+4]
        jg %%continue2
        mov ebx, [rsi+4]    ; rax = max(a.size, b.size)
        %%continue2:

        inc ebx             ; res.size = max(a.size, b.size) + 1 (1 for last carry, if it will)
        callocNDigits rbx
        mov r12, rax        ; r12 - res

        mov eax, [rsi]      ; eax = sign
        mov [r12], eax      ; res[0] = sign
        mov [r12+4], ebx    ; res[1] = size

        xor r13d, r13d        ; carry
        xor rbx, rbx
        %%loop:
            xor r8, r8
            add r8d, r13d    ; r8 += carry
            getIth ebx, rdi
            add r8d, eax     ; r8 += a.digits[i]
            getIth ebx, rsi
            add r8d, eax     ; r8 += b.digits[i]

            xor r13d, r13d      ; carry = 0
            cmp r8d, BASE
            jl %%no_carry
            inc r13d            ; carry = 1
            sub r8d, BASE       ; r8 %= BASE
            %%no_carry:
            mov [r12+(rbx+2)*4], r8d    ; res.digits[i] = (a.digits[i]+b.digits[i]+carry)%BASE
            inc rbx                     ; i++
            cmp ebx, [r12+4]
            jne %%loop

        %%overit:

        deleteNils r12  ; delete leading zeros

        push rsi
        mov rsi, r12
        biCopy          ; copy tmp to a
        pop rsi

        push rdi
        push rsi
        mov rdi, r12
        call free       ; delete tmp
        pop rsi
        pop rdi

        pop r13
        pop r12
        pop rbx
%endmacro ; addSameSigns

; a -= b (a > b)
;
; Input:
;   rdi - a.values
;   rsi - b.values
; Output:
;   a.values = (a - b).values
%macro subAGB 0
        push rbx
        push r12
        push r13

        xor rbx, rbx
        mov ebx, [rdi+4]    ; ebx = a.size
        cmp ebx, [rsi+4]
        jg %%continue2
        mov ebx, [rsi+4]    ; res.size = rbx = max(a.size, b.size)
        %%continue2:

        callocNDigits rbx
        mov r12, rax        ; r12 - res

        mov eax, [rdi]      ; eax = sign
        mov [r12], eax      ; res[0] = sign
        mov [r12+4], ebx    ; res[1] = size

        xor r13d, r13d        ; carry
        xor rbx, rbx
        %%loop:
            xor r8, r8
            sub r8d, r13d    ; r8 -= carry
            getIth ebx, rdi
            add r8d, eax     ; r8 += a.digits[i]
            getIth ebx, rsi
            sub r8d, eax     ; r8 -= b.digits[i]

            xor r13d, r13d      ; carry = 0
            cmp r8d, 0
            jge %%no_carry
            inc r13d            ; carry = 1
            add r8d, BASE       ; r8 %= BASE
            %%no_carry:
            mov [r12+(rbx+2)*4], r8d    ; res.digits[i] = (a.digits[i]-b.digits[i]-carry)%BASE
            inc rbx                     ; i++
            cmp ebx, [r12+4]
            jne %%loop

        %%overit:

        deleteNils r12  ; delete leading zeros

        push rsi
        mov rsi, r12
        biCopy          ; copy tmp to a
        pop rsi

        push rdi
        push rsi
        mov rdi, r12
        call free       ; delete tmp
        pop rsi
        pop rdi

        %%finish:
        pop r13
        pop r12
        pop rbx
%endmacro ; subAGB

; a -= b (a > 0 && b > 0)
;
; Input:
;   rdi - a.values
;   rsi - b.values
; Output:
;   a.values = (a - b).values
%macro subPositive 0
        push r12
        push r13

        biCmpMacro
        cmp rax, 0          ; a == b
        jne %%not_equal
        push rsi
        call free           ; delete a.values
        ; a = 0:
        pop rsi
        callocNDigits 1     ; 1 bigdigit
        mov rdi, rax

        xor eax, eax        ; eax = 0;
        mov [rdi], eax      ; sign = 0
        mov eax, 1          ; eax = 1
        mov [rdi+4], eax    ; size = 1
        xor eax, eax        ; eax = 0
        mov [rdi+8], eax    ; first big_digit = 0
        jmp %%finish

        %%not_equal:
        cmp rax, -1         ; a < b
        jne %%agb
        ; a < b
        ; then a - b = -(b - a)
        mov r12, rdi    ; r12 = a.values
        mov r13, rsi    ; r13 = a.values

        callocNDigits 0 ; create tmp.values

        mov rdi, rax    ; rdi = tmp.values
        biCopy          ; rdi = b.values
        mov rsi, r12    ; rsi = a.values
        subAGB          ; rdi = (b-a).values

        mov eax, [rdi]  ; eax = (b-a).sign
        mov ecx, -1     ; ecx = -1
        mul ecx         ; eax = -(b-a).sign
        mov [rdi], eax  ; rdi = (-(b-a)).values

        push rdi
        mov rdi, r12    ; rdi = a.values
        call free       ; delete a.values
        pop rdi

        mov rsi, r13    ; rsi = b.values

        jmp %%finish

        %%agb:
        subAGB

        %%finish:
        deleteNils rdi
        isNull rdi
        pop r13
        pop r12
%endmacro ; subPositive

; a -= b
;
; Input:
;   rdi - a.values
;   rsi - b.values
; Output:
;   a.values = (a - b).values
%macro subMacro 0
        push r12

        xor rax, rax
        cmp [rdi], eax  ; if a == 0, then a = -b
        jne %%continue1
        biCopy          ; a.values = b.values
        mov r12d, [rdi] ; r12 = b.sign
        mov eax, -1     ; rax = -1
        mul r12d        ; rax = -b.sign
        mov [rdi], eax  ; a.sign = -b.sign
        jmp %%finish
        %%continue1:
        xor rax, rax
        cmp [rsi], eax  ; if b == 0, then a = a
        je %%finish

        ; a != 0 && b != 0 now
        getSignsMask
        cmp r12, 1 ; a > 0 && b < 0 ?
        jne %%continue2
        ; a > 0 && b < 0
        ; then a - b = a - (-abs(b)) = a + abs(b)
        mov eax, 1      ;
        mov [rsi], eax  ; b = abs(b)
        addSameSigns    ; rdi = (a + abs(b)).values
        mov eax, -1     ;
        mov [rsi], eax  ; load old b.sign
        jmp %%finish

        %%continue2:
        cmp r12, 2 ; a < 0 && b > 0 ?
        jne %%continue3
        ; a < 0 && b > 0
        ; then a - b = -(abs(a) + b)
        mov eax, 1
        mov [rdi], eax
        addSameSigns
        mov eax, -1
        mov [rdi], eax
        jmp %%finish

        %%continue3:
        cmp r12, 0 ; a < 0 && b < 0 ?
        jne %%continue4
        ; a < 0 && b < 0
        ; then a - b = -abs(a) - (-abs(b)) = abs(b) - abs(a) = -(abs(a) - abs(b))
        mov eax, 1
        mov [rdi], eax  ; a = abs(a)
        mov [rsi], eax  ; b = abs(b)
        subPositive     ; rdi = (abs(a)-abs(b)).values
        mov eax, [rdi]
        mov r12d, -1
        mul r12d         ; eax = -(abs(a)-abs(b)).sign
        mov [rdi], eax   ; rdi = -(abs(a)-abs(b))
        jmp %%finish
        %%continue4:

        ; a > 0 && b > 0
        subPositive

        %%finish:
        pop r12
%endmacro ; subMacro

; a -= b
;
; Input:
;   rdi - a
;   rsi - b
; Output:
;   a = a - b
biSub:
    push rdi
    mov rdi, [rdi]  ; rdi = a.values
    mov rsi, [rsi]  ; rsi = b.values
    subMacro        ; rdi = (a-b).values
    mov rax, rdi    ; save (a-b).values
    pop rdi
    mov [rdi], rax  ; a.values = (a-b).values
mov rax, r15
    ret

; a += b
;
; Input:
;   rdi - a.values
;   rsi - b.values
; Output:
;   a.values = (a+b).values
%macro addMacro 0
        push rbx
        push r12
        push r13

        xor rax, rax
        cmp [rdi], eax  ; if a == 0, then a = b
        jne %%continue1
        biCopy          ; a = b
        jmp %%finish
        %%continue1:
        xor rax, rax
        cmp [rsi], eax  ; if b == 0, then a = a
        je %%finish

        ; a != 0 && b != 0 now

        getSignsMask    ; r12 - mask of signs

        cmp r12, 1          ; a > 0 && b < 0 ?
        jne %%continue3     ; if not, continue add
        ; a > 0 && b < 0
        ; then a + b = a + (-abs(b)) = a - abs(b)
        mov eax, 1      ;
        mov [rsi], eax  ; b = abs(b)

        subPositive     ; a = a - abs(b)

        mov eax, -1     ;
        mov [rsi], eax  ; load b.sign
        jmp %%finish

        %%continue3:
        cmp r12, 2 ; a < 0 && b > 0 ?
        jne %%continue4
        ; a < 0 && b > 0
        ; then a + b = -abs(a) + b = -(abs(a) - b)
        mov eax, 1      ;
        mov [rdi], eax  ; a = abs(a)

        subPositive     ; a = abs(a) - b

        mov eax, -1
        mov r12d, [rdi]
        mul r12d        ; eax = (-(a - b)).sign = -1 * (abs(a) - b).sign
        mov [rdi], eax  ; rdi = -(abs(a) - b)
        jmp %%finish
        %%continue4:

        ; a > 0 and b > 0 or a < 0 && b < 0
        addSameSigns

        %%finish:
        pop r13
        pop r12
        pop rbx
%endmacro ; addMacro

; a += b
;
; Input:
;   rdi - a
;   rsi - b
; Output:
;   a = a+b
biAdd:
    push rdi
    mov rdi, [rdi]  ; rdi - address of a.values
    mov rsi, [rsi]  ; rsi - address of b.values
    addMacro        ; rdi - address of (a+b).values
    mov rax, rdi    ; save (a+b).values
    pop rdi
    mov [rdi], rax  ; a.values = (a+b).values
    ret

; a += b
;
; Input:
;   rdi - a.values
;   rsi - b.values
; Output:
;   a.values = (a+b).values
%macro mulMacro 0
        push r12
        push r13
        push r14
        push rbx

        xor eax, eax
        cmp [rdi], eax  ; a == 0 ?
        je %%finish
        cmp [rsi], eax
        je %%retb       ; b == 0 ?

        xor rbx, rbx        ; rbx = 0
        mov ebx, [rdi+4]    ; rbx += a.size
        add ebx, [rsi+4]    ; rbx += b.size
        callocNDigits rbx   ; allocate memory for a.size+b.size bigdigits
        mov r12, rax        ; r12 - tmp variable for multiply of a and b
        mov [r12+4], rbx    ; res.size = a.size+b.size as maximum

        mov eax, [rdi]      ; eax = a.sign
        mov ecx, [rsi]      ; ecx = b.sign
        mul ecx             ; eax = a.sign * b.sign
        mov [r12], eax      ; res.sign = a.sign * b.sign

        xor r11, r11        ; for carry
        xor r13, r13        ; iterator for a
        .loopA:
            xor r14, r14    ; iterator for b
            .loopB:
                mov r8, r13     ;
                add r8, r14     ;
                add r8, 2       ;
                shl r8, 2       ; r8 = ((r13+r14)+2)*4 - iterator to res.values

                push r12        ; save res.values address
                add r12, r8

                getIth r13d, rdi    ; eax = a.values[r13]
                mov r9d, eax        ; r9d = a.values[r13] = y
                getIth r14d, rsi    ; eax = b.values[r14] = x

                xor rdx, rdx
                mul r9d             ; edx:eax = x*y

                add eax, r11d       ; eax += carry
                adc edx, 0          ; edx:eax = x*y+carry (adc because of overflow of eax)

                add eax, [r12]      ; eax += res.values[r13+r14]
                adc edx, 0          ; edx:eax = res.values[r13+r14]+x*y+carry = cur

                xor r11, r11        ; carry = 0

                mov r10d, BASE
                div r10d            ; eax = cur/BASE (carry), edx = cur%BASE (bigdigit)

                mov r11d, eax       ; r11d = carry

                mov [r12], edx      ; res.values[r13+r14] = (res.values[r13+r14]+x*y+carry)%BASE
                pop r12             ; load res.values address

                inc r14d            ; b.iterator++
                cmp r14d, [rsi+4]   ; check it's the end
                jge .b_finished
                jmp .loopB          ; continue
                .b_finished:
                cmp r11d, 0         ; if carry != 0 |=> continue
                jne .loopB

            inc r13d                ; a.iterator++
            cmp r13d, [rdi+4]
            jl .loopA               ; if < a.size |=> continue


        deleteNils r12  ; delete leading zeros

        push rsi
        mov rsi, r12
        biCopy          ; copy tmp to a
        pop rsi

        push rdi
        push rsi
        mov rdi, r12
        call free       ; delete tmp
        pop rsi
        pop rdi

        jmp %%finish
        %%retb:
        biCopy

        %%finish:
        pop rbx
        pop r14
        pop r13
        pop r12
%endmacro ; mulMacro

; a *= b
;
; Input:
;   rdi - a
;   rsi - b
; Output:
;   a = a*b
biMul:
    push rdi
    mov rdi, [rdi]  ; rdi - address of a.values
    mov rsi, [rsi]  ; rsi - address of b.values
    mulMacro        ; rdi - address of (a*b).values
    mov rax, rdi    ; save (a*b).values
    pop rdi
    mov [rdi], rax  ; a.values = (a*b).values
    ret
