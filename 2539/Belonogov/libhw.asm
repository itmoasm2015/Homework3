
extern calloc
extern free

global biFromInt ;done
global biFromString ;done
global biToString
global biDelete ;done

global biSign
global biAdd
global biSub
global biMul
global biDivRem
global biCmp

%define POINTER 0
%define SIZE 8
%define CAPACITY 16
%define SIGN 24 ; 0 +    1 - 
%define STRUCT_SIZE 32
%define LONG_LONG_SIZE 8
%define CHAR_SIZE 1
%define DEFAULT_VECTOR_SIZE 1
%define BASE 10


        ;r14     pointer to BigInt
        ;r15     pointer to vector 

section .text


    ;void * createVector(int n)

    createVector: 
        mov rsi, LONG_LONG_SIZE 
        call calloc 
        ret

    ;void incSize(void *)  // rdi

    incSize: 
        push r12
        push r13
        push r14
        push r15 

        mov r14, rdi ;  r14 =  pointer to BigInt
        mov r12, [r14 + SIZE]  ; current vector size

        cmp r12, [r14 + CAPACITY] 
        jl .withoutReallocation
            mov rdi, [r14 + CAPACITY]
            imul rdi, 2  ; new vector size
            call createVector
            mov r13, rax  ; pointer to new vector
           
            mov rcx, 0    ; loop variable "i" 
            mov rdx, [r14 + CAPACITY] ; n 
            mov r15, [r14 + POINTER]  ; pointer to old vector 
            .loopStart             

                cmp  rcx, rdx
                je .loopFinish  ; i < n

                    mov rsi, [r15 + rcx * LONG_LONG_SIZE] ; move element from old vector to new
                    mov [r13 + rcx * LONG_LONG_SIZE], rsi

                inc rcx 
                jmp .loopStart 

            .loopFinish

            mov r8, [r14 + CAPACITY]
            imul r8, 2
            mov [r14 + CAPACITY], r8;

            mov rdi, r15
            call free
            mov [r14 + POINTER], r13
            
        .withoutReallocation 

        mov r8, [r14 + SIZE]
        inc r8
        mov [r14 + SIZE], r8

        pop r15
        pop r14 
        pop r13
        pop r12
        ret
    
    ;BigInt createBigInt(int sz) rdi = sz;

    createBigInt:
        push r12
        push r15
        mov r12, rdi  ; r12 = sz

        mov rdi, STRUCT_SIZE 
        mov rsi, 1
        call calloc  ; create new bigInt
        mov r15, rax ; save pointer to BigInt
        mov rdi, r12 
        call createVector       

        mov [r15 + POINTER], rax  ;save pointer to vector into BigInt 
        mov [r15 + CAPACITY], r12
        mov r8, 1
        mov [r15 + SIZE], r8  ;size := 1

        
        mov rax, r15
        pop r15
        pop r12
        ret


    ;BigInt biFromInt(int64_t x); x = rdi
    biFromInt: 
        push r14
        push r15

        mov r14, rdi ; save value to r14
        
        mov rdi, DEFAULT_VECTOR_SIZE
        call createBigInt
        mov r15, rax   

        ;;;;body
        cmp r14, 0     
        jge .end
            mov r8, 1
            mov [r15 + SIGN], r8 ; sing = 1 // -
            imul r14, -1 
        .end 

        mov r8, [r15 + POINTER]
        mov [r8 + 0 * LONG_LONG_SIZE], r14

        mov rax, r15
        pop r15
        pop r14
        ret


    ;mulShort(BigInt , unsigned long long value) // rdi = bigInt     rsi = value


    mulShort: 
        push r12
        push r13 
        push r14
        mov r12, rdi ; r12 = bigInt
        mov r13, rsi ; r13 = value
        mov r14, [r12 + POINTER] ; r14 = pointer to vector
        
        mov r8, 0 ; r8 = carry
        mov rsi, 0  ;           i
        mov rcx, [r12 + SIZE];  n
       
        mov r9, BASE
        .loopStart 
            cmp rsi, rcx
            je .loopEnd
                mov rax, [r14 + rdx * LONG_LONG_SIZE]
                mul r9
                add rax, r8
                adc rdx, 0          ; add carry flag
                mov [r14 + rsi * LONG_LONG_SIZE], rax  
                mov r8, rdx   ; r8 = new carry 
                inc rsi ;   i++
            jmp .loopStart
        .loopEnd
        cmp r8, 0
        je .withoutResize
            mov rdi, r12
            call incSize
            mov rcx, [r12 + SIZE];
            dec rcx    ; size - 1 = last element
            mov r14, [r12 + POINTER]   ;new pointer to vector
            mov [r14 + rcx * LONG_LONG_SIZE], r8
        .withoutResize
        pop r14
        pop r13
        pop r12
        ret


    ;void addShort(bigInt, long long value); rdi = bigInt, rsi = value

    addShort:
        push r12
        push r13 
        push r14
        mov r12, rdi ; r12 = bigInt
        mov r13, rsi ; r13 = value
        mov r14, [r12 + POINTER] ; r14 = pointer to vector
        
        mov r8, r13 ; r8 = carry
        mov rsi, 0  ;           i
        mov rcx, [r12 + SIZE];  n
       
        mov r9, BASE
        .loopStart 
            cmp rsi, rcx
            je .loopEnd
                mov rax, [r14 + rdx * LONG_LONG_SIZE]
                add rax, r8
                mov r8, 0
                adc r8, 0         ; add carry flag
                mov [r14 + rsi * LONG_LONG_SIZE], rax  
                inc rsi ;   i++
            jmp .loopStart
        .loopEnd
        cmp r8, 0
        je .withoutResize
            mov rdi, r12
            call incSize
            mov rcx, [r12 + SIZE]; rcx = vector.size()
            dec rcx    ; size - 1 = last element
            mov r14, [r12 + POINTER]   ;new pointer to vector
            mov [r14 + rcx * LONG_LONG_SIZE], r8
        .withoutResize
        pop r14
        pop r13
        pop r12
        ret

    ;   BigInt biFromString(char const *s); rdi = s

    biFromString: 
        push r12
        push r13    ; sign
        push r14    ; pointer to BigInt
        push r15    ; pointer to vector 
        mov r12, rdi  ; r12 = s
        mov rdi, DEFAULT_VECTOR_SIZE
        call createVector



        mov rcx, 0    ; i = 0
         


        mov r13, 0
        .loopStart
            mov al, 0 
            cmp al, [r12 + rcx * CHAR_SIZE]  ; if (s[i] == 0) break;
            je .loopEnd
            ;;;; body 
                mov dl, [r12 + rcx * CHAR_SIZE]  
                cmp dl, '-'
                jne .notMinus
                    cmp r13, 1
                    je .fail ; 
                    inc r13
                    jmp .endBody
                .notMinus
                cmp dl, '0'
                jl .fail
                cmp dl, '9'   
                jg .fail 

                mov rdi, r14
                mov rsi, BASE
                call mulShort  

                xor rax, rax
                mov al, [r12 + rcx * CHAR_SIZE]
                sub al, '0'
                mov rdi, r14 
                mov rsi, rax
                call addShort

                .endBody 
            ;;;; body
            inc rcx
            jmp .loopStart


        .loopEnd 
        mov [r14 + SIGN], r13
        mov rax, r14
        jmp .notFail
        .fail        
            ;body
            mov rdi, r14
            call biDelete
            mov rax, 0
            ;body
        .notFail 
        pop r15
        pop r14
        pop r13
        pop r12
        ret
      

        ;void biDelete(BigInt bi); rdi = bigInt
        biDelete:
            push r14
            push r15

            mov r14, rdi
            mov r15, [rdi + POINTER]
            mov rdi, r15
            call free
            mov rdi, r14
            call free 
             
            pop r15
            pop r14 
            ret 


