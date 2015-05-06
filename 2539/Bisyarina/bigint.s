section .text

extern malloc
extern calloc
extern free
extern strlen

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


;;; Aligns stack by 16, saves difference to alignStack
%macro alignStack16 0
        xor rdx, rdx
        mov rax, rsp
        mov qword rcx, 16
        div rcx
        mov r13, rdx
        sub rsp, rdx
%endmacro

;;; Return stack to state before alignStack16
;;; Nothing must be pushed between
%macro remAlignStack16 0
        add rsp, r13
%endmacro

;;; Allocates memory for bigint structure with given length of data
allocate:       
        push rdi
        push rsi
        push r12
        push r13

        alignStack16

        ;; Calc size of data in bytes
        mov qword rsi, 8
        ;; Allocate bytes for data
        call calloc
        ;; Check if allocation successfull
        test rax, rax
        jz .exit
        ;; Save pointer to data
        mov r12, rax
        ;; Allocate struct of bigint
        mov qword rdi, 3
        mov qword rsi, 8
        call calloc
        ;; Check if allocation successfull
        test rax, rax
        jz .exit
        ;; Initialize struct eith pointer to data
        mov [rax + 8], r12
.exit:
        remAlignStack16
        pop r13
        pop r12
        pop rsi
        pop rdi
        ret


%macro setSign 2
        push rdx
        push rax

        mov rdx, %1
        mov qword rax, %2
        mov qword [rdx + 16], rax

        pop rax
        pop rdx
%endmacro



addInt: 
        push rax
        push rcx
        push rdx
        push r8

        ;; Check if integer is positive
        mov rax, rsi
        test rax, rax
        jz .add
        ;; If positive set rsi bigint positive
        setSign rdi, 1
.add:
        mov rax, [rdi]
        test rax, rax
        jnz .addadd
        mov qword rax, 1
        mov [rdi], rax
.addadd:
        ;; Get pointer to data
        mov rax, rdi
        mov rcx, [rax + 8]
        ;; Get size
        mov r8, [rax]
        mov rax, [rcx]
        ;; Add to last int64 of bigint data an integer
        clc
        add rax, rsi
        mov [rcx], rax
        jnc .exit
        ;; While carry bit is true or intex less then size
.loop:
        ;; Check size
        test r8, r8
        jnz .looploop
        push rax
        mov rax, [rdi]
        inc rax
        mov [rdi], rax
        pop rax
.looploop:
        ;; Move pointer to current int64 of data
        add rcx, 8
        mov rax, [rcx]
        dec r8
        ;; Add carry
        clc
        add rax, 1
        jc .loop

.exit:
        pop r8
        pop rdx
        pop rcx 
        pop rax
        ret
;;; rdi
;;; rsi
mulInt: 
        push rax
        push rcx
        push rdx
        push r8
        push r9

        ;; Check if int is zero
        test rsi, rsi
        jnz .mul
        ;; Set sign zero if zero
        setSign rdi, 0
.mul:
        ;; Init carry
        xor r8, r8
        mov rax, rdi
        mov rcx, [rax + 8]
        ;; Get size
        mov r9, [rax]
.loop:
        ;; Check size
        cmp r9, 0
        jg .looploop
        test r8, r8
        jz .exit
.looploop:
        ;; Multiply
        xor rdx, rdx
        mov rax, [rcx]
        mul rsi
        clc
        ;; Add carry
        add rax, r8
        mov [rcx], rax
        ;; Save new carry
        mov r8, rdx
        dec r9
        add qword rcx, 8
        jnc .loop
.add:
        ;; Add carry from sum
        add r8, 1
        jmp .loop

.exit:
        cmp r9, 0
        jge .exitexit
        mov rax, [rdi]
        inc rax
        mov [rdi], rax

.exitexit:
        pop r9
        pop r8
        pop rdx
        pop rcx 
        pop rax
        ret


;;; rdi - int64
biFromInt:      
        push rdi
        mov qword rdi, 1
        call allocate
        pop rdi
        ;; Check successful allocation
        test rax, rax
        jz .exit
        ;; Set size
        mov qword [rax], 1
        ;; Save pointer
        mov rsi, rax
        push rax

        ;; Manage sign
        cmp rdi, 0
        je .exit
        jl .neg
        
        ;; Init positive bigint
        setSign rsi, 1
        mov rdx, [rsi + 8]
        mov [rdx], rdi
        jmp .exit
.neg:
        setSign rsi, -1
        neg rdi
        mov rdx, [rsi + 8]
        mov [rdx], rdi
.exit:
        pop rax
        ret


;;; rdi - string s
biFromString:
        push r12
        push rdi
        ;; Get length of string
        alignStack16
        call strlen
        remAlignStack16
        ;; Allocate
        push rax
        add rax, 10
        xor rdx, rdx
        ;; Don't need int64 for each symbol, but some extra space is ok
        mov qword r8, 10
        div r8
        mov rcx, rax
        push rdi
        mov rdi, rcx
        call allocate
        pop rdi
        pop rcx
        pop rdi
        ;; Check allocation successfull
        test rax, rax
        jz .exit
        ;; Save pointer no bigint
        mov rsi, rax
        ;; Check if negaive
        xor r12, r12
        mov al, [rdi]
        dec rdi
        cmp al, '-'
        jne .loop
        ;; Check for "-"
        cmp rcx, 1
        je .exit_fail
        ;; Set negative
        mov qword r12, 1

        inc rdi
.loop:                          ; possible to chunk by 19 figures
        inc rdi
        ;; CHeck if end
        xor rax, rax
        mov al, [rdi]
        cmp al, 0
        je .finish

        push rsi
        push rdi
        mov rdi, rsi
        mov qword rsi, 10
        call mulInt 
        pop rdi
        pop rsi

        sub al, '0'
        test al, al
        jz .loop
        push rdi
        push rsi
        mov rdi, rsi
        mov rsi, rax
        call addInt 
        pop rsi
        pop rdi
        jmp .loop
.finish:
        mov rax, rsi
        cmp r12, 1
        je .set_neg
        mov rcx, [rsi + 16]
        cmp rcx, 0
        jne .exit
        mov qword rcx, 1
        mov [rsi], rcx
        jmp .exit
.exit_fail:
        ;; If fail, but allocated - free memory
        mov rdi, rsi
        call biDelete
.set_neg:
        push rax
        setSign rsi, -1
        pop rax
.exit:
        pop r12
        ret


biDelete:
        push rdi
        mov rax, [rdi + 8]
        mov rdi, rax
        call free
        pop rdi
        call free
        ret

biSign:
        mov rax, [rdi + 16]
        ret

biCmp:
        ret

biAdd:  
        ret

biSub:  
        ret

biMul:  
        ret

biDivRem:
        ret

biToString:
        ret
