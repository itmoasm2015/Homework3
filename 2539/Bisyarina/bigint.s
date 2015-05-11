section .text

extern malloc
extern calloc
extern realloc
extern memset
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
        push r13
        alignStack16
        push rdi
        mov rdi, [rdi + 8]
        call free
        pop rdi
        call free
        remAlignStack16
        pop r13
        ret

biSign:
        mov rax, [rdi + 16]
        ret

biCmp:
        push rdi
        push rsi
        ;; Compare signs of bigint
        mov rax, [rdi +16]
        mov rdx, [rsi +16]
        cmp rax, rdx
        ;; If equal continue comparing
        je .compare_size
        ;; If sign of first is less than second
        jl .set_less
.set_greater:
        ;; Return is greater
        mov qword rax, 1
        jmp .exit
.set_less:
        ;; Return is less
        mov qword rax, -1
        jmp .exit
.compare_size:
        ;; Save sign
        mov r8, [rdi + 16]
        mov rax, [rdi]
        mov rdx, [rsi]
        ;; Get length difference
        sub rax, rdx
        test rax, rax
        ;; If equal proceed to comparing
        jz .compare
        xor rdx, rdx
        ;; If length diff < 0 and sign < 0 than greater
        ;; If length diff < 0 and sign > 0 than less
        ;; If length diff > 0 and sign > 0 than greater
        ;; If length diff > 0 and sign < 0 than less
        ;; So, length diff * sign = answer
        mul r8
        jmp .exit
.compare:
        ;; Set loop counter
        mov rcx, [rdi]
        push rcx
        mov rcx, [rdi + 8]
        mov rdi, rcx
        mov rcx, [rsi + 8]
        mov rsi, rcx
        pop rcx
.loop:
        ;; Check if finished
        test rcx, rcx
        jz .exit_zero
        
        ;; Get current int64
        dec rcx
        mov rax, [rdi + rcx * 8]
        mov rdx, [rsi + rcx * 8]
        cmp rax, rdx
        ;; If equal continue
        je .loop
        jg .greater
        ;; If less return -sign
        mov rax, r8
        neg rax
        jmp .exit
.greater:
        ;; If greater return sign
        mov rax, r8
        jmp .exit
.exit_zero:
        xor rax, rax
.exit:
        pop rsi
        pop rdi
        ret


;;; rdi - bigint
;;; rsi - new size must be bigger than bigint in rdi size
recalloc:        
        push r13
        push rsi
        push rdi
        alignStack16
        ;; Calculate new size in bytes
        mov rax, rsi
        xor rdx, rdx
        mov qword rcx, 8
        mul rcx
        mov rsi, rax
        ;; Set pointer to data in rdi
        mov rdi, [rdi + 8]
        call realloc
        remAlignStack16
        pop rdi 
        pop rsi
        
        ;; Test allocation successfull
        test rax, rax
        jz .exit
        ;; Set pointer to new data in bigint
        mov [rdi + 8], rax

        push rdi
        ;; Calculating uninitialzed memory pointer after the bigint old data
        alignStack16
        mov rax, [rdi]
        mov rcx, [rdi]
        xor rdx, rdx
        push rcx
        mov qword rcx, 8
        mul rcx
        pop rcx
        mov rdi, [rdi + 8]
        add rdi, rax
        
        ;; Calculate additional memory size(after reallocation)
        mov rax, rsi
        sub rax, rcx
        xor rdx, rdx
        mov qword rcx, 8
        mul rcx
        mov rdx, rax
        xor rsi, rsi
        call memset
        remAlignStack16
        pop rdi
.exit:
        pop r13
        ret



biAdd:
        ;; Check if rdi and rsi are pointers to same bigint
        cmp rdi, rsi
        jne .sum
        ;; Set size of buffer to size + 1
        push rsi
        mov rax, [rdi]
        inc rax
        mov rsi, rax
        call recalloc
        pop rsi
        ;; Mul by 2
        push rsi
        mov qword rsi, 2
        call mulInt
        pop rsi
        jmp .exit
.sum:
        ;; Check if signs are equal
        mov rax, [rdi + 16]
        mov rcx, [rsi + 16]
        cmp rax, rcx
        jne .diff_signs
.just_sum:
        ;; If signs are equal
        ;; Get maximum of sizes
        mov rcx, [rdi]
        cmp rcx, [rsi]
        cmovb rcx, [rsi]
        push rcx
        inc rcx
        ;; Realloc rdi's data to max(sizes) + 1
        push rsi
        mov rsi, rcx
        call recalloc
        pop rsi
        pop rcx
        mov [rdi], rcx
        ;; Set loop bound
        mov r8, [rsi]
        mov r11, rdi
        ;; Set pointers to data
        mov rdi, [rdi + 8]
        mov rsi, [rsi + 8]

        clc
        xor r9, r9
        xor r10, r10
        xor rcx, rcx
.loop:
        ;; Checl length
        cmp rcx, r8
        jl .looploop
        ;; Check carry flag
        test r9, r9
        jz .exit
        inc qword [r11]
        mov rax, [rdi + rcx * 8]
        mov qword rdx, 1
        add rax, rdx
        ;; Save carry flag
        adc r10, 0
        ;; Add previous carry
        add rax, r9
        ;; Save carry flag
        adc r10, 0
        mov r9, r10
        xor r10, r10
        mov [rdi + rcx * 8], rax
        inc rcx
        test r9, r9
        jnz .loop
        jmp .exit
