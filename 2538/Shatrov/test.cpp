#include <cmath>
#include <iostream>
#include <assert.h>
#include <algorithm>
#include <utility>
#include <cassert>
#include "../../include/bigint.h"


#define bs(s) biFromString(s)

int main()
{
    //2^64 - 1 = 18446744073709551615
    //9223372036854775807
    BigInt b3 = biFromString("1000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000");
   // BigInt b2 = biFromString("2617");
//10s
    BigInt b1 = bs("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    /*BigInt b4 = biFromInt(0);
    BigInt b5 = biFromString("1");
    BigInt b6 = biFromString("-11011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    BigInt b7 = biFromString("-11112000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    BigInt b8 = biFromString("18446754073709551655111111111111100000000000000000000000000");
    BigInt b9 = biFromString("18446754073709551600000000000000000000000000000000000000000");
     */
    char str[500] = "     ";
    //printf("check sign: 1:%d, 0:%d -1:%d\n", biSign(bs("312342")),biSign(bs("-0000")),biSign(bs("-0000101")));
    //printf("check compare: 1:%d\n", biCmp(b1,b2));
    biToString(b1,str,450);
    printf("b1: %s\n", str);
    biToString(b3,str,450);
    printf("b3: %s\n", str);
    biMul(b1, b3);
    biToString(b1,str,450);
    printf("mul: %s\n",str);


    return 0;
}
