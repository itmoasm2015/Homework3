
; help me find the shift button
; or, better, help me find the strength to press it

default rel

; bigint structure
struc bigint
.sign: resq 1
.vector: resq 1
endstruc

; vector structure copypaste, because includes are not satisfying enough
struc vector
.size: resq 1
.capacity: resq 1
.data_ptr: resq 1
endstruc

; big integers are stored in vectors of qwords
; there never are leading zeroes
; so there are just two ways to store number equal to zero: +0 and -0 with 0 qwords
; while this way to store them might be slightly more annoying than using two's complement,
; it makes many operations simpler
; sign is using up whole qword for alignment purposes
; sign of zero is positive, one is negative

; this code needs more macros

; not a single data segment was used

section .text

extern malloc
extern free
extern abort

extern vectorNew
extern vectorNewSized
extern vectorDelete
extern vectorEnsureCapacity
extern vectorPush
extern vectorZeroExtend
extern vectorRightShift

global biFromInt
global biFromString
global biDelete
global biAdd
global biSub
global biMul
global biCmp
global biSign
global biToString
global biDivRem

;internal functions exposed for testing
global biRawMulShort
global biRawAddShort
global biRawDivRemShort

; biShrink vector temp1 temp2 temp3 label
; reduces vector size so that it contains no loeading zeroes
%macro biShrink 4-5
	mov %2, [%1 + vector.data_ptr]
	mov %3, [%1 + vector.size] ; load data pointer and size
	test %3, %3
	jz .no_shrink%5 ; don't shrink vectors of zero size
	
.shrink_loop%5:
	mov %4, [%2 + %3 * 8 - 8]
	test %4, %4
	jnz .no_shrink%5 ; if last element is not zero, we've had enough
	
	dec %3
	test %3, %3
	jnz .shrink_loop%5 ; if we haven't reached the end of the number, keep on looping
	
.no_shrink%5:
	mov [%1 + vector.size], %3 ; store the new size
%endmacro

; biSwap bigint bigint temp temp
; swaps contents of two given bigints
; pretty straightforward
%macro biSwap 4
	mov %3, [%1 + bigint.sign]
	mov %4, [%2 + bigint.sign]
	
	mov [%1 + bigint.sign], %4
	mov [%2 + bigint.sign], %3
	
	mov %3, [%1 + bigint.vector]
	mov %4, [%2 + bigint.vector]
	
	mov [%1 + bigint.vector], %4
	mov [%2 + bigint.vector], %3
%endmacro

; bigint biAlloc(uint64 len)
; allocates new bigint of specified length
; returns null on allocation failure
biAlloc:
	enter 0, 0
	push r12
	push r13
	mov r12, rdi ; r12: required size
	
	mov rdi, bigint_size
	call malloc ; allocate top-level structure
	
	test rax, rax
	jz .ret ; allocation failure, return null
	
	mov r13, rax ; r13: allocated bigint
	
	mov rdi, r12
	call vectorNewSized ; allocate new vector of specified size
	
	test rax, rax
	jz .no_vec ; go to deallocation of bigint in the event of vector allocation failure
	
	mov [r13 + bigint.vector], rax ; store the vector
	
	mov rax, r13 ; and return begint
	
.ret
	pop r13
	pop r12
	leave
	ret
	
.no_vec: ; this is here because reasons
	mov rdi, r13
	call free ; deallocate bigint
	xor rax, rax ; return null
	jmp .ret

; bigint biFromInt(int64 value)
; creates new bigint with give integral value
; returns null on allocation failure
biFromInt:
	enter 0, 0
	push r12
	push r13
	mov r12, rdi ; r12: required value
	
	mov rdi, 1
	call biAlloc ; allocate bigint if size one
	
	test rax, rax
	jz .ret ; return on allocation failure
	
	mov r13, rax ; r13: allocated bigint
	
	mov rsi, r12
	shr rsi, 63 ; put sign bit into rsi
	
	mov [r13 + bigint.sign], rsi ; store rsi to the field
	
	bt rsi, 0 ; bit test the bit here, CF will be checked later
	
	mov rsi, r12
	mov rax, [r13 + bigint.vector]
	mov rax, [rax + vector.data_ptr] ; take pointer to vector's data (macro this?)
	
	not rsi
	inc rsi ; does not touch CF
	
	cmovc rcx, rsi
	cmovnc  rcx, r12 ; conditionally store either original or negated number (based on CF from bit test)
	
	mov [rax], rcx ; store it into vector
	
	mov rax, r13
	mov r13, [r13 + bigint.vector] ; pull out the vector
	
	biShrink r13, rcx, rdx, r8 ; if it was zero - just shrink it. too lazy to code proper checks.
	
.ret
	pop r13
	pop r12
	leave
	ret

