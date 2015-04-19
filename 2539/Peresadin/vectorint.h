#ifndef VECTORINT_H
#define VECTORINT_H
#include <stdint.h>
#include <stddef.h>

typedef void* VectorInt;
typedef int TypeElement;

#ifdef __cplusplus
extern "C" {
#endif
VectorInt newVector(int size);
void pushBack(VectorInt a, TypeElement x);
void popBack(VectorInt a);
int back(VectorInt a);
void deleteVector(VectorInt a);

#ifdef __cplusplus
}
#endif

#endif
