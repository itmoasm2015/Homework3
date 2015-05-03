default rel
section .text

extern malloc, calloc, strlen, free, memcpy

global biFromInt
global biFromString
global biToString
global biDelete
global biSign
global biCmp
global biAdd
global biSub
global biMul
global biDivRem

%include 'macroses.inc'

;; BigInt structure representation:
;;      bigint - array of 32-bit numbers, where
;;      bigint[0] - sign of the number:
;;              * 1     - if > 0
;;              * 0     - if = 0
;;              * -1    - if < 0
;;      bigint[1] - a count of digits
;;      bigint[2..bigint[1] + 1] - digits that are in the base = 10^9

BASE equ 1000000000

;; int biSign(BigInt x)
;;      Returns a sign of BigInt
;; Takes:   RDI - x
;; Returns: RAX - sign of x
biSign:
    mov rdi, [rdi]
    mov rax, 0
    mov eax, [rdi]
    ret

;; BigInt biFromInt(int64_t x)
;;      Converts int to BigInt or returns null if it is impossible
;; Takes:   RDI - x
;; Returns: RAX - BigInt
biFromInt:
    xor rcx, rcx
    mov ecx, 1              ; set positive sign 
    cmp rdi, 0              ; if rdi < 0
    jge .isPositive
    mov ecx, -1             ; set negative flag
    neg rdi                 ; make BigInt positive
    .isPositive:
    push rdi
    push rsi
    push rcx                ; calloc can do harm to rcx
    mov rdi, 3              ; in int can't be more than 3 digits in BASE = 10000000
    add rdi, 2              ; 2 cells for sign and size
    mov rsi, 4              ; 4 bytes
    push r15
    mov r15, rsp
    and rsp, 0xFFFFFFF0
    call calloc
    mov rsp, r15
    pop r15
    pop rcx
    pop rsi
    pop rdi
    mov r9, rax             ; save allocated pointer
    mov rax, rdi
    mov rdx, 0
    mov r10, BASE
    div r10                 ; take digits by BASE
    mov [r9 + 8], edx       ; write the first digit  
    mov rdx, 0
    mov r10, BASE
    div r10
    mov [r9 + 12], edx      ; write the second digit
    mov rdx ,0
    mov r10, BASE
    div r10
    mov [r9 + 16], edx      ; write the third digit
    mov [r9], ecx           ; write sign
    mov eax, 3
    mov [r9 + 4], eax       ; write size = 3
    deleteZeroes r9           ; lets delete nulls in the begining
    mov eax, [r9 + 4]
    cmp eax, 1              ; if size == 1
    jne .ret_false_1
    mov eax, [r9 + 8]       ; add the first digit to the answer
    cmp eax, 0
    jne .ret_false_1
    mov eax, 0
    mov [r9], eax
    mov rax, 1
    jmp .break_out_1
    .ret_false_1:
    mov rax, 0              ; return null
    .break_out_1:
    push r9
    push rdi
    push rsi
    mov rdi, 8              ; malloc and now pointer in rax
    call malloc
    pop rsi
    pop rdi
    pop r9
    mov [rax], r9           ; return result to rax 
    ret

