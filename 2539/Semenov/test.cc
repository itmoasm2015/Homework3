#include "aux_bigint.hh"
#include <bigint.h>

#include <stdio.h>
#include <assert.h>
#include <random>

#define DEBUG(...) fprintf(stderr, __VA_ARGS__);

std::mt19937_64 rng;

void test_constructor_and_destructor(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("Constructor and destructor testing (%d iterations)\n", iterations); 
  for (int i = 0; i < iterations; ++i) {
    int64_t val = (int64_t) rng();
    BigIntMask *foo = (BigIntMask *) biFromInt(val);
    assert (foo != nullptr);
    assert (foo->size == foo->capacity && foo->size == 1);
    assert (foo->data[0] == val);
    biDelete(foo);
  }
}

void test_sign(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("Sign testing (%d iterations)\n", iterations);
  for (int i = 0; i < iterations; ++i) {
    int64_t val = (int64_t) rng();
    BigIntMask *foo = (BigIntMask *) biFromInt(val);
    int real_sign = val < 0 ? -1 : val > 0 ? 1 : 0;
    int sign = biSign(foo);
    assert (real_sign == sign);
    biDelete(foo);
  }
}

void test_grow_capacity(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("biGrowCapacity testing (%d iteratinos)\n", iterations);
  for (int i = 0; i < iterations; ++i) {
    int64_t val = (int64_t) rng();
    BigIntMask *foo = (BigIntMask *) biFromInt(val);
    biGrowCapacity(foo, size_t(42 + i));
    assert (foo != nullptr);
    assert (foo->size == 1);
    assert (foo->capacity == size_t(42 + i));
    assert (foo->data[0] == val);
    biDelete(foo);
  }
}

void test_mul_by_two(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("biMulBy2 testing (%d iteratinos)\n", iterations);
  
  for (int i = 0; i < iterations; ++i) {
    int64_t val = (int64_t) rng() / 2;
    BigIntMask *foo = (BigIntMask *) biFromInt(val);
    biMulBy2(foo);
    assert (foo != nullptr);
    assert (foo->size == 1);
    assert (foo->capacity == 1);
    assert (foo->data[0] == 2 * val);
    biDelete(foo);
  }
}

void test_mul_by_two_large(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("biMulBy2 large testing (%d iteratinos)\n", iterations);
  int64_t val = (1 << 13) - 1;
  for (int it = 0; it < 2; ++it) {
    BigIntMask *foo = (BigIntMask *) biFromInt(val);
    for (int pow = 1; pow <= iterations; ++pow) {
      size_t msb(pow + 12);
      biMulBy2(foo);
      assert (foo != nullptr);
//      if (verbose) dump(foo);
      assert (foo->size == (2 + msb + 63) / 64);
      /* TODO: check foo->data[foo->size - 1] and foo->data[foo->size - 2] */
    }
    biDelete(foo);
    val = ~val;
  }
}

void test_add(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("biAdd testing (%d iterations)\n", iterations);
  // small only
  for (int it = 0; it < iterations; ++it) {
    int64_t first = (int64_t) rng() % (1LL << 60);
    int64_t second = (int64_t) rng() % (1LL << 60);
    BigIntMask *foo = (BigIntMask *) biFromInt(first);
    BigIntMask *bar = (BigIntMask *) biFromInt(second);
    biAdd(foo, bar);
    assert (foo != nullptr && bar != nullptr);
    assert (foo->size == 1 && bar->size == 1);
    assert (foo->capacity == 1 && bar->capacity == 1);
    assert (bar->data[0] == second);
    assert (foo->data[0] == first + second);
  }
}

int main() {
  test_constructor_and_destructor(100, true);
  test_sign(100, true);
  test_grow_capacity(100, true);
  test_mul_by_two(1000, true);
  test_mul_by_two_large(1000, true);
  test_add(100, true);
  return 0;
}

