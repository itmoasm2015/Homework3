#define BOOST_TEST_DYN_LINK
#define BOOST_TEST_MODULE VectorTest
#include <boost/test/unit_test.hpp>
#include "vector.h"
#include <bigint.h>

BOOST_AUTO_TEST_CASE (VectorTest)
{
    Vector v = vectorNew(8, 0);

    BOOST_CHECK_EQUAL(vectorSize(v), 0);

    v = vectorResize(v, 5, 0);
    BOOST_CHECK_EQUAL(vectorSize(v), 5);

    for (int i = 0; i < 5; i++) {
        BOOST_CHECK_EQUAL(vectorGet(v, i), 0);
    }

    vectorSet(v, 3, 1e17);
    BOOST_CHECK_EQUAL(vectorGet(v, 3), 1e17);

    v = vectorAppend(v, 30);
    v = vectorAppend(v, 40);
    v = vectorAppend(v, 60);
    BOOST_CHECK_EQUAL(vectorSize(v), 8);
    BOOST_CHECK_EQUAL(vectorGet(v, 5), 30);
    BOOST_CHECK_EQUAL(vectorGet(v, 6), 40);
    BOOST_CHECK_EQUAL(vectorGet(v, 7), 60);

    v = vectorResize(v, 10, -1);
    BOOST_CHECK_EQUAL(vectorSize(v), 10);
    BOOST_CHECK_EQUAL(vectorGet(v, 8), 0xFFFFFFFFFFFFFFFF);

    Vector v2 = vectorCopy(v);
    BOOST_CHECK_EQUAL(vectorSize(v), vectorSize(v2));
    int s = vectorSize(v);
    for (int i = 0; i < s; i++) {
        BOOST_CHECK_EQUAL(vectorGet(v, i), vectorGet(v2, i));
    }

    vectorDelete(v);
    vectorDelete(v2);
}

BOOST_AUTO_TEST_CASE(BigintCreationAndOutput)
{
    BigInt bi = biFromInt(234);
    BOOST_CHECK_EQUAL(biSign(bi), 1);
    BigInt bi2 = biFromInt(-234435);
    BOOST_CHECK_EQUAL(biSign(bi2), -1);
    BigInt bi_zero = biFromInt(0);
    BOOST_CHECK_EQUAL(biSign(bi_zero), 0);
    BOOST_ASSERT(biFromString("") == NULL);
    BOOST_ASSERT(biFromString("-") == NULL);
    BOOST_ASSERT(biFromString("123sadfsadf") == NULL);

    BigInt bi_s  = biFromString("234");
    BigInt bi_s2 = biFromString("-234435");
    BOOST_ASSERT(bi_s != NULL);
    BOOST_ASSERT(bi_s != NULL);

    // naive comparison
    int size = vectorSize(bi);
    BOOST_CHECK_EQUAL(size, vectorSize(bi_s));
    for (int i = 0; i < size; i++) {
        BOOST_CHECK_EQUAL(vectorGet(bi, i), vectorGet(bi_s, i));
    }

    BOOST_CHECK_EQUAL(biCmp(bi, bi_s), 0);
    BOOST_CHECK_EQUAL(biCmp(bi2, bi_s2), 0);
    BOOST_CHECK_EQUAL(biCmp(bi_zero, bi), -1);
    BOOST_CHECK_EQUAL(biCmp(bi_zero, bi_s2), 1);
    BOOST_CHECK_EQUAL(biCmp(bi_s2, bi), -1);

    char buf[4096];
    biToString(bi, buf, 4096);
    BOOST_CHECK_EQUAL(buf, "234");

    biToString(bi2, buf, 4096);
    BOOST_CHECK_EQUAL(buf, "-234435");

    biToString(bi_s2, buf, 3);
    BOOST_CHECK_EQUAL(buf, "-2");

    BigInt big = biFromString("100000000000000000000000000005000000000000000000000000000000000000000000000000000");
    BOOST_CHECK_EQUAL(vectorSize(big), 5);
    biToString(big, buf, 4096);
    BOOST_CHECK_EQUAL(buf, "100000000000000000000000000005000000000000000000000000000000000000000000000000000");

    BigInt big2 = biFromString("12312312312312312312312312312312312312312312312312312312312312312312312312312312");
    BOOST_CHECK_EQUAL(biCmp(big, big2), -1);
    biToString(big2, buf, 4096);
    BOOST_CHECK_EQUAL(buf, "12312312312312312312312312312312312312312312312312312312312312312312312312312312");


    BigInt b2_64 = biFromString("18446744073709551616");
    size = vectorSize(b2_64);
    BOOST_CHECK_EQUAL(size, 2);

    for (int i = 0; i < size - 1; i++) {
        BOOST_CHECK_EQUAL(vectorGet(b2_64, i), 0);
    }
    BOOST_CHECK_EQUAL(vectorGet(b2_64, size - 1), 1);
    biToString(b2_64, buf, sizeof buf);
    BOOST_CHECK_EQUAL(buf, "18446744073709551616");


    BigInt b2_512 = biFromString("13407807929942597099574024998205846127479365820592393377723561443721764030073546976801874298166903427690031858186486050853753882811946569946433649006084096");

    // check inner representation (must be 8 zeros and 1);
    size = vectorSize(b2_512);
    BOOST_CHECK_EQUAL(size, 9);

    for (int i = 0; i < size - 1; i++) {
        BOOST_CHECK_EQUAL(vectorGet(b2_512, i), 0);
    }
    BOOST_CHECK_EQUAL(vectorGet(b2_512, size - 1), 1);


    biToString(b2_512, buf, sizeof buf);
    BOOST_CHECK_EQUAL(buf, "13407807929942597099574024998205846127479365820592393377723561443721764030073546976801874298166903427690031858186486050853753882811946569946433649006084096");

    biDelete(big);
    biDelete(b2_512);
    biDelete(big2);
    biDelete(bi);
    biDelete(bi2);
    biDelete(bi_zero);
    biDelete(bi_s);
    biDelete(bi_s2);
}