;; BigInt biFromString(char const *s)
;;      Creates a BigInt from a decimal string representation
;; Takes:   RDI - pointer to the string
;; Returns: RAX - BigInt of the string or NULL if string is invalid number
biFromString:
    push rbx
    mov rcx, 1              ; set positive sign to rcx
    cmp byte[rdi], '-'
    jne .skip_minus_sign
    inc rdi
    mov rcx, -1             ; set negative sign
    .skip_minus_sign:
    .skip_nulls:
    cmp byte[rdi], '0'
    jne .break_nulls        ; while current char == '0'
    inc rdi
    cmp byte[rdi], 0        ; and it's not the end of the string
    je .break_2
    jmp .skip_nulls
    .break_2:
    sub rdi, 1              ; lets return to the previous null
    .break_nulls:
    push rdi
    push rcx                ; strlen can do harm rcx
    call strlen
    pop rcx                 ; return it from stack
    mov r10, rax            ; save length of the string
    pop rdi
    cmp r10, 0              ; if isEmpty
    je .if_is_empty
    mov rdx, 0
    mov rax, r10
    add rax, 8
    mov ebx, 9
    div ebx                 ; put to rax count of digits in the string
    mov r11, rax            ; and put save it to r11
    push rdi
    push rsi
    mov rdi, r11            ; for allocating save count of digits to rdi
    add rdi, 2              ; 2 more cells for size and sign
    mov rsi, 4              ; by 4 bytes
    push rcx
    push r11
    push r10
    push r15
    mov r15, rsp
    and rsp, 0xFFFFFFF0
    call calloc
    mov rsp, r15
    pop r15
    pop r10
    pop r11
    pop rcx
    pop rsi
    pop rdi
    mov rsi, rax
    mov rax, rcx            ; put sign to rax 
    mov [rsi], eax          ; and to rsi
    mov rax, r11            ; save size
    mov [rsi + 4], eax      ; write next cell the size
    mov rcx, 0              ; i = 0
    ;; for (int i = 0; i < size; i++)
    .loop:
    mov r11, r10
    sub r10, 9
    cmp r10, 0
    jge .break_sub_out
    mov r10, 0
    .break_sub_out:
    mov r9, 0               ; j = 0
    ;; for (int j = 0; j < size; j++)
    .loop_2:
    mov rbx, 0
    mov bl, byte[rdi + r10] ; current digit
    mov rax, 0
    cmp bl, '0'             ; if (current digit is not a digit) then break to wrong format
    jl .wrong_format
    cmp bl, '9'
    jg .wrong_format
    sub bl, '0'
    mov rax, r9
    push rcx
    mov rcx, 10
    mul rcx                 ; rax = curent * 10
    pop rcx
    add rax, rbx            ; rax = curent * 10 + digit
    mov r9, rax
    inc r10
    cmp r11, r10
    jne .loop_2
    sub r10, 9
    cmp r10, 0
    jge .break_sub
    mov r10, 0
   .break_sub:    
    mov rax, r9
    mov [rsi + rcx * 4 + 8], eax
    inc rcx                 ; i++
    cmp r10, 0
    jne .loop
    .finish:
    mov eax, [rsi + 4]      ; put size to rax
    cmp eax, 1
    jne .skip_1             ; if size == 1
    mov eax, [rsi + 8]
    cmp eax, 0
    jne .skip_1             ; return false
    mov eax, 0
    mov [rsi], eax          ; save sign
    mov rax, 1
    jmp .break_out
    .skip_1:
    xor rax, rax
    .break_out:
    mov eax, [rsi + 4]
    cmp eax, 1
    jne .skip_2
    mov eax, [rsi + 8]
    cmp eax, 0
    jne .skip_2
    mov eax, 0
    mov [rsi], eax
    mov rax, 1
    jmp .break_out_n
    .skip_2:
    mov rax, 0
    .break_out_n:
    push rdi
    push rsi
    mov rdi, 8
    
    push rcx                ; malloc can do harm to rcx

    call malloc

    pop rcx

    pop rsi
    pop rdi
    mov [rax], rsi          ; save values
    pop rbx
    ret
    .wrong_format:
    push rdi
    mov rdi, rsi
    push r15
    mov r15, rsp
    and rsp, 0xFFFFFFF0
    call free
    mov rsp, r15
    pop r15               ; free memory
    pop rdi
    mov rax, 0              ; return 0
    pop rbx
    ret
    .if_is_empty:
    mov rax, 0              ; return 0
    pop rbx
    ret

;; void biDelete(BigInt a)
;; Delete BigInt and free memory
;; Takes:   rdi - BigInt to delete
biDelete:
    push rdi
    mov rdi, [rdi]
    push r15
    mov r15, rsp
    and rsp, 0xFFFFFFF0
    call free
    mov rsp, r15
    pop r15
    pop rdi
    push r15
    mov r15, rsp
    and rsp, 0xFFFFFFF0
    call free
    mov rsp, r15
    pop r15
    ret

