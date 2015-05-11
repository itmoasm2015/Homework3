default rel

%include "ivector.inc"

;;; bigint structure
struc bigint
.sign: resq 1   ; sign of bigint
.vector: resq 1 ; vector, containing elements of 
endstruc

;;; bigint is stored as vector of uint64, no leading zeros are allowed.
;;; Sign of bigint is qword for alignment.

extern malloc
extern printf
extern free

extern vecNew
extern vecAlloc
extern vecFree
extern vecEnsureCapacity
extern vecExtend
extern vecPush
extern vecCopy

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

;;; Internal functions (for debug)
global biUAdd
global biUSub
global biUCmp
global biDump
global biCopy

;;; bigint biAlloc(uint64 length)
;;; Allocates new bigint with specified length (in qwords).
biAlloc:
	enter 8, 0
	
	push rdi
	mov rdi, bigint_size
	call malloc   ; allocate bigint structure
	pop rdi

	test rax, rax
	jz .ret      ; if bigint malloc failed, then return NULL

	push rax
	call vecAlloc ; allocate vector for bigint
	pop rdi

	test rax, rax
	jz .failed      ; if vector malloc failed, then free bigint and return NULL
	
	mov [rdi + bigint.vector], rax

	mov rax, rdi
.ret
	leave
	ret

.failed
	call free
	xor rax, rax
	jmp .ret

;;; bigint biFromInt(uint64 value)
;;; Creates simple bigint, representing value.
biFromInt:
	enter 8, 0
	push rdi
	mov rdi, 1
	call biAlloc
	pop rdi
	test rax, rax
	jz .ret
	
	mov rsi, rdi
	shr rsi, 63     ; remove all bit, excluding sign bit
	mov [rax + bigint.sign], rsi
	
.abs
	neg rdi
	js .abs         ; rdi = abs(rdi)

	mov rdx, [rax + bigint.vector]
	mov rcx, [rdx + vector.data]
	mov [rcx], rdi
	test rdi, rdi
	jne .ret
	dec qword [rdx + vector.size]
.ret
	leave 
	ret

;;; void biDelete(bigint* big)
;;; Deletes allocated bigint, freeing all memory, used by it.
biDelete:
	enter 8, 0
	push rdi
	mov rdi, [rdi + bigint.vector]
	call vecFree
	pop rdi
	call free
	leave
	ret

;;; void biUAddShort(bitint* big, uint64 val)
;;; Adds val to big. Assumes, that val is unsigned.
biUAddShort:
	enter 0, 0
	
	test rsi, rsi
	jz .ret	

	mov rdi, [rdi + bigint.vector]
	mov rcx, [rdi + vector.size]

	test rcx, rcx
	jnz .add       ; if bigint is empty, than just push value to it

	call vecPush
	jmp .ret

.add
	mov r8, [rdi + vector.data]
	mov rdx, [r8]

	add rdx, rsi
	mov [r8], rdx  ; added val to lowest part and set cf

	jnc .ret       ; if cf == 0, then just return

	dec rcx
	jrcxz .done    ; if bigint has not enough space, than let's create new digit
.loop
	add r8, 8
	mov rdx, [r8]  ; get current digit
	add rdx, 1     ; inc doesn't set cf, so let's add 1
	mov [r8], rdx  ; write result

	jnc .ret       ; if cf == 0, then just return

	loop .loop
	; FIXME: IT'S BUGGY, NO?!
.done
	mov rsi, 1     ; if we have cf == 1, then let's push it to the end
	call vecPush 

.ret
	leave
	ret

;;; void biUAdd(bigint* first, bigint* second)
;;; first += second
;;; Ignores signs of bigints.
biUAdd:
	enter 8, 0
	mov r8, rdi
	mov r9, rsi
	
	mov rdi, [rdi + bigint.vector]
	mov rdi, [rdi + vector.size]

	mov rsi, [rsi + bigint.vector]
	mov rsi, [rsi + vector.size]    ; get bigints' sizes

	cmp rdi, rsi
	cmovb rdi, rsi                  ; find maximum length (cmovb - mov if below)

	lahf                            ; store flags in ah

	test rdi, rdi
	jz .ret
	
	sahf                            ; load flags from ah

	mov r10, rdi

	je .equal                       ; no need to expand bigints if their size are equal
	
	mov rsi, rdi
	cmovb rdi, [r8 + bigint.vector]
	cmova rdi, [r9 + bigint.vector] ; load the lowest one vector
	push r8
	push r9
	push r10
	call vecExtend                  ; extend lesser vector's size to greater vector's size
	pop r10
	pop r9
	pop r8

	mov rsi, [r8 + bigint.vector]
	mov [rsi + vector.size], r10    ; first.size = max(first.size, second.size)

.equal
	mov rdi, [r8 + bigint.vector]
	mov rsi, [r9 + bigint.vector]
	mov rdi, [rdi + vector.data]
	mov rsi, [rsi + vector.data]

	xor rcx, rcx                    ; counter of current digit
	xor rax, rax

.loop
	sahf
	mov rax, [rdi + 8 * rcx]
	adc rax, [rsi + 8 * rcx]
	mov [rdi + 8 * rcx], rax
	lahf

	inc rcx
	cmp rcx, r10                     ; r10 contains max(first.size, second.size)

	bt rax, 8
	jnc .ret

	mov rdi, [r8 + bigint.vector]
	mov rsi, 1
	push rdi
	call vecPush
	pop rdi

