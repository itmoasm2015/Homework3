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
	BigInt bi1 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137215"); // 2**1024 -1
BigInt bi2 = biFromInt(-1ll);
biSub(bi1, bi2);
assert(bi1);
bi2 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216"); // 2**1024
assert(biCmp(bi1, bi2) == 0);
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
    //char buf[100];
    //biToString(biFromInt(0), buf, 4);
    //printf("%s\n", buf);
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

