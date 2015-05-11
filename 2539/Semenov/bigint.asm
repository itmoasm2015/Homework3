default rel

extern malloc
;extern calloc
extern free

global biFromInt        ;; DONE
global biFromString     ;; TODO

global biAllocate       ;; DONE
global biGrowCapacity   ;; DONE
global biDelete         ;; DONE

global biMulBy2         ;; DONE 
global biAdd            ;; IN PROCESS
global biSub            ;; TODO
global biMul            ;; TODO
global biCmp            ;; TODO
global biSign           ;; DONE
global biDivRem         ;; TODO

global biToString       ;; TODO

;;; biginteger is represented in two's complement system
;;; biginteger stored as a tupple:
;;; (lenght in dwords, capacity, pointer to array of unsigned integers)
;;; 
;;; typedef (void *) BigInt

%define DATA 0
%define SIZE 8
%define CAPACITY 16


; set zero flag (ZF) iff no overflow condition exists
%macro overflowWarning 1
    push r12
    push r13
    mov r12, %1
    mov r13, r12
    shr r12, 63 ; R12 is most significatn bit of %1
    shr r13, 62 
    and r13, 1 ; R13 is second most significant bit of %1
    xor r12, r13 ; if R12 = R13 then ZF = 1
    pop r13
    pop r12
%endmacro


; calls function with RSP mod 16 = 0
%macro callItWithAlignedStack 1
    push rbp
    mov rbp, rsp
    and rsp, ~15 ; rsp = (rsp / 16) * 16
    call %1
    mov rsp, rbp
    pop rbp
%endmacro


; allocates memory for array of ints (int64_t)
; capacity in RDI
; pointer to array in RAX
%macro newArray 0
    mov rax, 8
    mul rdi
    mov rdi, rax ; RDI = sizeof(int64_t) * capacity
    callItWithAlignedStack malloc
;    push rsi
;    mov rsi, 8 ; RSI = sizeof(int64_t)
;    callItWithAlignedStack calloc
;    pop rsi
%endmacro


section .text

; BigInt biAllocate(uint capacity);
; allocates memory for capacity-digits BigInt 
; BigInt->size = 0
; BigInt->capacity = capcity
; BigInt->data filled with zeros (or trash)
; capacity in RDI
biAllocate:
            push r12
            push r13

            mov r13, rdi ; memoize capacity

            newArray ; RAX = BigInt->data
            test rax, rax
            je .fail
            mov r12, rax ; memoize BigInt->data

            mov rdi, 24 ; 24 = sizeof(*int64_t) + sizeof(size_t) + sizeof(size_t) 
            callItWithAlignedStack malloc ; allocates memory for BigInt
            test rax, rax 
            jne .fill
            mov rdi, r12
            callItWithAlignedStack free ; say "NO" to memory leaks!
            jmp .fail

        .fill:
            mov [rax + DATA], r12
            mov qword [rax + SIZE], 0
            mov qword [rax + CAPACITY], r13
            jmp .return

        .fail:
            xor rax, rax ; RAX = nullptr

        .return:
            pop r13
            pop r12
            ret


; BigInt biFromInt(int64_t x);
; creates BigInt from one signed 64-bit integer
; x in RDI
; result in RAX
biFromInt: 
            push r12

            mov r12, rdi ; memoize initial value
            mov rdi, 1
            call biAllocate

            mov r8, [rax + DATA] ; R8 = BigInt->data
            mov [r8], r12 ; set to initial value
            mov dword [rax + SIZE], 1

            pop r12
            ret


biFromString: ret

; void biDelete(BigInt x);
; x in RDI
biDelete:   
            push rdi
            mov rdi, [rdi + DATA]
            callItWithAlignedStack free ; free x->data
            pop rdi
            callItWithAlignedStack free ; free x
            ret


