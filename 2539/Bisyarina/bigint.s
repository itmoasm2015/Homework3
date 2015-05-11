default rel

section .text

extern calloc
extern realloc
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

;;; Bigint struct: uint64 size, uint65 pointer to data, int64 sign
;;; Amount of allocated memory may be greater than size
;;; Base is (2 << 64)
;;; Least significant bits go first
;;; There are no leading zeroes if bigint is not zero

;;; Swaps pointers to data of two bigints and deletes the first
%macro swapNfree 2
        mov rax, [%1 + 8]
        mov rcx, [%2 + 8]
        mov [%2 + 8], rax
        mov [%1 + 8], rcx
        push rdi
        push rsi
        mov rdi, %1
        call biDelete
        pop rsi
        pop rdi
%endmacro

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
;;; RDI - length of data for bigint
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

;;; setSgin(bigint b, int64 a)
;;; Sets sign of b to a
%macro setSign 2
        push rdx
        push rax

        mov rdx, %1
        mov qword rax, %2
        mov qword [rdx + 16], rax

        pop rax
        pop rdx
%endmacro

;;; Checks if bigint data is zero and sets zero sign
%macro setZeroIfZero 1
        mov rax, [%1]
        dec rax
        mov rcx, [%1 + 8]
        mov rax, [rcx + 8 * rax]
        test rax, rax
        jnz %%no_zero
        setSign %1, 0
%%no_zero:
%endmacro


;;; Adds  rsi to rdi
;;; rdi -  bigint 
;;; rsi - uint64
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
        ;; Add to last uint64 of bigint data an integer
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

;;; Multiplies rdi by rsi and stores result to rdi
;;; rdi -  bigint 
;;; rsi - uint64
;;; O(n) where n is rdi size
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

;;; Creates bigint from int64
;;; rdi - int64
;;; O(1)
biFromInt:      
        ;; Allocate with data size = 1
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

;;; Creates bigint from string
;;; RDI - pointer string s
;;; O(m^2) where m is string length(mulInt and addInt for each char)
biFromString:
        push r13
        push r12
        push rdi
        ;; Get length of string
        alignStack16
        call strlen
        remAlignStack16
        test rax, rax
        jnz .continue
        pop rdi
        jmp .exit
.continue:       
        ;; Allocate bigint
        push rax
        
        ;; Calculate size of bigint's data
        ;; Don't need uint64 for each symbol, but some extra space is ok
        add rax, 10
        xor rdx, rdx
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
.loop:
        inc rdi
        ;; Check if end
        xor rax, rax
        mov al, [rdi]
        cmp al, 0
        je .finish
        ;; Mul current result by 10
        push rsi
        push rdi
        mov rdi, rsi
        mov qword rsi, 10
        call mulInt 
        pop rdi
        pop rsi

        ;; Add (current symbol - '0')
        sub al, '0'
        test al, al
        jz .loop
        cmp al, 0
        jl .exit_fail
        cmp al, 9
        jg .exit_fail
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
        ;; Set sign
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
        xor rax, rax
        jmp .exit
.set_neg:
        push rax
        setSign rsi, -1
        push rdi
        mov rdi, rax
        setZeroIfZero rdi
        pop rdi
        pop rax
.exit:
        pop r12
        pop r13
        ret

;;; Frees memory assigned to bigint
;;; RDI - bigint
;;; O(1) + free complexity
biDelete:
        push r13
        push rdi
        alignStack16
        mov rdi, [rdi + 8]
        call free
        remAlignStack16
        pop rdi
        alignStack16
        call free
        remAlignStack16
        pop r13
        ret

;;; Return sign of bigint
;;; RDI - bigint
;;; O(1)
biSign:
        mov rax, [rdi + 16]
        ret
      
;;; Compare two BitInts.
;;; returns sign(a - b)
;;; RDI - first bigint
;;; RSI - second bigint
;;; O(n) where n is maximum of lengths
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
        mov rdi, [rdi + 8]
        mov rsi, [rsi + 8]
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


