extern _malloc
global malloc
extern _calloc
global calloc
extern _free
global free


extern biAllocate
global _biAllocate

extern biGrowCapacity
global _biGrowCapacity

extern biFromInt
global _biFromInt
extern biFromString
global _biFromString

extern biDelete
global _biDelete

extern biMulBy2
global _biMulBy2
extern biAdd
global _biAdd
extern biNot
global _biNot
extern biInc
global _biInc
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

_biAllocate:    jmp biAllocate
_biGrowCapacity:jmp biGrowCapacity 
_biFromInt:     jmp biFromInt
_biFromString:  jmp biFromString
_biDelete:      jmp biDelete
_biMulBy2:      jmp biMulBy2
_biAdd:         jmp biAdd
_biNot:         jmp biNot
_biInc:         jmp biInc
_biSub:         jmp biSub
_biMul:         jmp biMul
_biCmp:         jmp biCmp
_biSign:        jmp biSign
_biDivRem:      jmp biDivRem
_biToString:    jmp biToString

