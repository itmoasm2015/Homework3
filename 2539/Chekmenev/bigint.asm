default rel

section .text

extern malloc
extern calloc
extern free
extern strlen
extern memcpy
extern printf

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

;; Constants

BASE              equ 1000000000
BASE_LENGTH       equ 9

;; Structure of BitInt:
;; =============================================
;;  1) stores an array of 'values'
;;  2) every 'value' is 32-bit number up to BASE
;; values:
;;  [0] - sign (
;;      -1 - number < 0,
;;      0 - number == 0,
;;      1 - number > 0
;;  )
;;  [1] - size (count of digits stored in 'values')
;;  [2..size+1] - digits[] (stored in reversed order)
;; =============================================

;; MacroUtils

;frequent operations

; Check whether cmp %1, %3 satisfies j(%+2), then go to %4
%macro if 4
    cmp %1, %3
    j%+2 %4
%endmacro

; Push every passed register on stack
%macro multiPush 1-*
    %rep %0
        push %1
        %rotate 1
    %endrep
%endmacro

; Pop every passed register from stack
%macro multiPop 1-*
    %rep %0
        pop %1
        %rotate 1
    %endrep
%endmacro

; Set every passed register to 0
%macro fillZero 1-*
	%rep %0
		xor %1, %1
		%rotate 1
	%endrep
%endmacro

;   Return 10^(%1)
;   Input:
;       %1 - power of 10
;   Output:
;       rax = 10^(%1)
;   Complexity - O(power)
%macro powerOfTen 1
    multiPush r12, rbx
    mov r12, %1             ; r12 = power
    fillZero rax           ; fill zero
    mov eax, 1              ; eax = 1
%%continue:
    if r12, e, 0, %%finish  ; finish if power == 0
    sub r12, 1              ; power -= 1
    mov ebx, 10
    mul ebx                 ; eax *= 10
    jmp %%continue
%%finish:
    multiPop rbx, r12
%endmacro

;   Safe subtract: %1 -= BASE_LENGTH (if %1 < 0 then %1 = 0)
;   Input:
;       %1 - number to be subtracted
;   Output:
;       %1 - (%1 -= BASE_LENGTH)
;   Complexity - O(1)
%macro subBaseLength 1
    sub %1, BASE_LENGTH
    if %1, ge, 0, %%finish  ; finish if %1 >= 0
    mov %1, 0               ; set %1 to 0
%%finish:
%endmacro

;   Calc how many digits in number
;   Input:
;       %1 - number
;   Output:
;       rax - digits count in %1
;   Complexity - O(1)
%macro digitsInNumber 1
    push rbx
    mov rax, %1             ; rax = %1
    fillZero r9            ; count = 0
%%loop:
    inc r9                  ; count += 1
    mov ebx, 10
    fillZero rdx           ; fill zero
    div ebx                 ; rax /= 10
    if rax, e, 0, %%finish  ; finish if rax == 0
    jmp %%loop
%%finish:
    mov rax, r9             ; rax = count
    pop rbx
%endmacro

; allocations

; Set zero last four bits
%macro alignStack 0
    and rsp, ~15
%endmacro

%macro alignedFree 0
    push r12
    mov r12, rsp        ; save rsp
    alignStack
    call free
    mov rsp, r12        ; restore rsp
    pop r12
%endmacro

%macro alignedCalloc 0
    push r12
    mov r12, rsp        ; save rsp
    alignStack
    call calloc
    mov rsp, r12        ; restore rsp
    pop r12
%endmacro


;; BigInt operations macros

;   Create BigInt with one memory cell for address to values
;   Output:
;       rax - address of BigInt
;   Complexity - O(1)
%macro biCreate 0
    multiPush rdi, rsi
    mov rdi, 8   ; size of address to values
    sub rsp, 8
    call malloc
    add rsp, 8
    multiPop rsi, rdi
%endmacro

;   Trim leading zeroes
;   Input:
;       %1 - address of BigInt
;   Complexity - O(BigInt.size)
%macro trimLeadingZeroes 1
    mov ecx, [%1+4]         ; ecx = BigInt.size
%%continue:
    sub ecx, 1
    cmp ecx, 0
    je %%finish             ; finish if counter is 0

    fillZero rdx           ; fill zero
    cmp [%1+(2+rcx)*4], edx
    jne %%finish            ; finish if current digit != 0

    mov edx, [%1+4]         ; edx = BigInt.size
    sub edx, 1
    mov [%1+4], edx         ; decrease BigInt.size

    jmp %%continue
