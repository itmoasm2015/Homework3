#include "aux_bigint.hh"
#include <bigint.h>

#include <stdio.h>
#include <assert.h>
#include <random>
#include <algorithm>
#include <vector>

#define DEBUG(...) fprintf(stderr, __VA_ARGS__);

std::mt19937_64 rng;

void test_set_bit(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("biSetBit testing (%d iterations)\n", iterations);
  const int max_bit = 256; // 10 * 1000;
  const int ops = 1000;
  for (int it = 0; it < iterations; ++it) {
    BigIntRepresentation *foo = (BigIntRepresentation *) biFromInt(0);
    size_t size = 1;
    for (int i = 0; i < ops; ++i) {
      size_t bit;
      if (rng() % 3) {
        bit = ((rng() % max_bit) + max_bit) % max_bit;
      } else {
        bit = (((rng() % (max_bit / 64)) + max_bit / 64) % (max_bit / 64)) * 64 + 63;
      }
      size_t block = bit / 64;
      size_t idx = bit % 64;
      size_t cur_size = 1 + block;
      if (idx == 63) {
        ++cur_size;
      }
      size = std::max(size, cur_size);
      biSetBit(foo, bit);
//      DEBUG("after setting %dht bit on %dth iteration: size is %d-%d\n", (int) bit, i, (int) size, (int) foo->size);
//      dump(foo);
      assert (foo->size == size);
      assert (foo->data[block] >> idx & 1);
    }
    biDelete(foo);
  }
}

void test_to_string(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("biToString testing (%d iterations)\n", iterations);
  static const int max_length = 10 * 1000 + 10;
  static char src[max_length];
  static char dst[max_length];
  for (int i = 0; i < iterations; ++i) {
    size_t ptr = 0;
    if (rng() % 2) {
      src[ptr++] = '-';
    }
    int digits = (rng() % (max_length - 2)) + 1;
    //int digits = 100 * 1000;
    for (int j = 0; j < digits; ++j) {
      src[ptr++] = '0' + (rng() % 10);
      while (j == 0 && src[ptr - 1] == '0') src[ptr - 1] = '0' + (rng() % 10);
    }
    src[ptr] = 0;
//    auto start_constructing = std::chrono::system_clock::now();
    BigIntRepresentation *foo = (BigIntRepresentation *) biFromString(src);
//    auto finish_constructing = std::chrono::system_clock::now();
//    auto start_printing = std::chrono::system_clock::now();
    biToString(foo, dst, max_length);
//    auto finish_printing = std::chrono::system_clock::now();
//    DEBUG("constructing: %.3fs, printing: %.3fs\n", std::chrono::duration<double>(finish_constructing - start_constructing).count(), std::chrono::duration<double>(finish_printing - start_printing).count());
    ptr = 0;
    while (true) {
      if (src[ptr] != dst[ptr]) {
        DEBUG("Fail on:\n%s\n%s\n", src, dst);
      }
      assert (src[ptr] == dst[ptr]);
      if (src[ptr] == 0) break;
      ++ptr;
    }
//    DEBUG("%d ok\n", (int) i);
  }
}

void test_constructor_and_destructor(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("Constructor and destructor testing (%d iterations)\n", iterations); 
  for (int i = 0; i < iterations; ++i) {
    int64_t val = (int64_t) rng();
    BigIntRepresentation *foo = (BigIntRepresentation *) biFromInt(val);
    assert (foo != nullptr);
    assert (foo->size == foo->capacity && foo->size == 1);
    assert (foo->data[0] == val);
    biDelete(foo);
  }
}