; void normalize(BigInt ) rdi = bigInt
        normalize:
            push r13
            push r14
            push r15
            mov r14, rdi               ; r14 - bigInt
            mov r15, [r14 + POINTER]   ; r15 - vector
            mov rcx, [r14 + SIZE]      ; rcx = vector.size();
            dec rcx
            .loopStart
                cmp rcx, 0
                je .loopEnd
                mov r13, [r15 + rcx * LONG_LONG_SIZE] ;; r13 = vector[rcx]
                cmp 0, r13
                jne .loopEnd  
                ;body
                     

                ;body
                dec rcx
                jmp .loopStart
            .loopEnd
            mov r13, [r15 + rcx * LONG_LONG_SIZE] ;; r13 = vector[rcx]
            cmp r13, 0
            jne .plusZero
                mov [r14 + SIGN], 0
            .plusZero
            inc rcx
            mov [r14 + SIZE], rcx

            pop r15
            pop r14
            pop r13
            ret


;long long biDivShort(BigInt, long long divisor)  rdi = bigInt      rsi = divisor
; return remainder
        biDivShort:
            push r12
            push r13
            push r14
            push r15
            mov r14, rdi               ; r14 = bigInt
            mov r13, rsi               ; r13 = divisor
            mov r15, [r14 + POINTER]   ; r15 = pointer to vector
            mov rcx, [r14 + SIZE]      ; rcx = vector.size()
            dec rcx                    ; rcz = vector.size() - 1;

            mov r12, 0                 ; carry
            .loopStart                 ; i = vector.size() - 1 .... 0
                cmp rcx, 0 
                jl .loopEnd           
                ;body
                    mov rax, [r15 + rcx * LONG_LONG_SIZE]
                    xor rdx, rdx
                    add rax, r12
                    adc rdx, 0 
                    div r13
                    mov [r15 + rcx * LONG_LONG_SIZE], rax
                    mov r12, rdx
                ;body
                dec rcx
                jmp .loopStart
            .loopEnd
            mov rdi, r14
            call normalize 
            mov rax, r12
            pop r15
            pop r14
            pop r13
            pop r12

            ret


;BigInt makeCopy(BigInt) rdi = bigInt;
        makeCopy:
            push r12
            push r13
            push r14
            push r15
            mov r14, rdi            ; r14 = old bigInt
            mov r15, [r15 + POINTER]; r15 = old vector 
           
            mov rdi, [r14 + SIZE] 
            call createBigInt 
            mov r13, rax            ; r13 = new BigInt
            mov r12, [r13 + POINTER]; r12 = new vector

            mov rdx = [r14 + SIZE]  ; n  old vector.size()
            mov [r13 + SIZE], rdx   ; newVector size = oldVector size
            
            mov r8, [r14 + SIGN]    ; old sign 
            mov [r13 + SIGN], r8    ; new sign = old sign

            mov rcx = 0;            ; i 

            .loopStart              ; i = 0 ... n - 1
                cmp rcx, rdx
                je .loopEnd
                ;body
                    mov r8, [r15 + rcx * LONG_LONG_SIZE]
                    mov [r12 + rcx * LONG_LONG_SIZE], r8
                ;body
                inc rcx
                jmp .loopStart
            .loopEnd

            mov rax, r13

            pop r15
            pop r14
            pop r13
            pop r12
            ret


;/** Generate a decimal string representation from a BigInt.
 ;*  Writes at most limit bytes to buffer.
 ;*/
;void biToString(BigInt bi, char *buffer, size_t limit);

        biToString:
            push r12
            push r13
            push r14
            push r15
            
             
            
        


            pop r15
            pop r14
            pop r13
            pop r12
            ret


