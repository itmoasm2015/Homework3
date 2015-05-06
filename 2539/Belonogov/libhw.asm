
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
global biDivShort
global biCopy
global biIsZero
global biMulShort
global biAddShort

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
        push r14
        mov r12, rdi  ; r12 = sz

        mov rdi, STRUCT_SIZE 
        mov rsi, 1
        call calloc  ; create new bigInt
        mov r14, rax ; save pointer to BigInt

        mov rdi, r12 
        call createVector       

        mov [r14 + POINTER], rax  ;save pointer to vector into BigInt 
        mov [r14 + CAPACITY], r12
        mov r8, 1
        mov [r14 + SIZE], r8  ;size := 1

        
        mov rax, r14
        pop r14
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


    ;biMulShort(BigInt , unsigned long long value) // rdi = bigInt     rsi = value


    biMulShort: 
        push r12
        push r13 
        push r14
        push r15
        mov r14, rdi ; r14 = bigInt
        mov r13, rsi ; r13 = value
        mov r15, [r14 + POINTER] ; r15 = pointer to vector
        
        mov r12, 0 ; r12 = carry
        mov rsi, 0  ;           i
        mov rcx, [r14 + SIZE];  n
       
        mov r9, r13
        .loopStart 
            cmp rsi, rcx
            je .loopEnd
                mov rax, [r15 + rsi * LONG_LONG_SIZE]
                mul r9
                add rax, r12
                adc rdx, 0          ; add carry flag
                mov [r15 + rsi * LONG_LONG_SIZE], rax  
                mov r12, rdx   ; r8 = new carry 
            inc rsi ;   i++
            jmp .loopStart
        .loopEnd
        cmp r12, 0
        je .withoutResize
            mov rdi, r14
            call incSize
            mov rcx, [r14 + SIZE];
            dec rcx    ; size - 1 = last element
            mov r15, [r14 + POINTER]   ;new pointer to vector
            mov [r15 + rcx * LONG_LONG_SIZE], r12
        .withoutResize
        pop r15
        pop r14
        pop r13
        pop r12
        ret


    ;void biAddShort(bigInt, long long value); rdi = bigInt, rsi = value

    biAddShort:
        push r12
        push r13 
        push r14
        mov r12, rdi ; r12 = bigInt
        mov r13, rsi ; r13 = value
        mov r14, [r12 + POINTER] ; r14 = pointer to vector
        
        mov r8, r13 ; r8 = carry
        xor rsi, rsi  ;           i
        mov rcx, [r12 + SIZE];  n
       
        ;mov r9, r13 
        .loopStart 
            cmp rsi, rcx
            je .loopEnd
                mov rax, [r14 + rsi * LONG_LONG_SIZE]
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
            push r15    ; loop variable
            mov r12, rdi  ; r12 = s
            mov rdi, DEFAULT_VECTOR_SIZE
            call createBigInt
            mov r14, rax

            ;mov rcx, 0    ; i = 0
            xor r15, r15   ; i = 0
            ;xor rcx, rcx   ; i = 0;
            ;mov r13, 0
            xor r13, r13   ; sign "+" by default
            .loopStart
                xor al, al
                cmp al, [r12 + r15 * CHAR_SIZE]  ; if (s[i] == 0) break;
                je .loopEnd
                ;;;; body 
                    mov dl, [r12 + r15 * CHAR_SIZE]  
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
                    call biMulShort  

                    xor rax, rax
                    mov al, [r12 + r15 * CHAR_SIZE]
                    sub al, '0'
                    mov rdi, r14 
                    mov rsi, rax
                    call biAddShort

                    .endBody 
                ;;;; body
                inc r15
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
                cmp r13, 0
                jne .loopEnd  
                ;body
                     

                ;body
                dec rcx
                jmp .loopStart
            .loopEnd
            mov r13, [r15 + rcx * LONG_LONG_SIZE] ;; r13 = vector[rcx]
            cmp r13, 0
            jne .plusZero
                mov r8, 0
                mov [r14 + SIGN], r8
            .plusZero
            inc rcx
            mov [r14 + SIZE], rcx

            pop r15
            pop r14
            pop r13
            ret