;; void biToString(BigInt bi, char *buffer, size_t limit)
;;      Converts BigInt to string and writes at most linit bytes to buffer
;; Takes:  rdi - bi to convert to string
;;         rsi - buffer to write string
;;         rdx - limit of bytes to write
biToString:
    mov rdi, [rdi]
    push rcx
    mov rcx, rdx
    cmp rcx, 1
    jle .write_result
    mov eax, [rdi]
    cmp eax, -1
    jne .convert
    mov byte[rsi], '-'
    inc rsi
    sub rcx, 1
    cmp rcx, 1
    je .write_result
    .convert:
    mov eax, [rdi + 4]
    sub eax, 1
    mov ebx, 9
    mul ebx
    mov r9, 0
    mov r9d, [rdi + 4]
    mov rbx, 0
    mov ebx, [rdi + r9 * 4 + 4]
    push rbx
    mov rax, rbx
    mov r9, 0
    .loop:
    inc r9
    mov ebx, 10
    mov rdx, 0
    div ebx
    cmp rax, 0
    je .break1
    jmp .loop
    .break1:
    mov rax, r9
    pop rbx
    sub rax, 1
    push r12
    push rbx
    mov r12, rax
    mov rax, 10
    mov eax, 1
    .loop1:
    cmp r12, 0
    je .break2
    sub r12, 1
    mov ebx, 10
    mul ebx
    jmp .loop1
    .break2:
    pop rbx
    pop r12
    push r14
    mov r8d, eax
    mov r14d, [rdi + 4]
    mov eax, [rdi + r14 * 4 + 4]
    push r15
    push rdx
    .loop2:
        mov r15, 0
        mov r15d, eax
        mov rdx, 0
        div r8d
        mov rbx, rax
        add bl, '0'
        mov byte[rsi], bl
        inc rsi
        sub rcx, 1
        cmp rcx, 1
        je .write_result
        mul r8d
        sub r15d, eax
        mov rax, r15
        push rax
        mov eax, r8d
        mov ebx, 10
        div ebx
        mov r8d, eax
        pop rax
        cmp r8, 0
        jne .loop2
    .loop3:
    sub r14d, 1
    cmp r14d, 0
    je .break3
    mov eax, [rdi + r14 * 4 + 4]
    mov r9d, 100000000
    mov r10, 0
    mov r10d, 10
    .loop_in:
    cmp r9d, 0
    je .break_in
    mov r8d, r9d
    mov r15, 0
    mov r15d, eax
    mov rdx, 0
    div r8d
    mov rbx, rax
    add bl, '0'
    mov byte[rsi], bl
    inc rsi
    sub rcx, 1
    cmp rcx, 1
    je .write_result
    mul r8d
    sub r15d, eax
    mov rax, r15
    push rax
    mov rax, 0
    mov eax, r9d
    div r10d
    mov r9d, eax
    pop rax
    jmp .loop_in
    .break_in:
    jmp .loop3
    .break3:
    .write_result:
    mov byte[rsi], 0
    pop rdx
    pop r15
    pop r14
    pop rcx
    ret

