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

bool biFromString_test() {
    BigInt a = biFromString("1000000000000000000000123");
    BigInt b = biFromString("-19000000000000001212121212");
    BigInt c = biFromString("1lffdlkjkfdjkfdjk3434kjdkf");
    if (c != 0)
        return false;
    BigInt d = biFromString("");
    if (d != 0)
        return false;
    BigInt e = biFromString("-");
    if (e != 0)
        return false;
    return true;
}

int main() {
    TEST(biFromInt_test);
    TEST(biFromString_test);
    return 0;
}
