#ifndef _HOMEWORK3_BIGINT_H
#define _HOMEWORK3_BIGINT_H
#include <stdint.h>
#include <stddef.h>

typedef void* BigInt;

#ifdef __cplusplus
extern "C" {
#endif

/** Create a BigInt from 64-bit signed integer.
 */
BigInt biFromInt(int64_t x);

/** Create a BigInt from a decimal string representation.
 *  Returns NULL on incorrect string.
 */
BigInt biFromString(char const *s);

/** Generate a decimal string representation from a BigInt.
 *  Writes at most limit bytes to buffer.
 */
void biToString(BigInt bi, char *buffer, size_t limit);

/** Destroy a BigInt.
 */
void biDelete(BigInt bi);

/** Get sign of given BigInt.
 *  \return 0 if bi is 0, positive if bi is positive, negative if bi is negative.
 */
int biSign(BigInt bi);

/** dst += src */
void biAdd(BigInt dst, BigInt src);

/** dst -= src */
void biSub(BigInt dst, BigInt src);

/** dst *= src */
void biMul(BigInt dst, BigInt src);

/** Compute quotient and remainder by divising numerator by denominator.
 *  quotient * denominator + remainder = numerator
 *
 *  \param remainder must be in range [0, denominator) if denominator > 0
 *                                and (denominator, 0] if denominator < 0.
 */
void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
//BigInt biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);

/** Compare two BigInts.
 * \returns sign(a - b)
 */
int biCmp(BigInt a, BigInt b);

/////////////////////my functions

long long biDivShort(BigInt , long long );

BigInt biCopy(BigInt); 

long long biIsZero(BigInt);

void biMulShort(BigInt, unsigned long long);
void biAddShort(BigInt, unsigned long long);

BigInt biAddMy(BigInt dst, BigInt src);
BigInt biSubMy(BigInt dst, BigInt src);
BigInt biMulMy(BigInt dst, BigInt src);
void biMove (BigInt dst, BigInt src);
void biSetBit(BigInt, int);
void biBigShl(BigInt, int);


#ifdef __cplusplus
}
#endif

#endif