.looploop:
        mov rax, [rdi + rcx * 8]
        mov rdx, [rsi + rcx * 8]
        add rax, rdx
        ;; Save carry flag
        adc r10, 0
        ;; Add previous carry
        add rax, r9
        ;; Save carry flag
        adc r10, 0
        mov r9, r10
        xor r10, r10
        mov [rdi + rcx * 8], rax
        inc rcx
        jmp .loop
.diff_signs:
        mov rax, [rdi + 16]
        mov rcx, [rsi + 16]
        test rax, rax
        jz .or_sign
        test rcx, rcx
        jz .or_sign
        

.or_sign:        
        or rax, rcx
        mov [rdi + 16], rax
        jmp .just_sum
.exit:
        ret

biSub:  
        ;; Check if rdi and rsi are pointers to same bigint
        cmp rdi, rsi
        jne .sub
        mov qword [rdi], 1
        mov rdi, [rdi + 8]
        xor rax, rax
        mov [rdi], rax
        jmp .exit
.sub:
        
        ;; Check if signs are equal
        mov rax, [rdi + 16]
        mov rcx, [rsi + 16]
        cmp rax, rcx
        jne .diff_signs
.just_sub:
        ;; TODO check a >= b
        ;; If signs are equal
        ;; Get maximum of sizes
        mov rcx, [rdi]
        cmp rcx, [rsi]
        cmovb rcx, [rsi]
        push rcx
        inc rcx
        ;; Realloc rdi's data to max(sizes) + 1
        push rdi
        push rsi
        mov rdi, rsi
        mov rsi, rcx
        call recalloc
        pop rsi
        pop rdi
        pop rcx
        ;; Set loop bound
        mov r8, [rsi]
        mov r11, rdi
        ;; Set pointers to data
        push rsi
        push rdi
        mov rdi, [rdi + 8]
        mov rsi, [rsi + 8]

        xor r9, r9
        xor r10, r10
        xor rcx, rcx
.loop:
        ;; Checl length
        cmp rcx, r8
        jnl .finish
.looploop:
        mov rax, [rdi + rcx * 8]
        mov rdx, [rsi + rcx * 8]
        sub rax, rdx
        ;; Save carry flag
        adc r10, 0
        ;; Add previous carry
        sub rax, r9
        ;; Save carry flag
        adc r10, 0
        mov r9, r10
        xor r10, r10
        mov [rdi + rcx * 8], rax
        inc rcx
        jmp .loop
.diff_signs:
        jmp .exit
.finish:
        dec rcx
        xor rdx, rdx
.lead_z:
        test rcx, rcx
        jz .pop_exit
        mov rax, [rdi + rcx * 8]
        test rax, rax
        jnz .pop_exit
        inc rdx
        dec rcx
        jmp .lead_z
.pop_exit:
        pop rdi
        mov rax, [rdi]
        sub rax, rdx
        mov [rdi], rax
        pop rsi
.exit:
        ret

biMul:
        push r12
        push r13
        push r14
        push r15

        mov rax, [rdi]
        mov rcx, [rsi]
        add rax, rcx
        push rdi
        push rsi
        mov rdi, rax
        call allocate
        pop rsi
        pop rdi
        mov r12, rax
        push r12
        mov r12, [r12 + 8]

        xor r8, r8
        xor r9, r9
        mov r10, [rdi]
        mov r11, [rsi]
        push rdi
        push rsi
        mov rdi, [rdi + 8]
        mov rsi, [rsi + 8]
        xor r15, r15
.loopI:
        cmp r8, r10
        jnl .finish
        xor r9, r9
        xor r13, r13            ;TODO push
        xor r14, r14            ;TODO push
.loopJ:
        cmp r9, r11
        jl .loopBody
        test r13, r13
        jnz .loopBody
        inc r8
        jmp .loopI
.loopBody:
        xor rdx, rdx
        mov rax, [rdi + r8 * 8]
        mov qword rcx, 0
        cmp r9, r11
        jnl .loopBodyFinish
        mov rcx, [rsi + r9 * 8]
.loopBodyFinish:
        mul rcx
        mov r14, rdx

        mov r15, r9
        add r15, r8
        add rax, [r12 + r15 * 8]
        adc r14, 0
        add rax, r13
        adc r14, 0
        mov r13, r14
        xor r14, r14
        mov r15, r9
        add r15, r8
        mov [r12 + r15 * 8], rax
        inc r9
        jmp .loopJ
        
.finish:
        pop rsi
        pop rdi
        pop r12
        mov rax, [r12 + 8]
        mov rcx, [rdi + 8]
        mov [rdi + 8], rax
        mov [r12 + 8], rcx
        push rdi
        push rsi
        mov rdi, r12
        call biDelete
        pop rsi
        pop rdi
        inc r15
        mov [rdi], r15
        mov rax, [rdi + 16]
        mov rcx, [rsi + 16]
        xor rdx, rdx
        mul rcx
        mov [rdi + 16], rax
        test rax, rax
        jnz .exit
        mov qword [rdi], 1
.exit:
        pop r15
        pop r14
        pop r13
        pop r12
        ret

biDivRem:
        ret

biToString:
        ret
