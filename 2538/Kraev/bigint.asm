default rel

section .text

; multipush
%macro mpush 1-*
    %rep %0
        push %1
        %rotate 1
    %endrep
%endmacro

;multipop
%macro mpop 1-*
    %rep %0
        %rotate -1
        pop %1
    %endrep
%endmacro

%macro pushall 0
    mpush rax, rbx, rcx, rdx, rsi, rdi, rbp, r8, r9, r10, r11 
%endmacro
%macro popall 0
    mpop rax, rbx, rcx, rdx, rsi, rdi, rbp, r8, r9, r10, r11
%endmacro


; save registers for some calls, like malloc
%macro x86_64_calle_push 0
    mpush rbp, rbx, r12, r13, r14, r15 
%endmacro

; restore them
%macro x86_64_calle_pop 0
    mpop rbp, rbx, r12, r13, r14, r15 
%endmacro

;nasm macros for plain structures
;store bigint with base 2^64 in data_ptr
struc big_int 
    .sign:         resq 1
    .capacity:     resq 1
    .vsize:        resq 1
    .data_ptr:     resq 1
endstruc


extern calloc
extern malloc
extern free
extern memcpy

global biFromInt
global biFromString
global biDelete
global biAdd
global biSub
global biMul
global biCmp
global biDivRem
global biSign
global biToString

section .text

;align stack by 16
%macro stack_align 0
    push rbp
    mov rbp, rsp
    sub rsp, 16
    and rsp, ~15
%endmacro

;call function with aligned stack and return all to right places
%macro call_aligned 1
    stack_align
    call %1
    mov rsp, rbp
    pop rbp
%endmacro


%macro if 3
    %push if 
    %assign %$__curr 1
    cmp %1, %3
    j%+2 %%if_code
    jmp %$loc %+ %$__curr
%%if_code:
%endmacro

%macro elif 3
    jmp %$end_if
%$loc %+ %$__curr:
    %assign %$__curr %$__curr + 1
    cmp %1, %3
    j%+2 %%elif_code
    jmp %$loc %+ %$__curr 
%%elif_code:
%endmacro

%macro else 0
    jmp %$end_if
    %$loc %+ %$__curr:
    %assign %$__curr %$__curr + 1
%endmacro

%macro endif 0
%$loc %+ %$__curr:
%$end_if:
%pop
%endmacro

%macro do 0
 %push do
    jmp %$init_loop
%$start_loop:
%endmacro


;do ... while loop
%macro while 3
 %ifctx do
    cmp %1, %3
    j%-2 %%end_loop
    jmp %$start_loop
%$init_loop:
    jmp %$start_loop
%%end_loop:
 %pop
 %endif
%endmacro


;BigInt biCreate(size_t size); 
biCreate:
   x86_64_calle_push

   mov r12, rdi ; preparations for calling calloc
   mov rdi, 4
   mov rsi, 8
   call_aligned calloc ;allocate memory for structure of BigInt

   mov r13, rax ; allocated memory for data of BigInt
   mov rdi, 8
   mov rsi, r12
   call_aligned calloc
   
   mov [r13 + big_int.data_ptr], rax ;init values of BigInt
   mov [r13 + big_int.capacity], r12
   mov qword [r13 + big_int.vsize], 1 ;size == 0?? it is impossible and was breaking all my conventions.
   mov rax, r13 

   x86_64_calle_pop
   ret 

    
;;; BigInt biFromInt(int64_t x);
biFromInt:
    x86_64_calle_push
    
    mov r12, rdi
    mov rdi, 8 
    call biCreate ; Create BigInt with initial capacity = 8
    mov r13, rax 
    mov r14, [rax + big_int.data_ptr]
    if r12, l, 0
        mov qword [rax + big_int.sign], 1;something, like abs() 
        neg r12
    endif
    mov [r14], r12
    mov rax, r13

    x86_64_calle_pop
    ret

