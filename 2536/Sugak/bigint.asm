default rel

extern calloc
extern free

global biFromInt
global biSign
global biDelete
global biToString
global biFromString
global biCmp
global biAdd
global biSub
global biMul
global biDivRem

section .text

;BigInt is stored as an array of digits in 2^64 numerical system. Zero is represented as an empty array with sign set to 1.
;Sign is either -1 or +1 for negative and positive numbers respectively.
;Length is the amount of digits stored (at some point some of which can be redundant leading zeros).
struc BigInt
sign: 		resq	1
length:		resq 	1
digits: 		resq	1
endstruc

;Macros to push & pop multiple registers at once
%macro MPUSH 1-*
%rep %0
	push %1
%rotate 1
%endrep
%endmacro

%macro MPOP 1-*
%rep %0
%rotate -1
	pop %1
%endrep
%endmacro

;Sets 3rd argument to be maximum of first and second.
%macro max 3
	mov %3, %1
  cmp %2, %1
  cmovg %3, %2
%endmacro

;Copies %3 digits from givien array to RAX, size of space allocated for RAX is equal to %2 qwrods
%macro biCopy 3
MPUSH rdi, rsi, rdx, rcx, r8, r9
  mov rdi, %2
  mov rsi, 8
  call aligned_calloc
MPOP rdi, rsi, rdx, rcx, r8, r9

MPUSH rdi, rsi, rdx, rcx, r8, r9
  mov rcx, %3
  mov rsi, %1
  mov rdi, rax
  cld
  repnz movsq
MPOP rdi, rsi, rdx, rcx, r8, r9
%endmacro

;Macro to call function with stack aligned by 16 bytes,
%macro aligned 1
aligned_ %+ %1:
  test rsp, 15
  jz .aligned_ %+ %1
  push rdi
  call %1
  pop rdi
  ret
.aligned_ %+ %1
  call %1
  ret
%endmacro

aligned calloc
aligned free

;biFromInt(int_64t num);
;Creates BigInt from 64-bit singed integer
;takes:   RDI - 64 bit integer
;returns: RAX - created BigInt
biFromInt:
  push rdi
  mov rdi, 1
  mov rsi, BigInt_size                  ; allocate struct
  call aligned_calloc
  mov r8, rax

  mov qword [r8 + sign], 1              ; default sign is 1

  pop rdi
  cmp rdi, 0
  je .finish
  jg .positive
  mov qword [r8 + sign], -1             ; change sign is RDI < 0
  neg rdi

.positive:
  push rdi
  mov rdi, 1
  mov rsi, 8
  push r8
  call aligned_calloc                   ; allocate 1 digit
  pop r8
  mov qword [r8 + length], 1            ; set legnth  to 1
  pop rdi
  mov [rax], rdi
  mov [r8 + digits], rax                ; set R8.digits to newly allocated array (RAX)

.finish:
  mov rax, r8
  ret

;Returns buffer containing string representation of given BigInt,
;this function is guaranteed to write no more than limit chars to buffer.
;void biToString(BigInt n, char *buffer, length_t limit);
;takes:   RDI - BIgInt
;   RSI - output buffer
;   RDX - char limit
;returns: ---
biToString:
  enter 0, 0
  MPUSH r11, r12, r14, r15              ; push calee-saved registers

  mov r15, rdi
  mov r9, [rdi + length]                ; allocate space on stack, it will be used for digits processing
  shl r9, 5
  sub rsp, r9

  push rdi
  xor rdi, rdi
  MPUSH rsi, rdx,  r9
  call biFromInt                        ; Create new BigInt(0) to be used for division
  MPOP rsi, rdx, r9
  mov r8, rax
  pop rdi

  mov rcx, [rdi + length]               ; Copy length of initial BigInt, set sign to 1
  mov [r8 + length], rcx
  mov qword [r8 + sign], 1

  biCopy [rdi + digits], rcx, rcx       ; R8 is now a positive copy of initial BigInt
  mov [r8 + digits], rax

  mov r12, rbp                          ; R12 is used for adressing number on stack
  xor r11, r11                          ; Intermidiate
  xor rcx, rcx                          ; Amount of decimal digits processed.

