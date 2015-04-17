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
