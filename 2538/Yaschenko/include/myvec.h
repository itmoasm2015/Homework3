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

/** Adds \element at the end of vector. Vector automatically grows to hold elements. */
void vectorPushBack(Vector v, unsigned element);

/** Returns index'th element of vector \v, or 0 if index is out of bounds. */ 
unsigned vectorGet(Vector v, size_t index);

/** Returns last element of VECTOR, or zero if vector is empty. */
unsigned vectorBack(Vector v);

/** Sets \index'th element of vector v to value \element, or 0 if \index is out of bounds. */
void vectorSet(Vector v, size_t index, unsigned element);

/** Returns size of vector \v. */
size_t vectorSize(Vector v);

/** Returns capacity of VECTOR. */
size_t vectorCapacity(Vector v);

#ifdef __cplusplus
}
#endif

#endif
