extern calloc
extern free

global biFromInt ;done
global biFromString ;done
global biToString  ;done
global biDelete ;done

global biSign   ;done
global biAdd  ;done
global biSub ;done
global biMul  ;done
global biDivRem ;done
global biCmp ;done
global biDivShort ;done
global biCopy ;done
global biIsZero ;done
global biMulShort ;done
global biAddShort ;done
global biAddMy ;done
global biSubMy ;done
global biMulMy ;done
global biMove  ;done
global biSetBit ;done
global biBigShl ;done

%define POINTER 0
%define SIZE 8
%define CAPACITY 16
%define SIGN 24 ; 0 +    1 - 
%define STRUCT_SIZE 32
%define LONG_LONG_SIZE 8
%define CHAR_SIZE 1
%define DEFAULT_VECTOR_SIZE 1
%define BASE 10
%define ALIGNMENT 4 


%macro call2 3          ; macro for function call with two arguments
    mov rdi, %2
    mov rsi, %3
    call %1 
%endmacro

%macro call1 2          ; macro for function call with one argument
    mov rdi, %2
    call %1
%endmacro


        ;I will keep the BigInt as follows
        ;BigInt contains link to 4 eight-byte numbers
        ; first  - pointer to vector with digits
        ; second - vector size 
        ; third  - vector capacity 
        ; fourth - BigInt sign ; 0 <=> +; 1 <=> -
        ;
        ; base of BigInt is 2^64
        ;

        ; usually
        ; r14     pointer to BigInt
        ; r15     pointer to vector 

