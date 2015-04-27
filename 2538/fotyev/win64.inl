;; win64 calling conv.
;; https://en.wikipedia.org/wiki/X86_calling_conventions#Microsoft_x64_calling_convention
extern abort
%macro CALL64 1
	sub rsp, 32 		; shadow space
	test rsp, 15
	jnz abort
	call %1
	add rsp, 32
%endmacro
	
%define Arg1 rcx ;; volatile
%define Arg2 rdx
%define Arg3 r8
%define Arg4 r9
%define ArgR rax
%define T1 r10
%define T2 r11
%define R1 r12 ;; non-volatile
%define R2 r13
%define R3 r14
%define R4 r15
%define R5 rdi
%define R6 rsi
%define R7 rbx



%macro _SAVE_OFFSET 1
        mov [rsp + 8 * (%1 - 1)], R%1
%endmacro

%macro SAVE_REGS 1
	sub rsp, 8 * %1
%assign t 1
%rep %1
	_SAVE_OFFSET t
%assign t t+1
%endrep
	

%endmacro

;;;;;
%macro _RESTORE_OFFSET 1
        mov R%1, [rsp + 8 * (%1 - 1)]
%endmacro

%macro RESTORE_REGS 1

%assign t 1
%rep %1
        _RESTORE_OFFSET t
%assign t t+1
%endrep
	add rsp, 8 * %1

%undef _RESTORE_OFFSET
%endmacro
	