%%finish:
%endmacro

;   Check whether BigInt is null
;   Input:
;       %1 - address of BigInt
;   Output:
;       rax = {
;           1, if %1 equals to 0
;           0, otherwise
;       }
;   Complexity - O(1)
%macro isNull 1
    mov eax, [%1+4]         ; eax = BigInt.size
    if eax, ne, 1, %%error  ; error if BigInt.size != 1

    mov eax, [%1+8]         ; eax = BigInt.digits[0]
    if eax, ne, 0, %%error  ; error if BigInt.digits[0] != 0

    mov eax, 0
    mov [%1], eax           ; update sign

    jmp %%success
%%error:
    fillZero rax   ; fill zero
%%success:
    mov rax, 1
%endmacro

;   Divide rax by BASE, set reminder to cell [%1+4*%2]
;   Output:
;       rax = rax/BASE
;   Complexity - O(1)
%macro setReminderToIndex 2
    fillZero rdx       ; fill zero
    mov r10, BASE
    div r10             ; rax = x/BASE, rdx = x%BASE
    mov [%1+4*(2+%2)], edx  ; set reminder to cell
%endmacro

;   Allocate memory for BigInt.values with %1 digits
;   Input:
;       %1 - size
;   Complexity - O(BigInt.size)
%macro callocDigits 1
    multiPush rdi, rsi
    mov rdi, %1         ; rdi = size
    add rdi, 2          ; one for sign and one for size
    mov rsi, 4          ; every value is 32-bit number
    alignedCalloc
    multiPop rsi, rdi
%endmacro

;; BigInt Operations

;   Create a BigInt from 64-bit signed integer.
;   Input:
;      rdi - int64_t x
;   Output:
;      rax - BigInt result
;   Complexity - O(1)
biFromInt:
    push rbx
    mov esi, 1                  ; sign = 1
    if rdi, ge, 0, .positive

    mov esi, -1                 ; sign = -1
    neg rdi                     ; x = |x|
.positive:
    callocDigits 3              ; (10^9)^3 > 2^63 - 1
    mov r9, rax                 ; r9 - address of BigInt

    mov rax, rdi
    setReminderToIndex r9, 0
    setReminderToIndex r9, 1
    setReminderToIndex r9, 2

    mov [r9], esi               ; BigInt.sign
    mov eax, 3
    mov [r9+4], eax             ; BigInt.size = 3

    trimLeadingZeroes r9
    isNull r9                   ; check is 0 for sign

    push r9
        biCreate
    pop r9

    mov [rax], r9               ; rax[0] = address of values
    pop rbx
    ret

;   Create new BigInt from given string s
;   Input:
;       rdi - string s
;   Output:
;       rax - new BigInt
;   Complexity - O(|s|)
biFromString:
    multiPush r12, rbx

    mov r12, 1                          ; for sign
    if byte[rdi], ne, '-', .after_sign
    inc rdi
    mov r12, -1                         ; r12 = sign
.after_sign:
    .trim_loop:                             ; trim leading zeros
        if byte[rdi], ne, '0', .processing  ; if s[ptr] != '0' then break
        inc rdi                             ; ptr++
        if byte[rdi], e, 0, .undo           ; if ptr == |s|
        jmp .trim_loop
    .undo
        sub rdi, 1                          ; if s = '0'
.processing:
    push rdi
    call strlen
    mov r10, rax                            ; r10 = strlen(s)
    pop rdi
    if r10, e, 0, .no_digits                ; if there is no digits

    fillZero rdx
    mov rax, r10    ;
    add rax, BASE_LENGTH-1
    mov ebx, BASE_LENGTH
    div ebx                                 ; rax = (strlen(s)+BASE_LENGTH-1)/BASE_LENGTH = digits count
    mov r11, rax                            ; r11 = digits count

    multiPush r10, r11
    callocDigits r11 ; allocate memory for BigInt
    multiPop r11, r10

    mov rsi, rax
    mov rax, r12
    mov [rsi], eax      ; sign
    mov rax, r11
    mov [rsi+4], eax    ; size

    fillZero r12        ; index of big_digit