section .text
    ;void * createVector(int n)

        myAlloc:           ; myAlloc - allocation with alignment up to 16 byte
            push r15
            mov r15, rsp   ; save stack pointer
            shr rsp, ALIGNMENT ; alignment  /= 16
            shl rsp, ALIGNMENT ; alignment  *= 16
            call calloc 
            mov rsp, r15   ; return old value
            pop r15
     
            ret

    ;myDelete(void * );
        myDelete:          ; myDelete - free with alignment up to 16 byte 
            push r15
            mov r15, rsp ; save stack pointer
            
            shr rsp, ALIGNMENT ; alignment  /= 16
            shl rsp, ALIGNMENT ; alignment  *= 16
            call free 

            mov rsp, r15 ; return old value
            pop r15
            ret



    createVector: 
        mov rsi, LONG_LONG_SIZE 
        call myAlloc 
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
            mov rdi, [r14 + CAPACITY]    ; old capacity
            imul rdi, 2                  ; new vector size
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

            mov r8, [r14 + CAPACITY]  ; increase capacity
            imul r8, 2
            mov [r14 + CAPACITY], r8  ;

            mov rdi, r15
            call myDelete; delete old vector
            mov [r14 + POINTER], r13  ; set new vector
            
        .withoutReallocation 

        mov r8, [r14 + SIZE]          ; increase size by one
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
        push r15
        mov r12, rdi  ; r12 = sz

        mov rdi, STRUCT_SIZE 
        mov rsi, 1
        
        mov r15, rsp


        call myAlloc; create new bigInt

        mov rsp, r15

        mov r14, rax ; save pointer to BigInt

        call1 createVector, r12

        mov [r14 + POINTER], rax  ;save pointer to vector into BigInt 
        mov [r14 + CAPACITY], r12 ; sz
        mov [r14 + SIZE], r12     ; sz
        
        mov rax, r14
        pop r15
        pop r14
        pop r12
        ret


    ;BigInt biFromInt(int64_t x); x = rdi
    biFromInt: 
        push r14
        push r15

        mov r14, rdi ; save value to r14
         
        call1 createBigInt, DEFAULT_VECTOR_SIZE    ; create BigInt with size = 1
        mov r15, rax   

        cmp r14, 0     
        jge .end
            mov r8, 1
            mov [r15 + SIGN], r8                   ; sing = 1 <=>  '-'
            imul r14, -1 
        .end 
                                                   ; assert r14 >= 0
        mov r8, [r15 + POINTER]
        mov [r8 + 0 * LONG_LONG_SIZE], r14         ; set value in vector[0]

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
        mov r13, rsi ; r13 = multiplier 
        mov r15, [r14 + POINTER] ; r15 = pointer to vector
        
        mov r12, 0 ; r12 = carry
        mov rsi, 0  ;           i
        mov rcx, [r14 + SIZE];  n
       
        mov r9, r13
        .loopStart 
            cmp rsi, rcx
            je .loopEnd
                mov rax, [r15 + rsi * LONG_LONG_SIZE] ; rax = vector[i]
                mul r9                                ; rdx__rax = vector[i] * multiplier
                add rax, r12                          ; add carry
                adc rdx, 0                            ; add new carry 
                mov [r15 + rsi * LONG_LONG_SIZE], rax  
                mov r12, rdx                       ; r8 = new carry 
            inc rsi                                ; i++
            jmp .loopStart
        .loopEnd
        cmp r12, 0
        je .withoutResize
            mov rdi, r14
            call incSize
            mov rcx, [r14 + SIZE];
            dec rcx                                ; size - 1 = last element
            mov r15, [r14 + POINTER]               ; new pointer to vector
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
        push r15
        mov r14, rdi ; r14 = bigInt
        mov r15, [r14 + POINTER] ; r15 = pointer to vector

        mov r13, rsi ; r13 = value, carry
        
        xor rsi, rsi  ;           i
        mov rcx, [r14 + SIZE];  n
       
        .loopStart 
            cmp rsi, rcx
            je .loopEnd
                mov rax, [r15 + rsi * LONG_LONG_SIZE]   ; rax = vector[i]
                add rax, r13                            ; rax = vector[i] + carry
                mov r13, 0                              ; 
                adc r13, 0                               ; add carry flag
                mov [r15 + rsi * LONG_LONG_SIZE], rax   ; vector[i] = rax
            inc rsi ;   i++
            jmp .loopStart
        .loopEnd
        cmp r13, 0
        je .withoutResize
            mov rdi, r14
            call incSize
            mov rcx, [r14 + SIZE]     ; rcx = vector.size()
            dec rcx                     ; size - 1 = last element
            mov r15, [r14 + POINTER]   ;new pointer to vector
            mov [r15 + rcx * LONG_LONG_SIZE], r13
        .withoutResize
        pop r15
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

            call1 createBigInt, DEFAULT_VECTOR_SIZE
            mov r14, rax

            xor r15, r15   ; i = 0
            xor r13, r13   ; sign "+" by default
            .loopStart
                xor al, al
                cmp al, [r12 + r15 * CHAR_SIZE]  ; if (s[i] == 0) break;
                je .loopEnd
                    mov dl, [r12 + r15 * CHAR_SIZE]  
                    cmp dl, '-'
                    jne .notMinus              ; s[i] == '-'
                        cmp r15, 0
                        jne .fail ;             ; if there is at least two minuses
                        inc r13                ; inc minuses count
                        jmp .endBody
                    .notMinus
                    cmp dl, '0'                ; check what s[i] isDigit
                    jl .fail                 
                    cmp dl, '9'   
                    jg .fail                   ; if ! isDigit then fail

                    call2 biMulShort, r14, BASE  ; bigInt *= 10

                    xor rax, rax
                    mov al, [r12 + r15 * CHAR_SIZE]
                    sub al, '0'                 ; s[i] - '0';

                    call2 biAddShort, r14, rax   ; bigInt  += s[i] - '0'

                    .endBody 
                inc r15
                jmp .loopStart


            .loopEnd 
            sub r15, r13
            cmp r15, 0
            je .fail                               ; check case then string doesn't contains digits
        

            mov [r14 + SIGN], r13                  ; set sign

            mov rdi, r14
            call normalize                         ; normalize handles case "-0"

            mov rax, r14
            
            jmp .notFail
            .fail        
                call1 biDelete, r14                
                xor rax, rax                       ; return NULL
            .notFail 
            pop r15
            pop r14
            pop r13
            pop r12
            ret
          

        ;void biDelete(BigInt bi); rdi = bigInt
        biDelete:
            push r12
            push r14
            push r15
            mov r14, rdi                           ; bigInt
            mov r15, [rdi + POINTER]               ; vector
            call1 myDelete, r15                        ; delete vector

            call1 myDelete, r14                        ; delete bigInt
            pop r15
            pop r14 
            pop r12
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
                cmp r13, 0                             ; while (vector.back() == 0)  vector.pop_back() 
                jne .loopEnd  

                dec rcx                                ; size -- <=> pop_back
                jmp .loopStart
            .loopEnd
            mov r13, [r15 + rcx * LONG_LONG_SIZE] ;; r13 = vector[rcx]
            cmp r13, 0
            jne .plusZero                        ; -0 => +0 
                mov r8, 0
                mov [r14 + SIGN], r8
            .plusZero
            inc rcx
            mov [r14 + SIZE], rcx               ; set new size

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
                    mov rax, [r15 + rcx * LONG_LONG_SIZE]  ; rax = vector[i]
                    mov rdx, r12                           ; rdx = carry
                    div r13                                ; rdx_rax /= r13 
                    mov [r15 + rcx * LONG_LONG_SIZE], rax  ; vector[i] = rax
                    mov r12, rdx                           ; write new_carry value
                dec rcx
                jmp .loopStart
            .loopEnd
            call1 normalize, r14                        ; delete leading zero
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
           
            call1 createBigInt, [r14 + SIZE]
            mov r13, rax            ; r13 = new BigInt
            mov r12, [r13 + POINTER]; r12 = new vector

            mov rdx, [r14 + SIZE]   ; n  old vector.size()
            mov [r13 + SIZE], rdx   ; newVector size = oldVector size
            
            mov r8, [r14 + SIGN]    ; old sign 
            mov [r13 + SIGN], r8    ; new sign = old sign

            mov rcx, 0;             ; i 

            .loopStart              ; i = 0 ... n - 1
                cmp rcx, rdx
                je .loopEnd
                    mov r8, [r15 + rcx * LONG_LONG_SIZE]    ; r8 := oldVector[i]
                    mov [r12 + rcx * LONG_LONG_SIZE], r8    ; newVector[i] := r8
                inc rcx            ; i++
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
            mov rax, 0                               ; rax := 0
            mov rcx, [r14 + SIZE]
            cmp rcx, 1
            jne .end
                mov r8, [r15 + 0 * LONG_LONG_SIZE]   ; r8 = vector[0]
                cmp r8, 0                            ; r[8] == 0 ? 
                jne .end 
                    mov rax, 1                           ; if equal then rax := 1
            .end
            pop r15
            pop r14
            ret


    ;void reverse(char * s, int n) rdi = s     n = rsi
        ; reverse string 
        ;
        reverse: 
            mov r8, rsi
            shr r8, 1                                 ; mid element
            
            xor r9, r9                               ; i := 0
            .loopStart
                cmp r9, r8                           ; while i != mid
                je .loopEnd  
                    mov r11, rsi    
                    dec r11
                    sub r11, r9                      ; r11 = n - i - 1 

                    mov al, [rdi + r9 * CHAR_SIZE]          ; swap two elements with indexes r9 and r11
                    mov dl, [rdi + r11 * CHAR_SIZE] 
                    mov [rdi + r11 * CHAR_SIZE], al
                    mov [rdi + r9 * CHAR_SIZE], dl

                inc r9                                ; i++;
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
                call biIsZero        ; while bigInt != 0
                cmp rax, 1
                je .loopEnd 
                cmp r15, r13         ; i != limit
                je .loopEnd 
                    call2 biDivShort, r14, BASE 
                    add rax, '0'               ; rax = BigInt %= 10
                    mov [r12 + r15 * CHAR_SIZE], al  ; write char to string
                inc r15              ; i++
                jmp .loopStart 
            .loopEnd 

            pop rdi             ; getBigInt
            
            mov r8, 1
            cmp r8, [rdi + SIGN]  
            jne .trimmed              ; try add sign if r8 < limit
                cmp r15, r13
                je .trimmed
                    mov al, '-'
                    mov [r12 + r15 * CHAR_SIZE], al
                    inc r15
            .trimmed 
            
            call2 reverse, r12, r15           ; reverse string

            xor rax, rax                      ; rax = 0
            mov [r12 + r15 * CHAR_SIZE], al   ; add terminate character

            cmp r15, 0
            jne .notZero                      ; if len == 0 then BigInt == 0 => s = "0"
            cmp r15, r13
            je .notZero
                mov al, '0'
                mov [r12 + r15 * CHAR_SIZE], al  ; s[0] = '0'
                inc r15
            .notZero 

            call1 biDelete, r14                ; delete temporary 

            pop r15
            pop r14
            pop r13
            pop r12
            ret

        ;BigInt biAddMy(BigInt l, BigInt r); 
        ; l = rdi
        ; r = rsi

        biAddMy:
            push r12                
            push r13                
            push r14                
            push r15               

            mov r12, rdi            ; Bigint l
            mov r14, rsi            ; BigInt r
            mov r13, [r12 + POINTER]; vector l
            mov r15, [r14 + POINTER]; vector r
            
            mov r8, [r12 + SIGN]    ; sign l
            mov r9, [r14 + SIGN]    ; sign r
            cmp r8, r9
            jne .callSub
                mov r10, [r12 + SIZE] ; l.size();
                mov r11, [r14 + SIZE] ; r.size()
                cmp r10, r11
                jg .notChange
                    mov r10, r11     ; r10 = max(r10, r11)
                .notChange 
                call1 createBigInt, r10
                mov r8, rax           ; r8 = bigInt res
                mov r9, [r8 + POINTER]  ; r9 = res.vector
                mov rax, [r12 + SIGN] 
                mov [r8 + SIGN], rax    ; set Sign
                mov r10, [r8 + SIZE]    ; size
                xor rcx, rcx            ; i == 0 .. size - 1
                xor rdx, rdx            ; carry 

                .loopStart
                    cmp rcx, r10
                    je .loopEnd         ; jump if i == size
                        mov rax, rdx             ; rax = carry;
                        xor rdx, rdx
                        cmp rcx, [r12 + SIZE]
                        jge .notAdd1         ; i < l.size()
                            add rax, [r13 + rcx * LONG_LONG_SIZE]  ; rax += vector[l]
                            adc rdx, 0                             ; add to new carry
                        .notAdd1
                        cmp rcx, [r14 + SIZE]
                        jge .notAdd2         ; i < r.size()
                            add rax, [r15 + rcx * LONG_LONG_SIZE]  ; rax += vector[r]
                            adc rdx, 0                             ; add to new carry
                        .notAdd2
                        mov [r9 + rcx * LONG_LONG_SIZE], rax       ; write rax in result
                    inc rcx                       ; i++
                    jmp .loopStart
                .loopEnd
                cmp rdx, 0
                je .notIncrease              ; jump if carry = 0
                    push rdx
                    push r8
                    call1 incSize, r8
                    pop r8
                    pop rdx
                    mov r9, [r8 + POINTER]    ; pointer could change 
                    mov rcx, [r8 + SIZE]      ; new size
                    dec rcx                   ; rcx = size - 1
                    mov [r9 + rcx * LONG_LONG_SIZE], rdx  ;  vecotr[size - 1] = carry
                .notIncrease
                mov rax, r8

            jmp .go
            .callSub    ; if a.sign != b.sign then let's call biSub!
                xor r9, 1
                mov [r14 + SIGN], r9  ; a + b = a - (- b) 
                                      ; changed b.sign
                call2 biSubMy, r12, r14 
                mov r9, [r14 + SIGN]  ; change sign again
                xor r9, 1
                mov [r14 + SIGN], r9  ; recovery sign bit
            .go

            pop r15
            pop r14
            pop r13
            pop r12
            ret
       


       
        ; BigInt biSubMy(BigInt l, BigInt r);
        ; l = rdi
        ; r = rsi 
        biSubMy:
            push r12                ; bigInt l
            push r13                ; vector l 
            push r14                ; bigInt r
            push r15                ; vector r
            mov r12, rdi
            mov r14, rsi
            mov r13, [r12 + POINTER]
            mov r15, [r14 + POINTER] 
            
            mov r8, [r12 + SIGN]    ; l.sign
            mov r9, [r14 + SIGN]    ; r.sign
            cmp r8, r9
            jne .callAdd            ; jump if l.sign != r.sign
                push r8
                push r9               ; save signs on the stack
                xor r10, r10          ; 0
                mov [r12 + SIGN], r10 ; set l.sign = 0 <=> +
                mov [r14 + SIGN], r10 ; set r.sign = 0 <=> + 
                call2 biCmp, r12, r14

                pop r9
                pop r8
                mov [r12 + SIGN], r8  ; recovery sign
                mov [r14 + SIGN], r9  ; recovery sign
                cmp rax, -1 
                jne .letsSub        ; if |l| < |r| then swap arguments and call this function again
                                    ; a - b =  -(b - a)
                    call2 biSubMy, r14, r12
                    mov r10, [rax + SIGN]
                    xor r10, 1
                    mov [rax + SIGN], r10   ; reverse result.sign 
                jmp .overSub
                .letsSub
                    call1 createBigInt, [r12 + SIZE]
                    mov r8, rax                 ; result bigInt
                    mov r9, [r8 + POINTER]      ; result vector
                    xor rcx, rcx                ; i = 0 loop variable
                    mov r10, [r12 + SIZE]       ; size
                    xor rdx, rdx                ; carry
                    ;clc                         ; clear cf flag
                        
                    .loopStart
                        cmp rcx, r10
                        je .loopEnd             ; jump if i == size
                            mov rax, [r13 + rcx * LONG_LONG_SIZE]   ; rax = vector[i]
                            sub rax, rdx                            ; rax -= carry 
                            mov rdx, 0                              ; 
                            adc rdx, 0                              ; rdx = CF
                            cmp rcx, [r14 + SIZE]                   ; 
                            jge .notSub                             ; 
                                sub rax, [r15 + rcx * LONG_LONG_SIZE];  i < size()
                                adc rdx, 0
                            .notSub
                            mov [r9 + rcx * LONG_LONG_SIZE], rax
                        inc rcx                                     ; i++
                        jmp .loopStart 
                    .loopEnd 
                    mov rcx, [r14 + SIGN]
                    mov [r8 + SIGN], rcx                             ; r8.sign = l.sign
                    mov rax, r8 
                .overSub

            jmp .overCallAdd
            .callAdd                  
                xor r9, 1             ; change sign 
                mov [r14 + SIGN], r9  ; a + b = a - (- b)
                call2 biAddMy, r12, r14  ; result in rax
                mov r9, [r14 + SIGN]
                xor r9, 1
                mov [r14 + SIGN], r9  ; recovery sign bit
            .overCallAdd
            push rax
            call1 normalize, rax      ; delete leading zeros

            pop rax

            pop r15
            pop r14
            pop r13
            pop r12
            ret 
                      
        ;int biCmp(BigInt l, BigInt r);
        ; l = rdi
        ; r = rsi
        biCmp:
            push r12                ; bigInt l
            push r13                ; vector l 
            push r14                ; bigInt r
            push r15                ; vector r
            mov r12, rdi
            mov r14, rsi
            mov r13, [r12 + POINTER]
            mov r15, [r14 + POINTER] 

            mov r8, [r12 + SIGN]    ; sign l
            mov r9, [r14 + SIGN]    ; sign r
            cmp r8, r9
            jne .diffSign           ; jump if l.sign != r.sing
                mov r8, [r12 + SIZE]  ; l.len
                mov r9, [r14 + SIZE]  ; r.len
                cmp r8, r9
                je .cmpVector         ; jump if l.len == r.len
                    cmp r8, r9
                    jl .lessLen
                        mov rax, 1    ; l.len > r.len
                        jmp .afterLess
                    .lessLen 
                        mov rax, -1   ; l.len < r.len
                    .afterLess

                jmp .notCmpVector
                .cmpVector 
                    mov rcx, r8                                ; r8 = i = size
                    mov rax, 0
                    .loopStart
                        dec rcx                                ; i--
                        mov r10, [r13 + rcx * LONG_LONG_SIZE]  ; r10 = l[i]
                        mov r11, [r15 + rcx * LONG_LONG_SIZE]  ; r11 = r[i]
                        cmp r10, r11 
                        je .notInteresting                     ; jump if l[i] == r[i]
                            cmp r10, r11
                            jb .lLess
                                mov rax, 1                     ; l[i] > r[i] => l > r
                                jmp .rLess
                            .lLess
                                mov rax, -1                    ; l[i] < r[i] => l < r
                            .rLess
                            mov rcx, 0                         ; i = 0 <=> break
                        .notInteresting                        ; l[i] == r[i]
                    cmp rcx, 0                               
                    jne .loopStart                             ; jump if i != 0 
                .notCmpVector
                mov r8, [r12 + SIGN]                           ; if r12.sign == -1 then
                                                               ; reverse result
                cmp r8, 1
                jne .notRev 
                    imul rax, -1                    
                .notRev
                 
            jmp .go
            .diffSign          ; l.sign != r.sign
                cmp r8, 1
                je .c1
                    mov rax, 1    ; l.sign == '+'
                    jmp .c2
                .c1
                    mov rax, -1   ; r.sign == '+'
                .c2
            .go 
            pop r15
            pop r14
            pop r13
            pop r12
            ret 
         
    ;   BigInt biMulMy(BigInt l, BigInt r);
    ; rdi = l
    ; rsi = r
        biMulMy:
            push r12                ; bigInt l
            push r13                ; vector l 
            push r14                ; bigInt r
            push r15                ; vector r
            mov r12, rdi
            mov r14, rsi
            mov r13, [r12 + POINTER]
            mov r15, [r14 + POINTER] 
         
            mov rdi, [r12 + SIZE]
            add rdi, [r14 + SIZE]   ; rdi = size for result vector = l.size + r.size 

            call createBigInt 
            mov r8, rax              ; bigInt res
            mov r9, [r8 + POINTER]   ; vector res
             
            xor r10, r10             ; i
            .loopStart1
                cmp r10, [r12 + SIZE] ; i = 0 .. l.size() - 1
                je .loopEnd1
                ;{
                    xor r11, r11     ; j
                    xor rcx, rcx     ; carry
                    .loopStart2      ; j = 0 .. r.size() - 1
                        cmp r11, [r14 + SIZE]
                        je .loopEnd2
                        ;{
                            mov rax, [r13 + r10 * LONG_LONG_SIZE]    ; rax = l[i]
                            mov rdi, [r15 + r11 * LONG_LONG_SIZE]    ; rdi = r[j] 
                            mul rdi                                  ; l[i] *= r[j]

                            add rax, rcx                             ; add carry
                            adc rdx, 0      

                            mov rsi, r10                             ; rsi = i
                            add rsi, r11                             ; rsi = i + j

                            mov rdi, [r9 + rsi * LONG_LONG_SIZE]     ;add value from result
                            add rax, rdi
                            adc rdx, 0 
                            
                            mov rcx, rdx                             ; set carry
                            mov [r9 + rsi * LONG_LONG_SIZE], rax     ; write rax
                        ;}
                        inc r11                                      ; j++
                        jmp .loopStart2
                    .loopEnd2
                    mov rsi, r10    ; 
                    add rsi, r11    ; rsi = i + r.size()
                    add [r9 + rsi * LONG_LONG_SIZE], rcx  ; write carry
                ;}
                inc r10             ; i++
                jmp .loopStart1
            .loopEnd1
            
            mov r10, [r12 + SIGN]
            xor r10, [r14 + SIGN]   ; calculate sign of result  = l.sign ^ r.sign
            
            mov [r8 + SIGN], r10    ; write res.sign = l.sign ^ r.sign 

            push r8
            call1 normalize, r8
            pop r8
            mov rax, r8   ;return result

            pop r15
            pop r14
            pop r13
            pop r12
            ret

