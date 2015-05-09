;; Convenience macros

;; mpush - pushes multiple values on stack
;; in given order
%macro mpush 1-*
%rep  %0
              push  %1              
%rotate 1
%endrep
%endmacro

;; mpop - pops values from the stack to registers
;; in reversed order.
%macro  mpop 1-*
%rep %0
%rotate -1
              pop   %1              
%endrep
%endmacro

;; madd - add first value to all the others
%macro  madd 2-*
%assign x %1
%rep %0-1
%rotate -1
              add   %1, x
%endrep
%endmacro

;; save registers and allocate stack space
%macro CDECL_ENTER 2
              mpush rbx, r12, r13, r14, r15
              enter %1, %2
%endmacro

;; restore registers and clean stack space
%macro CDECL_RET 0
              leave
              mpop  rbx, r12, r13, r14, r15
              ret
%endmacro

;; A macro which helps to preserve stack alignment by AMD64 ABI conventions
%macro ALIGNED_CALL 1
              ; mpush r8, r9
              mov   r8, rsp
              and   r8, 15          ; R8 = RSP % 16
              mov   r9, 16
              sub   r9, r8          ; R9 = 16 - (RSP % 16)
              add   r9, 8           ; R9 = 24 - (RSP % 16)
              sub   rsp, r9         ; RSP = RSP + (RSP % 16) - 24 = align(RSP, 16) - 8
              push  r9              ; RSP = align(RSP, 16) - 16 -- alignment preserves
              call  %1
              pop   r9
              add   rsp, r9
              ; mpop  r8, r9
%endmacro
              
;; round number up by 4
%macro ROUND_4 1
              add   %1, 3
              and   %1, -4
%endmacro