;; int biCmp(BigInt a, BigInt b)
;;      Returns sign of a - b
;; Takes:   RDI - a
;;          RSI - b
;; Returns: sign of a - b
biCmp:
    mov rdi, [rdi]                  ; put digits to rdi
    mov rsi, [rsi]                  ; and to rsi the second one
    push r12
    push r13
    push rbx
    mov r12, 0                      ; if a and b are zeroes
    mov rax, 0
    cmp [rdi], eax
    jne .continue_cmp_1
    add r12, 1
    .continue_cmp_1:
    mov rax ,0
    cmp [rsi], eax
    jne .continue_cmp_2
    add r12, 2
    .continue_cmp_2:
    mov rax, 0
    cmp r12, 3                      ; set than a and b are zeroes
    je .write_cmp_result
    mov r12, 0                      ; a and b are of different signs
    mov rax, 0
    cmp [rdi], eax
    jg .continue_cmp_3
    add r12, 1
    .continue_cmp_3:
    mov rax ,0
    cmp [rsi], eax
    jl .continue_cmp_4
    add r12, 2
    .continue_cmp_4:
    mov rax, -1                     ; then a < b
    cmp r12, 3                      ; set that a <= 0 and b >= 0
    je .write_cmp_result
    mov r12, 0
    mov rax ,0
    cmp [rdi], eax
    jl .continue_cmp_5
    add r12, 1
    .continue_cmp_5:
    mov rax ,0
    cmp [rsi], eax
    jg .continue_cmp_6
    add r12, 2
    .continue_cmp_6:
    mov rax, 1                      ; if a > b
    cmp r12, 3
    je .write_cmp_result            ; if a and b of the same sign then compare their absolute values
    mov eax, [rdi]
    mov r13d, eax                   ; set sign
    mov eax, [rdi + 4]              ; size of a 
    mov ebx, [rsi + 4]              ; size of b
    cmp eax, ebx
    je .do_compare
    mov eax, r13d                   ; set a v b : it depends on sign
    jg .write_cmp_result
    neg rax                         ; if a and b are negative than reverse result
    jmp .write_cmp_result
    .do_compare:
    mov r12, 0
    mov eax, [rdi + 4]
    mov r12d, eax
    .loop_cmp:
        mov rax ,0                  ; then all digits are equal
        cmp r12, 0                  ; if the end
        je .write_cmp_result
        sub r12, 1
        mov rax, 0
        mov rbx, 0
        mov eax, [rdi + r12 * 4 + 8]
        mov ebx, [rsi + r12 * 4 + 8]
        cmp eax, ebx
        je .loop_cmp
        mov eax, r13d
        jg .write_cmp_result
        neg rax
        jmp .write_cmp_result
    .write_cmp_result:
    pop rbx
    pop r13
    pop r12
    ret

;; void biSub(BigInt dst, BigInt src)
;;      Returns subtraction of two BigInts and put result to the first argument
;; Takes:   RDI - dst
;;          RSI = src
biSub:
    push rdi
    mov rdi, [rdi]              ; put BigInts to rdi and rsi
    mov rsi, [rsi]
    push r12
    mov rax, 0
    cmp [rdi], eax              ; if a is zero then copy there -b
    jne .continue_sub_1
    push rbx
    push rsi
    push r15
    mov r15, rsp
    and rsp, 0xFFFFFFF0
    call free
    mov rsp, r15
    pop r15               ; delete a
    pop rsi
    push rsi
    push rbx
    xor rbx, rbx
    mov ebx, [rsi + 4]
    push rdi
    push rsi
    mov rdi, rbx            ; put size of a to rdi
    add rdi, 2              ; 2 cells for sign and size
    mov rsi, 4              ; by 4 bytes
    push r15
    mov r15, rsp
    and rsp, 0xFFFFFFF0
    call calloc
    mov rsp, r15
    pop r15
    pop rsi
    pop rdi
    mov rdi, rax
    pop rbx
    pop rsi
    xor rdx, rdx
    mov edx, [rsi + 4]      ; size of b
    add edx, 2              ; 2 cells
    shl edx, 2
    call memcpy
    pop rbx
    mov r12d, [rdi]             ; let set negstive sign
    neg r12d
    mov [rdi], r12d
    jmp .write_sub_result
    .continue_sub_1:
    mov rax, 0
    cmp [rsi], eax              ; if b is zero then do nothing
    je .write_sub_result
    mov r12, 0
    mov rax, 0
    cmp [rdi], eax
    jl .a_sign_1
    add r12, 1                  ; if a > 0
    .a_sign_1:
    mov rax, 0
    cmp [rsi], eax              ; compare sig of b
    jl .b_sign_1
    add r12, 2                  ; if b > 0
    .b_sign_1:
    cmp r12, 1                  ; a and b of different signs
    jne .continue_sub_2
    mov eax, 1
    mov [rsi], eax              ; a + |b| 
    sumOfOneSign
    mov eax, -1
    mov [rsi], eax              ; sign
    jmp .write_sub_result
    .continue_sub_2:
    cmp r12, 2
    jne .continue_sub_3
    mov eax, 1
    mov [rdi], eax
    sumOfOneSign
    mov eax, -1
    mov [rdi], eax
    jmp .write_sub_result
    .continue_sub_3:
    cmp r12, 0                  ; a and b are negative
    jne .continue_sub_4
    mov eax, 1
    mov [rdi], eax
    mov [rsi], eax
    subtractPositive                 ; |a| - |b|
    mov r12d, [rdi]             ; set sign
    neg r12d
    mov [rdi], r12d
    mov eax, -1
    mov [rsi], eax
    jmp .write_sub_result
    .continue_sub_4:
    subtractPositive                 ; a and b are positive
    .write_sub_result:
    pop r12
    mov rax, rdi                ; return result
    pop rdi
    mov [rdi], rax
    ret

