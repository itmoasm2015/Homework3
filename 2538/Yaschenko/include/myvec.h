#ifndef _HOMEWORK3_VECTOR_H
#define _HOMEWORK3_VECTOR_H
#include <stdint.h>
#include <stddef.h>

typedef void* Vector;

#ifdef __cplusplus
extern "C" {
#endif

/** Creates a vector that can hold \size elements.
*/
Vector vectorNew(size_t size);

/** Deletes vector \v.
*/
void vectorDelete(Vector v);

/** Adds \element at the end of vector.
 * 	Vector automatically grows to hold elements.
 */
void vectorPushBack(unsigned element);

unsigned vectorGet(Vector v, size_t index);

void vectorSet(Vector v, size_t index, unsigned element);

#ifdef __cplusplus
}
#endif

#endif