;;; Reallocates bigints data to given size and fills added space with zeroes
;;; rdi - bigint
;;; rsi - new size of data. It must be bigger than bigint in rdi size
;;; O(n + rsi) where n is rdi size + realloc complexity
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
        mov rax, [rdi]
        xor rdx, rdx
        mov qword rcx, 8
        mul rcx

        mov rcx, [rdi]
        mov rdi, [rdi + 8]
        add rdi, rax
        push rsi
        ;; Calculate additional memory size(after reallocation)
        sub rsi, rcx
        ;; Set added memory with zeroes
        mov rcx, rsi
        mov rsi, rdi
        mov qword rax, 0
        cld
        repe stosq
        pop rsi
        pop rdi
.exit:
        pop r13
        ret

;;; RDI - bigint to copy
;;; Creates a new copy of bigint with new copy of data
;;; Copies are independent
;;; O(n) where n is rdi size
biCopy:
        push rdi
        ;; Allocate bigint of rdi size
        mov rdi, [rdi]
        call allocate
        pop rdi

        push rdi
        push rsi
        push rax

        mov rsi, rax
        ;; Copy size
        mov rax, [rdi]
        mov [rsi], rax
        ;; Copy sign
        mov rax, [rdi + 16]
        mov [rsi + 16], rax
        ;; Set size and  pointers to their data
        mov rcx, [rdi]
        mov rdi, [rdi + 8]
        mov rsi, [rsi + 8]
.loop:
        test rcx, rcx
        jz .exit
        dec rcx
        ;; Copy uint64
        mov rax, [rdi + 8 * rcx]
        mov [rsi + 8 * rcx], rax
        jmp .loop
.exit:
        pop rax
        pop rsi
        pop rdi
        ret

;;; RDI - destination
;;; RSI - source
;;; But sign(dst) == sign(src)
;;; Add src to dst
;;; O(n) where n is maximum of lengths of bigints
biSimpleAdd:
        push r12
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
        mov r8, rcx
        mov r12, [rsi]
        ;; Save pinter to dst
        mov r11, rdi
        ;; Set pointers to data
        mov rdi, [rdi + 8]
        mov rsi, [rsi + 8]

        xor r9, r9
        xor r10, r10
        xor rcx, rcx
.loop:
        ;; Check idx less than size
        cmp rcx, r8
        jl .looploop
        ;; Check carry not zero
        test r9, r9
        jz .exit
        ;; If carry not zero, and size is over
        inc qword [r11]
.looploop:
        ;; Get uint64 in index rcx of rdi
        mov rax, [rdi + rcx * 8]
        mov rdx, 0
        ;; If src length is over set to 0
        cmp rcx, r12
        jnl .loopBody
        ;; Otherwise
        ;; Get uint64 in index rcx of rsi
        mov rdx, [rsi + rcx * 8]
.loopBody:
        add rax, rdx
        ;; Save carry flag
        adc r10, 0
        ;; Add previous carry
        add rax, r9
        ;; Set carry 
        adc r10, 0
        ;; Save current carry
        mov r9, r10
        xor r10, r10
        ;; Set result
        mov [rdi + rcx * 8], rax
        inc rcx
        jmp .loop
.exit:
        pop r12
        ret


;;; RDI - destination
;;; RSI - source
;;; Add src to dst
;;; O(n) where n is maximum of lengths of bigints
biAdd:
        ;; Check if rdi and rsi are pointers to same bigint
        ;; If so sum equal to rdi * 2
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
        je .simple_sum
.diff_signs:
        ;; Sum of bigints with different sizes is subtraction
        ;; Check to find zeroes
        mov rax, [rdi + 16]
        mov rcx, [rsi + 16]
        test rcx, rcx
        jz .exit
        test rax, rax
        jnz .sub
        ;; Set dst to the same sign as src and proceed to equal sign sum
        or rax, rcx
        mov [rdi + 16], rax
        jmp .simple_sum
.sub:
        ;; Here we have one negative and one positive bigint
        ;; Other cases are already taken
        ;; Check to determine which is positive
        cmp rcx, 0
        jg .swap
        ;; If second is negative
        ;; Invert its sign and compute sum
        push rdi
        push rsi
        mov qword [rsi + 16], 1
        call biSub
        pop rsi
        pop rdi
        ;; Invert sign again
        mov qword [rsi + 16], -1
        jmp .exit
