#ifndef UBIGINT_H
#define UBIGINT_H

#include <stdint.h>

typedef uint64_t uint64;

#ifdef __cplusplus
extern "C" {
#endif

  int read_long(uint64 * dest, uint64 size, const char * str);
  void write_long(uint64 * num, uint64 size, char * buf, uint64 limit);
  void mul_long_long(const uint64 * num1, const uint64 * num2, uint64 size, uint64 * dest);

  void set_zero(uint64 * num, uint64 size);
  int is_zero(const uint64 * num, uint64 size); // 1 = true, 0 = false
  uint64 mul_long_short(const uint64 * mul1, uint64 mul2, uint64 size, uint64 * dest);
  void add_long_short(uint64 * add1, uint64 add2, uint64 size);

  uint64 div_long_short(const uint64 * src, uint64 div, unsigned size, uint64 * dest);

#ifdef __cplusplus
}
#endif

#endif /* UBIGINT_H */
