
section .text

	
global biFromInt
global biFromString
global biDelete
global biToString
global biSign
global biCmp
global biAdd
global biSub
global biMul
global biDivRem

global normal_size

extern read_long
extern write_long
extern mul_long_long
extern sub_long_long
extern add_long_long
extern set_zero
extern is_zero
extern mul_long_short



extern realloc
extern malloc
extern calloc
extern free
extern strlen
extern exit

struc BigInt
.size: resq 1
.data: resq 1 ; uint64 * data
.sign: resq 1 ; 1 = negative, 0 = positive
endstruc
; Invariants:
; number = (-1)^sign * (data[0] + data[1] * 2^64 + ... + data[size - 1] * (2^64)^(size-1))
; sign == 0 or sign == 1
; Notes:
; data[size-1] might be 0 
; size does not represent capacity of data, capacity is managed implicitly by *alloc family
; if data[size-1] != 0 then number is "normalized", i.e. its size is minimal for this number
;

; allocate_bigint(size_t size)
allocate_bigint:
	push Arg1
	mov Arg1, BigInt_size
	CALL64 malloc
	pop Arg1
	push ArgR
	mov [ArgR + BigInt.size], Arg1
	shl Arg1, 3
	mov Arg2, 1
	CALL64 calloc ; calloc(size * 8, 1)
	pop T1 ; pointer to BigInt
	mov [T1 + BigInt.data], ArgR
	mov qword [T1 + BigInt.sign], 0
	mov ArgR, T1
	ret

; reallocate_bigint(BigInt bi, size_t size)
reallocate_bigint:
	push Arg1
; bi->size = size
	mov [Arg1 + BigInt.size], Arg2
; bi->data = realloc(bi->data, size * 8)
	mov Arg1, [Arg1 + BigInt.data]
	shl Arg2, 3
	CALL64 realloc
	pop Arg1
	mov [Arg1 + BigInt.data], ArgR
	ret

; reallocate_bigint_zx(BigInt bi, size_t size) - zero extend
reallocate_bigint_zx:
	SAVE_REGS 3
	mov R1, Arg1 ; bi
	mov R2, [Arg1 + BigInt.size] ; oldsize
	mov R3, Arg2 ; newsize
	
	call reallocate_bigint

	cmp R2, R3
        jae .done ; if(oldsize >= newsize) return

	mov T2, [R1 + BigInt.data]
	lea T1, [T2 + 8 * R2] ; oldend
	lea T2, [T2 + 8 * R3] ; newend
.loop:
	cmp T1, T2
	jae .done

	mov qword [T1], 0
	add T1, 8
	jmp .loop
.done:
	RESTORE_REGS 3
        ret

; size_t normal_size(const BigInt bi)
; actually, it just returns ceil(log_2^64(abs(bi)))
normal_size:
	mov T1, [Arg1 + BigInt.data]
	mov ArgR, [Arg1 + BigInt.size]
	lea T2, [T1 + 8 * ArgR]

	test ArgR, ArgR
	jz .done

.loop:
	sub T2, 8
	cmp qword [T2], 0
	jnz .done

	dec ArgR
	jnz .loop ; while(--size)

.done:
	ret

; size_t normalize(BigInt bi)
; return bi.size = normal_size(bi)
normalize:
	push Arg1
	call normal_size
	pop T1
	mov [T1 + BigInt.size], ArgR
        test ArgR, ArgR
        jz .zero
	ret
.zero:
        ; invariant: if number == 0, sign is positive
        mov qword [T1 + BigInt.sign], 0
        ret


; size_t max_normal_size(BigInt a, BigInt b)
; returns max(size(a), size(b)) in ArgR, min in T1
max_normal_size:
	push Arg2
	call normal_size
; normal_size(b)
	pop Arg1
	push ArgR ; size(a)
	call normal_size
	pop T1 ; size(a)
	cmp T1, ArgR
	jb .done
	xchg T1, ArgR
.done:
	ret

; size_t extend_bigints(BigInt a, BigInt b)
; extend two bigints to the same size
; returns new size
extend_bigints:
	SAVE_REGS 3
	mov R1, Arg1
	mov R2, Arg2
	call normal_size
	mov R3, ArgR ; size(a)
	mov Arg1, R2
	call normal_size

	cmp R3, ArgR ; if(size(a) > size(b)) reallocate_bigint_zx(b, size(a))
	ja .extend_b
; else reallocate_bigint_zx(a, size(b))
	mov Arg1, R1
	mov Arg2, ArgR
	mov R3, ArgR ; new size
	call reallocate_bigint_zx
	jmp .done
