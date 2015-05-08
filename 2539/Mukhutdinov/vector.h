#ifndef FLF_HW3_VECTOR
#define FLF_HW3_VECTOR

#include <stdint.h>

typedef void* Vector;

#ifdef __cplusplus
extern "C" {
#endif

Vector vectorNew(unsigned int initialCapacity);
void vectorDelete(Vector vec);
unsigned int vectorSize(Vector vec);
Vector vectorResize(Vector vec, unsigned int newSize);
uint64_t vectorGet(Vector vec, unsigned int i);
void vectorSet(Vector vec, unsigned int i, uint64_t val);

#ifdef __cplusplus
}
#endif

#endif