;; System V calling conv.
;; https://en.wikipedia.org/wiki/X86_calling_conventions
extern abort
%macro CALL64 1
	test rsp, 15
	jnz %%.bad_align
	call %1
	jmp %%.ok
	%%.bad_align:
        and rsp, ~15
	call abort
	%%.ok:
%endmacro


; SYSTEM V calling convention
;; volatile        
%define Arg1 rdi
%define Arg2 rsi
%define Arg3 rdx
%define Arg4 rcx
%define Arg5 r8
%define Arg6 r9
%define ArgR rax
%define T1 r10
%define T2 r11
;; non volatile
%define R1 r12
%define R2 r13
%define R3 r14
%define R4 r15
%define R5 rbx



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
	