.ret
	leave
	ret

;;; int biUCmp(bigint* first, bigint* second)
;;; Compares two bigint, ignoring their signs
biUCmp:
	enter 0, 0

	mov rdi, [rdi + bigint.vector]
	mov rsi, [rsi + bigint.vector]  ; load vectors

	mov rax, [rdi + vector.size]
	mov rcx, [rsi + vector.size]    ; and their sizes

	cmp rax, rcx
	je .compare                     ; only equal-sized vectors need to be compared by data

	cmovb rax, [minus_one]
	cmovb rax, [one]

	jmp .ret

.compare
	test rax, rax
	jz .ret          ; if both zeros, than they are equal

	mov rdi, [rdi + vector.data]
	mov rsi, [rsi + vector.data]
	lea rdi, [rdi + rax * 8]
	lea rsi, [rsi + rax * 8]

.loop
	sub rdi, 8
	sub rsi, 8

	mov r8, [rdi]
	mov r9, [rsi]

	cmp r8, r9

	jne .different

	loop .compare   ; rcx contains length, so it's correct

	xor rax, rax
	jmp .ret        ; didn't found different digits, so they are equal

.different
	cmovb rax, [minus_one]
	cmova rax, [one] 

.ret
	leave
	ret

biCmp:
	enter 8, 0

	mov r8, [rdi + bigint.vector]
	mov r9, [rsi + bigint.vector]
	mov rdx, [r8 + vector.size]
	test rdx, rdx
	jnz .nz

	mov rdx, [r9 + vector.size]
	test rdx, rdx
	jnz .nz

	jmp .ret     ; zeros are equal

.nz
	mov rax, [rdi + bigint.sign]
	mov rdx, [rsi + bigint.sign]

	cmp rax, rdx ; compare signs

	je .compare  ; if signs are equal, then we must really compare them

	cmova rax, [minus_one]
	cmovb rax, [one]

	jmp .ret

.compare
	push rdx
	call biUCmp  ; let's compare stupidly
	pop rdx
	mov rdi, rax
	neg rdi      ; negate result if signs are minuses
	test rdx, rdx
	cmovnz rax, rdi

.ret
	leave
	ret


biUSub:
	enter 16, 0   ;; need 8 bytes to save first bigint (to shrink it's size later)
	              ;; but need 8 more bytes for alignment
	mov [rsp], rdi
	mov rdi, [rdi + bigint.vector]
	mov rsi, [rsi + bigint.vector]

	mov r8, rdi
	mov r9, [rsi + vector.size]

	test r9, r9
	jz .ret       ; do not subtract zero

	mov rdi, [rdi + vector.data]
	mov rsi, [rsi + vector.data]

	xor rcx, rcx
	xor rax, rax

.loop
	sahf
	mov rax, [rdi + rcx * 8]
	sbb rax, [rsi + rcx * 8]
	mov [rdi + rcx * 8], rax
	lahf

	inc rcx
	cmp rcx, r9
	jb .loop

	bt rcx, 8
	jnc .shrink

.loop2          ; we have carry and we need to something with it
	mov rax, [rdi + rcx * 8]
	test rax, rax
	jz .continue
	dec rax
	mov [rdi + rcx * 8], rax
	jmp .shrink
.continue
	sub rax, 1
	mov [rdi + rcx * 8], rax
	inc rcx
	jmp .loop2

.shrink
	mov rdi, [rsp]
	call biShrink
.ret
	leave
	ret

;;; void biShrink(bigint* big)
;;; Removes leading zeros from passed bigint.
biShrink:
	enter 0, 0
	
	mov rdi, [rdi + bigint.vector]
	mov rsi, [rdi + vector.data]
	mov rdx, [rdi + vector.size]
	test rdx, rdx
	jz .ret
	
.loop
	mov rax, [rsi + rdx * 8 - 8]
	test rax, rax
	jnz .end

	dec rdx
	test rdx, rdx
	jnz .ret

.end
	mov [rdi + vector.size], rdx
.ret
	leave
	ret

;;; bigint* biCopy(bigint* big)
;;; Copies passed bigint.
biCopy:
	enter 8, 0

	push rdi
	mov rdi, bigint_size
	call malloc
	pop rdi
	mov rdx, [rdi + bigint.sign]
	mov [rax + bigint.sign], rdx
	push rax
	mov rdi, [rdi + bigint.vector]
	call vecCopy
	pop rdi
	mov [rdi + bigint.vector], rax
	mov rax, rdi
	leave
	ret


;;; void biDump(bigint* big)
;;; Prints some information about passed bigint
;;; (used for debug only).
biDump:
	enter 0, 0

	mov r8, [rdi + bigint.vector]
	mov r9, [r8 + vector.data]

	mov rsi, [rdi + bigint.sign]
	mov rdx, [r8 + vector.size]
	mov rcx, [r9]
	mov rdi, qword dump_string
	call printf

	leave
	ret

section .data
minus_one:   dq -1
one:         dq 1
dump_string: db "BigInt: sign is %ld, size is %ld, value is %ld", 10, 0
