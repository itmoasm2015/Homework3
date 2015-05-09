#define BOOST_TEST_DYN_LINK
#define BOOST_TEST_MODULE VectorTest
#include <boost/test/unit_test.hpp>
#include "vector.h"

BOOST_AUTO_TEST_CASE (VectorCommon)
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

    vectorDelete(v);
}
