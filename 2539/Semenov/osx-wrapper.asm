extern _malloc
global malloc
extern _calloc
global calloc
extern _free
global free


extern biFromInt
global _biFromInt
extern biFromString
global _biFromString

extern biDelete
global _biDelete

extern biMulBy2
global _biMulBy2
extern biNot
global _biNot
extern biInc
global _biInc
extern biNegate
global _biNegate

extern biAdd
global _biAdd
extern biSub
global _biSub
extern biMul
global _biMul

extern biCmp
global _biCmp
extern biSign
global _biSign

extern biDivRem
global _biDivRem

extern biToString
global _biToString

malloc:         jmp _malloc
calloc:         jmp _calloc
free:           jmp _free

_biFromInt:     jmp biFromInt
_biFromString:  jmp biFromString

_biDelete:      jmp biDelete

_biMulBy2:      jmp biMulBy2
_biNot:         jmp biNot
_biInc:         jmp biInc
_biNegate:      jmp biNegate

_biAdd:         jmp biAdd
_biSub:         jmp biSub
_biMul:         jmp biMul

_biCmp:         jmp biCmp
_biSign:        jmp biSign

_biDivRem:      jmp biDivRem
_biToString:    jmp biToString

