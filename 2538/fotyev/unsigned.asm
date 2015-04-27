section .text

global read_long
global write_long
global mul_long_long
global sub_long_long
global add_long_long
global set_zero
global is_zero
global mul_long_short

extern memcpy


;; Arg1 - write to
;; Arg2 - size in qwords
; void set_zero(uint64 * num, uint64 size);
set_zero:
        xor T1, T1
.loop:
        mov [Arg1], T1
        add Arg1, 8
        ;sub Arg2, 1
        dec Arg2
        jnz .loop
        ret


; int is_zero(const uint64 * num, uint64 size)
is_zero:
        mov T1, 0               ;const
        mov ArgR, 0
.loop:
        cmp [Arg1], T1
        jne .done

        add Arg1, 8
        dec Arg2
        jnz .loop

        mov ArgR, 1
.done:
        ret

; uint64 mul_long_short(const uint64 * mul1, uint64 mul2, uint64 size, uint64 * dest)
; returns overflowed value
mul_long_short:
        ;;
        SAVE_REGS 5
        mov R1, Arg1
        mov R2, Arg2
        mov R3, Arg3
        mov R4, 0
        mov R5, Arg4
.loop:
        mov rax, [R1]
        mul R2
        add rax, R4
        adc rdx, 0
        mov [R5], rax
        lea R1, [R1+8] ; mul1++
        lea R5, [R5+8] ; dest++
        mov R4, rdx
        dec R3
        jnz .loop

        mov ArgR, R4
        RESTORE_REGS 5
        ret



; void add_long_short(uint64 * add1, uint64 add2, uint64 size)
add_long_short:
.loop:
        xor T1, T1
        add [Arg1], Arg2
        adc T1, 0
        jz .done
        mov Arg2, T1

        lea Arg1, [Arg1 + 8]    ;add1++
        dec Arg3                ;while(--size)
        jnz .loop
.done:
        ret

;; read long from string
; bool read_long(uint64 * dest, uint64 size, const char * str)
; returns 1 if str is correct, 0 otherwise
read_long:
        ;;
        SAVE_REGS 4
        mov R1, Arg1
        mov R2, Arg2
        mov R3, Arg3
        call set_zero           ; set_zero(dest, size);

        xor ArgR, ArgR
.loop:
        mov byte al, [R3] ; ArgR[0:8] = al

        or ArgR, ArgR           ; ArgR = ArgR
        jz .done                ; \0

        cmp byte al, '9'
        ja .invalid             ; > '9'
        sub ArgR, '0'
        jb .invalid             ; < '0'

        mov R4, ArgR
        ;; mul_long_short(const uint64 * dest, uint64 mul, uint64 size, uint64 * src)
        mov Arg1, R1
        mov Arg2, 10
        mov Arg3, R2
        mov Arg4, R1
        call mul_long_short

        ; add_long_short(dest, *src, size)
        mov Arg1, R1
        mov Arg2, R4
        mov Arg3, R2
        call add_long_short

        inc R3 ; str++
        jmp .loop

.done:
        RESTORE_REGS 4
        mov ArgR, 1 ; return true
        ret
.invalid:
        RESTORE_REGS 4
        mov ArgR, 0 ; return false
        ret


; divides uint64 number by a short
;    Arg1 -- address of dividend (const uint64 *)
;    Arg2 -- divisor (uint64)
;    Arg3 -- length of uint64 number in qwords
;    Arg4 -- destination of quotient (uint64 *)
; result:
;    remainder
; uint64 div_long_short(const uint64 * src, uint64 div, unsigned size, uint64 * dest)
div_long_short:

        SAVE_REGS 2
        ;; the most significant qword first
        lea T1, [Arg1 + 8 * Arg3 - 8] ;src = src + size - 1
        lea T2, [Arg4 + 8 * Arg3 - 8] ;dest = dest + size - 1

        mov R1, Arg2
        mov R2, Arg3
        mov rdx, 0

.loop:
        mov rax, [T1]
        div R1
        mov [T2], rax

        sub T1, 8               ;src--;
        sub T2, 8               ;dest--;
        dec R2
        jnz .loop

        RESTORE_REGS 2
        mov ArgR, rdx
        ret

;; write_long to string
; void write_long(uint64 * num, uint64 size, char * buf, uint64 limit);
write_long:
        ;;
        SAVE_REGS 5
        mov R1, Arg1
        mov R2, Arg2
        mov R3, Arg3
        mov R4, Arg4
        push rbp
        mov rbp, rsp

