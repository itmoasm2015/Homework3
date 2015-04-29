#include "bigint.h"
#include <stdio.h>
#include <cstdlib>
#include <climits>
#include <cmath>

int64_t get_random_int(int64_t l, int64_t r) {
        return rand() % r + l;
}

#define TEST(test)  if (test()) \
                            printf("%s %s\n", #test, "OK"); \
                    else \
                        printf("%s %s\n", #test, "FAILED"); \

using namespace std;

bool biFromInt_test() {
    BigInt a = biFromInt(get_random_int(-1000, 1000000));
    return true;
}

int main() {
    TEST(biFromInt_test);
    return 0;
}
