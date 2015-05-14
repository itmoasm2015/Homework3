default rel

; extern _biDump

extern malloc
; extern calloc
extern free

global biFromInt        ;; DONE
global biFromString     ;; DONE

global biDelete         ;; DONE

global biMulBy2         ;; DONE 
global biNot            ;; DONE
global biInc            ;; DONE
global biNegate         ;; DONE

global biAdd            ;; DONE (TODO: test it better)
global biSub            ;; DONE (TODO: test it better)
global biMul            ;; DONE (TODO: test it better)

global biCmp            ;; DONE
global biSign           ;; DONE

global biDivRem         ;; TODO

global biToString       ;; TODO

; private biAllocate        ;; DONE
; private biMove            ;; DONE
; private biEnsureCapacity  ;; DONE
; private biGrowCapacity    ;; DONE

; private biTrim            ;; TODO: method to trim size of vector to spare memory


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
;
; * overflow condition exists iff left two bits 
;   (two most significant bits) are different
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
%endmacro


; same as newArray macro, but filled with zeros
; %macro newArrayWithZeros 0
;     push rsi
;     mov rsi, 8 ; RSI = sizeof(int64_t)
;     callItWithAlignedStack calloc
;     pop rsi
; %endmacro


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

            mov r13, rdi ; memorize capacity

            newArray ; RAX = BigInt->data
            test rax, rax
            je .fail
            mov r12, rax ; memorize BigInt->data

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

            mov r12, rdi ; memorize initial value
            mov rdi, 1
            call biAllocate
            test rax, rax
            jz .return ; failed to allocate memory

            mov r8, [rax + DATA] ; R8 = BigInt->data
            mov [r8], r12 ; set to initial value
            mov qword [rax + SIZE], 1

        .return:
            pop r12
            ret


; BigInt biFromString(const char *string)
; string must match ^-\d+$ regexp
; string in RDI
; result in RAX
biFromString: 
            push r12 ; accumulator
            push r13 ; multiplier
            push r14 ; ad
            push r15 ; multiplier limit
            push rbp ; current index in string
            push rbx 
            mov rbx, rdi ; RBX - pointer to string

            mov rax, 1
            mov rcx, 17
            mov r15, 10
         .grow_r15:
            mul r15
            dec rcx
            jnz .grow_r15 
            mov r15, rax ; multiplier limit = 10^17
            ; TODO: move to constant

            mov rdi, 0
            call biFromInt
            test rax, rax
            jz .return

            mov r12, rax ; accumulator = 0 initially
            mov r13, 1 ; multiplier
            xor r14, r14 ; ad

;            %define INPUT_BASE 10
;            %define MAX_MUL 100000000000000000 ; INPUT_BASE^17

            xor rbp, rbp ; pointer to current position in string
            sub rsp, 8 ; allocate memory on stack for sign
            mov qword [rsp], 1 ; memorize sign
            mov al, [rbx + rbp]
            cmp al, '-'
            jne .parse_loop
            inc rbp ; skip sign character
            mov qword [rsp], -1 ; update sign

            ; R12 -- accumulator (BigInt)
            ; R13 -- multiplier (qword)
            ; R14 -- ad (qword)
            ; as result accumulator = accumulator * multiplier + ad
        %macro update_result 0
            mov rdi, r13
            call biFromInt ; multiplier from int64_t to BigInt
            ; check not null
            test rax, rax
            jz .fail
            
            mov rdi, r12 ; accumulator
            mov rsi, rax ; multiplier
            push rax ; memorize multiplier (BigInt)
            call biMul
;            call biMulByPositiveMultiplier ; accumulator *= multiplier

            pop rdi
            call biDelete ; delete multiplier

            mov rdi, r14
            call biFromInt ; ad from int64_t to BigInt
            ; check not null
            test rax, rax
            jz .fail

            mov rdi, r12 ; accumulator
            mov rsi, rax ; ad
            push rax ; memorize ad (BigInt)
            call biAdd ; accumulator += ad

            pop rdi
            call biDelete ; delete ad
        %endmacro

        .parse_loop:
            xor rax, rax
            mov al, [rbx + rbp] ; current character
            test rax, rax
            jz .end_of_loop ; null-character

            cmp al, '0'
            jb .fail ; illegal digit
            cmp al, '9'
            ja .fail ; illegal digit

            sub al, '0'

            xchg rax, r13
            mov r8, 10
            mul r8
            xchg rax, r13 ; multiplier *= 10

            xchg rax, r14
            mov r8, 10
            mul r8
            add r14, rax ; ad = ad * 10 + current_digit

            cmp r13, r15 ; multiplier vs 10^17
            jb .continue_accumulating

            update_result ; accumulator = accumulator * multiplier + ad
            mov r13, 1 ; multiplier = 1
            xor r14, r14 ; ad = 0

          .continue_accumulating:
            inc rbp
            jmp .parse_loop

        .end_of_loop:

            cmp rbp, 1
            jb .fail ; empty string
            jne .last_update

            ; check if string = "-"
            cmp word [rbx], '-'
            je .fail

        .last_update:
            update_result

            mov rax, r12
            pop r8 ; sign
            cmp r8, 0
            je .fail ; WTF?!
            jg .return

            ; sign < 0, so we have to negate result
            push rax
            mov rdi, rax
            call biNegate
            pop rax
            jmp .return

        .fail:
            pop rax ; remove sign from stack
            mov rdi, r12
            call biDelete ; free not calculated result
            xor rax, rax

        .return:
            pop rbx
            pop rbp
            pop r15
            pop r14
            pop r13
            pop r12
            ret


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

            call biNormalize ; normalize x
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
            call biNormalize ; normalize dst
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

            ret ; no need to normalize, cause if x normalized, then ~x normalized too


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
            call biNormalize
            ret