.swap:
        ;; If first is negative
        ;; Copy rsi not to affect it
        push rdi 
        mov rdi, rsi
        call biCopy
        mov rdi, rax
        pop rdi
        ;; Compute copy_rsi - rdi
        push rax
        push rdi
        push rsi
        mov rsi, rdi
        mov rdi, rax
        ;; Invert rdi sign
        mov qword [rsi + 16], 1
        call biSub
        pop rsi
        pop rdi
        pop rdx
        ;; Copy result to rdi and free extra bigint
        mov rcx, [rdx]
        mov [rdi], rcx
        mov rcx, [rdx + 16]
        mov [rdi + 16], rcx
        swapNfree rdx, rdi
        jmp .exit
.simple_sum:
        ;; Just call equal sign sum
        push rdi
        push rsi
        call biSimpleAdd
        pop rsi
        pop rdi
.exit:
        ret

;;; RDI - destination
;;; RSI - source
;;; But |dst| >= |src|, sign(dst) == sign(src)
;;; Subtract dst by src and stores result in dst
;;; O(n) where n is maximum of lengths of bigints
biSimpleSub:    
        ;; Set loop bound
        mov r8, [rdi]
        mov r11, [rsi]
        ;; Set pointers to data
        push rsi
        push rdi
        mov rdi, [rdi + 8]
        mov rsi, [rsi + 8]

        xor r9, r9
        xor r10, r10
        xor rcx, rcx
.loop:
        ;; Check idx is less than length of dst
        cmp rcx, r8
        jnl .finish
.looploop:
        ;; Get uint64 in index rcx of rdi
        mov rax, [rdi + rcx * 8]
        mov qword rdx, 0
        ;; Check if idx is less than second bigint
        ;; Size of src is always less or equal than size of dst
        cmp rcx, r11
        jnl .loopBody
        ;; Get uint64 in index rcx of rsi
        mov rdx, [rsi + rcx * 8]
.loopBody:
        sub rax, rdx
        ;; Save carry flag
        adc r10, 0
        ;; Add previous carry
        sub rax, r9
        ;; Save carry flag
        adc r10, 0
        mov r9, r10
        xor r10, r10
        ;; Set to result
        mov [rdi + rcx * 8], rax
        inc rcx
        jmp .loop
.diff_signs:
        jmp .exit
.finish:
        dec rcx
        xor rdx, rdx
.lead_z:
        ;; Delete leading zeroes until size == 1
        ;; Save their amount to rdx
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
        ;; Subtract size by amount of leading zeroes
        mov rax, [rdi]
        sub rax, rdx
        mov [rdi], rax

        setZeroIfZero rdi

        
        pop rsi
.exit:
        ret

;;; RDI - destination
;;; RSI - source
;;; Subtract dst by src and stores result in dst
;;; O(n) where n is maximum of lengths of bigints
biSub:  
        ;; Check if rdi and rsi are pointers to same bigint
        cmp rdi, rsi
        jne .sub
        ;; If so, result is 0
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
        ;; If signs are equal
        ;; Get modules of bigints
        mov qword [rdi + 16], 1
        mov qword [rsi + 16], 1
        ;; Compare modules of bigints
        push rax
        push rcx
        push rdi
        push rsi
        call biCmp
        mov rdx, rax
        pop rsi
        pop rdi
        pop rcx
        pop rax
        ;; Return signs
        mov [rdi + 16], rax
        mov [rsi + 16], rcx
        ;; Check result of comparing
        cmp rdx, 0
        jnl .simple_sub
.firstisless:
        ;; We don't want to affest rsi's bigint
        ;; So we would copy it and compute rsi - rdi
        ;; And invert sign
        push rdi 
        mov rdi, rsi
        call biCopy
        mov rdi, rax
        pop rdi
        ;; Result of copying is in rax
        push rax
        push rdi
        push rsi
        mov rsi, rdi
        mov rdi, rax
        call biSimpleSub
        pop rsi
        pop rdi
        pop rdx
        mov rcx, [rdx]
        mov [rdi], rcx
        mov rcx, [rdx + 16]
        neg rcx
        mov [rdi + 16], rcx
        swapNfree rdx, rdi

        jmp .exit