.loop:
    mov r11, r10
    subBaseLength r10

    fillZero r9
    .inner_loop:
        xor rbx, rbx            ;
        mov bl, byte[rdi+r10]   ; bl = cur_digit as character

        if bl, l, '0', .wrong_input  ; bl < '0' |=> bad format
        if bl, g, '9', .wrong_input  ; bl > '9' |=> bad format

        sub bl, '0'             ; rbx - cur_digit of big_digit

        mov rax, r9             ; rax = cur_big_digit
        mov rcx, 10             ; rcx = 10
        mul rcx                 ; rax = cur_big_digit * 10
        add rax, rbx            ; rax = cur_big_digit * 10 + cur_digit
        mov r9, rax             ; cur_big_digit = cur_big_digit * 10 + cur_digit

        inc r10
        if r11, ne, r10, .inner_loop

    subBaseLength r10

    mov rax, r9
    mov [rsi+(r12+2)*4], eax     ; BigInt.digits[r12] = cur_big_digit
    inc r12                      ; BigInt_index++

    if r10, ne, 0, .loop

.finish:
    isNull rsi
    biCreate        ; rax - empty BigInt
    mov [rax], rsi  ; rax = address of values
    pop rbx
    pop r12
    ret

.no_digits:
    fillZero rax    ; return NULL
    pop rbx
    pop r12
    ret

.wrong_input:
    push rdi
    mov rdi, rsi
    alignedFree       ; delete allocated memory
    pop rdi

    fillZero rax    ; return NULL
    pop rbx
    pop r12
    ret

; write rax/r8 to [rsi]
; compare r13 with limit (r8 - power of 10, r8 > rax)
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

;   Generate a decimal string representation of BigInt to the buffer.
;   Buffer can be up to limit characters.
;   Input:
;      rdi - BigInt address
;      rsi - buffer
;      rdx - limit
;   Complexity - O(|s|)
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
    digitsInNumber rbx          ; rax - digits count of first_big_digit

    ; first big_digit:
    sub rax, 1              ; first_big_digit.length - 1
    powerOfTen rax
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
.finish:
    mov byte[rsi], 0    ; s = '\0'
    pop rbx
    pop r15
    pop r14
    pop r13
    ret

;   Delete BigInt
;   Input:
;      rdi - BigInt address
;   Complexity - O(1)
biDelete:
    push rdi
    mov rdi, [rdi]  ; rdi = BigInt.values
    alignedFree     ; delete BigInt.values
    pop rdi
    alignedFree     ; delete BigInt
    ret

;   Return sign of this BigInt.
;   Input:
;      rdi - BigInt
;   Output:
;      rax - 0 if BigInt == 0, 1 if BigInt > 0, -1 if BigInt < 0.
;   Complexity - O(1)
biSign:
    mov rdi, [rdi] ; rdi = BigInt.values
    mov eax, [rdi]
    ret

;   Compare two BigInts
;   Input:
;       rdi - a.values
;       rsi - b.values
;   Output:
;       rax - result(
;           result =  0 if a = b
;           result = -1 if a < b
;           result =  1 if a > b)
;   Complexity - O(max(|a|, |b|))
%macro cmpOperation 0
        push r12
        push r13
        push rbx

        ; r12 for mask of signs:
        ; r12 = 0 - first condition is FALSE, second condition is FALSE
        ;     = 1 - TRUE  FALSE
        ;     = 2 - FALSE TRUE
        ;     = 3 - TRUE  TRUE

        ; a == 0 && b == 0
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

        ; a <= 0 && b >= 0
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


        ; a >= 0 && b <= 0
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

        ; a > 0 && b > 0  OR a < 0 && b < 0
        ; compare absolute values, r13 for sign (res*r13 at the end)
        mov eax, [rdi]
        mov r13d, eax            ; r13 - sign of a and b

        mov eax, [rdi+4]        ; rax = a.length
        mov ebx, [rsi+4]        ; rbx = b.length
        cmp eax, ebx
        je %%start_compare       ; if a.length != b.length, then start hard comparing
        mov eax, r13d            ; if a.length > b.length, then res = 1 * sign
        jg %%finish
        neg rax                  ; else res = -1 * sign
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
        neg rax         ; else res = -sign
        jmp %%finish

        %%finish:
        pop rbx
        pop r13
        pop r12
%endmacro

