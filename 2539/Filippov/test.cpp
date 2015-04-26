#include <bits/stdc++.h>
#include "bigint.h"

const size_t MAX_SIZE = 100000;
const size_t INF = 1e9; 

int main() {
    srand(239017);
    char out[MAX_SIZE];
    {
        printf("=========================\n");
        printf("Starting first group of tests\n");
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
        printf("All tests passed\n");
        printf("============================\n");
    }
    {
        printf("============================\n");
        printf("Starting second group of tests\n");
        BigInt a = biFromString("6");
        biToString(a, out, 100);
        printf("%s\n", out);
        BigInt b = biFromString("2123456789");
        biToString(b, out, 100);
        printf("%s\n", out);
        BigInt c = biFromString("00000000000000000000000000000000000000");
        biToString(c, out, 100);
        printf("%s\n", out);
        BigInt d = biFromString("-0000000000000000000000000000000000000");
        biToString(d, out, 100);
        printf("%s\n", out);
        BigInt e = biFromString("9000000000000000000");
        biToString(e, out, 100);
        printf("%s\n", out);
        BigInt f = biFromString("-9000000000000000000");
        biToString(f, out, 100);
        printf("%s\n", out);
        BigInt g = biFromString("1027210398793739217392137219373982173921739218739213879187391273193719373921873921873921387219837");
        biToString(g, out, 100);
        printf("%s\n", out);
        BigInt h = biFromString("+123");
        assert(!h);
        BigInt hh = biFromString("00000000000000000000000000000000000000123");
        biToString(hh, out, 100);
        printf("%s\n", out);
        BigInt gg = biFromString("-00000000000000000000000000000000000000000123");
        biToString(gg, out, 100);
        printf("%s\n", out);
        BigInt aa = biFromString("-0000000001234567890123456789032981028302137");
        biToString(aa, out, 100);
        printf("%s\n", out);
        BigInt x = biFromString("-");
        assert(!x);
        printf("All tests passed\n");
        printf("============================\n");
    }
    {
        printf("============================\n");
        printf("Starting third group of tests\n");
        BigInt a = biFromInt(6);
        BigInt b = biFromString("000000000000006");
        assert(biCmp(a, b) == 0);
        BigInt c = biFromInt(6);
        BigInt d = biFromString("07");
        assert(biCmp(c, d) == -1);
        BigInt e = biFromString("55555555555555555555555555556");
        BigInt f = biFromString("55555555555555555555555555555");
        assert(biCmp(e, f) == 1);
        printf("All tests passed\n");
        printf("============================\n");
    }
}