;;;  Create a BigInt from a decimal string representation.
;;;  Returns NULL on incorrect string.
;;; 
;;; BigInt biFromString(char const *s);
biFromString:
    x86_64_calle_push
     
    mov r12, rdi ;save some regs for future
    mov rdi, 8 
    call biCreate; create zero bigInt
    mov r13, rax ; and save it
   
    if r12, e, 0;this string is null 
        jmp .error
    endif
     
    xor r15, r15
    xor r14, r14; operations on low part of registers don't flush other part of it ;(
    mov r14b, [r12]  
    if r14b, e, '-';check for minus sign in the beginning 
        inc r12
        mov r14b, [r12]
        mov r15, 1
    endif 
  
    if r14b, e, 0;we have an sudden end there
       jmp .error 
    endif 

    .digits:
    if r14b, e, 0;we have a real end
        mov [r13 + big_int.sign], r15  ;save our revealed sign
        mov rdi, r13 ;normalize it
        call normalize
        mov rax, r13; and return it in rax;
        jmp .end
    endif   
    if r14b, l, '0'; is our symbol a digit?
        jmp .error ;oops
    elif r14b, g, '9'
        jmp .error; another oops
    endif 
     
    mov rdi, r13 ;multiply our number by 10
    mov rsi, 10
    call mul_long_short
    mov rdi, r13
    mov rsi, r14
    sub rsi, 48 ;make our character more similar to digit
    call add_long_short; and add it
    inc r12
    mov r14b, [r12] ;let's examine next character 
    jmp .digits 
 
    .error: 
    mov rdi, r13;some errors occures
    call biDelete; we should delete unneseccary BigInts
    xor rax, rax
   
    .end:
    x86_64_calle_pop
    ret

biDelete: ;delete our poor BigInt. Just call free two times.
    x86_64_calle_push
    mov r12, rdi
    mov rdi, [r12 + big_int.data_ptr]
    call_aligned free

    mov rdi, r12
    call_aligned free
    x86_64_calle_pop
    ret


;void ensure_capacity(BigInt, size_t new_cap);
;make the capacity of given BigInt greater or equal to new_cap;
ensure_capacity:
    x86_64_calle_push
    mov r13, rdi 
    if rsi, g, [rdi + big_int.capacity] ;if we really need to expand
        mov r12, [rdi + big_int.capacity]
        do
            shl r12, 1  ; calculate new size by multiplying by two.
        while r12, l, rsi
        mov rdi, 8
        mov rsi, r12
        call_aligned calloc; and calloc new data array
        mov r14, rax    ;and save it
        
        mov rdi, r14
        mov rsi, [r13 + big_int.data_ptr] 
        mov rdx, [r13 + big_int.vsize]
        lea rdx, [rdx * 8]
        call_aligned memcpy ;copy old data to new array
        
        mov rdi, [r13 + big_int.data_ptr]; free old array
        call_aligned free
        mov [r13 + big_int.data_ptr], r14 ;update capacity values
        mov [r13 + big_int.capacity], r12 
    endif
    
    x86_64_calle_pop 
    ret

;simply adds 64bit short to BigInt
add_long_short:
    x86_64_calle_push
    mov r13, rsi 
    mov r12, rdi
    
    mov rsi, [rdi + big_int.vsize]
    inc rsi
    call ensure_capacity ;expand if we really need it;
   
    mov rdi, [r12 + big_int.data_ptr]
    mov rax, r13 
   
    xor r14, r14
    xor rdx, rdx
    
    .loop:  ;simple addition with carry, while we have carry
        inc r14
        add [rdi], rax
        adc rdx, 0
        mov rax, rdx
        xor rdx, rdx
        add rdi, 8
        test rax, rax 
    jnz .loop
 
    inc qword [r12 + big_int.vsize] ;we could expand by 1 
    mov rdi, r12
    call normalize ;just normalize it;
    x86_64_calle_pop
    ret     

;this functions multiply given BigInt by uint64_t
mul_long_short:
    x86_64_calle_push
    mov r13, rsi
    mov r12, rdi
    mov rsi, [rdi + big_int.vsize]
    inc rsi
    call ensure_capacity; we can expand only by 1 digit
    
    mov rdi, [r12 + big_int.data_ptr]
    mov rbx, r13
    xor rsi, rsi
    mov r14, [r12 + big_int.vsize]
    inc r14 ;loop counter
     
    .loop             ;multiply with carry
        mov rax, [rdi]; copy digit
        mul rbx       ;mul it by given short
        add rax, rsi  ;add carry
        adc rdx, 0    ;save carry
        mov [rdi], rax;store result
        add rdi, 8    ;go to the next digit
        mov rsi, rdx  ;save carry for another iteration 
        dec r14

        jnz .loop 
    
    inc qword [r12 + big_int.vsize] ;we could extend
    mov rdi, r12
    call normalize ;normalize our BigInt
     
    x86_64_calle_pop
    ret