;/** Get sign of given BigInt.
 ;*  \return 0 if bi is 0, positive if bi is positive, negative if bi is negative.
 ;*/
;int biSign(BigInt bi);
        ; rdi = bigInt 

        biSign:
            push r14
            mov r14, rdi                 ; r14 = bigint
            call biIsZero               
            cmp rax, 1 
            je .retZero                  ; if bigInt == 0
                xor rcx, rcx
                cmp rcx, [r14 + SIGN]
                je .retOne
                mov rax, -1             ; bigInt < 0

            jmp .overRetOne
            .retOne                     ; bigInt > 0
                mov rax, 1               

            .overRetOne

            jmp .overRetZero
            .retZero                      ; bigInt == 0
                mov rax, 0
            .overRetZero

            pop r14
            ret


;void biMove (BigInt dst, BigInt src);
        ; dst <= src
        ; and delete src
        biMove:
            push r12                ; bigInt l
            push r14                ; bigInt r
            mov r12, rdi
            mov r14, rsi
        
            call1 myDelete, [r12 + POINTER]  

            mov r8, [r14 + POINTER]     ; copy POINTER
            mov [r12 + POINTER], r8;

            mov r8, [r14 + SIGN]        ; copy SIGN
            mov [r12 + SIGN], r8;

            mov r8, [r14 + CAPACITY]    ; copy CAPACITY
            mov [r12 + CAPACITY], r8;

            mov r8, [r14 + SIZE]        ; copy SIZE
            mov [r12 + SIZE], r8;
    

            call1 myDelete, r14         ; delete old BigInt

            pop r14
            pop r12
            ret
    
     