; long long biDivShort(BigInt, long long divisor)  rdi = bigInt      rsi = divisor
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

            mov r12, 0                 ; r12 = carry
            .loopStart                 ; i = vector.size() - 1 .... 0
                cmp rcx, 0 
                jl .loopEnd           
                ;body
                    mov rax, [r15 + rcx * LONG_LONG_SIZE]
                    mov rdx, r12
                    ;add rax, r12
                    ;adc rdx, 0 
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


;BigInt biCopy(BigInt) rdi = bigInt;
        biCopy:
            push r12
            push r13
            push r14
            push r15
            mov r14, rdi            ; r14 = old bigInt
            mov r15, [r14 + POINTER]; r15 = old vector 
           
            mov rdi, [r14 + SIZE] 
            call createBigInt 
            mov r13, rax            ; r13 = new BigInt
            mov r12, [r13 + POINTER]; r12 = new vector

            mov rdx, [r14 + SIZE]  ; n  old vector.size()
            mov [r13 + SIZE], rdx   ; newVector size = oldVector size
            
            mov r8, [r14 + SIGN]    ; old sign 
            mov [r13 + SIGN], r8    ; new sign = old sign

            mov rcx, 0;            ; i 

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


; long long biIsZero(BigInt) rdi = bigInt
        biIsZero: 
            push r14
            push r15
            mov r14, rdi
            mov r15, [r14 + POINTER]
            mov rax, 0
            mov rcx, [r14 + SIZE]
            cmp rcx, 1
            jne .end
                mov r8, [r15 + 0 * LONG_LONG_SIZE]
                cmp r8, 0
                jne .end 
                mov rax, 1
            .end
            pop r15
            pop r14
            ret


    ;void reverse(char * s, int n) rdi = s     n = rsi
        reverse: 
            mov r8, rsi
            shr r8, 1
            
            xor r9, r9
            .loopStart
                cmp r9, r8
                je .loopEnd 
                    mov r11, rsi
                    dec r11
                    sub r11, r9

                    mov al, [rdi + r9 * CHAR_SIZE]    
                    mov dl, [rdi + r11 * CHAR_SIZE] 
                    mov [rdi + r11 * CHAR_SIZE], al
                    mov [rdi + r9 * CHAR_SIZE], dl

                inc r9
                jmp .loopStart 
            .loopEnd 
       
        
            ret

;/** Generate a decimal string representation from a BigInt.
 ;*  Writes at most limit bytes to buffer.
 ;*/
;void biToString(BigInt bi, char *buffer, size_t limit);  
;rdi = bigInt 
;rsi = buffer
;rdx = limit
        biToString:
            push r12
            push r13
            push r14
            push r15
            push rdi                ; save bigint
            mov r12, rsi            ;buffer
            mov r13, rdx            ;limit
            dec r13                 ; reserve place for terminate symbol
            
            call biCopy
            mov r14, rax            ; r14 = bigInt 
            mov r15, 0              ; i = 0
            .loopStart
                mov rdi, r14
                call biIsZero     
                cmp rax, 1
                je .loopEnd
                cmp r15, r13
                je .loopEnd 
                ;body
                    mov rdi, r14
                    mov rsi, BASE
                    call biDivShort   
                    add rax, '0' 
                    mov [r12 + r15 * CHAR_SIZE], al
                ;body
                inc r15
                jmp .loopStart 
            .loopEnd 

            pop rdi             ; getBigInt
            
            mov r8, 1
            cmp r8, [rdi + SIGN]
            jne .trimmed
                cmp r15, r13
                je .trimmed
                    mov al, '-'
                    mov [r12 + r15 * CHAR_SIZE], al
                    inc r15
            .trimmed 
            
            mov rdi, r12
            mov rsi, r15
            call reverse
            xor r8, r8
            mov [r12 + r15 * CHAR_SIZE], r8

            cmp r15, 0
            jne .notZero
                mov al, '0'
                mov [r12 + r15 * CHAR_SIZE], al
                inc r15
            .notZero 

            mov rdi, r14
            call biDelete

            pop r15
            pop r14
            pop r13
            pop r12
            ret