.div_loop:
  MPUSH rdi, rsi, rdx, rcx, r8, r12, r11
  mov rdi, r8
  mov rsi, 10
  call biDivShort                       ; Divide copied BigInt by 10 to get next decimal digit
  MPOP rdi, rsi, rdx, rcx, r8, r12, r11
  mov r11, rax                          ; RAX <-  integer representation current decimal digit

  add r11, '0'                          ; RAX <- actual ASCII number
  dec r12
  mov byte [r12], r11b                  ; put current digit on stack
  inc rcx                               ; move pointer to prepare for next digit placement

  mov r14, [r8 + length]                ; if length is zero, we need to stop dividing
  test r14,  r14
  jne .div_loop

  cmp qword [rdi + sign], -1
  jne .reverse_loop

  cmp rdx, 1                            ; if remaining limit is 1 or less we need to stop adding digits and proceeed to reverse
  jle .reverse_loop

  mov byte [rsi], '-'                   ; put '-' to buffer and increase beginning pointer
  inc rsi
  dec rdx

.reverse_loop:
  MPUSH rdi, rsi                        ; simply reverse the number on stack and put it into output buffer
  mov rdi, rsi
  mov rsi, r12
  cld
  repnz movsb
  mov byte [rdi], 0                     ; put terminating null at the end
  MPOP rdi, rsi

.finish:
  MPOP r11, r12, r14, r15               ; pop calee-saved registers
  leave
  ret

;Sums up given BigInt with 64-bit unsinged integer
;takes:   RDI - BigInt
;   RSI - uint64_t
;returns: ---
biAddShort:
  push rdi
  mov     r10, [rdi + digits]
  mov     rcx, [rdi + length]

  test     rcx, rcx                     ; if length != 0 proceed to add, else allocate one digit
  jne     .pre_loop

  MPUSH rsi, rdi
  mov rdi, 1
  mov rsi, 8                            ; allocate one digit
  call aligned_calloc
  MPOP rsi, rdi

  mov     [rax], rsi
  mov     [rdi + digits], rax           ; fill it with RSI

  mov     qword [rdi + length], 1
  mov     qword [rdi + sign], 1         ; 1 since it is only used with positive integers

  jmp     .finish

.pre_loop:
  xor     r8, r8                        ; R8 - last iteration carry
.add_loop:
  add     [r10], rsi
  adc     r8, 0                         ; R8 += carry

  mov     rsi, r8                       ; RSI - current iteration carry
  xor     r8, r8

  add     r10, 8                        ; move result pointer
  loop .add_loop

.post_loop:
  test     rsi, rsi                     ; if carry == 0 - finish
  je      .finish

MPUSH rdi, rsi
  mov     r11, [rdi + length]

  inc     r11

  mov     r8, [rdi + digits]
  mov     rcx, [rdi + length]
  biCopy r8,  r11, rcx                  ; allocate one empty digit, and copy rest from result

  MPOP rdi, rsi

  MPUSH r11, rsi, rdi, rax
  mov     rdi, [rdi + digits]
  call    aligned_free                  ; deallocate old digits
  MPOP r11, rsi, rdi, rax

  mov     [rdi + digits], rax           ; update digits
  mov     r11, [rdi + length]

  inc     r11                           ; increase length

  mov     [rdi + length], r11
  mov     r10, [rdi + digits]
  mov     [r10 + r11 * 8 - 8], rsi      ; move carry to last digit

.finish:
  pop rdi
  ret

;Divides given BigInt by 64-bit integer
;takes:   RDI - BigInt
;   RSI - uint64_t
;returns: RAX - remainder
biDivShort:
  xor rax, rax
  mov r11, [rdi + length]
  cmp  r11, 0                           ; handle the 0 / anything case
  je .finish

  mov r8, [rdi + digits]
  mov rcx, [rdi + length]

