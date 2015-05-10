default rel
extern malloc
extern free

global biFromInt
global biFromString
global biToString
global biDelete
global biSign
global biAdd
global biSub
global biMul
global biDivRem
global biCmp

section .text
; BigInt is a structure, which keep sign, size and pointer to number
; number is a array. We store out number in reverse order
; Radix = BASE, every element in array <= BASE

; should save RBP, RBX, R12-R15

BASE	equ 1000000000

struc bigInt
	.sign:	resq 1		; number sign
	.size:	resq 1		; size of number vector
	.digit:	resq 1		; count of digits
	.num:	resq 1		; pointer to number memory (vector)
endstruc

%macro saveRegisters 0
	push rbp		; save registers
	push rbx
	push r12
	push r13
	push r14
	push r15
%endmacro

%macro returnRegisters 0
	pop r15			; return saved registers on positions
	pop r14
	pop r13
	pop r12
	pop rbx
	pop rbp
%endmacro

%macro createNumber 1		; create number
	mov rdi, %1
	call malloc
%endmacro

%macro swapNumbers 2		; swap two numbers
	mov [tmp], %1
	mov %1, %2
	mov %2, [tmp]
%endmacro

%macro copyBigInt 2		; copy bigInt : sign, digit, size, number
	push r15
	mov r15, [%2 + bigInt.sign]
	mov [%1 + bigInt.sign], r15
	mov r15, [%2 + bigInt.size]
	mov [%1 + bigInt.size], r15
	mov r15, [%2 + bigInt.digit]
	mov [%1 + bigInt.digit], r15
	mov r15, [%2 + bigInt.num]
	mov [%1 + bigInt.num], r15
	pop r15
%endmacro

negBigInt:		; number = -number if minus == 1
	cmp qword[minus], 1
	jnz .neg
	neg qword[rdi + bigInt.sign]
	mov qword[minus], 0
.neg:
	ret


;Create a BigInt from 64-bit signed integer
; RDI -- current number
; RAX -- pointer to result BIgInt
biFromInt:
	saveRegisters
	mov rbx, rdi
	createNumber 24		; create Number, 24 = 3 * 8 = max length of number with BASE = 10^9
	mov rcx, rax
	push rcx
	createNumber 32		; create BigInt, 32 = 4 * 8, we have 4 fields
	pop rcx
	mov [rax + bigInt.num], rcx	; remember pointer to number
	mov qword[rax + bigInt.size], 0
	mov qword[rax + bigInt.sign], 1		; try to determine sign of number rbx
	mov r10, rax
	cmp rbx, 0
	jg .positive
	jl .negative
	mov qword[rax + bigInt.sign], 0
	jmp .en_parse
.negative:
	neg rbx
	mov qword[rax + bigInt.sign], -1
.positive:
	mov rax, rbx	; save rbx in rax
	mov rdx, 0
.st_parse:		; parse number rax, divide it to base while rax != 0
	cmp rax, 0
	jz .en_parse
	mov r9, BASE
	div r9
	mov [rcx], rdx
	add rcx, 8
	add qword[r10 + bigInt.size], 1
	mov rdx, 0
	jmp .st_parse
.en_parse:
	mov rax, r10	; return pointer to BigInt structure
	returnRegisters
	ret

;Create a BigInt from a decimal string representation.
;Returns 0 on incorrect string.
;BigInt biFromString(char const *s);
biFromString:
	saveRegisters
	mov rbx, rdi
	mov qword[lenn], 0
.start_lenn:		; find count of digits and check right string
	cmp byte[rbx], 0	; MINUS!!!
	jz .end_lenn
	cmp byte[rbx], '0'
	jl .fail
	cmp byte[rbx], '9'
	jg .fail
	add qword[lenn], 1
	add rbx, 1	
	jmp .start_lenn
.end_lenn:
	mov rbx, rdi
	mov rax, [lenn]	
	mov r9, 8 
	mov rdx, 0
	div r9
	add rax, 1
	mov r12, rax
	imul rax, 8
	createNumber rax	; create number, number size = (len / 8 - 1) * 8
	mov rcx, rax
	push rcx
	createNumber 32		; create BigInt structure
	pop rcx
	mov [rax + bigInt.num], rcx
	mov qword[rax + bigInt.size], r12
	mov r12, [lenn]
	mov qword[rax + bigInt.digit], r12	
	mov qword[rax + bigInt.sign], 1		; define sign of number
	cmp byte[rbx], '-'
	jnz .positive
	mov qword[rax + bigInt.sign], -1
	add rbx, 1
