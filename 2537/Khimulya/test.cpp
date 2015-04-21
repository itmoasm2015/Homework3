#include <algorithm>
#include <cassert>
#include <cstdlib>
#include <vector>
#include <utility>
#include "gtest/gtest.h"
#include <iostream>

#include <bigint.h>

TEST(correctness, allocAndFree) {
    BigInt bi = biFromInt(100);
    biDelete(bi);
}

TEST(correctness, sign) {
    BigInt bi = biFromInt(1);
    ASSERT_GT(biSign(bi), 0);
    biDelete(bi);
    int64_t tmp = 9223372036854775807l;
    bi = biFromInt(9223372036854775807l);    // 2 ** 63 - 1
    ASSERT_GT(biSign(bi), 0);
    biDelete(bi);
    bi = biFromInt(-1);
    ASSERT_LT(biSign(bi), 0);
    biDelete(bi);
    bi = biFromInt(-9223372036854775808l);    // -2 ** 63
    ASSERT_LT(biSign(bi), 0);
    biDelete(bi);
    bi = biFromInt(0);
    ASSERT_EQ(biSign(bi), 0);
    biDelete(bi);
}
