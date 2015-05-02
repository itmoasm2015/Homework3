#ifndef _REGCHK_H
#define _REGCHK_H

#ifdef __cplusplus
extern "C"
#endif
size_t __regchk(void *f, ...);

#define regchk(f, ...) __regchk(reinterpret_cast<void*>(f), ##__VA_ARGS__)

#define _biFromInt(x) reinterpret_cast<BigInt>(regchk(biFromInt, x))

#define _biFromString(s) reinterpret_cast<BigInt>(regchk(biFromString, s))

#define _biToString(bi, buffer, limit) regchk(biToString, bi, buffer, limit)

#define _biDelete(bi) regchk(biDelete, bi)

#define _biSign(bi) (int)regchk(biSign, bi)

#define _biAdd(dst, src) regchk(biAdd, dst, src)

#define _biSub(dst, src) regchk(biSub, dst, src)

#define _biMul(dst, src) regchk(biMul, dst, src)

#define _biDivRem(quotient, remainder, numerator, denominator) regchk(biDivRem, quotient, remainder, numerator, denominator)

#define _biCmp(a, b) (int)regchk(biCmp, a, b)

#endif
