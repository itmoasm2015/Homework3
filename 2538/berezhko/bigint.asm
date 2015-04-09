default rel

section .text

extern calloc, strlen, free, memcpy

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

; Divide rax by %1 and write reminder to [%2+4*%3], result to rax
%macro remToI 3
        xor rdx, rdx        ; rdx = 0
        mov r10, %1
        div r10             ; rax = x/y, rdx = x%y
        mov [%2+4*%3], rdx
%endmacro

; Delete leading nils from bigint %1
%macro deleteNils 1
        xor rcx, rcx
        mov ecx, [%1+4]
        %%loop:
        cmp qword[%1+(1+rcx)*4], 0     ; compare with 0
        jne %%overit

        xor rdx, rdx
        mov edx, [%1+4]
        sub edx, 1
        mov [%1+4], edx                ; decrease digit count

        sub ecx, 1
        cmp ecx, 1
        jne %%loop
        %%overit:
%endmacro

; Check bigint %1 == 0, 1 or 0 in rax
%macro isNull 1
        xor rax, rax
        mov eax, [%1+4]
        cmp eax, 1
        jne %%ret_false
        mov eax, [%1+8]
        cmp eax, 0
        jne %%ret_false
        mov eax, 0
        mov [%1], eax ; only +0
        mov rax, 1
        jmp %%finish
        %%ret_false:
        mov rax, 0
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

; Allocates memory for %1 32bit numbers using calloc
%macro callocNDigits 1
        push rdi
        push rsi
        mov rdi, %1     ; rdi = numbers count
        add rdi, 2      ; for sign and number count
        mov rsi, 4      ; 32bit
        call calloc
        pop rsi
        pop rdi
%endmacro

; Calcs digits count of %1, result to rax
%macro getDigitsCount 1
        push rdx
        push rbx
        mov rax, %1
        mov r9, 0
        %%loop:
        inc r9
        xor rbx, rbx
        mov ebx, 10
        xor rdx, rdx
        div ebx
        cmp rax, 0
        je %%finish
        jmp %%loop
        %%finish:
        mov rax, r9
        pop rbx
        pop rdx
%endmacro

; rax = 10 ** %1
%macro power10 1
        push r12
        push rbx
        mov r12, %1
        xor rax, rax
        mov eax, 1
        %%loop:
        cmp r12, 0
        je %%finish
        sub r12, 1
        xor rbx, rbx
        mov ebx, 10
        mul ebx
        jmp %%loop
        %%finish:
        pop rbx
        pop r12
%endmacro

; rdi - int x
; rsi - result
biFromInt:
    push rbx

    xor rsi, rsi

    cmp rdi, 0
    jge .positive

    mov esi, -1     ; set sign flag

    mov rax, rdi    ; rax = x
    mov rbx, -1     ; rbx = -1
    mul rbx         ; x = abs(x)
    mov rdi, rax    ; rdi = abs(x)

    .positive:

    callocNDigits 3
    mov r9, rax     ; r9  - void *bigint

    mov rax, rdi
    remToI BASE, r9, 2
    remToI BASE, r9, 3
    remToI BASE, r9, 4

    mov [r9], esi     ; bigint[0] = sign
    xor rax, rax
    mov eax, 3
    mov [r9+4], eax   ; bigint[1] = 3

    deleteNils r9
    isNull r9
    mov rax, r9 ; rax - void *bigint

    pop rbx
    ret

; rdi - s
; rsi - result
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

    xor rdx, rdx
    mov rax, r10    ;
    add rax, 8      ;
    mov ebx, 9
    div ebx         ; rax = floor(strlen(s)/9)
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
    mov rax, rsi    ; return BigInt
    pop rbx
    pop r12
    ret

    .bad_format:
    push rdi
    mov rdi, rsi
    call free       ; delete allocated memory
    pop rdi

    mov rax, 0      ; return NULL
    pop rbx
    pop r12
    ret

