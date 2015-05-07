;;; bigint.asm
;;; Big Integers implementation.

%include "macro.inc"
%include "vector.inc"

section .text

global biFromInt
global biFromString
global biDelete
global biAdd
global biSub
global biMul
global biCmp
global biSign
global biDivRem
global biToString


;; @cdecl64
;; BigInt biFromInt(int64_t x);
;;
;; Creates a BigInt from a single int64_t value.
;; @param  RDI x -- source integer
;; @return RAX -- a freshly baked BigInt
biFromInt:
              push  rdi
              mov   rdi, 2          ; not too many and preserves a lot of reallocations for relatively small numbers
              call  vectorNew
              pop   rdi
              mov   rbx, 1
              mov   [rax + vector.size], rbx
              mov   [rax + vector.data], rdi
              ret

;; @cdecl64
;; BigInt biFromString(char const *s);
;;
;; Makes a BigInt from a string literal.
;;
;; @param  RDI s -- address of beginning of string
;; @return RAX -- a freshly baked BigInt
biFromString:
              movb  rbx, [rdi]      ; first symbol
              cmp   rbx, '-'
              
              
