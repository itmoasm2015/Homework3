#include "bigint.h"
#include <cstdio>
#include <cmath>
#include <cstdlib>
#include <ctime>
#include <cassert>
#include <vector>
#include <iostream>
using namespace std;
int rndInt(int m) {
    int x = rand();
    return x % m;
}
long long x = 1000000000000000LL + 12;
int main() { 
/*    BigInt a = biFromInt(0);
    int ra = 0;
    for (int i = 0; i < 1000; ++i) {
        int ri = rndInt(10000);
        ra -= ri;
        BigInt b = biFromInt(ri);
        biSub(a, b);
        BigInt bb = biFromInt(ra);
        assert(biCmp(a, bb) == 0);
    }
    BigInt biRa = biFromInt(ra);
    printf("cmp = %d\n", biCmp(a, biRa));*/
    char buf[100];
    biToString(biFromInt(0), buf, 4);
    printf("%s\n", buf);
    /*long x = 100;
    long y = -13000000000000LL;
    BigInt a = biFromInt(x);
    BigInt b = biFromInt(y);
    printf("%d\n", biSign(a));
    printf("%d\n", biSign(b));
    BigInt c = biFromString("-1300");
    assert(biCmp(c, biFromInt(-1300)) == 0);
    biMul(a, b);
    assert(biCmp(a, c) == 0);*/
    return 0;
}