.positive:
	push rax
	mov r13, rcx
	mov rcx, 0
	mov rdx, 0	
.loop_parse:
; rbx -- pointet to current string position
; rcx -- current number
	cmp byte[rbx], 0
	jz .add_d
	imul rcx, 10
	mov byte dl, byte[rbx]
	sub byte dl, '0'
	add rcx, rdx	; rcx = rcx * 10 + (s[rbx] - '0')
	add rbx, 1	; go to next position
	cmp rcx, BASE	; if rcx >= BASE write it
	jl .loop_parse
.add_d:
	mov [r13], rcx	; write rcx % BASE to [r13], r13 -- pointer to result number 
	add r13, 8
	mov rdx, 0
	mov rax, rcx
	mov r9, BASE
	div r9
	mov rcx, rax
	cmp byte[rbx], 0
	jnz .loop_parse		; go to next string number
.end_parse:
	pop rax
	returnRegisters
	ret
.fail:
	returnRegisters
	mov rax, 0
	ret

;Generate a decimal string representation from a BigInt. Writes at most limit bytes to buffer.
;void biToString(BigInt bi, char *buffer, size_t limit);
; RDI -- poiner to bi
; RSI -- poiner to buffer
; RDX -- limit
biToString:
	saveRegisters
	mov rax, rdi
	mov r9, rdx
	mov qword[lenn], 0
.print_sign:
	cmp qword[rax + bigInt.sign], 1	; define sign and print it
	jz .end_print_sign
	cmp qword[rax + bigInt.sign], -1
	jz .print_minus
	mov byte[rsi], '0'
	add rsi, 1
	add qword[lenn], 1
	jmp .end_print
.print_minus:
	mov byte[rsi], '-'
	add rsi, 1
	add qword[lenn], 1
.end_print_sign:
; R15 -- pointer to end number
; R10 -- length
	mov r10, [rax + bigInt.size]
	mov r15, [rax + bigInt.num]
	mov r11, r10
	sub r11, 1
	imul r11, 8
	add r15, r11
	mov r12, 1000000000
.cut:	; try to delete zeros from begin of number
	mov rax, r12
	mov rdx, 0
	mov r11, 10
	div r11		; divide numbers to 10 ans compare with 0
	mov r12, rax
	mov rax, [r15]
	mov rdx, 0
	div r12
	cmp rax, 0
	jz .cut
.start_print:
	cmp r12, 0
	jnz .set_r
	mov r12, 100000000
.set_r:
	cmp r10, 0	; limit end
	jz .end_print
	sub r10, 1
	mov r11, qword[r15]
	sub r15, 8
	mov rbx, r11
.cur_num:	; take max digit, second max digit etc.
		; print each of them
	cmp r12, 0
	jz .start_print
	mov rdx, 0
	mov rax, rbx
	div r12
	add byte al, '0'
	mov [rsi], byte al
	add qword[lenn], 1
	add rsi, 1
	mov rbx, rdx
	mov rdx, 0
	mov rax, r12
	mov r11, 10
	div r11
	mov r12, rax
	mov rcx, [lenn]
	add rcx, 1
	cmp rcx, r9
	jl .cur_num
.end_print:
	mov byte[rsi], 0	; print end of string
	add rsi, 1
	returnRegisters
	ret

;Destroy a BigInt.
biDelete:
	saveRegisters
	mov rbx, rdi
	mov rdi, [rbx + bigInt.num]
	call free	; free memory of number
	mov rdi, rbx
	call free	; free memory of bigInt structure
	returnRegisters
	ret

;Get sign of given BigInt. 
;return 0 if bi is 0, 1 if bi is positive, -1 if bi is negative.
biSign:
	saveRegisters
	mov rax, [rdi + bigInt.sign]
	returnRegisters
	ret

