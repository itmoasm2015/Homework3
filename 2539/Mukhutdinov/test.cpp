#define BOOST_TEST_DYN_LINK
#define BOOST_TEST_MODULE VectorTest
#include <boost/test/unit_test.hpp>
#include "vector.h"

BOOST_AUTO_TEST_CASE (VectorCommon)
{
    Vector v = vectorNew(8);

    BOOST_CHECK_EQUAL(vectorSize(v), 0);

    v = vectorResize(v, 5);
    BOOST_CHECK_EQUAL(vectorSize(v), 5);

    for (int i = 0; i < 5; i++) {
        BOOST_CHECK_EQUAL(vectorGet(v, i), 0);
    }

    vectorSet(v, 3, 1e17);
    BOOST_CHECK_EQUAL(vectorGet(v, 3), 1e17);

    v = vectorResize(v, 10);
    BOOST_CHECK_EQUAL(vectorSize(v), 10);

    vectorDelete(v);
}