;/** dst += src */
;void biAdd(BigInt l, BigInt r);
        ; rdi = l
        ; rsi = r
        ; implementation "+=" through  "+"
        biAdd:             
            push r14
            mov r14, rdi 
            call biAddMy 
           
            call2 biMove, r14, rax

            pop r14
            ret


;/** dst -= src */
;void biSub(BigInt dst, BigInt src);
        
        ; implementation "-=" through  "-"
        biSub: 
            push r14
            mov r14, rdi 
            call biSubMy 
            call2 biMove, r14, rax

            pop r14
            ret


;/** dst *= src */
;void biMul(BigInt dst, BigInt src);
        ; implementation "*=" through "*"
        biMul:
            push r14
            mov r14, rdi 
            call biMulMy 
           
            call2 biMove, r14, rax

            pop r14
            ret


        ;void biSetBit(BigInt, int )
        ; rdi = BigInt
        ; rsi = pos 
        ; set bit to One
        biSetBit:
            push r14          ;BigInt
            push r15          ;vector
            mov r14, rdi
            mov r15, [r14 + POINTER]
            mov rcx, rsi     
            shr rcx, 6        ;position
            and rsi, 63       ;shift
            mov rax, 1


            ;cl;shl 1, rsi
            push rcx 
            mov rcx, rsi    
            shl rax, cl      ; 1 << shift
            
            pop rcx
            or  [r15 + rcx * LONG_LONG_SIZE], rax   ; "or" appropriate element and bit with one

            pop r15
            pop r14
            ret
    

