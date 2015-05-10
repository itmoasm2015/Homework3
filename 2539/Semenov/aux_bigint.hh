#ifndef __AUX_BIGINT_H_
#define __AUX_BIGINT_H_

#include <bigint.h>
#include <stdio.h>

/* TODO: create doc */

#ifdef __cplusplus
extern "C" {
#endif

void biGrowCapacity(BigInt x, size_t new_capacity);
void biMulBy2(BigInt x);

#ifdef __cplusplus
}
#endif

struct BigIntMask {
  int64_t *data;
  size_t size;
  size_t capacity;
};

void dump(BigInt xx, FILE *stream = stderr) {
  BigIntMask *x = (BigIntMask *) xx;
  fprintf(stream, "BigInt: size = %zd, capacity = %zd, elements:\n ", x->size, x->capacity);
  for (int i = (int) x->size - 1; i >= 0; --i) {
    for (int bit = 63; bit >= 0; --bit) {
      fprintf(stream, "%lld", (x->data[i] >> bit & 1));
    }
    fprintf(stream, "%c", ":\n"[i == 0]);
  }
}

#endif

