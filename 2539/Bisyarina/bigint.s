section .text

extern malloc
extern calloc
extern free

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

alignStack:
        dq 0

;;; Aligns stack by 16, saves difference to alignStack
%macro alignStack16
        mov rax, rsp
        div 16
        mov [alignStack], rdx
        sub rsp, rdx
%endmacro

;;; Return stack to state before alignStack16
;;; Nothing must be pushed between
%remAlignStack16
        add rsp, [alignStack]
        mov qword [alignStack], 0
%endmacro

;;; Allocates memory for bigint structure with given length of data
%macro allocate %1
        push rdi
        push r12

        alignStack16
        ;; Calc size of data in bytes
        mov rax, %1
        mul rax, 8
        mov rdi, rax
        ;; Allocate bytes for data
        call calloc
        ;; Check if allocation successfull
        test rax, rax
        jz %%exit
        ;; Save pointer to data
        mov r12, rax
        ;; Allocate struct of bigint
        mov qword rdi, 24
        call calloc
        ;; Check if allocation successfull
        test rax, rax
        jz .exit
        ;; Initialize struct eith pointer to data
        mov [rax + 8], r12
%%exit:

        remAlignStack16
        pop r12
        pop rdi
%endmacro

%macro addInt 2
        push rax
        push rcx
        push rdx
        push r8

        ;; Check if integer is positive
        mov rax, %2
        test rax, rax
        jz %%add
        ;; If positive set rsi bigint positive
        setSign %2, 1
%%add:  
        ;; Get pointer to data
        mov rax, %1
        mov rcx, [rax + 8]
        ;; Get size
        mov r8, [rax]
        mov rax, [rcx]
        ;; Add to last int64 of bigint data an integer
        clc
        add rax, %2
        mov [rcx], rax
        jnc .exit
        ;; While carry bit is true or intex less then size
%%loop:
        ;; Check size
        test r8, r8
        jz %%exit
        ;; Move pointer to current int64 of data
        add rcx, 8
        mov rax, [rcx]
        dec r8
        ;; Add carry
        clc
        add rax, 1
        jc %%loop

%%exit:
        pop r8
        pop rdx
        pop rcx 
        pop rax
%endmacro

%macro mulInt 2
        push rax
        push rcx
        push rdx
        push r8
        push r9

        ;; Check if int is zero
        mov rax, %2
        test rax, rax
        jnz %%mul
        ;; Set sign zero
        setSign %2, 0
%%mul:
        ;; Init carry
        xor r8, r8
        mov rax, %1
        mov rcx, [rax + 8]
        ;; Get size
        mov r9, [rax]
%%loop:
        ;; Check size
        test r9, r9
        jz %%exit
        ;; Multiply
        xor rdx, rdx
        mov rax, [rcx]
        mul rax, %2
        clc
        ;; Add carry
        add rax, r8
        mov [rcx], rax
        ;; Save new carry
        mov r8, rdx
        dec r9
        jnc %%loop
%%add:
        ;; Add carry from sum
        add r8, 1
        jmp %%loop

%%exit:
        pop r9
        pop r8
        pop rdx
        pop rcx 
        pop rax
%endmacro

%macro setSign 2
        push rdx
        push rax
        mov rdx, %1
        mov rax, %2
        mov qword [rdx + 16], rax
        pop rax
        pop rdx
%endmacro       

;;; rdi - int64
biFromInt:      
        allocate 1
        test rax, rax
        jz .exit
        ;; Init bigint
        mov qword [rax], 1
        mov rdx, [rax + 8]
        mov [rdx], rdi
.exit:
        ret


;;; rdi - string s
biFromString:
        push rdi
        ;; Get length of string
        alignStack16
        call strlen
        remAlignStack16
        ;; Allocate
        push rax
        ;; Don't need int64 for each symbol, but some extra space is ok
        div 10
        mov rcx, rax
        allocate rcx
        pop rcx
        pop rdi
        ;; Check allocation successfull
        test rax, rax
        jz .exit
        ;; Save pointer no bigint
        mov rsi, rax
        ;; Check if negaive
        mov al, [rdi]
        cmp al, '-'
        jne .loop
        ;; Check for "-"
        cmp rcx, 1
        je .exit_fail
        ;; Set negative
        setSign rsi, -1
        inc rdi
.loop:                          ; possible to chunk by 19 figures
        ;; CHeck if end
        xor rax, rax
        mov al, [rdi]
        cmp al, 0
        je .finish
        
        mulInt rsi, 10               ; must not affect rax

        sub al, '0'
        test al, al
        jz .loop
        addInt rsi, rax
        jmp .loop
.finish:
        mov rax, rsi
        jmp .exit
.exit_fail:
        ;; If fail, but allocated - free memory
        mov rdi, rsi
        call biDelete
.exit:
        ret

biToString:     
        ret

biDelete:       
        ret

biSign: 
        ret

biAdd:  
        ret

biSub:  
        ret

biMul:  
        ret

biDivRem:       
        ret

biCmp:  
        ret