; void biNegate(BigInt x);
; x = -x = (~x) + 1
; x in RDI
biNegate:
            push rdi
            call biNot
            pop rdi
            push rdi
            call biInc ; x normalized
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
            call biAdd ; dst normalized

            mov rdi, [rsp]
            call biNegate ; return src to initial value

            pop rsi
            pop rdi
            ret


; void biMul(BigInt dst, BigInt src);
; dst *= src
; dst in RDI
; src in RSI
biMul:
            push rdi
            push rsi

        %macro common_part 0
            mov rdi, [rsp + 8] ; rdi = dst
            mov rsi, [rsp] ; rsi = src
            call biMulByPositiveMultiplier
            pop rsi
            pop rdi
            test rax, rax
            jz .return
        %endmacro

            mov rdi, rsi
            call biSign
            cmp rax, 0 ; sign(src) vs 0
            jl .negative_multiplier

            common_part

            mov rsi, rax
            call biMove
            jmp .return

        .negative_multiplier:
            ; let's negate multiplier and multiplicand!
            mov rdi, [rsp + 8] ; RDI = dst
            call biNegate
            mov rdi, [rsp] ; RDI = src
            cmp rdi, [rsp + 8] ; src =? dst
            je .skip_first_negating
            call biNegate
          .skip_first_negating:

            common_part

            push rax
            push rsi
            push rdi
            
            call biNegate ; returns dst to initial state
            mov rdi, [rsp + 8]
            cmp rdi, [rsp] ; src =?dst
            je .skip_second_negating
            call biNegate ; returns src to initial state
          .skip_second_negating:

            pop rdi
            pop rsi
            pop rsi ; in RSI product
            call biMove 

        .return:
            ret


; BigInt biMul(BigInt multiplicand, BigInt multiplier);
; requirement: multiplier >= 0
; multiplicand in RDI
; multiplier in RSI
; result in RAX
biMulByPositiveMultiplier:
            mov rax, [rdi + SIZE]
            add rax, [rsi + SIZE]
            ; size of product <= multiplier->size + multiplicand->size = RAX
            ; memorize multiplicand and multiplier
            push rdi 
            push rsi

            mov rdi, 1
        .loop_to_find_capacity_for_new_vector:
            shl rdi, 1 ; RDI *= 2
            cmp rdi, rax
            jb .loop_to_find_capacity_for_new_vector

            ; now RDI is power of two and RDI >= RAX
            push rdi ; memorize capacity of new vector
            call biAllocate
            pop rcx ; RCX = capacity of allocated (?) BigInt
            pop rsi
            pop rdi
            test rax, rax
            jz .return ; failed to create new BigInt

            ; damn calling convention!
            push rbp
            push rbx
            push r12
            push r13
            push r14
            push r15

            push rax ; memorize pointer to result

            ; memset(result->data, 0, result->capacity)
            push rdi
            push rsi
            mov rdi, [rax + DATA] 
            xor rax, rax
            rep stosq ; RCX = result->capacity 
            pop rsi
            pop rdi

            mov rax, [rsp]
            mov rbp, [rax + DATA] ; in RBP will be vector with product

            fillR8__11 rdi, rsi

            xor r14, r14; outer loop counter
        .for_r14_from_0_to_size_of_multiplier:
            mov r13, [r11 + 8 * r14] ; current multiplier
            xor r12, r12 ; carry bit

            xor r15, r15 ; inner loop counter
            mov rbx, r14 ; position to update in product (RBP)
            .for_r15_from_0_to_size_of_multiplicand:
                mov rax, [r9 + 8 * r15] 
                xor rdx, rdx
                mul r13 ; RDX:RAX = multiplier->data[R14] * multiplicand->data[R15]
                add rax, r12 ; RAX += carry
                adc rdx, 0 ; RDX - next carry

                add [rbp + 8 * rbx], rax ; result[R14 + R15] += RAX
                adc rdx, 0

                mov r12, rdx ; update carry

                inc rbx
                inc r15
                cmp r15, r8
                jb .for_r15_from_0_to_size_of_multiplicand

            xor r15, r15 ; remainder (leading zeros or ones)
            cmp r15, [r9 + 8 * r8 - 8] ; 0 vs most significant coeff of multiplicand
            jle .actual_remainder
            mov r15, -1
          .actual_remainder:
            
            mov rcx, r8
            add rcx, r10 ; RCX = size of result
            .while_rbx_less_than_size_of_result:
                mov rax, r15
                xor rdx, rdx
                mul r13
                add rax, r12
                adc rdx, 0 ; next carry

                add [rbp + 8 * rbx], rax
                adc rdx, 0

                mov r12, rdx ; update carry

                inc rbx
                cmp rbx, rcx
                jb .while_rbx_less_than_size_of_result

            inc r14
            cmp r14, r10
            jb .for_r14_from_0_to_size_of_multiplier

            ; fill fildes of result
            pop rax ; pointer to result
            mov [rax + SIZE], rbx

            push rax
            mov rdi, rax
            call biNormalize
            
            pop rax
            ; OMG :/
            pop r15
            pop r14
            pop r13
            pop r12
            pop rbx
            pop rbp

        .return: 
            ret


