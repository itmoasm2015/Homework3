#include <algorithm>
#include <cassert>
#include <cstdlib>
#include <vector>
#include <utility>
#include "gtest/gtest.h"
#include <iostream>

#include <bigint.h>

namespace {
    void ASSERT_STR(const char *a, const char *b) {
        ASSERT_EQ(strlen(a), strlen(b));
        for (int i = 0; i < strlen(a); i++) {
            ASSERT_EQ(a[i], b[i]);
        }
    }
}

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

    bi1 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137215"); // 2**1024 -1
    bi2 = biFromInt(-1ll);
    biSub(bi1, bi2);
    biDelete(bi2);
    bi2 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216"); // 2**1024
    ASSERT_EQ(biCmp(bi1, bi2), 0);
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

TEST(correctness, biCmp) {
    BigInt bi1 = biFromInt(0xffffffffll);
    BigInt bi2 = biFromInt(0xffffffffll);
    BigInt bi3 = biFromInt(0xffffffffll + 0xffffffffll);
    biAdd(bi1, bi2);
    ASSERT_EQ(biCmp(bi1, bi3), 0);
    biDelete(bi1);
    biDelete(bi2);
    biDelete(bi3);

    bi1 = biFromString("1111111111111111111111111111111111111111111111111");
    bi2 = biFromString("1111111111111111111111111111111111111111111111111");
    ASSERT_EQ(biCmp(bi1, bi2), 0);
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromString("1111111111111111111111111111111111111111111111111");
    bi2 = biFromString("11111111111111111111111");
    ASSERT_GT(biCmp(bi1, bi2), 0);
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromString("-1111111111111111111111111111111111111111111111111");
    bi2 = biFromString("11111111111111111111111");
    ASSERT_LT(biCmp(bi1, bi2), 0);
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromString("111111111111111111111111");
    bi2 = biFromString("1111111111111111111111111111111111111111111111111");
    ASSERT_LT(biCmp(bi1, bi2), 0);
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromString("111111111111111111111111");
    bi2 = biFromString("-1111111111111111111111111111111111111111111111111");
    ASSERT_GT(biCmp(bi1, bi2), 0);
    biDelete(bi1);
    biDelete(bi2);
}

TEST(correctness, biToString) {
    const char *input1 = "123456789012345678901234567890123456789012345678901234567890";
    char str[350];
    BigInt bi1 = biFromString(input1);
    biToString(bi1, str, 350);
    ASSERT_STR(input1, str);
    biDelete(bi1);

    bi1 = biFromInt(0);
    biToString(bi1, str, 10);
    ASSERT_STR("0", str);
    biDelete(bi1);

    bi1 = biFromString("-0");
    biToString(bi1, str, 10);
    ASSERT_STR("0", str);
    biDelete(bi1);

    bi1 = biFromString(input1);
    biToString(bi1, str, 10);
    ASSERT_STR("123456789", str);
    biDelete(bi1);

    const char *input2 = "-123456789012345678901234567890123456789012345678901234567890";
    bi1 = biFromString(input2);
    biToString(bi1, str, 350);
    ASSERT_STR(input2, str);
    biDelete(bi1);

    bi1 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137215"); // 2**1024 - 1
    BigInt bi2 = biFromInt(-1ll);
    biSub(bi1, bi2);
    biToString(bi1, str, 350);
    ASSERT_STR("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216", str);
    biDelete(bi1);
    biDelete(bi2);
}

TEST(correctness, mul) {
    char str[350];
    BigInt bi1 = biFromInt(2);
    BigInt bi2 = biFromInt(-2);
    biMul(bi1, bi2);
    biToString(bi1, str, 10);
    ASSERT_STR("-4", str);
    ASSERT_LT(biSign(bi2), 0);
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromInt(-9223372036854775808l);
    bi2 = biFromInt(-9223372036854775808l);
    biMul(bi1, bi2);
    biToString(bi1, str, 100);
    ASSERT_STR("85070591730234615865843651857942052864", str);
    ASSERT_LT(biSign(bi2), 0);
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromString("9223372036854775808");
    bi2 = biFromString("9223372036854775808");
    biMul(bi1, bi2);
    biToString(bi1, str, 100);
    ASSERT_STR("85070591730234615865843651857942052864", str);
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromString("170141183460469231731687303715884105727");
    bi2 = biFromString("170141183460469231731687303715884105727");
    biMul(bi1, bi2);
    biToString(bi1, str, 100);
    ASSERT_STR("28948022309329048855892746252171976962977213799489202546401021394546514198529", str);
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromString("85070591730234615865843651857942052864");
    bi2 = biFromString("85070591730234615865843651857942052864");
    biMul(bi1, bi2);
    biToString(bi1, str, 100);
    ASSERT_STR("7237005577332262213973186563042994240829374041602535252466099000494570602496", str);
    biDelete(bi1);
    biDelete(bi2);
}