;removes leading zeros in the end of our number and make any zero - positive zero
normalize:
    x86_64_calle_push
    ;mpush r12
    mov r12, rdi 
    mov rdi, [r12 + big_int.data_ptr]
    mov rcx, [r12 + big_int.vsize]
    
    dec rcx
    if rcx, e, 0;size is 1. There is nothing to delete
        jmp .after_trail
    endif
    .trail_loop:
        if qword [rdi + rcx * 8], e, 0;is it zero?
            dec rcx
            jz .after_trail
            jmp .trail_loop
        endif
    .after_trail:
    inc rcx; return true amount of digits
    mov [r12 + big_int.vsize], rcx; store actual size
    if rcx, e, 1
        if qword [rdi], e, 0
            mov qword [r12 + big_int.sign], 0;make all zeros positive.
        endif
    endif 
    x86_64_calle_pop 
    ret 

; rdi += rsi
; ignoring of sign
unsigned_add_long_long:
    x86_64_calle_push
    mov r12, rdi
    mov r13, rsi
    mov r14, [r12 + big_int.vsize]
    cmp r14, [r13 + big_int.vsize]
    cmovl r14, [r13 + big_int.vsize]
    inc r14;find maximal length
    
    mov rsi, r14 
    mov rdi, r12
    call ensure_capacity
  
    mov rsi, r14
    mov rdi, r13
    call ensure_capacity
    
    mov rdi, [r12 + big_int.data_ptr]
    mov rsi, [r13 + big_int.data_ptr]
    mov rcx, r14; preparations for loop;
   
    clc     ;flush carry flag
    .loop:  ;simple addition with carry
       mov rax, [rsi]
       lea rsi, [rsi + 8]
       adc [rdi], rax
       lea rdi, [rdi + 8]
       dec rcx
       jnz .loop
     
    mov [r12 + big_int.vsize], r14; we could extend for the max size
    
    mov rdi, r12
    call normalize
    
    x86_64_calle_pop
    ret

;such as previos one, but second operand is multiplied by 2^(64*shift)
unsigned_shifted_add_long_long:
    x86_64_calle_push
    mov r12, rdi
    mov r13, rsi
    mov r15, rdx
   
   
    mov r14, [r12 + big_int.vsize]
    cmp r14, [r13 + big_int.vsize]
    cmovl r14, [r13 + big_int.vsize]
    
    inc r14
    ;shift 
    add r14, r15  
   
    mov rsi, r14 
    mov rdi, r12
    call ensure_capacity
  
    mov rsi, r14
    mov rdi, r13
    call ensure_capacity
    ;shift
    sub r14, r15 
     
    mov rdi, [r12 + big_int.data_ptr]
    lea rdi, [rdi + 8*r15];shift
    mov rsi, [r13 + big_int.data_ptr]
    mov rcx, r14
   
    clc
    .loop:
       mov rax, [rsi]
       lea rsi, [rsi + 8]
       adc [rdi], rax
       lea rdi, [rdi + 8]
       dec rcx
       jnz .loop
    
    add r14, r15 
    mov [r12 + big_int.vsize], r14 
    
    mov rdi, r12
    call normalize
    
    x86_64_calle_pop
    ret

;similar code, where all adc are replaced with sbb
;first operand must be greater, than second
unsigned_sub_long_long:
    x86_64_calle_push
    mov r12, rdi
    mov r13, rsi
    mov r14, [r12 + big_int.vsize]
    cmp r14, [r13 + big_int.vsize]
    cmovl r14, [r13 + big_int.vsize]
    inc r14
    
    mov rsi, r14 
    mov rdi, r12
    call ensure_capacity
   
    mov rsi, r14
    mov rdi, r13
    call ensure_capacity
    
    mov rdi, [r12 + big_int.data_ptr]
    mov rsi, [r13 + big_int.data_ptr]
    mov rcx, r14
    clc
    
    .loop:
       mov rax, [rsi]
       lea rsi, [rsi + 8]
       sbb [rdi], rax
       lea rdi, [rdi + 8]
       dec rcx
       jnz .loop
     
    mov [r12 + big_int.vsize], r14
    mov rdi, r12
    call normalize
    
    x86_64_calle_pop
    ret


