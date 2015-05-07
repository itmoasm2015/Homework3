;; Takes poiner to BigInt and deletes leading nulls from it
%macro deleteZeroes 1
    push rcx
    push rdx
    %%loop1
    mov ecx, [%1 + 4]
    sub ecx, 1
    cmp ecx, 0
    je %%finish
    mov rdx, 0
    cmp [%1 + 4 * rcx + 8], edx
    jne %%finish
    mov edx, [%1 + 4]
    sub edx, 1
    mov [%1 + 4], edx
    jmp %%loop1
    %%finish:
    pop rdx
    pop rcx
%endmacro

;; Returns sum of two BigInts (in rds and rsi) of the same signs
%macro sumOfOneSign 0
        push rbx
        push r12
        push r13
        mov rbx, 0
        mov ebx, [rdi + 4]
        cmp ebx, [rsi + 4]
        jg %%continue_same_2
        mov ebx, [rsi+4]                ; put the maximum size
        %%continue_same_2:
        inc ebx                         ; for carry
        push rdi
        push rsi
        mov rdi, rbx                    ; size to rdi
        add rdi, 2                      ; sign and size
        mov rsi, 4                      ; cells by 4 bytes
        push r15
        mov r15, rsp
        and rsp, ~15
        call calloc
        mov rsp, r15
        pop r15
        pop rsi
        pop rdi
        mov r12, rax                    ; result
        mov eax, [rsi]                  ; write sign and size
        mov [r12], eax
        mov [r12 + 4], ebx
        mov r13d, 0                     ; and carry of course
        mov rbx, 0
        %%loop:
            mov r8, 0
            add r8d, r13d               ; add carry if it exists
            mov rax, 0
            cmp ebx, [rdi + 4]
            jge %%skip_out_of_size_1
            push r8
            mov r8, 0
            mov r8d, ebx
            mov eax, [rdi + r8 * 4 + 8]
            pop r8
            %%skip_out_of_size_1:
            add r8d, eax                ; i digit in a
            mov rax, 0
            cmp ebx, [rsi + 4]
            jge %%skip_out_of_size_2
            push r8
            mov r8, 0
            mov r8d, ebx
            mov eax, [rsi + r8 * 4 + 8]
            pop r8
            %%skip_out_of_size_2:
            add r8d, eax                ; ... in b
            mov r13d, 0                 ; refresh carry
            cmp r8d, BASE
            jl %%zero_carry
            inc r13d                    ; put 1 to carry
            sub r8d, BASE
            %%zero_carry:
            mov [r12 + rbx * 4 + 8], r8d
            inc rbx                     ; i++
            cmp ebx, [r12 + 4]
            jne %%loop
        deleteZeroes r12          ; delete zeroes
        push rsi
        mov rsi, r12
        push rbx
        push rsi
        push r15
        mov r15, rsp
        and rsp, ~15
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
        and rsp, ~15
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
        and rsp, ~15
        call free
        mov rsp, r15
        pop r15               ; free memory that we used
        pop rsi
        pop rdi
        pop r13
        pop r12
        pop rbx
%endmacro

;; subtract two BigInts where the first more then the second (in rdi and rsi)
%macro moreSub 0
        push rbx
        push r12
        push r13
        xor rbx, rbx
        mov ebx, [rdi + 4]       ; size of a
        cmp ebx, [rsi + 4]
        jg %%continue2
        mov ebx, [rsi + 4]       ; put maximum of sizes
        %%continue2:
        push rdi
        push rsi
        mov rdi, rbx             ; size
        add rdi, 2               ; sign and digits
        mov rsi, 4               ; by 4 bytes
        push r15
        mov r15, rsp
        and rsp, ~15
        call calloc
        mov rsp, r15
        pop r15
        pop rsi
        pop rdi
        mov r12, rax             ; result
        mov eax, [rdi]
        mov [r12], eax
        mov [r12+4], ebx
        xor r13d, r13d           ; write carry
        xor rbx, rbx
        %%loop:
            xor r8, r8
            sub r8d, r13d        ; use carry
            mov rax, 0
            cmp ebx, [rdi + 4]
            jge %%skip_out_of_size_3
            push r8
            mov r8, 0
            mov r8d, ebx
            mov eax, [rdi + r8 * 4 + 8]
            pop r8
            %%skip_out_of_size_3:
            add r8d, eax         ; a[i]
            mov rax, 0
            cmp ebx, [rsi + 4]
            jge %%skip_out_of_size_4
            push r8
            mov r8, 0
            mov r8d, ebx
            mov eax, [rsi + r8 * 4 + 8]
            pop r8
            %%skip_out_of_size_4:
            sub r8d, eax            ; b[i]
            xor r13d, r13d          ; refresh carry
            cmp r8d, 0
            jge %%zero_carry
            inc r13d                ; put 1
            add r8d, BASE
            %%zero_carry:
            mov [r12+(rbx+2)*4], r8d
            inc rbx                     ; i++
            cmp ebx, [r12+4]
            jne %%loop
        deleteZeroes r12              ; delete zeroes
        push rsi
        mov rsi, r12
        push rbx
        push rsi
        push r15
        mov r15, rsp
        and rsp, ~15
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
        and rsp, ~15
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
        and rsp, ~15
        call free
        mov rsp, r15
        pop r15       ; delete tmp
        pop rsi
        pop rdi
        %%finish:
        pop r13
        pop r12
        pop rbx