.extend_b: ; reallocate_bigint_zx(b, size(a))
        mov Arg1, R2
        mov Arg2, R3
        call reallocate_bigint_zx
	
.done:
	mov ArgR, R3
	RESTORE_REGS 3
	ret

	
; BigInt biFromInt(int64_t x);
biFromInt:
	push Arg1
	mov Arg1, 1
	call allocate_bigint
	pop T1 ; x
	cmp T1, 0
	jg .positive
        je .zero
	neg T1
	mov qword [ArgR + BigInt.sign], 1
.positive:
	mov T2, [ArgR + BigInt.data]
	mov [T2], T1
	ret
.zero:
; if number == 0 -> size = 0
	mov qword [ArgR + BigInt.size], 0
        ret

; BigInt biFromString(char const *s);
biFromString:
; we should allocate space for about strlen(s) / (log(2^64) / log(10)) qwords
; <= strlen(s) / 19.265 <= strlen(s) / 16
; <= 1 + floor(strlen(s) / 16)
	push Arg1
	
	CALL64 strlen
	shr ArgR, 4 ; /= 16
	inc ArgR ; += 1
	mov Arg1, ArgR
	call allocate_bigint
	
	pop Arg3
	
	cmp byte [Arg3], '-'
	jne .positive
	inc Arg3
; set sign
	mov qword [ArgR + BigInt.sign], 1
.positive:
	push ArgR
	; read_long(data, size, str)
	mov Arg1, [ArgR + BigInt.data]
	mov Arg2, [ArgR + BigInt.size]
	call read_long
; check for error
	test ArgR, ArgR
	jz .invalid ; if(!read_long) return NULL
; normalize(bi)
        mov Arg1, [rsp]
        call normalize
	
	pop ArgR
	ret
.invalid:
;pop Arg1 - split in two instructions to align rsp
        mov Arg1, [rsp]
	call biDelete
        add rsp, 8
	xor ArgR, ArgR
	ret

; void biDelete(BigInt bi);
biDelete:
	push Arg1
; free(bi.data)
	mov Arg1, [Arg1 + BigInt.data]
	CALL64 free
; pop Arg1 was splitted in two instructions to align stack
	mov Arg1, [rsp]
; free(bi)
	CALL64 free
        add rsp, 8
	ret

; void biToString(BigInt bi, char *buffer, size_t limit);
biToString:
; if(limit == 0) return
	test Arg3, Arg3
	jz .limit0
; if size(bi) == 0 return "0";
        mov T2, [Arg1 + BigInt.size]
        test T2, T2
        jz .zero
; add sign
	mov T1, [Arg1 + BigInt.sign]
	test T1, T1
	jz .positive
	mov byte [Arg2], '-'
	dec Arg3
; if(limit == 1) { *buffer = 0; return; }
	jz .limit1
	inc Arg2
.positive:
	mov Arg4, Arg3
	mov Arg3, Arg2
	mov Arg2, [Arg1 + BigInt.size]
        mov Arg1, [Arg1 + BigInt.data]
	jmp write_long
.limit1:
	mov byte [Arg2], 0
.limit0:
	ret
.zero:
        mov byte [Arg2], '0'
        dec Arg3
; if(limit == 1) { *buffer = 0; return; }
        jz .limit1
        inc Arg2
; else *++buffer = 0; return
        jmp .limit1

	
; int biSign(BigInt bi);
biSign:
	push Arg1
	call normal_size
	pop Arg1
	test ArgR, ArgR
	jz .done ; if size(bi) == 0 return 0
	
	mov ArgR, [Arg1 + BigInt.sign]
; ArgR = 0 -> return 1
; ArgR = 1 -> return -1
	test ArgR, ArgR
	jz .positive
	mov ArgR, -1
	ret
.positive:
	mov ArgR, 1
.done:
	ret

; int biCmp(BigInt a, BigInt b);
biCmp:
	mov T1, [Arg1 + BigInt.sign]
        mov T2, [Arg2 + BigInt.sign]

	cmp T1, T2
	; positive=0 < negative=1
	ja .lt
	jb .gt

	
.abs: ; int biCmp.abs(BigInt a, BigInt b);
        SAVE_REGS 3
	mov R1, Arg1
	mov R2, Arg2

	call normal_size
	mov R3, ArgR ; R3 = size(a)

	mov Arg1, R2
        call normal_size
; ArgR = size(b)

	cmp R3, ArgR
	ja .gt_restore
	jb .lt_restore
; size(a) == size(b)
	test R3, R3 ; both are zeroes
	jz .equal

	
	mov T1, [R1 + BigInt.data]
        mov T2, [R2 + BigInt.data]
	mov Arg1, T1 ; start
	lea T1, [T1 + 8 * R3] ; end1
        lea T2, [T2 + 8 * R3] ; end2