;Add two BigInt, and store result in the first operand
biAdd:
    x86_64_calle_push
    mov r12, rdi

    mov rdi, rsi
    call bi_clone   ;we can't touch second operand. Just copy it.
    mov r13, rax 
     
    mov rbx, [r13 + big_int.sign]
    if [r12 + big_int.sign], e, rbx; if we have the same signs, it is simple unsigned addition.
           mov rdi, r12
           mov rsi, r13
           call unsigned_add_long_long 
           jmp .done
    endif 
    
    mov r14, [r12 + big_int.sign]
    mov r15, [r13 + big_int.sign]
    
    mov qword [r12 + big_int.sign], 0
    mov qword [r13 + big_int.sign], 0
    ;Next step to compare abs values of our numbers 
    mov rdi, r12
    mov rsi, r13
    call biCmp
    ;different signs 
    if rax, ge, 0; if first is greater, result will be with it's sign, and it is sub
        mov rdi, r12
        mov rsi, r13
        call unsigned_sub_long_long 
        mov [r12 + big_int.sign], r14
        jmp .done
    else ;sub from clone number
        mov rdi, r13
        mov rsi, r12
        call unsigned_sub_long_long

        mov [r12 + big_int.sign], r15; restore sign
        
        mov rax, [r12 + big_int.data_ptr]
        xchg rax, [r13 + big_int.data_ptr]
        xchg rax, [r12 + big_int.data_ptr];and xchg datas, it will destroy with clone
             
        mov rax, [r13 + big_int.capacity]
        mov [r12 + big_int.capacity], rax

        mov rax, [r13 + big_int.vsize]
        mov [r12 + big_int.vsize], rax
        jmp .done 
    endif 
   
    .done:
    mov rdi, r13
    call biDelete ;delete clone
   
    mov rdi, r12  ;reassure for some +-0
    call normalize

    x86_64_calle_pop
    ret
    
    
biSub: ;copy second operand and inverse sign and do biAdd
    x86_64_calle_push
    push rdi
    mov rdi, rsi
    call bi_clone
    mov r12, rax
    mov rsi, rax
    xor qword [rsi + big_int.sign], 1; reverse sign
    push rsi
    mov rdi, rsi
    call normalize; normalize for +-0
    mpop rdi, rsi
    call biAdd 
   
    mov rdi, r12
    call biDelete ;delete bi_clone
    x86_64_calle_pop
    ret
    
biMul: ;multiplicate two BigInts
    x86_64_calle_push
    mov r12, rdi
    mov r13, rsi
    mov r14, [r12 + big_int.sign]
    xor r14, [r13 + big_int.sign]
    push r14 ; sign
    
    mov rdi, 8
    call biCreate ;create answer(accumulator)
    mov r14, rax
    
    mov rdi, r12
    call bi_clone ;we need some number for doing mul_long_short

    mov r15, rax
    
    xor r8, r8 ;loop counter

    do
    push r8 
   
    mov rax, [r12 + big_int.vsize] ;copy data from our init number to clone every time
    mov [r15 + big_int.vsize], rax ;because mul_long_short will spoil it
    
    mov rax, [r12 + big_int.capacity];we can have only greater capacity
    mov [r15 + big_int.capacity], rax

    mov rsi, [r12 + big_int.data_ptr]; preparations for memcpy
    mov rdi, [r15 + big_int.data_ptr]
    mov rdx, [r12 + big_int.capacity]
    shl rdx, 3
    call_aligned memcpy
    
    pop r8
    mov rsi, [r13 + big_int.data_ptr];fetch next digit in second operand
    mov rsi, [rsi + 8 * r8]
    push r8
     
    mov rdi, r15
    call mul_long_short; and mul
    
    mov rdi, r14
    mov rsi, r15

    pop r8
    mov rdx, r8;shift for add.
    push r8

    call unsigned_shifted_add_long_long
        
      
    pop r8 
    inc r8
    while r8, l, qword [r13 + big_int.vsize]

    pop rbx
    mov [r12 + big_int.sign], rbx 
        
    mov rax, [r12 + big_int.data_ptr]
    xchg rax, [r14 + big_int.data_ptr] ;stealing data from accumulator to giving BigInt
    xchg rax, [r12 + big_int.data_ptr]
             
    mov rax, [r14 + big_int.capacity]
    mov [r12 + big_int.capacity], rax

    mov rax, [r14 + big_int.vsize]
    mov [r12 + big_int.vsize], rax

    mov rdi, r12
    call normalize; and normilize it



    mov rdi, r14 ;delete useless BigInts
    call biDelete

    mov rdi, r15
    call biDelete

    x86_64_calle_pop
    ret


