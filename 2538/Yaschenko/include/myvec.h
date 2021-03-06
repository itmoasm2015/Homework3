#ifndef _HOMEWORK3_VECTOR_H
#define _HOMEWORK3_VECTOR_H
#include <stdint.h>
#include <stddef.h>

typedef void* Vector;
typedef long long digit_t;

#ifdef __cplusplus
extern "C" {
#endif

/** Creates a vector that can hold \size elements. */
Vector vectorNew(size_t size);

/** Deletes vector \v. */
void vectorDelete(Vector v);

/** Adds \element at the end of \v. Vector automatically grows to hold elements. */
void vectorPushBack(Vector v, digit_t element);

/** Pops last element from \v*/
void vectorPopBack(Vector v);

/** Returns last element of \v, or zero if \v is empty. */
digit_t vectorBack(Vector v);

/** Returns \index'th element of vector \v, or 0 if \index is out of bounds. */ 
digit_t  vectorGet(Vector v, size_t index);

/** Sets \index'th element of \v to value \element, or 0 if \index is out of bounds. */
void vectorSet(Vector v, size_t index, digit_t element);

/** Returns size of \v. */
size_t vectorSize(Vector v);

/** Returns capacity of \v. */
size_t vectorCapacity(Vector v);

Vector vectorCopy(Vector v);

#ifdef __cplusplus
}
#endif

#endif