;dst += src
;void biAdd(BigInt dst, BigInt src);
biAdd:
	saveRegisters
	cmp qword[rsi + bigInt.sign], 0
	jz .endd
	cmp qword[rdi + bigInt.sign], 0
	jnz .not_zero
	copyBigInt rdi, rsi
	jmp .endd
.not_zero:
	push rdi
	push rsi
	mov rbx, [rdi + bigInt.sign]	; compare sign of number
	add rbx, [rsi + bigInt.sign]
	cmp rbx, 0	; if signs are all minus or plus go to sum it
	jnz .sum
	cmp qword[rsi + bigInt.sign], 0
	jl .set_positive
	mov qword[rdi + bigInt.sign], 1	; -a + b = b - a, a and b -- absolutely values
	mov rbx, rsi
	mov rsi, rdi
	mov rdi, rbx
	jmp .go_sub
.set_positive:
	mov qword[rsi + bigInt.sign], 1	; a + (-b) = a - b, a and b -- absolutely values
.go_sub:
	call biSub
	returnRegisters
	ret
.sum:
	mov r9, qword[rsi + bigInt.num]
	mov r10, qword[rdi + bigInt.num]
	mov r11, qword[rsi + bigInt.size]
	mov [lenn], r11		; lenn = max(size of a, size of b)
	mov r11, [rdi + bigInt.size]
	cmp [lenn], r11
	jge .set_len
	mov [lenn], r11
.set_len:
	add qword[lenn], 1
	mov r11, [lenn]
	imul r11, 8
	push r9
	createNumber r11	; create number with size = lenn + 1
	pop r9
	mov r13, rax
	push r13
	mov r11, 0	; remind
	mov r12, 0	; length
.start_sum:
; R9 -- pointer to first number
; R10 -- pointer to second number
; R13 -- pointer to result
	cmp r12, [lenn]
	jz .end_sum
	mov rcx, [r9]
	mov [r13], rcx
	mov rcx, [r10]
	add [r13], rcx	; [r13] = rcx + r11 = [r9] + [r10]
	add [r13], r11
	mov rdx, 0
	mov rax, [r13]
	mov r15, BASE
	div r15
	mov [r13], rdx
	mov r11, rax
	add r12, 1
	add r10, 8
	add r9, 8
	add r13, 8
	jmp .start_sum
.end_sum:
	pop r13 ; new dst 
	pop r10 ; src
	pop r9	; dst
	mov rcx, [r9 + bigInt.num]	; save r13 -- pointer to result
	mov [r9 + bigInt.num], r13
	mov rdi, rcx
	push r9
	call free	; delete previous number
	pop r9
	call cut_zeros	; delete forward zeros
.endd:
	returnRegisters
	ret

;dst -= src
; RDI = dst
; RSI = src
biSub:
	saveRegisters
	push rdi
	push rsi
	mov qword[minus], 0
	call biCmp	; compare two numbers
	cmp rax, 0	; if first is bigger go to define sign
	jge .agrb
	swapNumbers rdi, rsi	; else swap numbers
	mov qword[minus], 1
.agrb:
	mov rbx, [rdi + bigInt.sign]
	add rbx, [rsi + bigInt.sign]
	cmp rbx, -2
	jnz .point1
	swapNumbers rdi, rsi	; a <= 0, b <= 0, SWAP????
	mov qword[rdi + bigInt.sign], 1
	mov qword[rsi + bigInt.sign], 1 ; RSI CHANGE
	jmp .sub
.point1:
	cmp qword[rsi + bigInt.sign], 0
	jnz .point2
	jmp .ret	; b == 0, result = a
.point2:
	cmp qword[rdi + bigInt.sign], 0
	jnz .point3
	copyBigInt rdi, rsi	; a == 0, result = -b 
	neg qword[rdi + bigInt.sign]
	jmp .ret
.point3: 
	cmp rbx, 0
	jnz .point4
	cmp qword[rsi + bigInt.sign], 0
	jg .point35
	mov qword[rsi + bigInt.sign], 1 ; RSI CHANGE result = a - (-b) 
	jmp .go_sum
.point35:	; result = -a - b = - (a + b)
	mov qword[rdi + bigInt.sign], 1
	mov qword[minus], 1
	jmp .go_sum
.point4:	; result = a - b
	jmp .sub