;check bigint for zero
is_zero:
    if qword [rdi + big_int.vsize], e, 1; if length == 1 && data[0] == 0
        mov rax, [rdi + big_int.data_ptr]
        if qword [rax], e, 0
            mov rax, 1
            ret 
        endif
    endif
    xor rax, rax
    ret

;rdi - bigint
;do the clone of BigInt
bi_clone:
    x86_64_calle_push
    
    mov r12, rdi
    mov rdi, [r12 + big_int.capacity];biCreate with appropreate capacity
    call biCreate
    
    mov r13, rax
    mov rax, [r12 + big_int.sign]
    mov [r13 + big_int.sign], rax
    mov rdi, [r13 + big_int.data_ptr]
    mov rsi, [r12 + big_int.data_ptr]
    mov rdx, [r12 + big_int.vsize]
    mov [r13 + big_int.vsize], rdx
    shl rdx, 3
    call_aligned memcpy; copy data
    mov rax, r13 
    x86_64_calle_pop
    ret

div_long_short:
    x86_64_calle_push
    mov r12, rdi
    mov rbx, rsi
    mov rcx, [r12 + big_int.vsize]
    mov rdi, [r12 + big_int.data_ptr]
    ;there we don't need to ensure capacity, because we can only become smaller 
    lea rdi, [rdi  + 8 * rcx - 8]
    xor rdx, rdx
    
    .loop:
        mov rax, [rdi];reminder automatically goes to rdx, and becomes new digit
        div rbx
        mov [rdi], rax
        sub rdi, 8
        dec rcx
        jnz .loop
    mov r13, rdx 
    
    mov rdi, r12
    call normalize ;check for multiple zeros

    mov rax, r13
    x86_64_calle_pop
    ret
;boiled biCmp with consideration of all cases
biCmp:
    x86_64_calle_push
    
    if qword [rdi + big_int.sign], e, 0
        if qword [rsi + big_int.sign], e, 1
            mov rax, 1 ;+   - 
            jmp .done
        else ; + +
            mov rbx, qword [rdi + big_int.vsize]
            if rbx, l, qword [rsi + big_int.vsize]    
               mov rax, -1; len 1 < len 2
               jmp .done
            elif rbx, g, qword [rsi + big_int.vsize]
               mov rax, 1; len 2 > len 1
               jmp .done 
            endif
            ;len 1 == len 2
            mov r12, [rdi + big_int.data_ptr]
            mov r13, [rsi + big_int.data_ptr]
            ;rbx - size
            ;let's begin from the hight digits and check them
            lea r12, [r12 + rbx * 8 - 8]
            lea r13, [r13 + rbx * 8 - 8]
            .loop1:
                mov rcx, [r12]
                if rcx, b, [r13] ;data1[n] < data2[n]
                    mov rax, -1
                    jmp .done
                elif rcx, a, [r13];data1[n] > data2[n]
                    mov rax, 1
                    jmp .done
                endif 
                sub r12, 8
                sub r13, 8
                dec rbx
                jnz .loop1
           
            xor rax, rax; equals
            jmp .done
        endif
    else ;it is the same reversed case  
        if qword [rsi + big_int.sign], e, 0
            mov rax, -1
            jmp .done
        else 
            mov rbx, qword [rdi + big_int.vsize]
            if rbx, l, qword [rsi + big_int.vsize]    
               mov rax, 1
               jmp .done
            elif rbx, g, qword [rsi + big_int.vsize]
               mov rax, -1
               jmp .done 
            endif

            mov r12, [rdi + big_int.data_ptr]
            mov r13, [rsi + big_int.data_ptr]
            ;rbx - size
            lea r12, [r12 + rbx * 8 - 8]
            lea r13, [r13 + rbx * 8 - 8]
            .loop2:
                mov rcx, [r12]
                if rcx, b, [r13] 
                    mov rax, 1
                    jmp .done
                elif rcx, a, [r13]
                    mov rax, -1
                    jmp .done
                endif 
                sub r12, 8
                sub r13, 8
                dec rbx
                jnz .loop2
           
            xor rax, rax
            jmp .done

        endif
    endif

    .done:
    x86_64_calle_pop
    ret

