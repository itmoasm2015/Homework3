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

    biDelete(big);
    biDelete(bi);
    biDelete(bi2);
    biDelete(bi_zero);
    biDelete(bi_s);
    biDelete(bi_s2);
}
