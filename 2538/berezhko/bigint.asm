default rel

section .text

extern calloc, strlen, free

global biFromInt
global biFromString
global biDelete
global biToString
global biSign
global biCmp

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

%macro fillBy9Zero 1
        mov byte[%1],   '0'
        mov byte[%1+1], '0'
        mov byte[%1+2], '0'
        mov byte[%1+3], '0'
        mov byte[%1+4], '0'
        mov byte[%1+5], '0'
        mov byte[%1+6], '0'
        mov byte[%1+7], '0'
        mov byte[%1+8], '0'
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

; Writes rax % 10 to string rsi
%macro writeRaxMod10ToRsi 0
        push rbx
        xor rdx, rdx
        xor rbx, rbx
        mov ebx, 10
        div ebx
        add dl, '0'
        sub rsi, 1
        mov byte[rsi], dl
        pop rbx
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
    push rsi    ; save string address
    push rbx
    push rdx    ; save limit for return

    push rdx    ; save limit

    xor rax, rax
    mov eax, [rdi]
    cmp eax, -1             ; check BigInt is negative
    jne .start_converting
    mov byte[rsi], '-'      ; put '-' to string
    inc rsi

    .start_converting:
    ; Calc string size to put BigInt to it:
    xor rax, rax
    mov eax, [rdi+4]
    sub eax, 1
    mov rbx, 9
    mul rbx
    mov r8, rax                 ; rax - length without last big_digit
    xor rcx, rcx
    mov ecx, [rdi+4]
    xor rbx, rbx
    mov ebx, [rdi+(rcx+1)*4]
    getDigitsCount rbx
    add r8, rax                 ; r8 - length of string

    pop rdx     ; load limit

    cmp r8, rdx
    jg .finish

    add rsi, r8         ; s = s + need_length
    mov byte[rsi], 0    ; s[need_length] = 0

    xor r8, r8

    .loop:
    xor rax, rax
    mov eax, [rdi+4]
    sub eax, 1          ; except first big_digit
    cmp r8, rax
    je .overit

    xor rax, rax
    mov eax, [rdi+(r8+2)*4]

    writeRaxMod10ToRsi
    writeRaxMod10ToRsi
    writeRaxMod10ToRsi
    writeRaxMod10ToRsi
    writeRaxMod10ToRsi
    writeRaxMod10ToRsi
    writeRaxMod10ToRsi
    writeRaxMod10ToRsi
    writeRaxMod10ToRsi

    inc r8
    jmp .loop

    .overit:

    ; first big_digit:
    xor rax, rax
    mov eax, [rdi+(r8+2)*4]
    .loop_dig:
    writeRaxMod10ToRsi
    cmp rax, 0
    jne .loop_dig

    .finish
    pop rdx
    pop rbx
    pop rsi
    mov byte[rsi+rdx-1], 0
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
biCmp:
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
    ret

; rdi - a
; rsi - b
;
; a += b
biAdd:

ret