; rdi - BigInt
biDelete:
    call free
    ret

; rdi - BigInt
; rsi - string
; rdx - limit
biToString:
    push r13
    push r14
    push rsi    ; save string address
    push rbx

    mov r13, rdx ; r13 - limit
    cmp r13, 1
    jle .finish

    xor rax, rax
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
    xor rax, rax
    mov eax, [rdi+4]
    sub eax, 1
    mov rbx, 9
    mul rbx
    xor rcx, rcx
    mov ecx, [rdi+4]
    xor rbx, rbx
    mov ebx, [rdi+(rcx+1)*4]
    getDigitsCount rbx          ; rax - digits count of first_big_digit

    ; Writes rax/r8 to [rsi] and compare r13 with limit
    ;       (r8 - power of 10, r8 > rax)
    %macro helper 0
        xor r9, r9
        mov r9d, eax    ; save old value
        div r8d         ; eax = cur_digit
        mov rbx, rax
        add bl, '0'         ; bl - cur_digit as char
        mov byte[rsi], bl
        inc rsi             ; s++
        sub r13, 1          ; limit--
        cmp r13, 1          ; check limit
        je .finish
        mul r8d         ; eax = cur_digit * 10^(...)
        sub r9d, eax    ; remove cur_digit
        mov rax, r9
    %endmacro

    ; first big_digit:
    sub rax, 1              ; first_big_digit.length - 1
    power10 rax
    xor r8, r8
    mov r8d, eax            ; r8 - 10 ** (first_big_digit.length-1)
    xor r14, r14
    mov r14d, [rdi+4]        ; r9 = digits_count
    xor rax, rax
    mov eax, [rdi+(r14+1)*4] ; rax - first_big_digit
    .loop_dig:
        helper

        cmp rax, 0          ; we've write first big_digit
        je .end_loop_dig

        push rax
        mov eax, r8d        ;
        mov ebx, 10         ;
        div ebx             ;
        mov r8d, eax        ; r8 /= 10 for next big_digit
        pop rax

        jmp .loop_dig
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
    mov byte[rsi], 0
    pop rbx
    pop rsi
    pop r14
    pop r13
    ret

; rdi - BigInt
; rax - result
biSign:
    xor rax, rax;
    mov eax, [rdi]
    ret

; rdi - BigInt a
; rsi - BigInt b
; rax - result (result =  0 if a = b
;               result = -1 if a < b
;               result =  1 if a > b)
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
        jne .continue1
        add r12, 1
        .continue1:
        xor rax, rax
        cmp [rsi], eax
        jne .continue2
        add r12, 2
        .continue2:

        xor rax, rax    ; res = 0, if below is true
        cmp r12, 3      ; a == 0 && b == 0
        je .finish

        ;;;;;;;;;;;;;;;;;;;;;;
        ;; a <= 0 && b >= 0 ;;
        ;;;;;;;;;;;;;;;;;;;;;;
        xor r12, r12
        xor rax, rax
        cmp [rdi], eax
        jg .continue3
        add r12, 1
        .continue3:
        xor rax, rax
        cmp [rsi], eax
        jl .continue4
        add r12, 2
        .continue4:

        mov rax, -1     ; res = -1, if below is true
        cmp r12, 3      ; a <= 0 && b >= 0
        je .finish

        ;;;;;;;;;;;;;;;;;;;;;;
        ;; a >= 0 && b <= 0 ;;
        ;;;;;;;;;;;;;;;;;;;;;;
        xor r12, r12
        xor rax, rax
        cmp [rdi], eax
        jl .continue5
        add r12, 1
        .continue5:
        xor rax, rax
        cmp [rsi], eax
        jg .continue6
        add r12, 2
        .continue6:

        mov rax, 1     ; res = 1, if below is true
        cmp r12, 3      ; a >= 0 && b <= 0
        je .finish

        ;;;;;;;;;;;;;;;;;;;;
        ;; a > 0 && b > 0 ;;
        ;;       or       ;;
        ;; a < 0 && b < 0 ;;
        ;;;;;;;;;;;;;;;;;;;;
        ;; We comapre absolute values, r13 for sign (res*r13 at the end)
        xor rax, rax
        mov eax, [rdi]
        mov r13, rax            ; r13 - sign of a and b

        xor rax, rax
        xor rbx, rbx
        mov eax, [rdi+4]        ; rax = a.length
        mov ebx, [rsi+4]        ; rbx = b.length
        cmp eax, ebx
        je .start_compare       ; if a.length != b.length, then start hard comparing
        mov rax, r13            ; if a.length > b.length, then res = 1 * sign
        jg .finish
        mov rcx, -1
        mul rcx                 ; else res = -1 * sign
        jmp .finish

        .start_compare:

        xor rax, rax
        mov eax, [rdi+4]    ; start from the end
        mov r12, rax
        .loop:
            xor rax, rax    ; res = 0 if we've compared all big_digits
            cmp r12, 0      ; check if we've compared all big_digits
            je .finish
            sub r12, 1
            xor rax, rax
            xor rbx, rbx
            mov eax, [rdi+(r12+2)*4] ; cur_big_digit of a
            mov ebx, [rsi+(r12+2)*4] ; cur_big_digit of b
            cmp eax, ebx
            je .loop

        mov rax, r13    ; res = sign if abs(a) > abs(b)
        jg .finish
        mov rcx, -1     ;
        mul rcx         ; else res = -sign
        jmp .finish

        .finish:
        pop rbx
        pop r13
        pop r12