.div_loop:
  mov rdx, rax                          ;Move last iteration  remainder to RDX
  mov rax, [r8 + rcx * 8 - 8]           ;move currently processed digit to RAX
  div rsi                               ;RDX:RAX /  RSI => (RAX, RDX) = (Quotient, Remainder)
  mov [r8 + rcx * 8 - 8], rax           ;Put the quotient to the digits array
  mov rax, rdx                          ;Move remainder to RDX
  xor rdx, rdx
  loop .div_loop
  push rax
  call biNormalize                      ;get rid of possible leading zeros
  pop rax

.finish:
  ret

;Multiplies given BigInt by 64-bit unsigned integer
;takes:   RDI - BigInt
;   RSI - uint64_t
;returns: ---
biMulShort:
  mov     rcx, [rdi + length]
  mov     r10, [rdi + digits]

  test     rcx, rcx                     ;if BigInt == 0 => result = 0
  je      .finish

  test     rsi, rsi                     ;same goes for uint64_t (RSI)
  jne     .pre_mul_loop

  push    rdi
  mov     rdi, [rdi + digits]
  call aligned_free                     ;deallocate old digits
  pop     rdi
  mov     qword [rdi + digits], 0       ;set filed accordingly
  mov     qword [rdi + length], 0
  mov     qword [rdi + sign], 1
  jmp     .finish

.pre_mul_loop:
  xor     r9, r9                        ;R9 <- carry
.mul_loop:
  mov     rax, [r10]                    ;load digit
  mul     rsi                           ;RAX *= RSI
  add     rax, r9                       ;RAX += carry
  adc     rdx, 0                        ;RDX <- new carry
  mov     [r10], rax                    ;Load new digit
  add     r10, 8                        ;move pointer
  mov     r9, rdx                       ;update carry
  loop .mul_loop

.endloop:
  test     r9, r9                       ;if carry == 0 finish
  je      .finish

  MPUSH r8, r9, r10

  mov     rax, [rdi + length]
  inc     rax
  mov     rsi, [rdi + digits]
  mov     rcx, [rdi + length]
  biCopy rsi, rax, rcx                  ;else copy old digits and allocate one extra fo carry

  MPOP r8, r9, r10

  MPUSH r8, r9, rax, r10, rdi
  mov     rdi, [rdi + digits]
  call    aligned_free                  ;deallocate old digits
  MPOP r8, r9, rax, r10, rdi

  mov     [rdi + digits], rax           ;update digits
  mov     rax, [rdi + length]
  inc  rax                              ;increase length by one
  mov     [rdi + length], rax
  mov     r10, [rdi + digits]
  mov     [r10 + rax * 8 - 8], r9       ;move carry to the oldest digit

.finish:
  ret

;BigInt biFromString(const char* s);
;Creates BigInt from its string representation, string must be a valid long number.
;takes:   RDI - string
;returns: RAX - created BigInt or nullptr if string is invalid
biFromString:
  push rdi
  xor rdi, rdi
  call biFromInt                        ;Create new BigInt - to hold result
  mov r8, rax
  pop rdi

  mov r9, 1                             ;R9 <- sign
  mov al, byte [rdi]
  cmp al, '-'                           ;parse sign
  jne .prepare_parse
  inc rdi
  mov r9, -1                            ;update sign

.prepare_parse:
  mov rsi, rdi
  xor rcx, rcx                          ;RCX <- digits read
  xor rax, rax                          ;loaded bytes holder

  .parse_loop:
  lodsb                                 ;load next byte
  cmp al, 0
  je .post_loop

  cmp     byte al, '0'                  ;check if the byte is valid digit
  jl      .invalid
  cmp     byte al, '9'
  jg      .invalid

  sub rax, '0'                          ;get actual integer instead of ASCII character
  inc rcx

  MPUSH rax, rsi, rcx, r8, r9, rdi
  mov rdi, r8
  mov rsi, 10
  call biMulShort                       ;result *= 10
  MPOP rax, rsi, rcx, r8, r9, rdi

  MPUSH rax, rsi, rcx, r8, r9, rdi
  mov rdi, r8
  mov rsi, rax
  call biAddShort                       ;result += digit
  MPOP rax, rsi, rcx, r8, r9, rdi
  jmp .parse_loop

  test rcx, rcx                         ;if no digits were read, abort
  je .invalid
  jmp .finish

