default rel

extern calloc
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

global biNew


section .data


section .text

;; Bigint stores digits with 1e9 base.
%assign	BASE		1000000000
%assign BASE_LEN	9

struc Bigint
	.digits	resq	1
	.sign	resq	1
	.size	resq	1
endstruc


;; Creates bi
biNew:
;; Allocates memory for BigInt struct.
	push	rdi
	push	rsi
	mov	rdi, 1
	mov	rsi, BigInt_size
	call	calloc
	pop	rsi
	pop	rdi
%endmacro

;; Allocates memory to store digits of BigInt.
;; Takes:
;;	* RAX: number of BASE-sized digits. 
%macro create_digits 1
	
%endmacro


;; BigInt biFromInt(int64_t x);
;;
;; Creates a BigInt from 64-bit signed integer.
;; Takes:
;;	* RDI: number x.
;; Returns:
;;	* RAX: pointer to a newly created BigInt.
biFromInt:
	