.loop:

	sub T1, 8
	sub T2, 8
	
	mov Arg4, [T1]
	cmp Arg4, [T2]
	ja .gt_restore
	jb .lt_restore

	cmp T1, Arg1
	jne .loop
; equal

.equal:
	RESTORE_REGS 3
        xor ArgR, ArgR
        ret
.gt_restore:
	RESTORE_REGS 3
.gt:
	mov ArgR, 1
	ret
.lt_restore:
	RESTORE_REGS 3
.lt:
	mov ArgR, -1
        ret

; void biAdd(BigInt dst, BigInt src);
biAdd:
	SAVE_REGS 3
	mov R1, Arg1
	mov R2, Arg2
        call extend_bigints
	mov R3, ArgR
        test ArgR, ArgR ; if max(size(a), size(b)) == 0 return;
        jz .done
	
	mov T1, [R1 + BigInt.sign]
	mov T2, [R2 + BigInt.sign]
	xor T1, T2 ; if(a.sign == b.sign) a += b
	jnz .subtract
	; add_long_long(a.data, b.data, size, a.data)
	mov Arg1, [R1 + BigInt.data]
	mov Arg2, [R2 + BigInt.data]
        mov Arg3, R3
        mov Arg4, Arg1
	call add_long_long
	test ArgR, ArgR
	jnz .overflow
; done
.done:
	RESTORE_REGS 3
	ret
	
.subtract: ; a.sign != b.sign
	mov Arg1, R1
	mov Arg2, R2
	call biCmp.abs

	; prepare args for sub_long_long
	mov Arg1, [R1 + BigInt.data]
        mov Arg2, [R2 + BigInt.data]
        mov Arg3, R3
        mov Arg4, Arg1
 
	cmp ArgR, 0
	jge .no_swap
; if(abs(a) < abs(b)) {a = b - a, a.sign = !a.sign}
; else a = a - b
	xchg Arg1, Arg2
	xor qword [R1 + BigInt.sign], 1
.no_swap:
	call sub_long_long
; normalize(dst)
        mov Arg1, R1
        call normalize
	RESTORE_REGS 3
	ret
.overflow:
; reallocate_bigint(dst, size + 1)
	mov Arg1, R1
	mov Arg2, R3
	inc Arg2
	call reallocate_bigint
	mov T1, [R1 + BigInt.data]
	mov qword [T1 + 8 * R3], 1 ; dst.data[size] = 1
	RESTORE_REGS 3
        ret

; void biSub(BigInt dst, BigInt src);
biSub:
; a -= b <-> a += (-b)
	xor qword [Arg2 + BigInt.sign], 1 ; swap sign
	push Arg2 ; save
	call biAdd
	pop Arg2
        xor qword [Arg2 + BigInt.sign], 1 ; restore sign
	ret

; void biMul(BigInt dst, BigInt src);
biMul:
	SAVE_REGS 3
	mov R1, Arg1
	mov R2, Arg2

; if dst == 0 return 0
	call normalize
	test ArgR, ArgR
	jz .done
	
; if src == 0 return 0
	mov Arg1, R2
        call normalize
        test ArgR, ArgR
        jz .return_zero
	
; newsize = max(dst.size, src.size)
        mov Arg1, R1
        mov Arg2, R2
        call extend_bigints
	mov R3, ArgR ; newsize

; allocate new array 
	shl ArgR, 4 ; malloc(newsize * 2 * sizeof(uint64))
	mov Arg1, ArgR
	mov Arg2, 1
	CALL64 calloc
; dest array is now in ArgR
	mov R4, ArgR

;void mul_long_long(a.data, b.data, size, dest);
	mov Arg4, ArgR
	mov Arg3, R3
	mov Arg1, [R1 + BigInt.data]
	mov Arg2, [R2 + BigInt.data]
	call mul_long_long

; save result in dst
; free(dst.data)
	mov Arg1, [R1 + BigInt.data]
	CALL64 free
        shl R3, 1
	mov [R1 + BigInt.size], R3 ; dst.size = newsize * 2
	mov [R1 + BigInt.data], R4 ; dst.data = dest

; fix sign!
        mov T2, [R2 + BigInt.sign]
        xor [R1 + BigInt.sign], T2

.done:
	RESTORE_REGS 3
	ret
.return_zero:
	mov qword [R1 + BigInt.size], 0
	mov qword [R1 + BigInt.sign], 0
	RESTORE_REGS 3
        ret
        

biDivRem:
	ret








	