.ret:		; if need a = -a, return
	call negBigInt
	pop r9
	pop r10
	returnRegisters
	ret
.go_sum:	; go to sum a and b
	call biAdd
	call negBigInt
	pop r9
	pop r10
	returnRegisters
	ret
.sub:
	mov r9, qword[rdi + bigInt.num]		; first number a
	mov r10, qword[rsi + bigInt.num]	; second number b
	mov r11, qword[rdi + bigInt.size]	; r11 = size of result number = size a + size b + 1
	mov qword[lenn], r11
	add qword[lenn], 1
	imul r11, 8
	push r9
	push rsi
	createNumber r11	; create result number with size = r11
	pop rsi
	pop r9
	mov r13, rax		; r13 -- pointer to result number
	push r13
	mov r11, 0	; remind
	mov r12, 0	; length
.start_sub:
	cmp r12, [lenn]	; if current length == lenn sub is ok
	jz .end_sub
	mov rcx, r11
	cmp [rsi + bigInt.size], r12
	jle .setB
	add rcx, [r10]
.setB:
	mov r11, 0
	mov r15, [r9]
	mov [r13], r15		; r13[i] = r9[i]
	cmp [r13], rcx
	jge .gr
	add qword[r13], BASE	; if r13[i] < r10[i] then r13[i] += BASE, remind++
	mov r11, 1	
.gr:
	sub [r13], rcx		; r13[i] -= r10[i]
	add r12, 1
	add r10, 8
	add r9, 8
	add r13, 8	
	jmp .start_sub		; go to next number
.end_sub:
	pop r13 ; new dst 
	pop r10 ; src
	pop r9	; dst
	mov rcx, [r9 + bigInt.num]
	mov [r9 + bigInt.num], r13	; write new number
	mov rdi, rcx		; delete previous number
	call free
	mov rcx, [lenn]
	mov [r9 + bigInt.size], rcx	; write new length
	mov rdi, r9
	call negBigInt		; if need result = -result
	call cut_zeros		; cut forwards zeros
	returnRegisters
	ret

;dst *= src
;RDI = dst
;RSI = src
biMul:
	saveRegisters
	cmp qword[rsi + bigInt.sign], 0
	jnz .point1
	mov qword[rdi + bigInt.sign], 0	; if b == 0 result = 0
	returnRegisters
	ret	
.point1:
	cmp qword[rdi + bigInt.sign], 0
	jnz .point2
	returnRegisters		; if a == 0 result = 0
	ret	
.point2:
	cmp qword[rsi + bigInt.sign], -1
	jnz .mul
	neg qword[rdi + bigInt.sign]	; if b < 0 then sign of result = - sign of a
.mul:
	mov r9, [rdi + bigInt.num]	; r9 -- pointer to a
	mov r10, [rsi + bigInt.num]	; r10 -- pointer to b
	mov r11, [rdi + bigInt.size]
	mov [lenn], r11
	mov r11, [rsi + bigInt.size]
	add [lenn], r11
	add qword[lenn], 1
	mov r11, [lenn]		; result size = size of a + size of b + 1
	imul r11, 8
	push rdi
	push r9
	push rsi
	createNumber r11	; create result number
	pop rsi
	pop r9
	pop rdi
	mov r13, rax
	mov r14, 0 	; current number in a
.loopA:
	cmp r14, [rdi + bigInt.size]	; if cur number in a == size of a then ok mul
	jz .end_mul
	add r14, 1
	mov r11, 0	; remind
	mov r15, 0	; current number in b
.loopB:
	cmp r15, [rsi + bigInt.size]
	jl .go
	cmp r11, 0	; if remind == 0 and cur number in b == size of b then go to next iteration in circle
	jz .loopA	
.go:
	push r9
	push r10
	push r13
	mov rcx, r14
	sub rcx, 1
	imul rcx, 8
	mov [aa], rcx
	mov rcx, r15
	imul rcx, 8
	mov [bb], rcx
	add r9, [aa]	; r9[aa] -- a
	add r10, [bb]	; r10[bb] -- b
	add r13, [aa]	; r13[aa + bb] -- result
	add r13, [bb]
	mov rcx, 0
	cmp r15, [rsi + bigInt.size]
	jz .aga
	mov rcx, [r10]	; rcx = r9[aa] * r10[bb]
	imul rcx, [r9]