void test_string_constructor(const char *string) {
  BigIntRepresentation *num = (BigIntRepresentation *) biFromInt(0);
  BigIntRepresentation *ten = (BigIntRepresentation *) biFromInt(10);
  size_t i = 0;
  bool negative = false;
  if (string[i] == '-') {
    negative = true;
    ++i;
  }
  while (string[i] != 0) {
    assert ('0' <= string[i] && string[i] <= '9');
    int digit = string[i] - '0';
    BigIntRepresentation *dig = (BigIntRepresentation *) biFromInt(digit);
    biMul(num, ten);
    assert (ten->size == 1 && ten->data[0] == 10);
    biAdd(num, dig);
    biDelete(dig);
    ++i;
  }
  if (negative) biNegate(num);
  BigIntRepresentation *result = (BigIntRepresentation *) biFromString(string);
  assert (result != nullptr);
  assert (biCmp(result, num) == 0);
  biDelete(result);
  biDelete(num);
  biDelete(ten);
}

void test_string_constructor(const int iterations = 1, const size_t length = 100, bool verbose = false) {
  if (verbose) DEBUG("biFromString testin (%d iterations)\n", iterations);
  for (int it = 0; it < iterations; ++it) {
    char *string = new char[length + 1];
    size_t i = 0;
    if (rng() % 2) {
      string[i++] = '-';
    }
    for (; i != length; ++i) {
      string[i] = (char) (rng() % 10 + '0'); 
    }
    string[length] = 0;
    test_string_constructor(string);
    delete[] string;
  }
}

void test_sign(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("Sign testing (%d iterations)\n", iterations);
  for (int i = 0; i < iterations; ++i) {
    int64_t val = (int64_t) rng();
    BigIntRepresentation *foo = (BigIntRepresentation *) biFromInt(val);
    int real_sign = val < 0 ? -1 : val > 0 ? 1 : 0;
    int sign = biSign(foo);
    assert (real_sign == sign);
    biDelete(foo);
  }
}

