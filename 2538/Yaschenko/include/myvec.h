#ifndef _HOMEWORK3_VECTOR_H
#define _HOMEWORK3_VECTOR_H
#include <stdint.h>
#include <stddef.h>

typedef void* Vector;

#ifdef __cplusplus
extern "C" {
#endif

/** Creates a vector that can hold \size elements. */
Vector vectorNew(size_t size);

/** Deletes vector \v. */
void vectorDelete(Vector v);

/** Adds \element at the end of \v. Vector automatically grows to hold elements. */
void vectorPushBack(Vector v, unsigned element);

/** Pops last element from \v*/
void vectorPopBack(Vector v);

/** Returns last element of \v, or zero if \v is empty. */
unsigned vectorBack(Vector v);

/** Returns \index'th element of vector \v, or 0 if \index is out of bounds. */ 
unsigned vectorGet(Vector v, size_t index);

/** Sets \index'th element of \v to value \element, or 0 if \index is out of bounds. */
void vectorSet(Vector v, size_t index, unsigned element);

/** Returns size of \v. */
size_t vectorSize(Vector v);

/** Returns capacity of \v. */
size_t vectorCapacity(Vector v);

#ifdef __cplusplus
}
#endif

#endif