.post_loop:
  test rcx, rcx
  jne .finish

.invalid:
  mov rdi, r8
  call biDelete                         ;delete what was allocated
  xor rax, rax
  ret

.finish:
  mov rax, r8
  mov [rax + sign], r9                  ;update sign
  push rax
  mov rdi, rax
  call biNormalize                      ;remove redundat zeros, if any
  mov rax, rdi
  pop rax
  ret


;Trims leading zeros from BigInt,  turning it into normal form, where all digits are significant, i.e. != 0.
;takes:   RDI - BigInt
;returns: ---
biNormalize:
  mov     rcx, [rdi + length]
  mov     r8, [rdi + digits]

.get_length:                            ;going from most significant digit reduce rcx, if the digits is zero
  test     rcx, rcx
  je      .get_length_finished

  mov     r9, [r8 + rcx * 8 - 8]
  test     r9, r9
  jne     .get_length_finished

  loop .get_length

.get_length_finished:
  mov     r10, [rdi + length]
  cmp     rcx, r10                      ;if no redundant zeros were found - return
  je      .return

  test     rcx, rcx
  je      .aligned_free


  biCopy r8, rcx,  rcx


.aligned_free:
  MPUSH rax, rcx, rdi
  mov     rdi, r8
  call    aligned_free
  MPOP rax, rcx, rdi

  mov     [rdi + digits], rax
  mov     [rdi + length], rcx

  test    rcx, rcx
  jne     .return
  mov     qword [rdi + sign], 1

.return:
  ret

;Deletes BigInt object deallocating used memory.
;void biDelete(BigInt n);
;takes:   RDI - BigInt
;returns: ---
biDelete:
  push rdi
  mov r8, [rdi + length]                ;deallocate digits if not null
  test r8, r8
  je .aligned_free_struct

  mov rdi, [rdi + digits]
  call aligned_free

.aligned_free_struct:
  pop rdi
  call aligned_free                     ;deallocate struct
  ret

;Returns sign of BigInt defined as follows: -1 for negative numbers, 1 for positive and 0 for zero.
;int biSign(BigInt n);
;takes:   RDI - BigInt
;returns: RAX - sign
biSign:
  mov r8, [rdi + length]
  test r8, r8                           ;if length == 0 => BigInt == 0 => sing  = 0
  je .is_zero

  mov rax, [rdi + sign]                 ;nonzero BigInt => simply load corresponding struct field
  ret

.is_zero:
  xor rax, rax
  ret

;Compares two BigInts of equal length as if they both are positive
;takes:   RDI - first BigInt
;   RSI - second BigInt
;returns: RAX - comparison result (-1, 0, 1)
biCompareUnsigned:
  mov rcx, [rdi + length]
  mov r8, [rdi + digits]
  mov r9, [rsi + digits]

.comparison_loop:
  mov r10, [r8 + rcx * 8 - 8]           ;load most significant digits from each vector and compare them
  mov r11, [r9 + rcx * 8 - 8]           ;since we assume length is the same this is enough
  cmp r10, r11
  ja .greater
  jb .less
  loop .comparison_loop

.equal:
  xor rax, rax
  ret

.greater:
  mov rax, 1
  ret

.less:
  mov rax, -1
  ret

;Compares two arbitrary BigInts.
;int biCmp(BigInt lhs, BigInt rhs);
;takes:   RDI - lhs
;   RSI - rhs
;returns: RAX - (-1, 0, 1) - comparison result
biCmp:
  push r14
  mov r14, 1
  mov r8, [rdi + sign]
  mov r9, [rsi + sign]
  cmp r8, r9
  jne .different_signs

  mov r8, [rdi + length]                ;signs are the same compare lengths
  mov r9, [rsi + length]
  mov r14, [rdi + sign]
  cmp r8, r9
  jl .less
  jg .greater

  test r8, r8                           ;rhs == lhs == 0
  jne .compare_digits
  pop r14
  xor rax, rax
  ret

