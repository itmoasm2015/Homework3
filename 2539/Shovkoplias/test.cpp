#include <bits/stdc++.h>
#include "bigint.h"

using namespace std;


int main() {
    BigInt a = biFromInt(3);
    BigInt b = biFromInt(-4);
    BigInt c = biFromInt(0);
    BigInt d = biCopy(b);//biCopy(a);
    printf("%d %d %d %d\n", biSign(a), biSign(b), biSign(c), biSign(d));
    biDelete(a);
    biDelete(b);
    biDelete(c);
    biDelete(d);

    char buf[100];

    a = biFromString("-000");
    if (a == NULL)
        cout << "NULL" << endl;
    else
    {
        biToString(a, buf, 100);
        printf("%s ", buf);
        cout << biSign(a) << endl;
        biDelete(a);
    }

    a = biFromString("-123");
    if (a == NULL)
        cout << "NULL" << endl;
    else
    {
        biToString(a, buf, 100);
        printf("%s ", buf);
        cout << biSign(a) << endl;
        biDelete(a);
    }

    a = biFromString("444");
    if (a == NULL)
        cout << "NULL" << endl;
    else
    {
        biToString(a, buf, 100);
        printf("%s ", buf);
        cout << biSign(a) << endl;
        biDelete(a);
    }

    {
        BigInt a = biFromString("1000000000000000000000000000000000000000000000000000000000000");
        biAdd(a, biFromString("-100000000000000000000"));
        biSub(a, biFromString("100000000000000000000"));
        char s[1000];
        biToString(a, s, 100);
        printf("%s\n", s);
        biSub(a, a);
        biToString(a, s, 100);
        printf("%s\n", s);

        BigInt b = biFromString("1000000000000000000000000000000000000000000000000000000000000");
        printf("%i\n", biCmp(a, b));
        biAdd(b, biFromString("-100000000000000000000"));
        printf("%i\n", biCmp(b, a));
        biSub(b, biFromString("100000000000000000000"));
        printf("%i\n", biCmp(a, b));
        biSub(b, b);
        printf("%i\n", biCmp(a, b));

        biDelete(a);
        biDelete(b);
    }

    return 0;
}