; void biDelete(bigint)
; deallocates bigint, freeing all memory used by it
; calling this on null pointer does nothing
biDelete:
	enter 8, 0 ; 8 bytes of stack alignment
	push r12
	
	test rdi, rdi ; don't do anything to null pointers
	jz .ret
	
	mov r12, rdi ; r12: bigint
	
	mov rdi, [rdi + bigint.vector]
	call vectorDelete ; deallocate vector
	
	mov rdi, r12
	call free ; free bigint itself
	
.ret:
	pop r12
	leave
	ret

; bigint biClone(bigint)
; returns a copy of given big integer
; returns null on allocation failure
biClone:
	enter 0,0
	push r12
	push r13
	
	mov r12, rdi ; r12: original bigint
	mov rdi, [rdi + bigint.vector]
	mov rdi, [rdi + vector.size] ; find out the size of original
	
	call biAlloc ; allocate new bigint with required size
	test rax, rax 
	jz .ret ; return on allocation failure
	
	; copy sign
	mov rdi, [r12 + bigint.sign]
	mov [rax + bigint.sign], rdi
	
	mov r12, [r12 + bigint.vector]
	mov rdx, [rax + bigint.vector] ; extract vectors
	
	mov rcx, [r12 + vector.size]
	mov [rdx + vector.size], rcx ; copy sizes (in case it wasn't). also, put it into rcx for later use
	
	mov rsi, [r12 + vector.data_ptr]
	mov rdi, [rdx + vector.data_ptr] ; prepare for movsq
	
	cld
	rep movsq ; copy the data to new vector
	
.ret:
	pop r13
	pop r12
	leave
	ret


; void biRawAddShort(bigint dst, uint64 value)
; adds the given value to big integer
; the value is considered to be unsigned
biRawAddShort:
	enter 0, 0
	
	test rsi, rsi ; don't do if asked to add a zero
	jz .ret
	
	mov rdi, [rdi + bigint.vector]
	mov rcx, [rdi + vector.size] ; extract vector and size, we're not concerned with the sign
	
	test rcx, rcx
	jnz .not_zero ; if vector is empty, just push the number
	
	call vectorPush
	jmp .ret ; and return
	
.not_zero:
	mov r8, [rdi + vector.data_ptr]
	mov rdx, [r8] ; load the low number
	
	add rdx, rsi
	mov [r8], rdx ; and perform addition
	
	jnc .ret ; if no overflow happened, just return
	
	dec rcx ; this is now a loop counter (was vector size)
	jrcxz .after_loop
.carry_loop:
	add r8, 8
	mov rdx, [r8]
	add rdx, 1
	mov [r8], rdx ; perform addition of ones (carry)
	
	jnc .ret ; if at some point no overflow happened, we are done
	
	loop .carry_loop
	
.after_loop: ; if we ran out of vector size and still have carry, just push it
	mov rsi, 1
	call vectorPush ; rdi is still good since the very start
	
.ret:
	leave
	ret

; void biRawAdd(bigint dst, bigint src)
; perform bigint addition ignoring their signs
biRawAdd:
	enter 8, 0 ; 8 bytes of stack alignment
	push r12
	push r13
	push r14
	
	mov r12, rdi ; r12: destination
	mov r13, rsi ; r13: source
	
	mov rdi, [r12 + bigint.vector]
	mov rdi, [rdi + vector.size]
	
	mov rsi, [r13 + bigint.vector]
	mov rsi, [rsi + vector.size] ; extract sizes
	
	cmp rdi, rsi
	cmovb rdi, rsi ; calculate maximum size
	
	lahf ; store size comparison result - we'll need it later
	
	test rdi, rdi ; if maximum size is zero, no addition must be performed
	jz .ret
	
	sahf ; restore comparison result
	
	mov r14, rdi ; r14: maximum size
	
	je .no_extend ; if the sizes were equal, no extension is required
	mov rsi, rdi ; move required length now
	cmovb rdi, [r12 + bigint.vector] ; and then move one of vectors to be extended
	cmova rdi, [r13 + bigint.vector] ; yes, cmov with memory always reads it, but we'v read it recently anyways
	call vectorZeroExtend ; do the extension of smaller vector
	
	mov rsi, [r12 + bigint.vector]
	mov [rsi + vector.size], r14 ; update the size of result vector
	
.no_extend:
	mov rdi, [r12 + bigint.vector]
	mov rsi, [r13 + bigint.vector]
	mov rdi, [rdi + vector.data_ptr]
	mov rsi, [rsi + vector.data_ptr] ; load data pointers to prepare for addition
	xor rcx, rcx
	xor rax, rax ; this is to make sure sahf at the beginning of loop 'restores' cf to zero
	
.loop:
	sahf ; restore carry
	mov rax, [rdi + rcx * 8]
	adc rax, [rsi + rcx * 8]
	mov [rdi + rcx * 8], rax ; perform addition with carry
	lahf ; save carry
	
	inc rcx
	cmp rcx, r14 ; the loop stuff - increments, comparisons, you know
	jb .loop
	
	bt rax, 8 ; test the stored carry
	jnc .ret ; if no carry was at the end of the loop - we are done
	
	mov rdi, [r12 + bigint.vector]
	mov rsi, 1
	call vectorPush ; otherwise, push the carry int new element of the array
	
.ret:
	pop r14
	pop r13
	pop r12
	leave
	ret

; void biRawSub(bigint dst, bigint src)
; dst = dst - src
; dst.size >= src.size
; |dst| >= |src|
; additionally saves r10, r11
; performs subtraction if big ints ignoring their signs
biRawSub:
	enter 0, 0
	
	mov rdi, [rdi + bigint.vector]
	mov rsi, [rsi + bigint.vector] ; extract the vectors
	
	mov r8, rdi ; save destination to r8
	mov r9, [rsi + vector.size]
	
	test r9, r9 ; if source is zero, nothing has to be done
	jz .ret
	
	mov rdi, [rdi + vector.data_ptr]
	mov rsi, [rsi + vector.data_ptr] ; extract data pointers
	
	xor rcx, rcx
	xor rax, rax ; this is just the addition loop, see comments for addition
.loop:
	sahf
	mov rax, [rdi + rcx * 8]
	sbb rax, [rsi + rcx * 8]
	mov [rdi + rcx * 8], rax
	
	lahf
	
	inc rcx
	cmp rcx, r9
	jb .loop
	
	bt rax, 8 ; test for carry
	jnc .shrinksize ; no carry - no problem
	
	; yes carry - yes problem
.find_nonzero_loop: ; go through number until we find nonzero something
	mov rax, [rdi + rcx * 8] ; if we never find one - it means that given numbers were of improper absolute values
	test rax, rax
	jnz .found_nonzero
	
	sub rax, 1 ; store 0xff..ff to the right place
	mov [rdi + rcx * 8], rax
	inc rcx
	jmp .find_nonzero_loop
	
.found_nonzero:
	dec rax
	mov [rdi + rcx * 8], rax
	
.shrinksize: ; remove leading zeroes
	biShrink r8, rax, rdx, rcx
	
.ret:
	leave
	ret

; void biSub(bigint dst, bigint src)
; performs big integer subtraction
; dst -= src
biSub:
	enter bigint_size, 0 ; allocate size for bigint on stack (and I know that it's 16, so no alignment)
	
	mov rax, [rsi + bigint.sign]
	xor rax, 1
	mov [rsp + bigint.sign], rax ; copy the inverted sign into stack copy
	
	mov rax, [rsi + bigint.vector]
	mov [rsp + bigint.vector], rax ; and copy the original data into stack copy
	
	mov rsi, rsp
	call biAdd ; and just add destination to the stack copy
	
	leave
	ret

; int biRawCmp(bi a, bi b)
; compare two numbers ignoring their sign
; additionally saves rdx, r10, r11
biRawCmp:
	enter 0, 0
	
	mov rdi, [rdi + bigint.vector]
	mov rsi, [rsi + bigint.vector] ; extract vectors
	
	mov rax, [rdi + vector.size]
	mov rcx, [rsi + vector.size] ; and sizes
	
	cmp rax, rcx
	
	je .compare_contents ; if sizes are equal, content comparison is required
	
	mov r8, 1
	mov r9, r8 ; otherwise, just compare sizes
	lahf
	neg r9
	sahf
	cmovb rax, r9
	cmova rax, r8 ; this hack returns -1 or 1 depending on size comparison
	
	jmp .ret ; nothing to do here
	
.compare_contents:
	test rax, rax
	jz .ret ; both lengths are zero, zeroes are equal
	
	mov rdi, [rdi + vector.data_ptr]
	mov rsi, [rsi + vector.data_ptr] ; otherwise, load data pointers to most significant qwords
	lea rdi, [rdi + rax * 8]
	lea rsi, [rsi + rax * 8]
	
.compare_loop:
	sub rdi, 8
	sub rsi, 8
	
	mov r8, [rdi]
	mov r9, [rsi]
	
	cmp r8, r9 ; compare current qwords
	
	jne .found_it ; if they are different - their comparison result is the return value
	
	loop .compare_loop ; otherwise loop
	
	xor rax, rax
	jmp .ret ; no differences found? equal.
	
.found_it:
	mov r8, 1
	mov r9, r8 ; same hack as above
	lahf
	neg r9
	sahf
	cmovb rax, r9
	cmova rax, r8
	
.ret:
	leave
	ret

; int biCmp(bigint a, bigint b)
; compares two big integers
; return -1, 0 or 1 if coparions is <, == or >
biCmp:
	enter 0, 0
	
	mov r8, [rdi + bigint.vector]
	mov r9, [rsi + bigint.vector]
	mov rax, [r8 + vector.size]
	test rax, rax ; check both numbers for zero
	jnz .not_zero
	
	mov rax, [r9 + vector.size]
	test rax, rax
	jnz .not_zero
	
	jmp .ret ; zeros are equal no matter what sign they are
	
.not_zero:
	mov rax, [rdi + bigint.sign]
	mov rdx, [rsi + bigint.sign]
	
	cmp rax, rdx ; compare signs - numbers of different signs compare trivially
	
	je .really_compare
	
	mov r8, 1
	mov r9, r8
	lahf
	neg r9 ; use sign comparion results (see above)
	sahf
	cmova rax, r9
	cmovb rax, r8
	
	jmp .ret
	
.really_compare
	
	call biRawCmp ; use raw comparion
	
	mov rcx, rax
	neg rcx
	test rdx, rdx ; negative numbers compare the other way as their absolute values do
	cmovnz rax, rcx
	
.ret:
	leave
	ret

; void biAdd(bigint dst, bigint src)
; adds two big integers
; dst += src
biAdd:
	enter 0, 0
	
	mov rax, [rdi + bigint.sign]
	mov rdx, [rsi + bigint.sign] ; extract signs
	
	cmp rax, rdx
	jne .different_signs
	
	call biRawAdd ; values of same sign can be added directly via rawAdd
	
	jmp .ret
	
.different_signs: ; oh, the pain
	mov r10, rdi
	mov r11, rsi ; r10 and r11 are saved by biRawCmp
	
	call biRawCmp ; compare the absolute values
	
	cmp rax, 0
	
	jl .very_bad ; if |dst| < |src|, it can't be used in biRawSub and it is indeed very bad
	
	mov rdi, r10
	mov rsi, r11
	call biRawSub ; otherwise, just apply some rawSub
	
	jmp .ret
	
.very_bad ; oh, the copy-pain
	
	push r10
	push r11
	mov rdi, r11
	call biClone ; copy source value
	pop r11
	pop r10
	
	test rax, rax
	jz abort ; failed to allocate memory, nowhere to run
	
	mov rdi, rax
	mov rsi, r10
	mov r11, rax
	call biRawSub ; subtract it the other way (src_copy -= dst)
	
	biSwap r10, r11, rdi, rsi ; swap src_copy and dst
	
	mov rdi, r11
	call biDelete ; free the unused copy (actually old destination)
	
.ret:
	leave
	ret

; void biRawMulShort(bigint dst, uint64 src)
; additionally saves r11
; multiplies big integer by unsigned short value
biRawMulShort:
	enter 8, 0 ; 8 is an offset for vectorPush alignment down the code
	
	mov rdi, [rdi + bigint.vector]
	mov r10, [rdi + vector.size]
	
	test r10, r10 ; don't bother multiplying zeroes
	jz .ret
	
	mov rcx, r10
	test rsi, rsi ; if multiplying by zero, just wipe with zeroes
	jz .zero_wipe
	
	mov r8, rsi
	
	xor r9, r9 ; r9: carry
	xor rcx, rcx ; rcx: loop counter
	mov rsi, [rdi + vector.data_ptr] ; rsi: data pointer
.mul_loop:
	xor rdx, rdx
	mov rax, [rsi + rcx * 8] ; your average multiplication loop
	
	mul r8
	add rax, r9
	adc rdx, 0 ; rdx is guaranteed to have one free bit for the carry (because 0xff...ff^2 < 0xff......ff)
	mov r9, rdx
	
	mov [rsi + rcx * 8], rax ; store the result
	
	inc rcx
	cmp rcx, r10
	jb .mul_loop
	
	test r9, r9 ; check for carry
	jz .ret ; no carry - no problem
	
	mov rsi, r9
	push r11 ; otherwise, push the carry
	call vectorPush
	pop r11
	
	jmp .ret
	
.zero_wipe:
	mov rsi, rdi
	mov rdi, [rdi + vector.data_ptr]
	xor rax, rax
	
	cld
	rep stosq
	
	mov qword [rsi + vector.size], 0
	
.ret:
	leave
	ret

; void biRawMul(bigint dst, bigint src)
; multiplies big integers ignoring theirs signs
; uses primitive multiplication via sum
; runs in O(nm) time, where n is size of dst, and m is size of src in qwords
biRawMul:
	enter 8, 0 ; 8 bytes of stack alignment
	push r12
	push r13
	push r14
	push r15
	push rbx
	
	mov rsi, [rsi + bigint.vector] ; extract the vector immediately, we don't care about sign
	
	mov r12, rdi ; r12: destination
	mov r13, rsi ; r13: source
	
	call biClone
	test rax, rax
	jz abort ; failed copy leads to failed program
	
	mov r14, rax ; r14: destination copy
	
	; zero out destination, we will use it as sum accumulator
	mov rdi, [r12 + bigint.vector]
	mov rcx, [rdi + vector.size]
	mov qword [rdi + vector.size], 0
	mov rdi, [rdi + vector.data_ptr]
	xor rax, rax
	
	cld
	rep stosq
	
	mov r15, [r13 + vector.size] ; r15: source length
	mov r13, [r13 + vector.data_ptr] ; r13: source data
	
	test r15, r15
	jz .free_ret ; return immediately on zero src (we just wiped dst with zeroes)
	
.mul_loop:
	dec r15
	
	mov rdi, r14
	call biClone ; copy the copy of destination
	test rax, rax
	jz abort
	
	mov rbx, rax
	mov rdi, rax
	mov rsi, [r13 + r15 * 8]
	call biRawMulShort ; multiply destination by some qword from source
	
	mov rdi, [rbx + bigint.vector]
	mov rsi, r15 ; shift multiplication result to it's place (remember long multiplication on paper)
	call vectorRightShift ; shifts data right, number left
	
	mov rdi, r12
	mov rsi, rbx
	call biRawAdd ; add shifted multiplication result to accumulator
	
	mov rdi, rbx
	call biDelete ; free the copy
	
	test r15, r15
	jnz .mul_loop
	
.free_ret:
	mov rdi, r14
	call biDelete ; and free the first copy
	
	pop rbx
	pop r15
	pop r14
	pop r13
	pop r12
	leave
	ret


; void biMul(bigint dst, bigint src)
; multiplies two big integers
; dst *= src
biMul:
	enter 0, 0
	push r12
	push r13
	
	mov rax, [rdi + bigint.sign]
	xor rax, [rsi + bigint.sign]
	mov [rdi + bigint.sign], rax ; new sign is xor of original signs
	
	xor r12, r12
	cmp rdi, rsi ; compare the numbers
	jne .skip_copy ; biRawMul doesn't like when dst and src are the same number - it just breaks
	
	mov r12, rdi ; r12: destination
	mov r13, rsi ; r13: source
	mov rdi, rsi
	call biClone ; so this area copies source
	test rax, rax
	jz abort
	
	mov rdi, r12 ; and stores source to r12
	mov rsi, rax
	mov r12, rax
	
.skip_copy:
	call biRawMul ; just multiply them
	
	test r12, r12 ; if no copying was performed, we are done
	jz .ret
	
	mov rdi, r12
	call biDelete ; otherwise free the copy
	
.ret:
	pop r13
	pop r12
	leave
	ret

; bigint biFromString(char*)
; creates new big integer from string representation
; returns null on malformed string or initial allocation failure
; call abort on intermediate allocation failure
biFromString:
	enter 0, 0
	push r12
	push r13
	
	xor rax, rax
	test rdi, rdi ; if string pointer is null, return immediately
	jz .ret
	
	mov r12, rdi ; r12: original pointer
	
	xor rdi, rdi
	call biFromInt ; allocate new zero
	
	test rax, rax ; return on allocation failure
	jz .ret
	
	mov r13, rax ; r13: allocated bigint
	
	xor rax, rax
	mov r11b, byte [r12]
	test r11b, r11b
	jz .destroy_and_ret ; empty string is invalid
	
	cmp r11b, '-'
	jne .number_loop ; check for first minus sign
	
	mov qword [r13 + bigint.sign], 1
	inc r12
	
	mov al, byte [r12]
	test al, al
	jz .destroy_and_ret ; '-' is an invalid number
	
.number_loop: ; parsing loop
	xor r11, r11
	mov r11b, byte [r12]
	test r11b, r11b
	jz .ret_value ; return the result on string end
	
	cmp r11b, '0'
	jb .destroy_and_ret ; charactes < '0' and > '9' are illegal
	
	cmp r11b, '9'
	ja .destroy_and_ret
	
	mov rdi, r13
	mov rsi, 10
	call biRawMulShort ; multiply current number by 10 (biRawMulShort saves r11)
	
	sub r11b, '0' ; and add the next digit
	mov rsi, r11
	mov rdi, r13
	call biRawAddShort
	
	inc r12
	
	jmp .number_loop
	
.destroy_and_ret:
	mov rdi, r13
	call biDelete ; delete allocated bigint in the event of some failure
	xor rax, rax
	
	jmp .ret
	
.ret_value:
	mov rax, r13 ; or return the parsed number
	
.ret:
	pop r13
	pop r12
	leave
	ret

; int biSign(bigint)
; returns the sign of big integer
; -1, 0 or 1
biSign:
	enter 0, 0
	
	mov rax, [rdi + bigint.vector]
	mov rcx, [rax + vector.size]
	xor rax, rax ; check for zero
	test rcx, rcx
	jz .ret
	
	mov rax, [rdi + bigint.sign]
	shl rax, 1 ; a bot of arithmetic magic on sign (return -(sign * 2 - 1))
	dec rax
	neg rax
	
.ret:
	leave
	ret

; uint64_t biRawDivRemShort(bi dst, uint64)
; additionally saves r10 and r11
; divides big integer by unsigned int64
; modifies dst
; returns remainder
biRawDivRemShort:
	enter 0, 0
	
	mov rdi, [rdi + bigint.vector]
	mov rcx, [rdi + vector.size] ; extract vector and size
	
	xor rax, rax
	
	test rcx, rcx ; do nothing with zeroes (return 0)
	jz .ret
	
	xor rdx, rdx ; zero out carry
	
	mov r8, rdi
	mov rdi, [rdi + vector.data_ptr] ; extract data pointer
	
.div_loop:
	mov rax, [rdi + rcx * 8 - 8]
	div rsi ; your average division loop. rdx is carry from previous iteration
	
	mov [rdi + rcx * 8 - 8], rax
	
	loop .div_loop
	
	biShrink r8, rax, rcx, r9 ; get rid of extra zeroes
	
	mov rax, rdx ; return last carry
	
.ret
	leave
	ret

; void biToString(bi, char* buf, uint64 limit)
; converts big integer to string, stores it in buffer, writes no more than limit characters
; requires lots of free memory to write full number into it
biToString:
	enter 0, 0
	push r12
	push r13
	push r14
	push r15
	
	; rdi: bigint
	; rsi: buffer
	; rdx : limit
	
	test rdx, rdx ; do nothing if limit == 0
	jz .ret
	
	xor rax, rax
	
	cmp rdx, 1 ; if limit == 1, only \0 fits
	jne .have_space
	
	mov byte [rsi], byte 0
	jmp .ret
	
.have_space:
	dec rdx ; zero char
	
	mov r12, rdi ; r12: source
	mov r13, rsi ; r13: destination string
	mov r14, rdx ; r14: limit remaining
	
	mov rax, [rdi + bigint.vector]
	mov rax, [rax + vector.size]
	test rax, rax ; check for zero
	jnz .not_zero
	
	mov byte [rsi], '0'
	inc rsi ; just write zero and forget about it
	mov byte [rsi], 0
	jmp .ret
	
.not_zero:
	mov rcx, [r12 + bigint.sign]
	test rcx, rcx
	jz .no_sign ; check for sign
	
	mov byte [r13], '-' ; write sign
	inc r13
	dec r14
	
.no_sign:
	mov rdi, [r12 + bigint.vector]
	mov rdi, [rdi + vector.size]
	inc rdi
	shl rdi, 5 ; allocate space for 32 * (length in qwords) chars. too lazy to find the exact bound, but 16 is clearly too small.
	
	call malloc
	test rax, rax ; failure is failure
	jz .zero_ret
	
	mov r15, rax ; r15: temporary string buffer
	
	mov rdi, r12
	call biClone ; copy the source bigint for division
	test rax, rax
	jz .free_ret ; allocation failure
	mov r10, rax ; r10: source copy for division
	
	xor r11, r11 ; r11: output counter
	
.division_loop:
	mov rdi, r10
	mov rsi, 10
	call biRawDivRemShort ; your average division loop (this saves r10 and r11)
	
	add rax, '0'
	mov byte [r15 + r11], al ; write remainder
	inc r11
	
	mov rax, [r10 + bigint.vector]
	mov rax, [rax + vector.size]
	test rax, rax ; check if there are more numbers to divide
	jnz .division_loop
	
	mov r12, r11
	mov rdi, r10
	call biDelete ; free the copy
	
	mov rcx, r14
	cmp rcx, r12
	cmova rcx, r12 ; take the minimum of limit and actual length
	
	jrcxz .free_ret
.copy_loop: ; copy and reverse thet much chars from temp to output
	dec r12
	mov al, byte [r15 + r12]
	mov byte [r13], al
	inc r13
	loop .copy_loop
	
.free_ret:
	mov rdi, r15
	call free ; free temp buffer
	
.zero_ret:
	mov byte [r13], byte 0 ; write zero char
	
.ret:
	pop r15
	pop r14
	pop r13
	pop r12
	leave
	ret

; void biRawDivRem(bi* q, bi* r, bi num, bi den)
; performs division of big integers ignoring their signs
; returns largest quotient such that |q|*|den| < |num|,
; and remainder equal to |num| - |q|*|den|
; uses binary search, works in O(mn^2) time, where n is length of num in qwords, and m is length of den in qwords
; results are null on division by zero or allocation failure within this function
; inner allocation failures result in call to abort
; I'd better write this in C, not in asm
biRawDivRem:
	enter 24, 0 ; stack space usage: quotinent ptr, remainder ptr, align/temp
	push r12
	push r13
	push r14
	push r15
	push rbx
	
	mov [rbp - 8], rdi ; store result pointers, we won't need them for almost all function
	mov [rbp - 16], rsi
	
	mov rax, [rcx + bigint.vector]
	mov rax, [rax + vector.size]
	test rax, rax ; check for division by zero
	jnz .not_div_by_zero
	
	jmp .zero_and_ret
	
.not_div_by_zero
	mov r12, rdx ; r12: numerator
	mov r13, rcx ; r13: denominator
	
	mov rdi, r12
	call biClone ; copy the numerator for upper bound
	test rax, rax
	jz .zero_and_ret
	
	mov r14, rax ; r14: binary search upper bound
	mov rdi, r14
	mov rsi, 1
	call biRawAddShort ; increase upper buond a bit so that binary search actually works
	
	xor rdi, rdi
	call biFromInt ; allocate lower bound equal to zero
	test rax, rax
	jz .free_upper_and_ret
	
	mov r15, rax ; r15: binary search lower bound
	
	; binary search predicate: value*denominator <= numerator
	; predicate is true for lower bound, false for upper
.binary_search_loop:
	mov rdi, r14
	call biClone ; copy upper bound into middle point
	test rax, rax
	jz .free_both_and_ret
	mov rbx, rax ; rbx: binary search middle point
	
	mov rdi, rbx
	mov rsi, r15 ; add lower bound to middle point
	call biRawAdd
	
	mov rdi, rbx
	mov rsi, 2
	call biRawDivRemShort ; divide middle point by two so that it's actually middle
	
	mov rdi, rbx
	call biClone ; copy middle point for multiplication
	test rax, rax
	jz .free_with_middle_and_ret
	
	push r14 ; will be reused temporarily
	push r15 ; alignment purposes
	
	mov r14, rax ; r14, temp: multiplication result
	
	mov rdi, r14
	mov rsi, r13
	call biRawMul ; multiply middle point by denominator
	
	mov rdi, r12
	mov rsi, r14
	call biRawCmp ; compare multiplication result with numerator
	
	mov rdi, r14
	mov r14, rax ; store comparison result in r14
	call biDelete ; delete multiplication result
	mov rax, r14 ; and restore comparison result to rax
	
	pop r15
	pop r14 ; restore r14: binsearch upper bound
	
	cmp rax, 0
	jge .not_upper ; binary search comparison
	
	xchg r14, rbx ; new upper bound
	jmp .after_bound_swap
	
.not_upper:
	xchg r15, rbx ; new lower bound
	
.after_bound_swap:
	mov rdi, rbx
	call biDelete ; delete old upper/lower bound
	
	mov rdi, r14
	call biClone ; copy upper bound for subtraction
	test rax, rax
	jz .free_both_and_ret
	
	mov rbx, rax
	mov rdi, rax
	mov rsi, r15
	call biRawSub ; check if bounds are close enough
	
	; following two blocks compare big int to one
	mov rax, [rbx + bigint.vector]
	mov rcx, [rax + vector.size]
	cmp rcx, 1
	jne .search_more 
	
	mov rcx, [rax + vector.data_ptr]
	mov rcx, [rcx]
	cmp rcx, 1
	jne .search_more
	
	; at this point result is found. duh.
	
	mov rdi, r15
	call biClone ; copy lower bound, which is the answer
	test rax, rax
	jz .free_with_middle_and_ret ; it will free rbx and both bounds, just like code below
	
	mov [rbp - 24], rax ; store the copy temporarily
	
	mov rdi, rbx
	call biDelete ; delete bound subtraction result
	
	mov rdi, r14
	call biDelete ; delete upper bound (it has nothing to do with answer)
	
	mov r14, [rbp - 24] ; restore lower bound clone
	mov rdi, r14
	mov rsi, r13
	call biRawMul ; multiply lower bound clone by denominator
	
	mov rdi, r12
	call biClone ; clone the numerator
	test rax, rax
	jz .free_both_and_ret ; will free r14 (temp) and r15 (answer)
	
	mov rbx, rax
	mov rdi, rax
	mov rsi, r14
	call biRawSub ; calculate |num|-|q|*|den|. that's the remainder.
	
	mov rax, [rbp - 8]
	test rax, rax ; make sure we won't write into null pointers
	jz .no_quot
	mov [rax], r15 ; lower bound is the answer (quotient)
	
.no_quot:
	mov rax, [rbp - 16]
	test rax, rax ; also make sure we won't write into null pointers
	jz .no_rem
	mov [rax], rbx
	
.no_rem:
	mov rdi, r14
	call biDelete ; at this point I don't even know what r14 is (copy of answer, actually)
	
	jmp .ret
	
.search_more:
	mov rdi, rbx ; delete some temporary subtraction result
	call biDelete
	
	jmp .binary_search_loop
	
	; there are lots of deallocation variants that make me want to write this in C++ with sweet RAII
.free_with_middle_and_ret:
	mov rdi, rbx
	call biDelete
	
.free_both_and_ret:
	mov rdi, r15
	call biDelete
	
.free_upper_and_ret:
	mov rdi, r14
	call biDelete
	
.zero_and_ret:
	mov rdi, qword [rbp - 8]
	mov rsi, qword [rbp - 16] ; these horrible things indicate failure
	mov qword [rdi], 0
	mov qword [rsi], 0
	
.ret:
	pop rbx
	pop r15
	pop r14
	pop r13
	pop r12
	leave
	ret


; void biDivRem(bigint *q, bigint *r, bigint num, bigint den)
; performs big integer division
; works just as long as biRawDivRem does (O(mn^2))
; read more about it in hw3.pdf
biDivRem:
	enter 16, 0 ; 2 result pointers, we always want them (sadness, slowness)
	push r12
	push r13
	push r14
	push r15
	
	mov r12, rdi
	mov r13, rsi
	mov r14, rdx
	mov r15, rcx ; store all arguments
	
	lea rdi, [rbp - 8]
	lea rsi, [rbp - 16] ; get results into local variables
	
	call biRawDivRem ; do the division
	
	; fixup 1: adjust the signs of results
	mov rax, [r14 + bigint.sign]
	mov rcx, [r15 + bigint.sign]
	
	mov rdx, 1
	xor r8, r8
	cmp rax, rcx
	cmove r9, r8 ; same old boring cmov trick
	cmovne r9, rdx
	
	mov rdi, [rbp - 8]
	mov rsi, [rbp - 16] ; load result pointers
	
	test rdi, rdi
	jz .no_quot ; results may be null
	mov [rdi + bigint.sign], r9 ; store the new and improved sign
	
.no_quot:
	test rsi, rsi
	jz .no_rem ; same as above
	mov [rsi + bigint.sign], r9
	
.no_rem:
	test r12, r12 ; these two blocks write division results into output
	jz .no_quot2
	mov [r12], rdi
	
.no_quot2:
	test r13, r13
	jz .no_rem2
	mov [r13], rsi
	
.no_rem2:
	test rsi, rsi
	jz .ret
	test rdi, rdi
	jz .ret ; check if we have both results
	
	shl rcx, 1
	or rax, rcx ; calculate argument sign bitmask (rcx and rax are still here from above)
	
	jmp [.jumptable + rax * 8] ; welcome to conveyor hell and lazy programmers area
	
	; division results may need adjusting, because biRawDivRem does strange things to them
.jumptable:
	dq .pos_div_pos
	dq .neg_div_pos
	dq .pos_div_neg
	dq .neg_div_neg
	
.neg_div_neg: ; two negatives: just flip remainder sign
	mov qword [rsi + bigint.sign], 1
	jmp .ret
	
.neg_div_pos: ; negative over positive: complex adjustment
	mov rax, [rsi + bigint.vector]
	mov rcx, [rax + vector.size]
	test rcx, rcx
	jz .ret ; don't touch zero remainder
	
	mov rdi, rsi
	mov rsi, r15
	call biAdd ; add denominator to remainder (remainder is negative, denominator is positive, result is positive)
	
	mov rdi, [rbp - 8]
	mov rsi, 1
	call biRawAddShort ; add one to absolute value of quotient (because we moved remainder a bit)
	
	jmp .ret
	
.pos_div_neg: ; positive over negative: almost the same as above, except for sign of remainder
	mov rax, [rsi + bigint.vector]
	mov rcx, [rax + vector.size]
	test rcx, rcx
	jz .ret ; don't touch zero remainder
	
	mov qword [rsi + bigint.sign], 0 ; change sign of remainder (it was negaative) to positive
	
	mov rdi, rsi
	mov rsi, r15
	call biAdd
	
	mov rdi, [rbp - 8]
	mov rsi, 1
	call biRawAddShort
	jmp .ret
	
.pos_div_pos: ; no adjustment required
.ret:
	pop r15
	pop r14
	pop r13
	pop r12
	leave
	ret