.compare_digits:
  call biCompareUnsigned                ;lengths are the same too, compare digits via biCompareUnsigned
  imul rax, r14
  pop r14
  ret

.different_signs:
  cmp r8, 1                             ;lhs sign == 1 => rhs sign == -1 | 0 => result = 1 else result == -1
  jl .less
  jmp .greater

.greater:
  mov rax, 1                            ;if lhs.length > rhs.length lhs is bigger only if it is positive and less otherwise
  imul rax, r14
  pop r14
  ret

.less:
  mov rax, -1                           ;if lhs.lengh < rhs.length lhs is bigger only if it is negative
  imul rax, r14
  pop r14
  ret

;Sums two BigInts as if they are both positive
;takes:   RDI - lhs
;   RSI - rhs
;returns: RAX - vector of sum's digits
;   RCX - RAX length
biAddUnsigned:
  MPUSH rdi, rsi, r12, r13

  mov r8, [rdi + length]
  mov r9, [rsi + length]

  mov rdi, [rdi + digits]
  mov rsi, [rsi + digits]

  max r8, r9, rcx
  inc rcx                               ;we need to allocate max(lhs.length + rhs.length) + 1 for resulting array
            	                          ;since sum of digits can overflow 2^64 limit
	MPUSH r8, r9, rcx, rdi, rsi
	mov rdi, rcx
	mov rsi, 8
	call aligned_calloc				            ;allocate array fo result
	MPOP r8, r9, rcx, rdi, rsi

	xor r10, r10			                    ;last iteration carry
	xor r11, r11				                  ;current index

.first_array:
	xor r12, r12				                  ;current resulting digit
	xor r13, r13				                  ;current iteration carry

	cmp r11, r8				                    ;if index >= lhs.length try to add digit from rhs
	jge .second_array

	mov r12, [rdi + r11 * 8]		          ;R12 <- current digit from lhs

.second_array:
	cmp r11, r9				                    ;if index >= rhs.length try to add carry
	jge .carry

	add r12, [rsi + r11 * 8]			        ;R12 <- digit from lhs + digit from rhs
	adc r13, 0				                    ;R13 <- carry

.carry:
	adc r12, r10				;
	adc r13, 0
	mov [rax + r11 * 8],  r12
	mov r10, r13

	inc r11
	cmp r11, rcx
	jl .first_array
	jmp .length

.length:
	mov r8, [rax + rcx * 8 - 8]
	test r8, r8
	jne .finish
	dec rcx

.finish;
	MPOP rdi, rsi, r12, r13
	ret

;Subtracts one BigInt from another, as if the both were positive
;takes:		RDI - lhs
;		RSI - rhs
;returns:	RAX - resulting array of digits
;		RCX - length of RAX
;		R8 - resulting sign
biSubUnsigned:
	MPUSH r12, r13, r14, r15
	mov r8, [rdi + length]
	mov r9, [rsi + length]
	cmp r8, r9					                  ;if lengths are the same compare digits
	je .compare

	mov rcx, -1
	cmovl qword rax, rcx
	mov rcx, 1
	cmovg qword rax, rcx
	jmp .end_compare				              ;one array is longer, no need to compare digits, (rax is used to determine resulting sign)

.compare:
	MPUSH rdi, rsi, rcx
	call biCompareUnsigned			          ;compare digits
	MPOP rdi, rsi, rcx

.end_compare;
	push r14
	mov r14, [rdi + sign]

	mov r8, [rdi + length]
	mov r9, [rsi + length]

	MPUSH rdi, rsi, r15
	mov rdi, [rdi + digits]
	mov rsi, [rsi + digits]


	test rax, rax					                ;if arrays are equal return 0
	je .zero

	max r8, r9, rcx
	cmp rax, 1
	cmove rax, r14
	je .pre_sub_loop

.swap:							                    ;for conviniece of use process bigger array first
	imul r14, -1
	mov rax ,r14
	xchg rdi, rsi
	xchg r8, r9
	mov rax, r14

