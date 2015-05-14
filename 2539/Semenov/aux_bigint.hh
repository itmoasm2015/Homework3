#ifndef __AUX_BIGINT_H_
#define __AUX_BIGINT_H_

#include <bigint.h>
#include <stdio.h>

/* TODO: create doc */

#ifdef __cplusplus
extern "C" {
#endif

void biMulBy2(BigInt x);
void biNot(BigInt x);
void biInc(BigInt x);
void biNegate(BigInt x);

#ifdef __cplusplus
}
#endif

struct BigIntRepresentation {
  int64_t *data;
  size_t size;
  size_t capacity;
};

#define dump(x) fprintf(stderr, "%s: ", #x); dump_(x)

void dump_(BigInt xx, FILE *stream = stderr) {
  BigIntRepresentation *x = (BigIntRepresentation *) xx;
  fprintf(stream, "BigInt: size = %zd, capacity = %zd, elements:\n", x->size, x->capacity);
  for (int i = (int) x->size - 1; i >= 0; --i) {
    for (int bit = 63; bit >= 0; --bit) {
      fprintf(stream, "%lld", (x->data[i] >> bit & 1));
    }
    fprintf(stream, "%c\n", ":\u0000"[i == 0]);
  }
}

#ifdef __cplusplus
extern "C" {
#endif
void biDump(BigInt x) {
  dump(x);
}
#ifdef __cplusplus
}
#endif

#endif