; int biCmp(BigInt fst, BigInt snd);
; retval < 0 iff fst < snd
; retval > 0 iff fst > snd
; fst in RDI
; snd in RSI
; retval in RAX (EAX)
biCmp:
            ; as fst and snd are normalized, 
            ; we need just check signs, after that - sizes, 
            ; and finally coefficients one by one
            push rdi
            push rsi
            call biSign
            push rax ; in RAX was sign of fst
            mov rdi, [rsp + 8] ; RDI = snd
            call biSign ; in RAX sign of snd
            pop r8 ; in R8 sign of fst
            pop rsi
            pop rdi
            cmp r8, rax ; sign(fst) vs sign(snd)
            jg .greater
            jl .less
            ; sign(fst) = sign(snd)  in rax
            mov r8, [rdi + SIZE]
            mov r9, [rsi + SIZE]
            cmp r8, r9
            jb .shorter
            ja .longer
            ; sign(fst) = sign(snd), fst->size = snd->size
            mov r10, [rdi + DATA]
            mov r11, [rsi + DATA]

            mov rcx, r8
        .comparison_loop: ; for RCX from size downto 1 do:
            mov rdx, [r10 + 8 * rcx - 8]
            cmp rdx, [r11 + 8 * rcx - 8] ; fst->data[RCX - 1] vs snd->data[RCX - 1]
            jb .less
            ja .greater
            dec rcx
            jnz .comparison_loop

            xor rax, rax ; fst = snd
            ret

        .shorter:
            cmp rax, 0
            jge .less    ; positive and shorter => less
            jmp .greater ; negative and shorter => greater

        .longer:
            cmp rax, 0
            jge .greater ; positive and longer => greater
            jmp .less    ; negative and longer => less

        .greater
            mov rax, 1
            ret

        .less
            mov rax, -1
            ret


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
            cmp r9, 1 ; x->size = 1?
            jne .positive ; x looks like 0000...0001... with at least 64 leading zeros
            ; else x = 0
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


; void biNormalize(BigInt x)
; removes leading ones/zeros (in two's complement representaion)
; TODO: call trim inside to spare memory
; x in RDI
biNormalize:
            ; we need to find last idx such that
            ;  * or sign(x->data[idx - 1]) != sign(x->data[idx - 2])
            ;  * or x->data[idx - 1] not in {-1, 0}
            ; that idx will be new size of x
            mov r8, [rdi + SIZE]
            mov r9, [rdi + DATA]
        .normalization_loop:
            cmp r8, 1
            jbe .return

            ; let's check first condition:
            mov r10, [r9 + 8 * r8 - 8]  ; R10 = x->data[R8 - 1]
            mov r11, [r9 + 8 * r8 - 16] ; R11 = x->data[R8 - 2]
            ; set R10 and R11 to most significant bit of them:
            shr r10, 63
            shr r11, 63
            cmp r10, r11
            jne .return ; sign(x->data[idx - 1]) != sign(x->data[idx - 2])

            ; and second condition:
            mov r10, [r9 + 8 * r8 - 8] ; once again R10 = x->data[R8 - 1]
            xor rax, rax
            cmp r10, 0
            jne .label_1
            inc rax
          .label_1:

            cmp r10, -1
            jne .label_2
            inc rax
          .label_2:

            test rax, rax 
            jz .return ; RAX = 0 iff R10 not in {0, -1}

            dec r8
            jmp .normalization_loop

        .return:
            mov [rdi + SIZE], r8
            ret


; void biMove(BigInt dst, BigInt src);
; replace all data from dst with src
; dst in RDI
; src in RSI
biMove:
            ; at first we need to free memory
            push rdi
            push rsi
            mov rdi, [rdi + DATA]
            callItWithAlignedStack free ; free dst->data
            pop rsi
            pop rdi

            ; and now just move from src to dst
            mov rax, [rsi + DATA]
            mov [rdi + DATA], rax

            mov rax, [rsi + SIZE]
            mov [rdi + SIZE], rax
            
            mov rax, [rsi + CAPACITY]
            mov [rdi + CAPACITY], rax

            ret