;; void biAdd(BigInt dst, BigInt src)
;;      Returns sum of two BigInts and put result to the first argument
;; Takes:   RDI - dst
;;          RSI - src
biAdd:
    push rdi
    mov rdi, [rdi]              ; put BigInt a to rdi
    mov rsi, [rsi]              ; b to rsi
    push rbx
    push r12
    push r13
    mov rax, 0
    cmp [rdi], eax
    jne .continue_add_1      
    jmp .write_add_result_1
    .continue_add_1:
    mov rax, 0
    cmp [rsi], eax  ;           ; b == 0 then do nothing
    je .write_add_result_1
    mov r12, 0
    mov rax, 0
    cmp [rdi], eax
    jl .a_sign_2
    add r12, 1                  ; if  a > 0
    .a_sign_2:
    mov rax, 0
    cmp [rsi], eax              ; compare sign of b
    jl .b_sign_2
    add r12, 2                  ; b > 0
    .b_sign_2:
    cmp r12, 1                  ; a and b of different signs
    jne .continue_add_3
    mov eax, 1
    mov [rsi], eax              ; take absolute value of b
    subtractPositive                 ; a  - |b|
    mov eax, -1
    mov [rsi], eax              ; put sign of b
    jmp .write_add_result_1
    .continue_add_3:
    cmp r12, 2
    jne .continue_add_4
    mov eax, 1
    mov [rdi], eax
    subtractPositive                 ; |a| - b
    mov r12d, [rdi]             ; sign of |a|- b
    neg r12d
    mov [rdi], r12d
    jmp .write_add_result_1
    .continue_add_4:
    sumOfOneSign                ; a and b of the same sign
    .write_add_result_1:
    pop r13
    pop r12
    pop rbx
    mov rax, rdi                ; put result
    pop rdi
    mov [rdi], rax
    ret