%endmacro

; %1 = abs(%1)
%macro biAbs 1
        push r12
        xor r12, r12
        cmp [%1], r12d ; compare sign with 0
        jeg %%is_positive
        xor rax, rax
        mov eax, [%1]
        mul eax, -1
        mov [%1], eax
        %%is_positive:
        pop r12
%endmacro

; rdi - BigInt a
; rsi - BigInt b
; rax - result (result =  0 if abs(a) = abs(b)
;               result = -1 if abs(a) < abs(b)
;               result =  1 if abs(a) > abs(b))
%macro biAbsCmp 0
        push r12
        push r13
        xor r12, r12
        xor r13, r13
        mov r12d, [rdi]
        mov r13d, [rsi]
        biAbs rdi
        biAbs rsi
        biCmpMacro
        mov [rdi], r12d
        mov [rsi], r13d
        pop r13
        pop r12
%endmacro

biCmp:
    biCmpMacro
    ret

; %1 - dst
; %2 - src
%macro biCopy 2
            ;;;;; DELETING ;;;;;
        push rdi
        push rsi
        push %2
        mov rdi, %1
        call free
        pop %2
        pop rsi
        pop rdi
            ;;;;; ALLOCATION ;;;;;
        push rbx
        push %2
        xor rbx, rbx
        mov ebx, [%2+4]
        callocNDigits rbx
        mov %1, rax
        pop %2
        pop rbx
            ;;;;; COPYING ;;;;;
        push rdi
        push rsi
        push rdx

        mov rdx, %2         ; rdx - src
        mov rdi, %1         ; rdi - dst
        mov rsi, rdx        ; rsi - src

        xor rdx, rdx
        mov edx, [%2+4]      ; rdx - src.length
        add edx, 2           ; for sign and length
        shl edx, 2           ; rdx = rdx * sizeof(int) (rdx * 4)

        call memcpy
        pop rdi
        pop rsi
        pop rdx
%endmacro

; %1 - which bigdigit
; %2 - bigint
%macro getIth 2
    xor rax, rax
    cmp %1, [%2+4]
    jge %%too_big
    push r8
    xor r8, r8
    mov r8d, %1
    mov eax, [%2+(r8+2)*4]
    pop r8
    %%too_big:
%endmacro

%macro biSubMacro 0

%endmacro

biSub:

    ret

