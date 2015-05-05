
extern calloc
extern free

global biFromInt ;done
global biFromString
global biToString

global biDelete
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
%define DEFAULT_VECTOR_SIZE 1
%define BASE 10

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

        mov r12, rdi ; r12 - pointer to BigInt
        mov r14, [rdi + SIZE]  ; current vector size

        cmp r14, [rdi + CAPACITY] 
        jl .withoutReallocation
            mov rdi, [r12 + CAPACITY]
            imul rdi, 2  ; new vector size
            call createVector
            mov r13, rax  ; pointer to new vector
           
            mov rcx, 0    ; loop variable "i" 
            mov rdx, [r12 + CAPACITY] ; n 
            mov rdi, [r12 + POINTER]  ; pointer to old vector 
            .loopStart             

                cmp  rcx, rdx
                je .loopFinish  ; i < n

                    mov rsi, [rdi + rcx * LONG_LONG_SIZE] ; move element from old vector to new
                    mov [r13 + rcx * LONG_LONG_SIZE], rsi

                inc rcx 
                jmp .loopStart 

            .loopFinish

            mov r8, [r12 + CAPACITY]
            imul r8, 2
            mov [r12 + CAPACITY], r8;

        .withoutReallocation 

        mov r8, [r12 + SIZE]
        inc r8
        mov [r12 + SIZE], r8

        pop r14 
        pop r13
        pop r12
        ret


    ;BigInt biFromInt(int64_t x); x = rdi
    biFromInt: 
        push r14
        push r15

        mov r14, rdi ; save value to r14
        mov rdi, STRUCT_SIZE 
        mov rsi, 1
        call calloc  ; create new bigInt
        mov r15, rax ; save pointer to BigInt

        mov rdi, DEFAULT_VECTOR_SIZE
        call createVector       
        mov [r15 + POINTER], rax  ;save pointer to vector into BigInt 
        mov r8, DEFAULT_VECTOR_SIZE
        mov [r15 + CAPACITY], r8 
        mov r8, 1
        mov [r15 + SIZE], r8  ;size := 1

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





        ret

