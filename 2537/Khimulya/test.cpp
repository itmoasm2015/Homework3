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

TEST(correctness, addition) {
    BigInt bi1 = biFromInt(1);
    BigInt bi2 = biFromInt(9223372036854775807l);
    biAdd(bi1, bi2);
    ASSERT_GT(biSign(bi1), 0);
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromInt(1);
    bi2 = biFromInt(9223372036854775806l);
    biAdd(bi1, bi2);
    ASSERT_GT(biSign(bi1), 0);
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromInt(9223372036854775807l);
    bi2 = biFromInt(9223372036854775807l);
    biAdd(bi1, bi2);
    biAdd(bi1, bi2);
    ASSERT_GT(biSign(bi1), 0);
    biDelete(bi2);
    bi2 = biFromInt(-9223372036854775807l);
    biAdd(bi1, bi2);
    biAdd(bi1, bi2);
    biAdd(bi1, bi2);
    ASSERT_EQ(biSign(bi1), 0);
    biDelete(bi2);
    bi2 = biFromInt(-1);
    biAdd(bi1, bi2);
    ASSERT_LT(biSign(bi1), 0);
    biDelete(bi1);
    biDelete(bi2);
}

TEST(correctness, additionSubtract) {
    BigInt bi1 = biFromInt(9223372036854775807l);
    BigInt bi2 = biFromInt(9223372036854775807l);
    biAdd(bi1, bi2);
    biAdd(bi1, bi2);
    ASSERT_GT(biSign(bi1), 0);
    biSub(bi1, bi2);
    ASSERT_GT(biSign(bi1), 0);
    biSub(bi1, bi2);
    ASSERT_GT(biSign(bi1), 0);
    biSub(bi1, bi2);
    ASSERT_EQ(biSign(bi1), 0);
    biSub(bi1, bi2);
    ASSERT_LT(biSign(bi1), 0);
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromInt(9223372036854775807l);
    bi2 = biFromInt(9223372036854775807l);
    biAdd(bi1, bi2);
    biAdd(bi1, bi2);
    biSub(bi1, bi1);
    ASSERT_EQ(biSign(bi1), 0);
    biDelete(bi1);
    biDelete(bi2);
}

TEST(correctness, fromString) {
    BigInt bi1 = biFromString("00000000000009223372036854775807");
    BigInt bi2 = biFromInt(9223372036854775807l);
    biSub(bi1, bi2);
    ASSERT_EQ(biSign(bi1), 0);
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromString("18446744073709551614");
    bi2 = biFromInt(9223372036854775807l);
    BigInt bi3 = biFromInt(9223372036854775807l);
    biSub(bi2, bi1);
    biAdd(bi2, bi3);
    ASSERT_EQ(biSign(bi2), 0);
    biDelete(bi1);
    biDelete(bi2);
    biDelete(bi3);

    bi1 = biFromString("00000000000009223372036854775808");
    bi2 = biFromInt(-9223372036854775808l);
    biAdd(bi1, bi2);
    ASSERT_EQ(biSign(bi1), 0);
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromString("-00000000000009223372036854775807");
    bi2 = biFromInt(9223372036854775807l);
    biAdd(bi1, bi2);
    ASSERT_EQ(biSign(bi1), 0);
    biDelete(bi1);
    biDelete(bi2);
}

TEST(correctness, fromStringMalformed) {
    BigInt bi = biFromString("");
    ASSERT_EQ(bi, (void*)NULL);
    bi = biFromString("-");
    ASSERT_EQ(bi, (void*)NULL);
    bi = biFromString("-00000000000009223372036854775807b");
    ASSERT_EQ(bi, (void*)NULL);
    bi = biFromString("0000000000000-9223372036854775807");
    ASSERT_EQ(bi, (void*)NULL);
}