; void biGrowCapacity(BigInt x, size_t new_capacity) 
; x in RDI
; new_capacity in RSI
biGrowCapacity:
            push rdi
            push rsi
            mov rdi, rsi
            newArray ; RAX = new_array
            pop rsi
            pop rdi
            test rax, rax
            jz .return ; cannot allocate memory for new array

            mov [rdi + CAPACITY], rsi ; now x->capacity is actual
            mov rcx, [rdi + SIZE]
            mov rdx, [rdi + DATA] ; RDX = x->data

            ;;; TODO: do it with SIMD
        .cpy_loop: ; for RCX from x->size downto 1 do RAX[RCX - 1] = RDX[RCX - 1]
            mov r8, [rdx + 8 * rcx - 8]
            mov [rax + 8 * rcx - 8], r8
            dec rcx
            jnz .cpy_loop

            push rax
            push rdi
            mov rdi, [rdi + DATA]
            callItWithAlignedStack free ; remove old array
            pop rdi
            pop rax
            mov [rdi + DATA], rax ; x->data = new_array

        .return:
            ret 


; void biMulBy2(BigInt x)
; multiplies x by 2
; x in RDI
biMulBy2:
            mov rsi, [rdi + SIZE] ; RSI = x->size
            mov rdx, [rdi + DATA] ; RDX = x->data
            mov r8, [rdx + 8 * rsi - 8] ; R8 is most significant coefficient
            overflowWarning r8
            jz .main_part
            ; if overflow risk exists we have to grow up size of BigInt
            cmp rsi, [rdi + CAPACITY]
            jb .capacity_ensured
            push rdi
            mov rsi, [rdi + CAPACITY]
            shl rsi, 1 ; new capcity
            call biGrowCapacity
            pop rdi
            mov rdx, [rdi + DATA]
            mov rsi, [rdi + SIZE]

        .capacity_ensured:
            inc rsi
            mov [rdi + SIZE], rsi
            mov qword [rdx + 8 * rsi - 8], 0
            mov r8, [rdx + 8 * rsi - 16]
            shr r8, 63 ; R8 is now most significant bit
            jz .main_part
            mov qword [rdx + 8 * rsi - 8], -1 

        .main_part:
            mov rcx, rsi 
            xor r11, r11 ; R11 is carry bit
            xor r9, r9
        .loop: ; for RCX from x->size downto 1
            mov r8, [rdx + r9 * 8] ; R8 = x->data[x->size - RCX]
            xor rax, rax ; RAX -- next carry bit
            shl r8, 1 ; R8 *= 2, if overflow update next carry bit (RAX)
            jnc .actual_carry_bit
            inc rax
          .actual_carry_bit:
            add r8, r11 ; R8 += carry_bit
            mov [rdx + r9 * 8], r8 
            mov r11, rax

            inc r9
            dec rcx
            jnz .loop

            ret


; void biAdd(BigInt dst, BigInt src);
; dst += src
; dst in RDI
; src in RSI
biAdd:
            mov r8, [rdi + SIZE]
            mov r9, [rdi + DATA]
            mov r10, [rsi + SIZE]
            mov r11, [rsi + DATA]
            test r10, r11
            jne .general_case
            ; if r10 = r11 then src = dst and we can just multiply dst by 2
            call biMulBy2
            ret

        .general_case:
            ret

biSub:      ret
biMul:      ret
biCmp:      ret

; int biSign(BigInt x);
; x in RDI
; result in RAX (-1 if x < 0, 1 if x > 0, 0 ohterwise)
biSign:     
            mov r8, [rdi + DATA] ; R8 = x->data
            mov r9, [rdi + SIZE] ; R9 = x->size
            mov r10, [r8 + r9 - 1] ; R9 = x->data[size - 1]
            cmp r10, 0
            jg .positive
            jl .negative
            xor rax, rax
            ret
        .positive:
            mov rax, 1
            ret
        .negative:
            mov rax, -1
            ret


biDivRem:   ret
biToString: ret

