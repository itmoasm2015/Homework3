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

;; round number up by 4
%macro ROUND_4 1
              add   %1, 3
              and   %1, -4
%endmacro