;   Compare two BigInts
;   Input:
;       rdi - a
;       rsi - b
;   Output:
;       rax - result
;           result =  0 if a = b
;           result = -1 if a < b
;           result =  1 if a > b
;   Complexity - O(max(|a|, |b|))
biCmp:
    mov rdi, [rdi] ; rdi = a.values
    mov rsi, [rsi] ; rsi = b.values
    cmpOperation
    ret

;   Copy b.values to a.values
;   Input:
;       rdi - a.values
;       rsi - b.values
%macro biCopy 0
        push rbx
%%deleting:
        push rsi
        alignedFree   ; delete a
        pop rsi
%%allocating:
        push rsi
        push rbx
        xor rbx, rbx
        mov ebx, [rsi+4]
        callocDigits rbx   ; allocate new BigInt.values
        mov rdi, rax
        pop rbx
        pop rsi
%%copying:
        xor rdx, rdx
        mov edx, [rsi+4]    ; rdx - b.length
        add edx, 2          ; for sign and length
        shl edx, 2          ; rdx = rdx * sizeof(int) (rdx * 4)
        call memcpy
        pop rbx
%endmacro

;   Return i-th digit from BigInt.digits
;   Input:
;       %1 - i
;       %2 - BigInt.values
;   Output:
;       eax - ith bigdigit
;   Complexity - O(1)
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

;   Input:
;       rdi - a != 0
;       rsi - b != 0
;   Output:
;       r12 = 0 - FALSE FALSE (a < 0 && b < 0)
;           = 1 - TRUE  FALSE (a > 0 && b < 0)
;           = 2 - FALSE TRUE  (a < 0 && b > 0)
;           = 3 - TRUE  TRUE  (a > 0 && b > 0)
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

;   b += a (b.sign = a.sign)
;   Input:
;       rdi - b.values
;       rsi - a.values
;   Output:
;       a.values = (a + b).values
;   Complexity - O(max(|a|, |b|))
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
        callocDigits rbx
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

        trimLeadingZeroes r12  ; delete leading zeros

        push rsi
        mov rsi, r12
        biCopy          ; copy tmp to a
        pop rsi

        push rdi
        push rsi
        mov rdi, r12
        alignedFree       ; delete tmp
        pop rsi
        pop rdi

        pop r13
        pop r12
        pop rbx
%endmacro ; addSameSigns

;   a -= b (a > b)
;   Input:
;       rdi - a.values
;       rsi - b.values
;   Output:
;       a.values = (a - b).values
;   Complexity - O(|a|)
%macro safeSubtract 0
        push rbx
        push r12
        push r13

        xor rbx, rbx
        mov ebx, [rdi+4]    ; ebx = a.size
        cmp ebx, [rsi+4]
        jg %%continue2
        mov ebx, [rsi+4]    ; res.size = rbx = max(a.size, b.size)
        %%continue2:

        callocDigits rbx
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

        trimLeadingZeroes r12  ; delete leading zeros

        push rsi
        mov rsi, r12
        biCopy          ; copy tmp to a
        pop rsi

        push rdi
        push rsi
        mov rdi, r12
        alignedFree       ; delete tmp
        pop rsi
        pop rdi

        %%finish:
        pop r13
        pop r12
        pop rbx
%endmacro ; safeSubtract

;   a -= b (a > 0 && b > 0)
;   Input:
;       rdi - a.values
;       rsi - b.values
;   Output:
;       a.values = (a - b).values
;   Complexity - O(max(|a|, |b|))
%macro subtractNonNegative 0
        push r12
        push r13

        cmpOperation
        cmp rax, 0          ; a == b
        jne %%not_equal
        push rsi
        alignedFree           ; delete a.values
        ; a = 0:
        pop rsi
        callocDigits 1     ; 1 bigdigit
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

        callocDigits 0 ; create tmp.values

        mov rdi, rax    ; rdi = tmp.values
        biCopy          ; rdi = b.values
        mov rsi, r12    ; rsi = a.values
        safeSubtract          ; rdi = (b-a).values

        mov eax, [rdi]  ; eax = (b-a).sign
        neg eax         ; eax = -(b-a).sign
        mov [rdi], eax  ; rdi = (-(b-a)).values

        push rdi
        mov rdi, r12    ; rdi = a.values
        alignedFree       ; delete a.values
        pop rdi

        mov rsi, r13    ; rsi = b.values

        jmp %%finish

        %%agb:
        safeSubtract

        %%finish:
        trimLeadingZeroes rdi
        isNull rdi
        pop r13
        pop r12
