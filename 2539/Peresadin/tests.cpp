#include "bigint.h"
#include <cstdio>
#include <cmath>
#include <cstdlib>
#include <ctime>
#include <cassert>
#include <vector>
#include <iostream>
using namespace std;

int main() {
    BigInt a = biFromInt(-5);
    BigInt b = biFromInt(5);
    BigInt c = biFromInt(0);
    biAdd(a, b);
    printf("cmp = %d\n", biCmp(c, a));
    return 0;
}