.aga:
	add rcx, [r13]
	add rcx, r11	; rcx += remind + r13[aa + bb]
	mov rdx, 0
	mov rax, rcx
	mov rcx, BASE
	div rcx		; divide rcx by BASE
	mov [r13], rdx	; write to result rcx % BASE
	mov r11, rax	; write to remind rcx / BASe
	pop r13
	pop r10
	pop r9
	add r15, 1
	jmp .loopB
.end_mul:
	mov rcx, [rdi + bigInt.num]
	mov [rdi + bigInt.num], r13	; save result multiply number
	push rdi
	mov rdi, rcx		; delete previuos number
	call free
	pop rdi
	mov rcx, [lenn]		; save size of result number
	mov [rdi + bigInt.size], rcx
	mov r9, rdi
	call cut_zeros		; cut forward zeros
	returnRegisters
	ret

biDivRem:
	saveRegisters
	returnRegisters
	ret

; Compare two BigInts. 
; returns sign(a - b)
biCmp:
	saveRegisters
	mov r9, [rdi + bigInt.sign]	; compare signs of numbers
	mov r10, [rsi + bigInt.sign]	
	mov rax, -1
	cmp r9, r10	; if sign(a) < sign(b) return -1
	jl .end
	mov rax, 1	; if sign(a) > sign(b) return 1
	jg .end
	mov rax, 0
	cmp r9, 0	; if a == b == 0 return 0
	jz .end
	mov r9, [rdi + bigInt.num]	; pointer to number a
	mov r10, [rsi + bigInt.num]	; pointer to number b
	mov r12, [rdi + bigInt.size]
	mov r13, [rsi + bigInt.size]	
	mov r11, [rdi + bigInt.size]
	mov [lenn], r11
	sub r11, 1
	imul r11, 8
	add r9, r11			; move pointer to last position of number a
	mov r11, [rsi + bigInt.size]
	sub r11, 1
	imul r11, 8
	add r10, r11			; move pointer to last position of number b
	mov r11, [rsi + bigInt.size]
	cmp [lenn], r11
	jge .first
	mov [lenn], r11		; lenn = max(size of a, size of b)
; compate every position by BASE at numbers a and b
.first:
; if size of a < r12 first = a[r12]
; otherwise first = 0
	mov rcx, 0	
	cmp [lenn], r12
	jg .second
	mov rcx, [r9]
	sub r9, 8
	sub r12, 1
.second:
; if size of b < r12 second = b[r12]
; otherwise second = 0
	mov rdx, 0	
	cmp [lenn], r13
	jg .cmp
	mov rdx, [r10]
	sub r10, 8
	sub r13, 1
.cmp:
	sub qword[lenn], 1
	mov rax, 1
	cmp rcx, rdx	; if a[r12] > b[r12] return 1
	jg .end
	mov rax, -1	
	jl .end		; if a[r12] < b[r12] return -1
	mov rax, 0
	cmp qword[lenn], 0	; if lenn == 0 and a[0] == b[0] return 0
	jz .end
	jmp .first		; if lenn != compare previous number
.end:
	mov rcx, [rsi + bigInt.sign]
	add rcx, [rdi + bigInt.sign]
	cmp rcx, -2	; if a < 0 and b < 0 then result = -result
	jnz .end2
	neg rax
.end2:
	returnRegisters
	ret

; Cut zerous at te begin of the number	
; R9 -- pointer to BigInt
cut_zeros:
	push rcx
	mov rcx, [lenn]
	mov [r9 + bigInt.size], rcx
	sub rcx, 1
	imul rcx, 8
	add rcx, [r9 + bigInt.num]	; go to last position of r9
	cmp qword[r9 + bigInt.sign], 0
	jz .ok
.cut:
	cmp qword[rcx], 0	; while (r9[size of r9 - 1] == 0) size of r9 --
	jnz .ok
	sub qword[r9 + bigInt.size], 1
	sub rcx, 8
	jmp .cut
.ok:
	pop rcx
	ret


section .bss
lenn:		resq 1
sum: 		resq 1
tmp:		resq 1
minus:		resq 1
aa:		resq 1
bb: 		resq 1
