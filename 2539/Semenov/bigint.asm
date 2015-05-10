extern malloc
extern calloc
extern free

global biFromInt    ;; DONE
global biFromString ;; TODO

global biDelete     ;; DONE

global biAdd        ;; TODO
global biSub        ;; TODO
global biMul        ;; TODO
global biCmp        ;; TODO
global biSign       ;; DONE
global biDivRem     ;; TODO

global biToString   ;; TODO

;;; biginteger is represented in two's complement system
;;; biginteger stored as a tupple:
;;; (lenght in dwords, capacity, pointer to array of unsigned integers)
;;; 
;;; typedef (void *) BigInt

%define DATA 0
%define SIZE 8
%define CAPACITY 16

; calls function with RSP mod 16 = 0
%macro callItWithAlignedStack 1
    push rbp
    mov rbp, rsp
    and rsp, ~15 ; rsp = (rsp / 16) * 16
    call %1
    mov rsp, rbp
    pop rbp
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

;            mov rsi, 8 ; RSI = sizeof(int64_t)
;            callItWithAlignedStack calloc ; allocates momory for BigInt->data
            mov rax, 8
            mul rdi
            mov rdi, rax ; RDI = capacity * sizeof(int64_t)
            callItWithAlignedStack malloc ; allocates memory for BigInt->data
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
            
biAdd:      ret
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

