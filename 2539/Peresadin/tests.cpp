#include "bigint.h"
#include <cstdio>
#include <cmath>
#include <cstdlib>
#include <ctime>
#include <cassert>

int main() {
    BigInt a = biFromInt(-1111);
    BigInt b = biFromInt(-1110);
    printf("cmp = %d\n", biCmp(a, b));
    return 0;
}