.pre_sub_loop:
	MPUSH r8, r9, rdi, rsi, rcx, rax
	mov rdi, rcx
	mov rsi, 8
	call aligned_calloc				            ;allocate array for result
	mov rdx, rax
	MPOP r8, r9, rdi, rsi, rcx, rax

	xor r10, r10					                ;current index
	xor r11, r11					                ;last iteration borrow

.sub_loop:
	xor r14, r14					                ;current borrow

	mov r12, [rdi + r10 * 8]			        ;R12 <- first array digit
	cmp r10, r9					                  ;check if index < second array length
	jge .sub_borrow_loop

	mov r13, [rsi + r10 * 8]			        ;R13 <- second array digit
	sub r12, r13					                ;R12 -= R13
	adc r14, 0					                  ;R14 <- borrow

.sub_borrow_loop:
	sub r12, r11					                ;R13 -= borrow
	adc r14, 0					                  ;update borrow

	mov [rdx + r10 * 8], r12			        ;load result digit

	mov r11, r14					                ;update last iteration borrow
	inc r10						                    ;increase index

	cmp r10, rcx					                ;check total length against current index, and finish if necessary
	jne .sub_loop
	jmp .finish

.zero:							                    ;return 0
	mov qword r8, 1
	xor rcx, rcx
	xor rax, rax
	MPOP rdi, rsi, r15
	pop r14
	MPOP r12, r13, r14, r15
	ret

.finish:
	mov r8, rax
	mov rax, rdx
	MPOP rdi, rsi, r15
	pop r14
	MPOP r12, r13, r14, r15
	ret


;Sums two BigInts
;void biAdd(BigInt lhs, BigInt rhs);
;takes:		RDI - lhs
;		RSI - rhs
;returns:	---
biAdd:
	mov r8, [rdi + length]
	mov r9, [rsi + length]

	test r9, r9				                    ;If rhs is zero, result == lhs
	je .finish

.nonzero_rhs:
	test r8, r8
	jne .nonzero_lhs

	biCopy [rsi + digits], r9, r9		      ;if lhs is zero, result == rhs, simply copy it's digits and field to rhs

	mov [rdi + digits], rax
	mov r8, [rsi + sign]
	mov [rdi + sign], r8
	mov [rdi + length], r9
	jmp .finish

.nonzero_lhs:					                  ;both lhs and rhs are non null, check signs
	 					                            ; and proceed based on their equality/inequality
	mov r8, [rdi + sign]
	mov r9, [rsi + sign]
	cmp r8, r9
	je .same_sign

.different_sign:					              ;signs are different subtract digits
	call biSubUnsigned
	MPUSH rdi, rsi, rax, rcx, r8
	mov rdi, [rdi + digits]
	call aligned_free			                ;deallocate old digits
	MPOP rdi, rsi, rax, rcx, r8

	mov [rdi + digits], rax			          ;lhs.digits  = result of subtraction
	mov [rdi + length], rcx			          ;size and sign are calculated by biSubUnsigned
	mov [rdi + sign], r8
	jmp .finish

.same_sign:					                    ;signs are the same, call biAddUnsigned
	call biAddUnsigned
	MPUSH rdi, rsi, rax, rcx
	mov rdi, [rdi + digits]
	call aligned_free			                ;deallocate old digits
	MPOP rdi, rsi, rax, rcx
	mov [rdi + digits], rax			          ;set new size and digits
	mov [rdi + length], rcx

.finish:
	call biNormalize				              ;remove posible leading zeros
	ret

;void biSub(BigInt lhs, BigInt rhs);
;Subtracts one BigInt from another
;takes:		RDI - lhs
;		RSI - rhs
;returns:	---
biSub:
	mov r8, [rdi + length]
	mov r9, [rsi + length]

	test r9, r9				                    ;if rhs == 0 => result = lhs
	je .finish

	mov r8, [rsi + sign]
	imul r8, -1				                    ;flip rhs sign
	mov [rsi + sign], r8

	push rsi
	call biAdd 				                    ;biAdd(lhs, -rhs)
	pop rsi

	mov r8, [rsi + sign]
	imul r8, -1				                    ;restore original rhs sign
	mov [rsi + sign], r8

