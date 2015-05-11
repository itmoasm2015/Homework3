default rel

extern malloc
;extern calloc
extern free

global biFromInt        ;; DONE
global biFromString     ;; TODO

global biAllocate       ;; DONE
global biDelete         ;; DONE

global biMulBy2         ;; DONE 
global biAdd            ;; DONE (TODO: test it better)
global biNot            ;; DONE
global biInc            ;; DONE
global biSub            ;; DONE (TODO: test it better)
global biMul            ;; TODO
global biCmp            ;; TODO
global biSign           ;; DONE

global biDivRem         ;; TODO

global biToString       ;; TODO


;;; biginteger is represented in two's complement system
;;; biginteger stored as a tuple:
;;; 
;;; struct BigIntRepresentation {
;;;   int64_t *data;    /* not null */
;;;   size_t size;      /* size > 0 */
;;;   size_t capacity;  /* capacity >= size */
;;; }
;;; typedef (BigIntRepresentation *) BigInt


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


; %1, %2 -- BigInts
; result:
;  R8  = %1->size
;  R9  = %1->data
;  r10 = %2->size
;  r11 = %2->data
%macro fillR8__11 2
    mov r8, [%1 + SIZE]
    mov r9, [%1 + DATA]
    mov r10, [%2 + SIZE]
    mov r11, [%2 + DATA]
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

            ;; TODO: do it with SIMD
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


; void biEnsureCapacity(BigInt x, size_t capacity);
; x in RDI
; capacity in RSI
biEnsureCapacity:
            mov r8, [rdi + CAPACITY]
            cmp rsi, r8
            jbe .return

        .loop:
            shl r8, 1
            cmp r8, rsi
            jb .loop
            ; now R8 >= capacity
            mov rsi, r8
            call biGrowCapacity

        .return
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
            push rdi
            inc rsi ; x->capacity has to be not less then x->size + 1
            call biEnsureCapacity
            pop rdi
            mov rdx, [rdi + DATA]
            mov rsi, [rdi + SIZE]

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
            fillR8__11 rdi, rsi
            cmp r9, r11
            jne .general_case
            ; if r9 = r11 then src = dst and we can just multiply dst by 2
            call biMulBy2
            ret

        .general_case:

            cmp r8, r10
            ja .r8_greater_than_r10
            je .r8_equals_r10
            ; so dst->size < src->size
            mov rdx, r10 ; RDX -- needed size of dst
            overflowWarning [r11 + 8 * r10 - 8] 
            jz .good_size_in_rdx
            inc rdx ; if overflow risk exists, we have to increase size of dst
            jmp .good_size_in_rdx

        .r8_equals_r10:
            mov rdx, r8
            overflowWarning [r9 + 8 * r8 - 8] ; most significant coefficient in dst
            jz .check_src_for_overflow_warning
            ; once again: if overflow risk exists, we have to increase size of dst
            inc rdx
            jmp .good_size_in_rdx

          .check_src_for_overflow_warning:
            ; RDX = R10
            overflowWarning [r11 + 8 * r10 - 8] ; most significant coefficient in src
            jz .good_size_in_rdx
            inc rdx
            jmp .good_size_in_rdx

        .r8_greater_than_r10:
            mov rdx, r8
            overflowWarning [r9 + 8 * r8 - 8] ; mos singnigicant coefficient in dst
            jz .good_size_in_rdx
            inc rdx

        .good_size_in_rdx:
            push rdx
            push rdi
            push rsi
            mov rsi, rdx
            call biEnsureCapacity ; biEnsureCapacity(dst, RDX)
            pop rsi
            pop rdi
            fillR8__11 rdi, rsi
            pop rdx
            xor rax, rax ; we fill new elements in dst with RAX
            cmp rax, [r9 + 8 * r8 - 8] ; compare 0 and most significant coefficient of dst
            jle .right_value_in_rax
            mov rax, -1
          .right_value_in_rax:
            cmp rdx, r8
            je .ready
            ; else dst->size < RDX

        .fill_loop: ; for R8 from dst->size up to RDX (new size): dst->data[R8] = RAX
            mov [r9 + 8 * r8], rax
            inc r8
            cmp r8, rdx
            jb .fill_loop

            mov [rdi + SIZE], r8 ; update dst->size
        .ready:
            push rbx
            ; dst->size >= src->size
            ; and finally add src to dst
            xor rbx, rbx ; RBX is carry bit
            xor rcx, rcx
        .add_loop ; for RCX from 0 up to src->size do
            mov rax, [r9 + 8 * rcx]
            add rax, rbx
            mov rbx, 0 ; MOV doesn't change carry flag
            adc rbx, 0
            add rax, [r11 + 8 * rcx]
            adc rbx, 0
            mov [r9 + 8 * rcx], rax ; dst->data[RCX] += src->data[RCX] + carry_bit 

            inc rcx
            cmp rcx, r10
            jb .add_loop

            push rbp
            xor rbp, rbp
            cmp rbp, [r11 + 8 * r10 - 8] ; 0 vs most significant bit in src
            jle .add_remainder_loop
            mov rbp, -1

        .add_remainder_loop: ; while RCX < dst->size (and carry flag is set)
            cmp rcx, r8
            jae .return
            mov rax, rbx
            xor rbx, rbx
            add rax, rbp
            adc rbx, 0
            add [r9 + 8 * rcx], rax ; dst->data[RCX] += mask + carry_bit
            adc rbx, 0
            inc rcx
            jmp .add_remainder_loop
            
        .return:
            pop rbp
            pop rbx
            ret