;; void biMul(BigInt dst, BigInt src)
;;      Returns mul of two BigInts and put result to the first argument
;; Takes:   RDI - dst
;;          RSI - src
biMul:
    push rdi
    mov rdi, [rdi]              ; put digits to rsi
    mov rsi, [rsi]              ; the same with rsi
    push r12
    push r13
    push r14
    push rbx
    mov eax, 0
    cmp [rdi], eax              ; if a == 0 then result 0
    je .write_mul_result
    cmp [rsi], eax
    je .return_b                ; the same with b
    mov rbx, 0                  ; rbx = 0
    mov ebx, [rdi + 4]          ; put size of a to rbx
    add ebx, [rsi + 4]          ; and add size of b
    push rdi                    ; save registers for calloc
    push rsi
    mov rdi, rbx                ; put count of digits to rdi now
    add rdi, 2                  ; also as usual 2 cells for sign and count
    mov rsi, 4                  ; by 4 byte on cell
    push r15
    mov r15, rsp
    and rsp, 0xFFFFFFF0
    call calloc
    mov rsp, r15
    pop r15
    pop rsi
    pop rdi
    mov r12, rax
    mov [r12 + 4], rbx          ; size of result <= size of a + size of b
    mov eax, [rdi]              ; put signs to rax and rcx
    mov ecx, [rsi]
    mul ecx                     ; sign of result
    mov [r12], eax              ; put it
    mov r11, 0
    mov r13, 0                  ; i = 0
    ;; for (int i = 0; i < a.size(); i++)
    .loop1:
        mov r14, 0              ; j = 0
    .loop2:
        mov r8, r13
        add r8, r14
        add r8, 2
        shl r8, 2               ; put result to r8
        push r12
        add r12, r8
        mov rax, 0
        cmp r13d, [rdi + 4]
        jge .skip_out_of_size_tt
        push r8
        mov r8, 0
        mov r8d, r13d
        mov eax, [rdi + r8 * 4 + 8]
        pop r8
        .skip_out_of_size_tt:
        mov r9d, eax
        mov rax, 0
        cmp r14d, [rsi + 4]
        jge .skip_out_of_size_pp
        push r8
        mov r8, 0
        mov r8d, r14d
        mov eax, [rsi + r8 * 4 + 8]
        pop r8
        .skip_out_of_size_pp:
        xor rdx, rdx
        mul r9d                 ; a[i] * b[j]
        add eax, r11d           ; += carry
        adc edx, 0              ; a[i] * b[j] + carry
        add eax, [r12]          ; previous result
        adc edx, 0              ; add results
        mov r11, 0              ; refresh carry
        mov r10d, BASE
        div r10d                ; eax = carry, edx = current digit
        mov r11d, eax           ; put carry to r11
        mov [r12], edx
        pop r12                 ; return values
        inc r14d                ; j++
        cmp r14d, [rsi + 4]     ; break if the end
        jge .b_finished
        jmp .loop2              ; next iteration
        .b_finished:
        cmp r11d, 0             ; if we have carry add it
        jne .loop2
        inc r13d                ; i++
        cmp r13d, [rdi + 4]
        jl .loop1               ; break if the end
        deleteZeroes r12          ; delete nulls
        push rsi
        mov rsi, r12
        push rbx
        push rsi
        push r15
        mov r15, rsp
        and rsp, 0xFFFFFFF0
        call free
        mov rsp, r15
        pop r15               ; delete a
        pop rsi
        push rsi
        push rbx
        xor rbx, rbx
        mov ebx, [rsi + 4]
        push rdi
        push rsi
        mov rdi, rbx            ; put size of a to rdi
        add rdi, 2              ; 2 cells for sign and size
        mov rsi, 4              ; by 4 bytes
        push r15
        mov r15, rsp
        and rsp, 0xFFFFFFF0
        call calloc
        mov rsp, r15
        pop r15
        pop rsi
        pop rdi
        mov rdi, rax
        pop rbx
        pop rsi
        xor rdx, rdx
        mov edx, [rsi + 4]      ; size of b
        add edx, 2              ; 2 cells
        shl edx, 2
        call memcpy
        pop rbx
        pop rsi
        push rdi
        push rsi
        mov rdi, r12
        push r15
        mov r15, rsp
        and rsp, 0xFFFFFFF0
        call free
        mov rsp, r15
        pop r15               ; free memory that we used
        pop rsi
        pop rdi
        jmp .write_mul_result
        .return_b:
        mov rdi, rax    ; rdi = tmp.values
        push rbx
        push rsi
        push r15
        mov r15, rsp
        and rsp, 0xFFFFFFF0
        call free
        mov rsp, r15
        pop r15               ; delete a
        pop rsi
        push rsi
        push rbx
        xor rbx, rbx
        mov ebx, [rsi + 4]
        push rdi
        push rsi
        mov rdi, rbx            ; put size of a to rdi
        add rdi, 2              ; 2 cells for sign and size
        mov rsi, 4              ; by 4 bytes
        push r15
        mov r15, rsp
        and rsp, 0xFFFFFFF0
        call calloc
        mov rsp, r15
        pop r15
        pop rsi
        pop rdi
        mov rdi, rax
        pop rbx
        pop rsi
        xor rdx, rdx
        mov edx, [rsi + 4]      ; size of b
        add edx, 2              ; 2 cells
        shl edx, 2
        call memcpy
        pop rbx
        .write_mul_result:
        pop rbx
        pop r14
        pop r13
        pop r12
        mov rax, rdi            ; return result to rax
        pop rdi
        mov [rdi], rax
        ret

biDivRem:
    ret