%endmacro

;; Subtractio of two positiveNumbers
%macro subtractPositive 0
        push r12
        push r13
        push r12
        push r13
        push rbx
        mov r12, 0                      ; if a and b are zeroes
        mov rax, 0
        cmp [rdi], eax
        jne %%continue_cmp_1
        add r12, 1
        %%continue_cmp_1:
        mov rax ,0
        cmp [rsi], eax
        jne %%continue_cmp_2
        add r12, 2
        %%continue_cmp_2:
        mov rax, 0
        cmp r12, 3                      ; set than a and b are zeroes
        je %%write_cmp_result
        mov r12, 0                      ; a and b are of different signs
        mov rax, 0
        cmp [rdi], eax
        jg %%continue_cmp_3
        add r12, 1
        %%continue_cmp_3:
        mov rax ,0
        cmp [rsi], eax
        jl %%continue_cmp_4
        add r12, 2
        %%continue_cmp_4:
        mov rax, -1                     ; then a < b
        cmp r12, 3                      ; set that a <= 0 and b >= 0
        je %%write_cmp_result
        mov r12, 0
        mov rax ,0
        cmp [rdi], eax
        jl %%continue_cmp_5
        add r12, 1
        %%continue_cmp_5:
        mov rax ,0
        cmp [rsi], eax
        jg %%continue_cmp_6
        add r12, 2
        %%continue_cmp_6:
        mov rax, 1                      ; if a > b
        cmp r12, 3
        je %%write_cmp_result            ; if a and b of the same sign then compare their absolute values
        mov eax, [rdi]
        mov r13d, eax                   ; set sign
        mov eax, [rdi + 4]              ; size of a 
        mov ebx, [rsi + 4]              ; size of b
        cmp eax, ebx
        je %%do_compare
        mov eax, r13d                   ; set a v b : it depends on sign
        jg %%write_cmp_result
        neg rax                         ; if a and b are negative than reverse result
        jmp %%write_cmp_result
        %%do_compare:
        mov r12, 0
        mov eax, [rdi + 4]
        mov r12d, eax
        %%loop_cmp:
        mov rax ,0                  ; then all digits are equal
        cmp r12, 0                  ; if the end
        je %%write_cmp_result
        sub r12, 1
        mov rax, 0
        mov rbx, 0
        mov eax, [rdi + r12 * 4 + 8]
        mov ebx, [rsi + r12 * 4 + 8]
        cmp eax, ebx
        je %%loop_cmp
        mov eax, r13d
        jg %%write_cmp_result
        neg rax
        jmp %%write_cmp_result
        %%write_cmp_result:
        pop rbx
        pop r13
        pop r12
        cmp rax, 0                  ; a == b
        jne %%not_equal
        push rsi
        push r15
        mov r15, rsp
        and rsp, ~15
        call free
        mov rsp, r15
        pop r15                   ; delete a
        pop rsi
        push rdi
        push rsi
        mov rdi, 1
        add rdi, 2
        mov rsi, 4
        push r15
        mov r15, rsp
        and rsp, ~15
        call calloc
        mov rsp, r15
        pop r15
        pop rsi
        pop rdi
        mov rdi, rax
        mov eax, 0
        mov [rdi], eax               ; zero
        mov eax, 1
        mov [rdi + 4], eax            
        mov eax, 0
        mov [rdi + 8], eax
        jmp %%finish

        %%not_equal:
        cmp rax, -1                 ; a < b
        jne %%more_sub
        mov r12, rdi                ; a
        mov r13, rsi                ; b

        push rdi
        push rsi
        mov rdi, 0
        add rdi, 2
        mov rsi, 4
        push r15
        mov r15, rsp
        and rsp, ~15
        call calloc
        mov rsp, r15
        pop r15
        pop rsi
        pop rdi
        mov rdi, rax                ; allocated 
        push rbx
        push rsi
        push r15
        mov r15, rsp
        and rsp, ~15
        call free
        mov rsp, r15
        pop r15                   ; delete a
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
        and rsp, ~15
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
        mov rsi, r12            ; a
        moreSub                 ; b - a
        mov eax, [rdi]          ; sign
        neg eax                 ; -sign
        mov [rdi], eax          ; digits
        push rdi
        mov rdi, r12            ; a
        push r15
        mov r15, rsp
        and rsp, ~15
        call free
        mov rsp, r15
        pop r15
        pop rdi
        mov rsi, r13            ; b
        jmp %%finish
        %%more_sub:
        moreSub
        %%finish:
        deleteZeroes rdi
        mov eax, [rdi+4]        ; size
        cmp eax, 1
        jne %%return_false_tt
        mov eax, [rdi+8]
        cmp eax, 0
        jne %%return_false_tt
        mov eax, 0
        mov [rdi], eax
        mov rax, 1
        jmp %%finish_tt
        %%return_false_tt:
        mov rax, 0
        %%finish_tt:
        pop r13
        pop r12
%endmacro
