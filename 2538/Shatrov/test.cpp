#include <cmath>
#include <iostream>
#include <assert.h>
#include <algorithm>
#include "../../include/bigint.h"

#ifdef __cplusplus
extern "C" {
#endif
    int getFirstInt(BigInt bi);
#ifdef __cplusplus
}
#endif


bool eq(double a, double b)
{
    using namespace std;
    return abs(a-b) < max(0.00001, max(abs(b) * 0.00001, abs(a) * 0.00001));
}

int main()
{

    BigInt b1 = biFromInt(9223372036854775807);
    BigInt b2 = biFromString("000001");
    BigInt b3 = biFromInt(-123);
    BigInt b4 = biFromInt(11111);
    char str[100] = "     ";
    biToString(b1,str,40);
    printf("work %s\n", str);
    printf("check sign: 1:%d, 0:%d -1:%d\n", biSign(b1),biSign(b2),biSign(b3));
    biAdd(b1, b2);
    biToString(b1,str,40);
    printf("add: %s\n",str);
    return 0;
}