;return sign of the number
;it is a comparsion with zero
biSign:
    x86_64_calle_push
    
    mov r12, rdi
    call is_zero
    if rax, e, 1
        xor rax, rax; if it is zero
        jmp .end
    endif
    
    if qword [r12 + big_int.sign], e, 0
        mov rax, 1; positive
    else 
        mov rax, -1;negative
    endif 
    
    .end:
    x86_64_calle_pop
    ret

; Generates a string representation
biToString:
    x86_64_calle_push
  
    cmp rdx, 0;we have no place to write into...
    je .end
  
    mpush rsi, rdx;save buffer and limit for future
    mov r15, rdi  ;and clone number. We shouldn't spoil it.
    call bi_clone
    mov r12, rax

    mov rdi, [r12 + big_int.vsize]
   
   ;fit all log_10(2**64)
    shl rdi, 5;nearest power of two, that greater, than 20
    
    call_aligned malloc;we want some memory for our string, because we earn digits from the end.
    mov r13, rax 
    xor r14, r14 

    do
       mov rdi, r12
       mov rsi, 10
       call div_long_short
       add rax, 48; += '0'
       mov [r13 + r14], al
       
       inc r14
       
       mov rdi, r12
       call is_zero
        
    while rax, e, 0 
    
    ;maybe it was negative
    if qword [r15 + big_int.sign], e, 1
        mov byte [r13 + r14], '-'
        inc r14
    endif
    
    ;restore saved buffer and fill it within limit of bytes
    mpop rdi, rdx
    ;min
    xor r15, r15 ; 1 - if we fit into the limitations
    if rdx, g, r14
       mov r15, 1
       mov rdx, r14 
    endif
    
    do ;simply save our number from the end of our string 
        ;to the buffer, because we have a reversed order
       mov al, [r13 + r14 - 1]
       stosb
       dec r14
       dec rdx
    while rdx, ne, 0
   
    ;if we don't fit to the buffer 
    if r15, ne, 1 
        dec rdi
    endif

    xor al, al
    stosb
    
    mov rdi, r13
    call_aligned free
    mov rdi, r12
    call biDelete
    .end: 
    x86_64_calle_pop
    ret

;biDivRemHelpers
; [[]]
%macro mov_in_ptr 3 
    push rax
    mov rax, %1
    mov %3 [rax], %2
    pop rax