;; void biBigShl(BigInt, int );
    ;bigInt rdi
    ;int    rsi
        biBigShl:
            push r12                
            push r14               
            push r15                
            mov r14, rdi    ; r14 bigInt
            mov r12, rsi    ; count multiplications

            mov rdi, 1 
            shl rdi, 32
            call biFromInt         ; rax = 2^32
            mov rdi, rax
            mov rsi, rax
            mov r15, rdi            ; r15 = 2^64
            call biMul              ; rax = 2^64
            
            .loopStart1
                cmp r12, 0       
                je .loopEnd1    ; jump if i == 0
                    call2 biMul, r14, r15
                dec r12          ; i--;
                jmp .loopStart1
            .loopEnd1 

            call1 biDelete, r15             ; r15 = 2^64
            
            pop r15
            pop r14
            pop r12
            ret


        ;biChangeSign(BigInt) 
        ;rdi = bigInt
        ; it's simple only "xor 1" field SIGN
        biChangeSign:
            push r14
            mov r14, rdi
            mov r8, [r14 + SIGN]    ; SIGN
            xor r8, 1               ; ^= 1
            mov [r14 + SIGN], r8    ; write down
            pop r14
            ret

        

;/** Compute quotient and remainder by divising numerator by denominator.
 ;*  quotient * denominator + remainder = numerator
 ;*
 ;*  \param remainder must be in range [0, denominator) if denominator > 0
 ;*                                and (denominator, 0] if denominator < 0.
 ;*/
