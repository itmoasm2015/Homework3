#include <cmath>
#include <iostream>
#include <assert.h>
#include <algorithm>
#include <utility>
#include <cassert>
#include "../../include/bigint.h"


int main()
{
    //2^64 - 1 = 18446744073709551615
    //9223372036854775807
    BigInt b1 = biFromInt((unsigned long long)2000000000000000009);
    BigInt b2 = biFromString("-00000000000000");
    BigInt b3 = biFromString("-0000000001");
    BigInt b4 = biFromInt(11111);
    BigInt b5 = biFromString("11111");
    BigInt b6 = biFromInt(-11111);
    BigInt b7 = biFromInt(-11112);
    BigInt b8 = biFromString("184467540737095516551111111111111");
    BigInt b9 = biFromString("184467440737095516000000000000000");
    char str[300] = "     ";
    printf("check sign: 1:%d, 0:%d -1:%d\n", biSign(b1),biSign(b2),biSign(b3));
    printf("check compare: 1:%d, 0:%d, -1:%d, -1:%d\n", biCmp(b1,b2), biCmp(b4, b5), biCmp(b6, b4), biCmp(b7,b6));
    int kk = biCmp(b6,b4);
    biToString(b1,str,40);
    printf("work %s\n", str);
    biAdd(b1, b2);
    biToString(b1,str,100);
    printf("add: %s\n",str);
    biSub(b4, b5);
    biToString(b4,str,100);
    printf("sub: %s\n",str);
    biSub(b8, b9);
    biToString(b8,str,100);
    printf("sub: %s\n",str);


    return 0;
}
