section .text

extern malloc
extern free

global biFromInt
global biCopy
global biFromString
global biToString
global biDelete
global biSign
global biAdd
global biSub
global biMul
global biDivRem
global biCmp

;  BigInt:
;
;  int sign
;  int size
;  int64_t* data
;  base is 2^64


; create BigInt from one signed 64-bit integer
; rdi -- BigInt value
biFromInt:
    push rbx
    push rdi
    mov rdi, 16 ; 4 + 4 + 8
    call malloc
    mov rbx, rax
    mov rdi, 8 ; one 8-byte integer
    call malloc
    pop rdi
    
    mov [rbx + 8], rax
    mov rax, rbx
    mov [rax + 4], dword 1
    
    mov [rax], dword 1 ; let's initially sign will be +
    cmp rdi, 0
    jne .isNotZero
    mov [rax], dword 0
    jmp .signReady
.isNotZero
    jnl .signReady
    mov [rax], dword -1
    neg rdi
.signReady
    mov rbx, [rax + 8]
    mov [rbx], rdi

    pop rbx    
    ret


; copy BigInt in rdi
biCopy:
    push rbx

    push rdi
    mov rbx, rdi ; save rdi
    mov rdi, 16 ; 4 + 4 + 8
    call malloc
    mov r8D, [rbx]
    mov [rax], r8D ; sign is copied
    mov r8D, [rbx + 4]
    mov [rax + 4], r8D ; size is copied
    mov rbx, rax ; save pointer to BigInt
    lea rdi, [ebx * 8]
    call malloc
    pop rdi

    mov [rbx + 8], rax
    mov rax, rbx
    mov rdi, [rdi + 8] ; ptr to old data
    mov rsi, [rax + 8] ; ptr to new data

    xor rcx, rcx
    mov ecx, [eax + 4]
    .while
        dec rcx
        mov r8, [rdi + rcx * 8]
        mov [rsi + rcx * 8], r8        
        test rcx, rcx
        jnz .while

    pop rbx
    ret

biFromString:
    ret


biToString:
    ret


; free BigInt
; rdi -- pointer to BigInt
biDelete:
    push rdi
    mov rdi, [rdi + 8]
    call free
    pop rdi
    call free
    ret


biSign:
    xor rax, rax
    mov eax, [rdi]
    ret

biAdd:
    ret

biSub:
    ret

biMul:
    ret

biDivRem:
    ret


; compares 2 BigInt's: rdi, rsi
biCmp:
    mov r8D, [rdi]
    mov r9D, [rsi]
    cmp r8D, r9D
    je .notEqual
    
.notEqual
    mov rax, 0
    ret