;void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
    ; quotient = rdi
    ; remainder = rsi
    ; numerator = rdx     =    A
    ; denominator = rcx   =    B
    ; A / B
    ; implementation:  B1 = B * 2^x,  so that B1 >= A 
    ; and after then will execute this cycle 
    ; i = x
    ; while (B1 >= B) 
    ;    if (A >= B1) 
    ;        A -= B1
    ;        R |= i
    ;    B1 /= 2
    ;    i--
    ; return R
        biDivRem:
            push r12                ; bigInt l
            push r13                ; vector l 
            push r14                ; bigInt r
            push r15                ; vector r

            push rdi                ; save quotient 
            push rsi                ; save remainder

            mov r12, rdi
            mov r13, rsi
            mov r14, rdx
            mov r15, rcx

            call1 biIsZero, r15     ; handles case when  denominator == 0
            cmp rax, 1
            je .fail                ; if denominator == 0 then  => fail

            mov rdi, r12
            mov rsi, r13
            mov rdx, r14
            mov rcx, r15

 
            mov rdi, rdx
            mov r15, rcx            ; tmp save
           
            mov r8, [rdx + SIGN]    ; numerator sign
            mov r9, [rcx + SIGN]    ; denominator sign
            imul r8, 2
            add r8, r9
            push r8                 ; save sign information on stack
                                    ; with followig format num.sign * 2 + den.sing


            call biCopy             ; create copy of numerator
            mov r12, rax 
            
            call1 biCopy, r15       ; create copy of denominator
            mov r14, rax

            xor r10, r10                
            mov [r12 + SIGN], r10       ; set l.sign to 0
            mov [r14 + SIGN], r10       ; set r.sign to 0
 

            mov rdi, [r12 + SIZE]
            sub rdi, [r14 + SIZE]
            inc rdi                    ; calculate result.size = l.size - r.size + 1
            cmp rdi, 1
            jge .notSetOne             ; result.size = max(1, result.size)
                mov rdi, 1
            .notSetOne
            mov r13, rdi              ; r13  contains max answer size

            call2 biBigShl, r14, r13  

            mov rdi, r13
            call createBigInt         ; create bigInt for result
            mov r15, rax              ; save in r8
        

            imul r13, 64 ; cnt Interation
            ; r15 - result
            ; r14 - subtractor
            ; r13 - loop variable
            ; r12 - numerator

            ; here begins the cycle described in the title
            .loopStart2
                    call2 biCmp, r12, r14          
                    cmp rax, -1
                    je .notOne                   ; if I can sub B1 from A;;;;;; A >= B
                        call2 biSub, r12, r14
                        call2 biSetBit, r15, r13
                    .notOne
                cmp r13, 0
                je .loopBreak
                
                call2 biDivShort, r14, 2           ; B1 /= 2
                dec r13                            ; i --
                jmp .loopStart2 
            .loopBreak

            pop r13

            call1 normalize, r12 ; remainder r
            call1 normalize, r14 ; denomirator b
            call1 normalize, r15 ; quotient c

            ; to the present moment  
            ; r12 contains remainder
            ; r15 contains quotient  if numerator was > 0 and denominor was > 0 

            ; let's start handle COOL cases with sign quotient and remainder 

            call1 biIsZero, r12
            cmp rax, 1
            jne .remNotZero   
                mov r8, r13   ; this case then quotient == 0
                and r8, 1     ; only first bit
                mov r9, r13
                shr r9, 1     ; 010 -> 001
                xor r8, r9    ; 
                mov [r15 + SIGN], r8
 
                jmp .beforeRet
            .remNotZero

            cmp r13, 2
            jne .not10                     ; case then num < 0 and denom > 0 
                call2 biAddShort, r15, 1   ;c + 1
                call1 biChangeSign, r15    ; -c -1
                         
                call2 biSub, r12, r14     ; r - b
                call1 biChangeSign, r12   ; b - r
                jmp .beforeRet
            .not10
          
            cmp r13, 1
            jne .not01                   ; case then num > 0 and denom < 0
                call2 biAddShort, r15, 1 ; c + 1
                call1 biChangeSign, r15  ; - c - 1
                call2 biSub, r12, r14    ; r - b
                jmp .beforeRet
            .not01
       
            cmp r13, 3
            jne .not11 
                call1 biChangeSign, r12 ; -r
            .not11
            .beforeRet

            call1 biDelete, r14

            call1 normalize, r15 ; quotient c
            call1 normalize, r12 ; remainder r

            jmp .notFail
            .fail
                xor r15, r15
                xor r12, r12
            .notFail
                
            pop rsi
            pop rdi

            mov [rdi], r15
            mov [rsi], r12

            pop r15
            pop r14
            pop r13
            pop r12
            ret
    