%endmacro ; subtractNonNegative

;   a += b
;   Input:
;       rdi - a.values
;       rsi - b.values
;   Output:
;       a.values = (a+b).values
;   Complexity - O(max(|a|, |b|))
%macro addOperation 0
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

        subtractNonNegative     ; a = a - abs(b)

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

        subtractNonNegative     ; a = abs(a) - b

        mov r12d, [rdi] ; r12 = (abs(a) - b).sign
        neg r12d        ; r12 = (-(a - b)).sign = -((abs(a) - b).sign)
        mov [rdi], r12d ; rdi = -(abs(a) - b)
        jmp %%finish
        %%continue4:

        ; a > 0 and b > 0 or a < 0 && b < 0
        addSameSigns

        %%finish:
        pop r13
        pop r12
        pop rbx
%endmacro ; addOperation

;   Add b to a and save value in a (a += b)
;   Input:
;      rdi - address of a
;      rsi - address of b
;    Output:
;       a = a + b
;   Complexity - O(max(|a|, |b|))
biAdd:
    push rdi
    mov rdi, [rdi]  ; rdi - address of a.values
    mov rsi, [rsi]  ; rsi - address of b.values
    addOperation        ; rdi - address of (a+b).values
    mov rax, rdi    ; save (a+b).values
    pop rdi
    mov [rdi], rax  ; a.values = (a+b).values
    ret

;   a -= b
;   Input:
;       rdi - a.values
;       rsi - b.values
;   Output:
;       a.values = (a - b).values
;   Complexity - O(max(|a|, |b|))
%macro subtractOperation 0
        push r12

        xor rax, rax
        cmp [rdi], eax  ; if a == 0, then a = -b
        jne %%continue1
        biCopy              ; a.values = b.values
        mov r12d, [rdi]     ; r12 = b.sign
        neg r12d            ; r12 = -b.sign
        mov [rdi], r12d     ; a.sign = -b.sign
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
        subtractNonNegative     ; rdi = (abs(a)-abs(b)).values
        mov r12d, [rdi] ; r12 = (abs(a)-abs(b)).sign
        neg r12d        ; r12 = -(abs(a)-abs(b)).sign
        mov [rdi], r12d ; rdi = -(abs(a)-abs(b))
        mov eax, -1     ;
        mov [rsi], eax  ; load b.sign
        jmp %%finish
        %%continue4:

        ; a > 0 && b > 0
        subtractNonNegative

        %%finish:
        pop r12
%endmacro

; Subtract b from a and save result in a (a -= b)
;   Input:
;       rdi - address of a
;       rsi - address of b
;   Output:
;       a = a - b
;   Complexity - O(max(|a|, |b|))
biSub:
    push rdi
    mov rdi, [rdi]  ; rdi = a.values
    mov rsi, [rsi]  ; rsi = b.values
    subtractOperation        ; rdi = (a-b).values
    mov rax, rdi    ; save (a-b).values
    pop rdi
    mov [rdi], rax  ; a.values = (a-b).values
    ret

;   a *= b
;   Input:
;       rdi - a.values
;       rsi - b.values
;   Output:
;       a.values = (a*b).values
;   Complexity - O(|a|*|b|)
%macro multiplyOperation 0
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
        callocDigits rbx   ; allocate memory for a.size+b.size bigdigits
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


        trimLeadingZeroes r12  ; delete leading zeros

        push rsi
        mov rsi, r12
        biCopy          ; copy tmp to a
        pop rsi

        push rdi
        push rsi
        mov rdi, r12
        alignedFree       ; delete tmp
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
%endmacro


;   Multiplies a on b and save result in a (a *= b)
;   Input:
;       rdi - a
;       rsi - b
;   Output:
;       a = a*b
;   Complexity - O(|a|*|b|)
biMul:
    push rdi
    mov rdi, [rdi]  ; rdi - address of a.values
    mov rsi, [rsi]  ; rsi - address of b.values
    multiplyOperation
    mov rax, rdi    ; save (a*b)
    pop rdi
    mov [rdi], rax  ; a.values = (a*b).values
    ret

;   no implementation
biDivRem:
    ret