;; allocate new number
;; rsp -= size * 8
        shl Arg2, 3
;lea rsp, [rsp - 8 * R2]
        sub rsp, Arg2
        mov R5, rsp
        ;; uint64 tmp[size] = R5

; memcpy(tmp, num, size * 8)
        mov Arg3, Arg2
        mov Arg1, R5
        mov Arg2, R1
;align
        and rsp, ~15
        CALL64 memcpy
        mov rsp, R5

.div_loop:
        ;; ArgR = div_long_short(tmp, 10, size, tmp)
        mov Arg1, R5
        mov Arg2, 10
        mov Arg3, R2
        mov Arg4, R5
        call div_long_short

        add ArgR, '0'
;; push character to the stack

;;push ArgR
        dec rsp
        mov byte [rsp], al

        ;; if(is_zero(tmp, size)) break;
        mov Arg1, R5
        mov Arg2, R2
        call is_zero

;cmp ArgR, 0
        test ArgR, ArgR
        jz .div_loop

        ;; output string
        ;; from rsp and up to R5
.output_loop:
;pop Arg1
        mov byte al, [rsp]
        mov byte [R3], al
        dec R4 ; while(--limit)
        jz .stop_outputting

        inc rsp
        inc R3 ; str++

        cmp rsp, R5
        jne .output_loop

.stop_outputting:
        mov byte [R3], 0 ; print '\0'
;; restore stack
        mov rsp, rbp
        pop rbp
        RESTORE_REGS 5
        ret

;;
sub_long_long:                  ; void sub_long_long(const uint64 * num1, const uint64 * num2, uint64 size, uint64 * dest);
        clc                     ;CF=0
.loop:
        mov T1, [Arg1]
        sbb T1, [Arg2]
        mov [Arg4], T1          ;*dest = *num1 - *num2 - CF

        lea Arg1, [Arg1+8]
        lea Arg2, [Arg2+8]
        lea Arg4, [Arg4+8]
        dec Arg3
        jnz .loop
        ;; jc .fail

        ret


; bool add_long_long(const uint64 * num1, const uint64 * num2, uint64 size, uint64 * dest);
; returns 1 on overflow, 0 otherwise
add_long_long:
        clc                     ;CF=0
        xor ArgR, ArgR
.loop:
        mov T1, [Arg1]
        adc T1, [Arg2]
        mov [Arg4], T1          ;*dest = *num1 + *num2 + CF

        lea Arg1, [Arg1+8]
        lea Arg2, [Arg2+8]
        lea Arg4, [Arg4+8]
        dec Arg3 ; CF is not affected
        jnz .loop
        jc .overflow
        ret
.overflow:
        inc ArgR
        ret


mul_long_long: ; void mul_long_long(const uint64 * num1, const uint64 * num2, uint64 size, uint64 * dest)
;; dest should be atleast 2*size and zero
;; dest should not intersect with num1 or num2
;;

        SAVE_REGS 5

        mov R1, Arg1
        mov R2, Arg2
        mov R3, Arg3 ;size (const)
        mov R5, Arg3 ; size(counter)
        mov R4, Arg4            ;dest

; ;; set_zero(dest, size*2)
;       add Arg3, Arg3          ;2*size
;       mov Arg1, R4
;       mov Arg2, Arg3
        ;call set_zero

        lea T1, [R3*8+8]

        push rbp
        mov rbp, rsp            ; old stk
        sub rsp, T1
; uint64 rsp[size+1]

.loop:
        ;;
        ;; mul_long_short(num1, *num2, size, rsp)
        mov Arg1, R1
        mov Arg2, [R2]
        mov Arg3, R3
        mov Arg4, rsp
        call mul_long_short
; write overflow to rsp[size]
        mov [rsp + 8 * R3], ArgR


        ;; add_long_long(dest, rsp, size+1, dest)
        mov Arg1, R4
        mov Arg2, rsp
        mov Arg3, R3
        inc Arg3
        mov Arg4, R4
        call add_long_long

        ;; num2++
        add R2, 8
;; dest++
        add R4, 8

        ;; while(--size)
        dec R5
        jnz .loop


        mov rsp, rbp
        pop rbp
        RESTORE_REGS 5
        ret