.simple_sub:
        ;; Just run simple subtraction
        call biSimpleSub
        jmp .exit

.diff_signs:
        ;; If signs are different subtraction is equal to sum
        ;; Of two bigints of equal sign
        mov rax, [rdi + 16]
        mov rcx, [rsi + 16]
        ;; If second bigint is 0 result already in rdi
        test rcx, rcx
        jz .exit
        test rax, rax
        jnz .add
        neg rcx
        mov [rdi + 16], rcx
.add:
        ;; Inverting rsi sign and running sum of equal sign bigint
        push rdi
        push rsi
        mov rcx, [rsi + 16]
        neg rcx
        mov [rsi + 16], rcx
        call biSimpleAdd
        pop rsi
        pop rdi
        mov rcx, [rsi + 16]
        neg rcx
        mov [rsi + 16], rcx
.exit:
        ret

;;; RDI - destination
;;; RSI - source
;;; Multiplies dst by src and stores result in dst
;;; O(m * n) where m and n are lengths of bigints
biMul:
        push r12
        push r13
        push r14
        push r15
        ;; Alloc bigint for result with data size (rdi data size) + (rsi data size)
        mov rax, [rdi]
        mov rcx, [rsi]
        add rax, rcx
        push rdi
        push rsi
        mov rdi, rax
        call allocate
        pop rsi
        pop rdi
        ;; Save pointer to result bigint
        mov r12, rax
        push r12
        ;; Get pointer to data
        mov r12, [r12 + 8]

        xor r8, r8              ; first loop idx
        xor r9, r9              ; second loop idx
        ;; Get sizes of rdi and rsi bigints
        mov r10, [rdi]
        mov r11, [rsi]
        ;; Get pointers to bigint's data
        push rdi
        push rsi
        mov rdi, [rdi + 8]
        mov rsi, [rsi + 8]
        ;; Last index of multiplication result
        xor r15, r15
.loopI:
        ;; Check first idx < than length of first
        cmp r8, r10
        jnl .finish
        ;; Set second idx to 0
        xor r9, r9
        ;; Set carry 0
        xor r13, r13
.loopJ:
        ;; Check second idx < than length of second or carry != 0
        cmp r9, r11
        jl .loopBody
        ;; If carry is not 0, continue
        test r13, r13
        jnz .loopBody
        ;; Otherwise inc loopI index
        inc r8
        jmp .loopI
.loopBody:
        xor rdx, rdx
        ;; Get uint64 in index r8 of rdi
        mov rax, [rdi + r8 * 8]
        mov qword rcx, 0
        ;; If r9 is less than data size, set to 0
        cmp r9, r11
        jnl .loopBodyFinish
        ;; Get uint64 in index r9 of rsi
        mov rcx, [rsi + r9 * 8]
.loopBodyFinish:
        ;; Multiply and save overflow
        mul rcx
        mov r14, rdx

        ;; Add (r8 + r9) int64 of result
        mov r15, r9
        add r15, r8
        add rax, [r12 + r15 * 8]
        ;; Save carry
        adc r14, 0
        ;; Add previous carry
        add rax, r13
        adc r14, 0
        ;; Save current carry
        mov r13, r14
        ;; Save result to result bigint
        mov r15, r9
        add r15, r8
        mov [r12 + r15 * 8], rax
        inc r9
        jmp .loopJ
        
.finish:
        pop rsi
        pop rdi
        pop r12
        ;; Swap datas of rdi ans r12(result of multiplication)
        ;; It is neccessary to save result and free useless memory
        swapNfree r12, rdi
        
        ;; Set rdi size to size of multiplication
        inc r15
        mov [rdi], r15

        ;; Get new sign as multiplication of signs
        mov rax, [rdi + 16]
        mov rcx, [rsi + 16]
        xor rdx, rdx
        mul rcx
        mov [rdi + 16], rax
        ;; If result size is 0, size may be invalid
        test rax, rax
        ;; If so, set size = 1
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

;;; rsi - buffer to put answer
biToString:
        mov byte [rsi], 'N'
        mov byte [rsi + 1], 'A'
        mov byte [rsi + 2], 0
        ret