; void biNot(BigInt x);
; x = ~x
; x in RDI
biNot:
            mov rcx, [rdi + SIZE]
            mov rdx, [rdi + DATA]
        .not_loop: ; for RCX from x->size downto 1: x->data[RCX] = ~x->data[RCX]
            xor qword [rdx + 8 * rcx - 8], -1

            dec rcx
            jnz .not_loop
            ret


; void biInc(BigInt x);
; x = x + 1
; x in RDI
biInc:
            mov rdx, [rdi + DATA]
            mov r8, [rdi + SIZE]
            overflowWarning [rdx + 8 * r8 - 8] ; most significant coefficient of x
            jz .main_part
            lea rsi, [r8 + 1]
            push rdi
            call biEnsureCapacity ; biEnsureCapacity(x, x->size + 1)
            pop rdi
            mov rdx, [rdi + DATA]
            mov r8, [rdi + SIZE]
            xor rax, rax
            cmp rax, [rdx + 8 * r8 - 8] ; 0 vs most significant coefficient of x
            jle .actual_value_in_rax
            mov rax, -1
          .actual_value_in_rax:
            mov [rdx + 8 * r8], rax
            inc r8
            mov [rdi + SIZE], r8 ; update x->size

        .main_part:
            xor rcx, rcx
            mov r10, 1
        .inc_loop: ; for RCX from 1 to x->size (R8), while carry flag is set: 
            inc rcx
            cmp rcx, r8
            ja .return
            add qword [rdx + 8 * rcx - 8], 1 ; why INC does not change CF?..
            jc .inc_loop

        .return:
            ret


; void biNegate(BigInt x);
; x = -x = (~x) + 1
; x in RDI
biNegate:
            push rdi
            call biNot
            pop rdi
            push rdi
            call biInc
            pop rdi
            ret


; void biSub(BigInt dst, BigInt src);
; dst -= src
; dst in RDI
; src in RSI
biSub:      
            ; dst -= src <==> dst += (-src)
            push rdi
            push rsi
            mov rdi, rsi
            call biNegate

            mov rsi, [rsp]
            mov rdi, [rsp + 8]
            call biAdd

            mov rdi, [rsp]
            call biNegate ; return src to initial value
            pop rsi
            pop rdi
            ret


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

biTrim:     ret
biNormalize:ret

