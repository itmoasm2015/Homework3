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
	enter 0, 0
	push rbp		; save registers
	push rbx
	push r12
	push r13
	push r14
	push r15
%endmacro

%macro saveOther 0
	push rax
	push rcx
	push rdx
	push rdi
	push rsi
	push r8
	push r9
	push r10
	push r11
%endmacro


%macro returnRegisters 0
	pop r15			; return saved registers on positions
	pop r14
	pop r13
	pop r12
	pop rbx
	pop rbp
	leave
%endmacro

%macro returnOther 0
	pop r11
	pop r10
	pop r9
	pop r8
	pop rsi
	pop rdi
	pop rdx
	pop rcx
	pop rax
%endmacro

; RDI -- size
createNumber:		; create number
	push rdi
	push rsi
	push r9
	push r10
	push r11
	push rcx
	push rbx
	push rdx
	mov r11, rax
	mov rdx, 0
	mov rax, rsp
	mov rcx, 16
	div rcx
	cmp rdx, 0
	jnz .call
	mov rax, r11
	call malloc
	jmp .ok
.call:
	sub rsp, 8
	mov rax, r11
	call malloc
	add rsp, 8
.ok:
	pop rdx
	pop rbx
	pop rcx
	pop r11
	pop r10
	pop r9
	pop rsi
	pop rdi
	ret

; clear memory
callFree:
	saveOther
	mov rax, rsp
	mov rdx, 0
	mov rcx, 16
	div rcx
	cmp rdx, 0
	jnz .call
	call free
	jmp .ok
.call:
	sub rsp, 8
	call free
	add rsp, 8
.ok:
	returnOther
	ret
	

%macro swapNumbers 2		; swap two numbers
	mov [tmp], %1
	mov %1, %2
	mov %2, [tmp]
%endmacro

%macro swapBigInt 2
	push rcx
	push rbx
	push rax
	push rdi
	mov rdi, 32
	call createNumber
	pop rdi
	mov r14, rax
	mov rbx, r14
	mov rcx, %2
	call copyBigInt
	mov rbx, %2
	mov rcx, %1
	call copyBigInt
	mov rbx, %1
	mov rcx, r14
	call copyBigInt	
	pop rax
	pop rbx
	pop rcx
%endmacro

%macro saveSecond 1
	push rdi
	mov rdi, 1
	call biFromInt
	mov %1, rax
	mov rcx, rsi
	mov rbx, %1
	call copyBigInt
	pop rdi
%endmacro

%macro returnSecond 2		; return second number
	push rbx
	push rcx
	push rdi
;	mov rdi, %1
;	call biDelete
	mov rbx, %1
	mov rcx, %2
	call copyBigInt
	pop rdi
	pop rcx
	pop rbx
%endmacro

; RBX -- first to
; RCX -- second from
copyBigInt:		; copy bigInt : sign, digit, size, number
	saveOther
	mov r15, [rcx + bigInt.sign]
	mov [rbx + bigInt.sign], r15
	mov r15, [rcx + bigInt.size]
	mov [rbx + bigInt.size], r15
	mov r15, [rcx + bigInt.digit]
	mov [rbx + bigInt.digit], r15
;	mov r15, [rcx + bigInt.num]
;	mov [rbx + bigInt.num], r15
	mov r15, [rcx + bigInt.size]
	mov rdi, [rbx + bigInt.num]
	imul r15, 8
	push rdi
	mov rdi, r15
	call createNumber
	pop rdi
	mov [rbx + bigInt.num], rax
	mov r9, [rbx + bigInt.num]
	mov r10, [rcx + bigInt.num]
	call callFree
	mov r15, 0
.loop:
	cmp r15, [rcx + bigInt.size]
	jz .end_loop
	mov rax, [r10]
	mov [r9], rax
	add r9, 8
	add r10, 8
	add r15, 1
	jmp .loop
.end_loop:
	returnOther
	ret

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
	push rdi
	mov rdi, 24
	call createNumber 		; create Number, 24 = 3 * 8 = max length of number with BASE = 10^9
	mov rcx, rax
	push rcx
	mov rdi, 32
	call createNumber		; create BigInt, 32 = 4 * 8, we have 4 fields
	pop rcx
	pop rdi
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
	cmp byte[rbx], 0
	jz .fail
	cmp byte[rbx], '-'
	jnz .start_lenn
	add rbx, 1
	cmp byte[rbx], 0
	jz .fail
	add qword[lenn], 1
