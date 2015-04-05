default rel

section .text

extern calloc, strlen, free

global biFromInt
global biFromString
global biDelete
global biToString

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
        cmp qword[%1+4], 1
        jne %%ret_false
        cmp qword[%1+8], 0
        jne %%ret_false
        mov r10, 0
        mov [%1], r10 ; only +0
        mov rax, 1

        %%ret_false:
        mov rax, 0
        %%finish:
%endmacro

; get positive number from rdi[%1..%2), result to rax
;%macro getNumberFromSubstr 2
;        xor rax, rax
;        mov r8, %1
;       %%loop:
;
;%endmacro

; Subtract 9 from %1 and put result to %1. If result is less than 0, then result = 0
%macro sub9 1
        sub %1, 9
        cmp %1, 0
        jge %%finish
        mov %1, 0
        %%finish:
%endmacro

%macro callocNDigits 1
        push rdi
        push rsi
        mov rdi, %1
        add rdi, 2
        mov rsi, 4
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

%macro writeRaxMod10ToRsi 0
        xor rdx, rdx
        xor rbx, rbx
        mov ebx, 10
        div ebx
        add dl, '0'
        sub rsi, 1
        mov byte[rsi], dl
%endmacro

; rdi - int x
biFromInt:
    push rbx

    xor rsi, rsi

    cmp rdi, 0
    jge .positive

    mov esi, 1      ; set sign flag

    mov rax, rdi    ; rax = x
    mov rbx, -1     ; rbx = -1
    mul rbx         ; x = abs(x)
    mov rdi, rax    ; rdi = abs(x)

    .positive:

   ; push rdi
   ; push rsi
   ; mov rdi, 5      ; 3 numbers for bigint digits, 1 for its count, 1 for sign
   ; mov rsi, 4
   ; call calloc     ; rax - void *bigint
   ; mov r9, rax     ; r9  - void *bigint
   ; pop rsi
   ; pop rdi

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
    mov rax, r9 ; rax - void *bigint

    pop rbx
    ret

; rdi - s
; rsi - result
biFromString:
    push r12
    push rbx

    xor r12, r12        ; for sign
    cmp byte[rdi], '-'
    jne .after_sign
    inc rdi
    mov r12, 1          ; r12 = sign
    .after_sign:
    push rdi
    call strlen
    mov r10, rax ; r10 = strlen(s)
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
    mov [rsi], r12      ; sign
    mov [rsi+4], r11    ; count of big_digits

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
    cmp eax, 1              ; check BigInt is negative
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

section .rodata
d10:    dq 10
d1:     dq 1
dm1:    dq -1
d0:     dq 0

