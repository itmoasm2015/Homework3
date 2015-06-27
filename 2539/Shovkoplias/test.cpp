#include <bits/stdc++.h>
#include "bigint.h"

using namespace std;

string gen_rand_number(int len)
{
    string ans = "";
    if (rand() % 2)
        ans += "-", len--;
    while (len--) {
        char c = rand() % 10 + '0';
        ans += c;
    }
    return ans;
}


int main() {

    char buf[1000];


    BigInt a = biFromInt(-3606);
    BigInt b = biFromInt(18);
    biAdd(a, b);
    biToString(a, buf, 100);
    printf("%s\n", buf);
    biDelete(a);
    biDelete(b);


    a = biFromInt(3);
    b = biFromInt(-4);
    BigInt c = biFromInt(0);
    BigInt d = biCopy(b);//biCopy(a);
    printf("%d %d %d %d\n", biSign(a), biSign(b), biSign(c), biSign(d));
    biDelete(a);
    biDelete(b);
    biDelete(c);
    biDelete(d);

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

    a = biFromInt(-3606);
    b = biFromInt(18);
    biAdd(a, b);
    biToString(a, buf, 100);
    printf("%s\n", buf);
    biDelete(a);
    biDelete(b);


    a = biFromString("1000000000000000000000000000000000000000000000000000000000000");
    b = biFromString("-1000000000000000000000000000000000000000000000000000000000000");
    biMul(a, b);
    biToString(a, buf, 1000);
    printf("%s\n", buf);
    biMul(a, b);
    biToString(a, buf, 1000);
    printf("%s\n", buf);
    biDelete(b);
    b = biFromString("0");
    biMul(a, b);
    biToString(a, buf, 1000);
    printf("%s\n", buf);
    biDelete(a);
    biDelete(b);

    //Without segfault check

    freopen("log.txt", "w", stdout);

    for (int i = 10; i < 1009; i++)
    {
        cerr << "test #" << i - 9 << ":" << endl;
        cout << "test #" << i - 9 << ":" << endl;
        string s = gen_rand_number(rand() % i + 2);
        cout << "!" + s << endl;
        a = biFromString(s.c_str());
        biToString(a, buf, 1000);
        printf("%s\n", buf);
        s = gen_rand_number(rand() % i + 2);
        cout << "!" + s << endl;
        b = biFromString(s.c_str());
        biToString(b, buf, 1000);
        printf("%s\n", buf);
        biAdd(a, b);
        biToString(a, buf, 1000);
        printf("%s\n", buf);
        biSub(a, b);
        biToString(a, buf, 1000);
        printf("%s\n", buf);
        biMul(a, b);
        biToString(a, buf, 1000);
        printf("%s\n", buf);
        biDelete(a);
        biDelete(b);
    }

    return 0;
}