.finish:
	ret

;Multiplies two BigInts as if the both are positive
;takes:		RDI - lhs
;		RSI - rhs
;returns:	RAX - product
;		RCX - product digits' length
biMulUnsigned:
	MPUSH r12, r13, r14, r15
	push rbx
	mov r8, [rdi + length]
	mov r9, [rsi + length]
	mov rcx, r8
	add rcx, r9				                    ;RCX <- lhs.size + rhs.size

	MPUSH rdi, rsi
	mov rdi, [rdi + digits]
	mov rsi, [rsi + digits]


	MPUSH r8, r9, rcx, rdi, rsi
	mov rdi, rcx
	mov rsi, 8
	call aligned_calloc			              ;allocate resulting array with size = lhs.size + rhs.size
	mov rbx, rax
	MPOP r8, r9, rcx, rdi, rsi

	xor r10, r10				                  ;first index (i)

.for_i:
	xor r11, r11				                  ;second index (j)
	xor r12, r12				                  ;last iteration carry

.for_j:
	xor rdx, rdx				                  ;RDX:RAX - current iteration carry
	mov rax, r12
	cmp r11, r9				                    ;if j >= rhs.length update result digit
	jge .put_result

	mov rax, [rdi + r10 * 8]		          ;RAX <- digit from lhs
	mov r14, [rsi + r11 * 8]		          ;R14 <- digit from rhs
	mul r14				                        ;RAX *= R14

	add rax, r12				                  ;RAX += last iteration carry
	adc rdx, 0				                    ;RDC <- new carry

.put_result:
	mov r15, r10				                  ;R15 <- i

	add r15, r11				                  ;R15 <- i + j
	add rax, [rbx+ r15 * 8]
	adc rdx, 0				                    ;update carry

	mov [rbx + r15 * 8], rax		          ;Put RAX to results array
	mov r12, rdx				                  ;Put new carry to R12
	inc r11					                      ;increment second index

	cmp r11, r9				                    ;if second index < rhs.length continue looping
	jl .for_j

	test r12, r12				                  ;if carry is not nill, continue looping
	jne .for_j

	inc r10					                      ;increment first index
	cmp r10, r8				                    ;if first index < lhs.length continue outer loop
	jl .for_i

	mov r8, r10				                    ;R8 <- result size, RAX - contains resulting digits
	add r8, r11
	mov rax, rbx
	MPOP rdi, rsi
	pop rbx
	MPOP r12, r13, r14, r15
	ret

;void biMul(BigInt lhs, BigInt rhs)
;Multiplies two BigInts
;takes:		RDI - lhs
;		RSI - rhs
;returns:	---
biMul:
	mov r8, [rdi + length]
	mov r9, [rsi + length]

	test r9, r9				                    ;rhs == 0 => Set lhs to be zero
	je .zero

	test r8, r8			                    	;lhs == 0 => Nothing needs to be done, return
	jne .non_nil
	ret

.non_nil:
	call biMulUnsigned			              ;Multiply digits
	MPUSH rdi, rsi, rcx, rax
	mov rdi, [rdi + digits]
	call aligned_free			                ;deallocate old lhs.digits
	MPOP rdi, rsi, rcx, rax

	mov [rdi + digits], rax		          	;Set digits to the product of biMulUnsigned
	mov [rdi + length], rcx			          ;length is calculated by biMulUnsigned too
	mov r8, [rdi + sign]
	mov r9, [rsi + sign]
	imul r8, r9				                    ;lhs.sign = lhs.sign * rhs.sign
	mov [rdi + sign], r8
	call biNormalize				              ;remove leading zeros
	ret

.zero:
	test r8, r8
	je .finish
	push rdi
	mov rdi, [rdi + digits]
	call aligned_free			                ;deallocate digits
	pop rdi

	mov qword [rdi + length], 0		        ;set length to 0
	mov qword [rdi + sign], 1		          ;set sign to 1

.finish:
	ret

biDivRem:
	xor rdi, rdi
	xor rsi, rsi
	ret