%macro biAddMacro 0
        push rbx
        push r12
        push r13

        xor rax, rax
        cmp [rdi], eax  ; if a == 0, then a = b
        jne .continue1
        biCopy rdi, rsi ; a = b
        jmp .finish
        .continue1:
        xor rax, rax
        cmp [rsi], eax  ; if b == 0, then a = a
        je .finish

        ; a != 0 && b != 0 now

        ; r12 for mask of signs:
        ; r12 = 0 - a > 0 is FALSE, b > 0 is FALSE (a < 0 && b < 0)
        ;     = 1 - TRUE  FALSE (a > 0 && b < 0)
        ;     = 2 - FALSE TRUE  (a < 0 && b > 0)
        ;     = 3 - TRUE  TRUE  (a > 0 && b > 0)
        xor r12, r12
        xor rax, rax
        cmp [rdi], eax  ; a.sign ? 0
        jl .al0
        add r12, 1      ; a > 0
        .al0:
        xor rax, rax
        cmp [rsi], eax  ; b.sign ? 0
        jl .bl0
        add r12, 2      ; b > 0
        .bl0:

        cmp r12, 1      ; a > 0 && b < 0 ?
        jne .continue3  ; if not, continue add
        ; a > 0 && b < 0
        ; then a + b = a + (-abs(b)) = a - abs(b)
        mov eax, 1      ;
        mov [rsi], eax  ; b = abs(b)

        biSubMacro      ; a = a - abs(b)

        mov eax, -1     ;
        mov [rsi], eax  ; load b.sign
        jmp .finish

        .continue3:
        cmp r12, 2 ; a < 0 && b > 0 ?
        jne .continue4
        ; a < 0 && b > 0
        ; then a + b = -abs(a) + b = -(abs(a) - b)
        mov eax, 1      ;
        mov [rdi], eax  ; a = abs(a) - b

        biSubMacro      ; a = abs(a) - b

        xor rax, rax
        mov eax, -1
        mov r12d, [rdi]
        mul r12d        ; eax = (-(a - b)).sign = -1 * (abs(a) - b).sign
        jmp .finish
        .continue4:

        ; a > 0 and b > 0 or a < 0 && b < 0

        xor rbx, rbx
        mov ebx, [rdi+4]    ; eax = a.size
        cmp ebx, [rsi+4]
        jg .continue2
        mov ebx, [rsi+4]    ; rax = max(a.size, b.size)
        .continue2:

        inc ebx             ; res.size = max(a.size, b.size) + 1 (1 for last carry, if it will)
        callocNDigits rbx
        mov r12, rax        ; r12 - res

        mov eax, [rsi]      ; eax = sign
        mov [r12], eax      ; res[0] = sign
        mov [r12+4], ebx    ; res[1] = size

        xor r13d, r13d        ; carry
        xor rbx, rbx
        .loop:
            xor r8, r8
            add r8d, r13d    ; r8 += carry
            getIth ebx, rdi
            add r8d, eax     ; r8 += a.digits[i]
            getIth ebx, rsi
            add r8d, eax     ; r8 += b.digits[i]

            xor r13d, r13d      ; carry = 0
            cmp r8d, BASE
            jl .no_carry
            inc r13d            ; carry = 1
            sub r8d, BASE       ; r8 %= BASE
            .no_carry:
            mov [r12+(rbx+2)*4], r8d    ; res.digits[i] = (a.digits[i]+b.digits[i]+carry)%BASE
            inc rbx                     ; i++
            cmp ebx, [r12+4]
            jne .loop

        .overit:

        deleteNils r12  ; deleteleading zeros

        biCopy rdi, r12 ; copy tmp to dst

        push rdi
        push rsi
        mov rdi, r12
        call free       ; delete tmp
        pop rsi
        pop rdi

        .finish:

        pop r13
        pop r12
        pop rbx
%endmacro

; rdi - a
; rsi - b
;
; a += b
biAdd:
    biAddMacro
    ret