BOOST_AUTO_TEST_CASE(biAddUnsignedSmall)
{
    char buf[4096];
    BigInt b1 = biFromInt(200);
    BigInt b2 = biFromInt(300);
    biAdd(b1, b2);
    biToString(b1, buf, sizeof buf);
    BOOST_CHECK_EQUAL(buf, "500");

    biDelete(b1);
    biDelete(b2);
}

BOOST_AUTO_TEST_CASE(biAddUnsignedBig)
{
    char buf[4096];
    BigInt b1 = biFromString("2000000000000000000000000000000000000000000000000000000000000000");
    BigInt b2 = biFromString("3000000000000000000000000000000000000000000000000000000000000000");
    biAdd(b1, b2);
    biToString(b1, buf, sizeof buf);
    BOOST_CHECK_EQUAL(buf, "5000000000000000000000000000000000000000000000000000000000000000");

    biDelete(b1);
    biDelete(b2);

    b1 = biFromString("123123123323233144542134213444341432342342341234345234532462354");
    b2 = biFromString("23498740234987601234015314606123450136423051235012350");
    biAdd(b1, b2);
    biToString(b1, buf, sizeof buf);
    BOOST_CHECK_EQUAL(buf, "123123123346731884777121814678356746948465791370768285767474704");

    biAdd(b2, b1);
    biToString(b2, buf, sizeof buf);
    BOOST_CHECK_EQUAL(buf, "123123123370230625012109415912372061554589241507191337002487054");

    biDelete(b1);
    biDelete(b2);
}

BOOST_AUTO_TEST_CASE(biSubUnsignedSmall)
{
    char buf[4096];
    BigInt b1 = biFromInt(100050000);
    BigInt b2 = biFromInt(50000);
    biSub(b1, b2);
    biToString(b1, buf, sizeof buf);
    BOOST_CHECK_EQUAL(buf, "100000000");

    biDelete(b1);
    biDelete(b2);
}

BOOST_AUTO_TEST_CASE(biSubUnsignedBig)
{
    char buf[4096];
    BigInt b1 = biFromString("2000000000000000000000000000000000000000000000000000000000000000");
    BigInt b2 = biFromString("3000000000000000000000000000000000000000000000000000000000000000");
    biSub(b2, b1);
    biToString(b2, buf, sizeof buf);
    BOOST_CHECK_EQUAL(buf, "1000000000000000000000000000000000000000000000000000000000000000");

    BigInt b2_512 = biFromString("13407807929942597099574024998205846127479365820592393377723561443721764030073546976801874298166903427690031858186486050853753882811946569946433649006084096");
    BigInt one = biFromInt(1);
    biSub(b2_512, one);
    biToString(b2_512, buf, sizeof buf);
    BOOST_CHECK_EQUAL(buf, "13407807929942597099574024998205846127479365820592393377723561443721764030073546976801874298166903427690031858186486050853753882811946569946433649006084095");

    biAdd(b2_512, one);
    biToString(b2_512, buf, sizeof buf);
    BOOST_CHECK_EQUAL(buf, "13407807929942597099574024998205846127479365820592393377723561443721764030073546976801874298166903427690031858186486050853753882811946569946433649006084096");

    biDelete(b1);
    biDelete(b2);
    biDelete(b2_512);
    biDelete(one);
}
