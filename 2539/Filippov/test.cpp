#include <bits/stdc++.h>
#include "bigint.h"

const int MAX_SIZE = 100000;

int main() {
    char out[MAX_SIZE];
    {
    BigInt a = biFromInt(6);
    biToString(a, out, 100);
    printf("%s\n", out);
    BigInt b = biFromInt(2123456789LL);
    biToString(b, out, 100);
    printf("%s\n", out);
    BigInt c = biFromInt(123456789123456789LL);
    biToString(c, out, 100);
    printf("%s\n", out);
    BigInt d = biFromInt(9000000000000000000LL);
    biToString(d, out, 100);
    printf("%s\n", out);
    biToString(d, out, 1);
    printf("%s\n", out);
    biToString(d, out, 4);
    printf("%s\n", out);
    BigInt e = biFromInt(-9000000000000000000LL);
    biToString(e, out, 100);
    printf("%s\n", out);
    biToString(e, out, 5);
    printf("%s\n", out);
    BigInt f = biFromInt(0);
    biToString(f, out, 100);
    printf("%s\n", out);

    printf("\n%d\n", biSign(a));
    printf("%d\n", biSign(b));
    printf("%d\n", biSign(c));
    printf("%d\n", biSign(d));
    printf("%d\n", biSign(e));
    printf("%d\n", biSign(f));
    }
}
