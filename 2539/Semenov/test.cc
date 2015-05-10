#include <bigint.h>

#include <stdio.h>
#include <assert.h>
#include <random>

#define DEBUG(...) fprintf(stderr, __VA_ARGS__);

struct BigIntMask {
  int64_t *data;
  size_t size;
  size_t capacity;
};

std::mt19937_64 rng;

void test_constructor_and_destructor(const int iterations, bool verbose = false) {
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


int main() {
  test_constructor_and_destructor(100, true);
  return 0;
}