.start_lenn:		; find count of digits and check right string
	cmp byte[rbx], 0
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
	mov r9, 9 
	mov rdx, 0
	div r9
	add rax, 1
	mov r12, rax
	imul rax, 8
	push rdi
	mov rdi, rax
	call createNumber	; create number, number size = (len / 8 - 1) * 8
	mov rcx, rax
	push rcx
	mov rdi, 32
	call createNumber		; create BigInt structure
	pop rcx
	pop rdi
	mov [rax + bigInt.num], rcx
	mov qword[rax + bigInt.size], r12
	mov r12, [lenn]
	mov qword[rax + bigInt.digit], r12	
	mov qword[rax + bigInt.sign], 1		; define sign of number
	cmp byte[rbx], '-'
	jnz .positive
	mov qword[rax + bigInt.sign], -1
.positive:
	push rax
	mov r13, rcx
	add rbx, qword[lenn]
	mov rcx, 0
	mov rdx, 0	
	mov r11, 0
	mov qword[nzero], 0	; check is number is zero
.loop_parse:
; rbx -- pointet to current string position
; rcx -- current number
; r14 -- current position in current substring
; r12 - cnt
; r11 -- new length
; lenn -- current length
	mov rdx, 9
	cmp qword[lenn], 9
	jge .bl
	mov rdx, qword[lenn]
.bl:
	sub qword[lenn], rdx
	sub rbx, rdx
	mov r14, rbx
	mov r12, rdx
	mov rcx, 0
.block:
	cmp r12, 0
	jz .add_d
	cmp byte[r14], '-'
	jnz .notM
	sub r12, 1
	add r14, 1
	jmp .block
.notM:
	imul rcx, 10
	mov rdx, 0
	mov byte dl, byte[r14]
	sub byte dl, '0'
	add rcx, rdx	; rcx = rcx * 10 + (s[rbx] - '0')
	add r14, 1	; go to next position
	sub r12, 1
	jmp .block
.add_d:
	cmp rcx, 0
	jz .zer
	mov qword[nzero], 1
.zer:
	mov qword[r13], rcx	; write rcx % BASE to [r13], r13 -- pointer to result number 
	add r11, 1
	add r13, 8
	cmp qword[lenn], 0
	jnz .loop_parse		; go to next string number
.end_parse:
	pop rax
	cmp qword[nzero], 0	; if number is zero set sign = 0
	jnz .nzer
	mov qword[rax + bigInt.sign], 0
.nzer:
	mov [rax + bigInt.size], r11
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
	cmp r9, 1
	jle .end_print
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
	mov rbx, qword[lenn]
	add rbx, 1
	cmp rbx, r9
	jge .end_print
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
	push rbx
	call callFree	; free memory of number
	pop rbx
	mov rdi, rbx
	call callFree	; free memory of bigInt structure
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
	saveSecond qword[second]
	cmp qword[rsi + bigInt.sign], 0
	jz .endd
	cmp qword[rdi + bigInt.sign], 0
	jnz .not_zero
	push rcx
	push rbx
	mov rbx, rdi
	mov rcx, rsi
	call copyBigInt
	pop rbx
	pop rcx
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
	push rsi
	swapBigInt rdi, rsi
	jmp .go_sub
.set_positive:
	mov qword[rsi + bigInt.sign], 1	; a + (-b) = a - b, a and b -- absolutely values
	push rsi
.go_sub:
	call biSub
	pop r14
	pop rsi
	pop r9
	mov rsi, r14
	cmp rdi, rsi
	jz .ok
	returnSecond rsi, qword[second]
	jmp .ok
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
	push rdi
	mov rdi, r11
	call createNumber	; create number with size = lenn + 1
	pop rdi
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
	mov rcx, 0
	cmp r12, qword[rsi + bigInt.size]
	jge .ok1
	mov rcx, qword[r9]
.ok1:
	mov [r13], rcx
	mov rcx, 0
	cmp r12, qword[rdi + bigInt.size]
	jge .ok2
	mov rcx, qword[r10]
.ok2:
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
	call callFree	; delete previous number
	call cut_zeros	; delete forward zeros
.endd:
	mov rdi, r9
	mov rsi, r10
	cmp rdi, rsi
	jz .ok
	returnSecond rsi, qword[second]
.ok:
	returnRegisters
	ret

;dst -= src
; RDI = dst
; RSI = src
biSub:
	saveRegisters
	saveSecond qword[ssecond]
	push rdi
	push rsi
	mov qword[minus], 0
	call biCmp	; compare two numbers
	cmp rax, 0	; if first is bigger go to define sign
	jg .agrb
	jz .equ
	swapBigInt rdi, rsi	; else swap numbers
	mov qword[minus], 1