void test_mul_by_two(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("biMulBy2 testing (%d iteratinos)\n", iterations);
  
  for (int i = 0; i < iterations; ++i) {
    int64_t val = (int64_t) rng() / 2;
    BigIntRepresentation *foo = (BigIntRepresentation *) biFromInt(val);
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
    BigIntRepresentation *foo = (BigIntRepresentation *) biFromInt(val);
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

void test_add_large(const int iterations = 1, const int summands = 100, bool verbose = false) {
  if (verbose) DEBUG("biAdd large testing (%d iterations)\n", iterations);
  // tests biSub, biSign, biInc and biCmp also
  for (int it = 0; it < iterations; ++it) {
    std::vector <BigIntRepresentation *> summand(summands);
    for (int i = 0; i < summands; ++i) {
      summand[i] = ((BigIntRepresentation *) biFromInt((int64_t) rng()));
    }
    BigIntRepresentation *first = (BigIntRepresentation *) biFromInt(0);
    for (auto i : summand) {
      biAdd(first, i);
    }
    std::shuffle(summand.begin(), summand.end(), rng);
    BigIntRepresentation *second = (BigIntRepresentation *) biFromInt(0);
    for (auto i : summand) {
      biAdd(second, i);
    }
    assert (first != nullptr && second != nullptr);
    assert (first->size == second->size);
    for (int i = 0; i < (int) first->size; ++i) {
      assert (first->data[i] == second->data[i]);
    }
    
    assert (biCmp(first, second) == 0);

    biInc(first);
    assert (biCmp(first, second) > 0);
    assert (biCmp(second, first) < 0);
    biInc(second);
    assert (biCmp(second, first) == 0);

    biSub(first, second);
    assert (biSign(first) == 0);
    assert (first->size == 1);
    assert (first->data[0] == 0);
    
    biDelete(first);
    biDelete(second);
    for (auto i : summand) {
      biDelete(i);
    }
  }
}

void test_add(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("biAdd testing (%d iterations)\n", iterations);
  // small only
  for (int it = 0; it < iterations; ++it) {
    int64_t first = (int64_t) rng() % (1LL << 60);
    int64_t second = (int64_t) rng() % (1LL << 60);
    BigIntRepresentation *foo = (BigIntRepresentation *) biFromInt(first);
    BigIntRepresentation *bar = (BigIntRepresentation *) biFromInt(second);
    biAdd(foo, bar);
    assert (foo != nullptr && bar != nullptr);
    assert (foo->size == 1 && bar->size == 1);
    assert (foo->capacity == 1 && bar->capacity == 1);
    assert (bar->data[0] == second);
    assert (foo->data[0] == first + second);
    biDelete(foo);
    biDelete(bar);
  }
}

void test_not(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("biNot testing (%d iterations)\n", iterations);
  const int BUBEN = 100;
  for (int it = 0; it < iterations; ++it) {
    int64_t first = (int64_t) rng();
    BigIntRepresentation *foo = (BigIntRepresentation *) biFromInt(first);
    for (int _ = 0; _ < BUBEN; ++_) {
      int64_t second = (int64_t) rng();
      BigIntRepresentation *bar = (BigIntRepresentation *) biFromInt(second);
      biAdd(foo, bar);
      assert (foo != nullptr && bar != nullptr);
      assert (bar->size == 1 && bar->capacity == 1);
      assert (bar->data[0] == second);
      BigIntRepresentation *baz = (BigIntRepresentation *) biFromInt(0);
      biAdd(baz, foo); // baz = biClone(foo), TODO: biClone
      biNot(foo);
      biNot(foo);
      for (int i = 0; i < (int) foo->size; ++i) assert (foo->data[i] == baz->data[i]);
      biDelete(bar);
      biDelete(baz);
    }
    biDelete(foo);
  }
}
 
void test_inc_case(int64_t val) {
  BigIntRepresentation *foo = (BigIntRepresentation *) biFromInt(val);
  BigIntRepresentation *bar = (BigIntRepresentation *) biFromInt(0);
  biAdd(bar, foo);
  static BigIntRepresentation *one = (BigIntRepresentation *) biFromInt(1);
  biInc(foo);
  biAdd(bar, one);
  assert (foo->size == bar->size && foo->capacity == bar->capacity);
  for (int i = 0; i < (int) std::min(foo->size, bar->size); ++i) {
    assert (foo->data[i] == bar->data[i]);
  }
  biDelete(foo);
  biDelete(bar);
}

void test_inc(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("biInc testing (%d iterations)\n", iterations);
  const int BUBEN = 100;
  BigIntRepresentation *one = (BigIntRepresentation *) biFromInt(1);
  for (int it = 0; it < iterations; ++it) {
    int64_t first = (int64_t) rng();
    int64_t second = (int64_t) rng();
    BigIntRepresentation *foo = (BigIntRepresentation *) biFromInt(first);
    BigIntRepresentation *bar = (BigIntRepresentation *) biFromInt(second);
    for (int _ = 0; _ < BUBEN; ++_) {
      biAdd(foo, bar);
      assert (foo != nullptr && bar != nullptr);
      assert (bar->size == 1 && bar->capacity == 1);
      assert (bar->data[0] == second);
      BigIntRepresentation *baz = (BigIntRepresentation *) biFromInt(0);
      biAdd(baz, foo); // baz = biClone(foo), TODO: biClone
      biInc(foo);
      biAdd(baz, one);
      assert (one->size == 1 && one->capacity == 1 && one->data[0] == 1);
      assert (foo->size == baz->size); 
      for (int i = 0; i < (int) foo->size; ++i) assert (foo->data[i] == baz->data[i]);
      biDelete(baz);
    }
    biDelete(foo);
    biDelete(bar);
  }
}

void test_sub(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("biSub testing (%d iterations)\n", iterations);
  // small only
  for (int it = 0; it < iterations; ++it) {
    int64_t first = (int64_t) rng() % (1LL << 60);
    int64_t second = (int64_t) rng() % (1LL << 60);
    BigIntRepresentation *foo = (BigIntRepresentation *) biFromInt(first);
    BigIntRepresentation *bar = (BigIntRepresentation *) biFromInt(second);
    biSub(foo, bar);
    assert (foo != nullptr && bar != nullptr);
    assert (foo->size == 1 && bar->size == 1);
    assert (foo->capacity == 1 && bar->capacity == 1);
    assert (bar->data[0] == second);
    assert (foo->data[0] == first - second);
    biDelete(foo);
    biDelete(bar);
  }
}


void test_mul(const int iterations = 1, bool verbose = false) {
  if (verbose) DEBUG("biMul testing (%d iterations)\n", iterations);
  // small only
  for (int it = 0; it < iterations; ++it) {
    int64_t first = (int64_t) rng() % (1 << 31);
    int64_t second = (int64_t) rng() % (1 << 31);
    BigIntRepresentation *foo = (BigIntRepresentation *) biFromInt(first);
    BigIntRepresentation *bar = (BigIntRepresentation *) biFromInt(second);
    biMul(foo, bar);

    BigIntRepresentation *baz = (BigIntRepresentation *) biFromInt(first * second);
    
    assert (foo != nullptr && bar != nullptr);
    assert (bar->size == 1);
    assert (foo->size == 1); 
    assert (bar->data[0] == second);
    assert (foo->data[0] == first * second);

    assert (biCmp(foo, baz) == 0);
    biDelete(foo);
    biDelete(bar);
    biDelete(baz);
  }
}

void test_mul_large(const int iterations = 1, const int multipliers = 100, bool verbose = false) {
  if (verbose) DEBUG("biMul large testing (%d iterations)\n", iterations);
  // tests biSub, biSign, biInc and biCmp also
  for (int it = 0; it < iterations; ++it) {
    std::vector <BigIntRepresentation *> multiplier(multipliers);
    for (int i = 0; i < multipliers; ++i) {
      multiplier[i] = ((BigIntRepresentation *) biFromInt((int64_t) rng()));
    }
    BigIntRepresentation *first = (BigIntRepresentation *) biFromInt(0);
    for (auto i : multiplier) {
      biMul(first, i);
    }
    std::shuffle(multiplier.begin(), multiplier.end(), rng);
    BigIntRepresentation *second = (BigIntRepresentation *) biFromInt(0);
//    for (auto i : multiplier) {
//      biMul(second, i);
//    }
    for (int i = 0; i + i < multipliers; ++i) {
      biMul(second, multiplier[i]);
    }
    BigIntRepresentation *aux = (BigIntRepresentation *) biFromInt(0);
    for (int i = multipliers / 2 + 1; i < multipliers; ++i) {
      biMul(aux, multiplier[i]);
    }
    biMul(second, aux); // testing large products
    assert (first != nullptr && second != nullptr);
    assert (first->size == second->size);
    for (int i = 0; i < (int) first->size; ++i) {
      assert (first->data[i] == second->data[i]);
    }
    
    assert (biCmp(first, second) == 0);

    biInc(first);
    assert (biCmp(first, second) > 0);
    assert (biCmp(second, first) < 0);
    biInc(second);
    assert (biCmp(second, first) == 0);

    biSub(first, second);
    assert (biSign(first) == 0);
    assert (first->size == 1);
    assert (first->data[0] == 0);
    
    biDelete(first);
    biDelete(second);
    for (auto i : multiplier) {
      biDelete(i);
    }
  }
}

int main() {
  test_set_bit(100, true);
  test_to_string(100, true);
  test_inc_case(-4858338985614885836);
  test_constructor_and_destructor(100, true);
  test_string_constructor(100, 4000, true);
  test_sign(100, true);
  test_mul_by_two(1000, true);
  test_mul_by_two_large(1000, true);
  test_add(100, true);
  test_add_large(100, 100, true);
  test_not(100, true);
  test_inc(100, true);
  test_sub(100, true);
  test_mul(100, true);
  test_mul_large(100, 10000, true);
  return 0;
}