%endmacro
;Binary Search for the answer
;
biDivRem:
    x86_64_calle_push
    enter 0, 0
    mpush rdi, rsi, rdx, rcx
    %define quotient_ptr [rbp - 8]
    %define reminder_ptr [rbp - 2*8]
    %define numerator [rbp - 3*8]
    %define denominator [rbp - 4*8]
    %define left [rbp - 5*8]
    ; left bound of binary search
    %define right [rbp - 6*8]
    ; right bound of it, it is not included
    %define tmp [rbp - 7*8]
    ; tmp = (l + r) / 2
    %define diff [rbp - 8*8]
    ; diff = abs(numerator) - abs(denominator)*tmp
    %define tmp_mul_y [rbp - 9*8]
    ;ans in [left, right)
    ;tmp variable for abs(denominaotr)*tmp
    sub rsp, 40 ;allocate some space for local variables
    mov rdi, denominator; if denominator is zero - return (null, null)
    call is_zero
    if rax, ne, 0 ; If denominator == 0 mov NULL to rem and q
        mov_in_ptr quotient_ptr, 0, qword     
        mov_in_ptr reminder_ptr, 0, qword
        jmp .end
    endif

    mov rdi, numerator
    call bi_clone
    mov r12, rax    ;abs copy of numerator in r12
    mov rax, [r12 + big_int.sign]
    if rax, ne, 0
        mov qword [r12 + big_int.sign], 0
    endif

    mov rdi, denominator 
    call bi_clone
    mov r13, rax; abs copy of denominator in r13 
    mov rax, [r13 + big_int.sign]
    if rax, ne, 0
        mov qword [r13 + big_int.sign], 0
    endif
    ;Binary search for answer in [0, nominator + 1)
    mov rdi, r12 ;clone nominator to right and do + 1
    call bi_clone
    mov right, rax  ;mov numerator + 1 to right
    
    mov rdi, right
    mov rsi, 1
    call add_long_short
    
    mov rdi, 8
    call biCreate; mov zero to left
    mov left, rax
    
     
     
    .loop:;binary serach while(true): answer always exists
    mov rdi, left ;preparing for calc tmp
    call bi_clone
    mov tmp, rax
    
    mov rdi, rax
    mov rsi, right
    call unsigned_add_long_long   
    
    mov rdi, tmp
    mov rsi, 2
    call div_long_short ;tmp = (left + right) / 2

    mov rdi, r12 ;preparing for calc diff
    call bi_clone
    mov diff, rax

    mov rdi, tmp
    call bi_clone
    mov tmp_mul_y, rax
    
    mov rdi, rax
    mov rsi, r13
    call biMul; calc tmp_mul_y = abs(denominator)*tmp
    
    mov rdi, diff
    mov rsi, tmp_mul_y
    call biSub; calc diff = abs(nominator) - tmp_mul_y
    
    mov rdi, tmp_mul_y ;clear some space
    call biDelete
    
    mov rdi, diff
    call biSign
    if rax, ge, 0 ;if diff >= 0
        mov rdi, diff
        mov rsi, r13
        call biCmp
        if rax, l, 0 ;and diff < denominator
            mov rdi, left
            call biDelete
            mov rdi, right
            call biDelete
            jmp .ans_found     ;it is an answer for abs division
        else ; if diff >= denominaotr then left = tmp + 1
            mov rdi, left
            call biDelete
            mov rdi, tmp
            mov left, rdi
            mov rsi, 1
            call add_long_short
       endif    
    else ; right = tmp
        mov rdi, right
        call biDelete

        mov rdi, tmp
        mov right, rdi
    endif
    
    mov rdi, diff
    call biDelete
     
    jmp .loop

    .ans_found: ;ans in tmp, reminder in diff
    mov rdi, numerator 
    call biSign
    mov r14, rax
    
    mov rdi, denominator
    call biSign
    mov r15, rax
     ;set proper signs and reminder value
    if r15, l, 0 ;if denominator was less, then zero
       if r14, g, 0; and numerator was greater then zero
          mov rdi, tmp
          mov qword [rdi + big_int.sign], 1
          ;quotent should be negative
         
          mov rdi, diff
          call is_zero
          
          ;and if division was not exact  
          if rax, ne, 1
             mov rsi, 1
             mov rdi, tmp
             call add_long_short
             ;add 1 to quotient
             ;and make reminder = diff - denominator
             mov rdi, diff
             mov rsi, r13
             call biSub
          endif
       else 
          mov rdi, diff
          mov qword [rdi + big_int.sign], 1 
       endif 
    else
        if r14, l, 0; numerator < 0
            mov rdi, tmp
            mov qword [rdi + big_int.sign], 1
            ;tmp = -tmp
            mov rdi, diff
            call is_zero
            ;if division was not exact
            ;
            if rax, ne, 1
                mov rdi, tmp
                mov rsi, 1
                call add_long_short; abs(tmp) + 1: tmp - 1
                mov rdi, diff
                mov rsi, r13
                call biSub; diff = -(diff - r13)
                mov rdi, diff
                mov rax, [rdi + big_int.sign]
                xor rax, 1
                mov qword [rdi + big_int.sign], rax
            endif
        endif
        ;if numerator and den are not less, than 0, ans is already
        ; in tmp and diff
    endif 
   
    ;some +-0 
    mov rdi, diff
    call normalize

    mov rdi, tmp
    call normalize
    
    mov rdi, tmp; mov quotient to it right place
    mov_in_ptr quotient_ptr, rdi, qword
    
    mov rdi, diff; mov reminder to it right place
    mov_in_ptr reminder_ptr, rdi, qword
    ;clear memory
    mov rdi, r13
    call biDelete
    mov rdi, r12
    call biDelete 
    .end:
    leave
    x86_64_calle_pop
    ret

    ;undef all local vars
    %undef quotient_ptr 
    %undef reminder_ptr
    %undef numerator
    %undef denominator
    %undef left
    %undef right
    %undef tmp
    %undef diff
    %undef tmp_mul_y