.agrb:
	mov rbx, [rdi + bigInt.sign]
	add rbx, [rsi + bigInt.sign]
	cmp rbx, -2
	jnz .point1
	swapBigInt rdi, rsi	; a <= 0, b <= 0, SWAP????
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
	push rbx
	push rcx
	mov rbx, rdi
	mov rcx, rsi
	call copyBigInt		; a == 0, result = -b 
	pop rcx
	pop rbx
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
	cmp r10, r9
	jz .ok
	returnSecond r9, qword[ssecond]
	jmp .ok
.go_sum:	; go to sum a and b
	push qword[minus]
	call biAdd
	pop qword[minus]
	mov rcx, [rdi + bigInt.sign]
	call negBigInt
	mov rcx, [rdi + bigInt.sign]
	pop r9
	pop r10
	cmp r9, r10
	jz .ok
	returnSecond r9, qword[ssecond]
	jmp .ok
.sub:
	mov r9, qword[rdi + bigInt.num]		; first number a
	mov r10, qword[rsi + bigInt.num]	; second number b
	mov r11, qword[rdi + bigInt.size]	; r11 = size of result number = size a + size b + 1
	mov qword[lenn], r11
	add qword[lenn], 1
	add r11, 1
	shl r11, 3
	push rdi
	mov rdi, r11
	call createNumber	; create result number with size = r11
	pop rdi
	mov r13, rax		; r13 -- pointer to result number
	push r13
	mov r11, 0	; remind
	mov r12, 0	; length
.start_sub:
	cmp r12, qword[lenn]	; if current length == lenn sub is ok
	je .end_sub
	mov rcx, r11
	cmp r12, [rsi + bigInt.size]
	jge .setB
	add rcx, [r10]
.setB:
	mov r11, 0
	mov r15, 0
	cmp r12, [rdi + bigInt.size]
	jge .setA	
	mov r15, qword[r9]
.setA:
	mov qword[r13], r15		; r13[i] = r9[i]
	cmp qword[r13], rcx
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
	call callFree
	mov rcx, [lenn]
	mov [r9 + bigInt.size], rcx	; write new length
	mov rdi, r9
	call negBigInt		; if need result = -result
	call cut_zeros		; cut forwards zeros
	cmp rdi, r10
	jz .ok
	returnSecond r10, qword[ssecond]
	jmp .ok
.equ:		; if a == b then a - b = 0
	pop rsi
	pop rdi
	mov qword[rdi + bigInt.sign], 0
	cmp rdi, rsi
	jz .ok
	returnSecond rsi, qword[ssecond]
.ok:
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
	add qword[lenn], 3
	mov r11, [lenn]		; result size = size of a + size of b + 3
	imul r11, 8
	push rdi
	mov rdi, r11
	call createNumber	; create result number
	pop rdi
	mov r13, rax
	mov r14, 0
.set_zeros:			; set new number = 0
	cmp r14, qword[lenn]
	jz .ok_zeros
	mov qword[rax], 0
	add rax, 8
	add r14,  1
	jmp .set_zeros	
.ok_zeros:
	mov r14, 0 	; current number in a
.loopA:
	cmp r14, [rdi + bigInt.size]	; if cur number in a == size of a then ok mul
	jge .end_mul
	add r14, 1
	mov r11, 0	; remind
	mov r15, 0	; current number in b
.loopB:
	cmp r15, [rsi + bigInt.size]
	jl .go
	cmp r11, 0	; if remind == 0 and cur number in b == size of b then go to next iteration in circle
	je .loopA	
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
	jge .aga
	mov rcx, [r10]	; rcx = r9[aa] * r10[bb]
	imul rcx, [r9]
.aga:
	mov rax, qword[lenn]
	add rcx, qword[r13]
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
	call callFree
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
	saveRegisters
	push rcx
	mov rcx, [lenn]
	mov [r9 + bigInt.size], rcx
	sub rcx, 1
	imul rcx, 8
	add rcx, [r9 + bigInt.num]	; go to last position of r9
	cmp qword[r9 + bigInt.sign], 0
	jz .ok
.cut:
	cmp qword[r9 + bigInt.size], 0
	jz .zz
	cmp qword[rcx], 0	; while (r9[size of r9 - 1] == 0) size of r9 --
	jne .ok
	sub qword[r9 + bigInt.size], 1
	sub rcx, 8
	jmp .cut
.zz:
	mov qword[r9 + bigInt.sign], 0
.ok:
	pop rcx
	returnRegisters
	ret


section .bss
lenn:		resq 1
sum: 		resq 1
tmp:		resq 1
minus:		resq 1
aa:		resq 1
second:		resq 1
ssecond:	resq 1
bb:		resq 1
nzero:		resq 1
