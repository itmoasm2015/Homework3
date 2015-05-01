#include <bits/stdc++.h>
#include "bigint.h"
#include <gmpxx.h>

using namespace std;

bool check(bool f, bool print = false) {
    if (print) cout << (f ? "OK" : "FAIL") << endl;
    return f;
}

string genRandNumber(int len) {
    string res = "";
    if (rand() % 2) res += "-";
    res += (char)('1' + rand() % 9);
    for (int j = 1; j < len; j++) {
        res += (char)('0' + rand() % 10);
    }
    return res;
}

void test1() {
    cout << "test 1: ";
    cout.flush();
    bool ok = 1;

    BigInt a, b, c;

    a = biFromInt(15);
    ok &= check(biSign(a) == 1);
    b = biCopy(a);
    ok &= check(biSign(b) == 1);
    c = biAddNew(a, b);
    ok &= check(biSign(c) == 1);
    biDelete(a);
    biDelete(b);
    biDelete(c);

    a = biFromInt(0);
    ok &= check(biSign(a) == 0);
    biDelete(a);

    a = biFromInt(-1000000000000LL);
    ok &= check(biSign(a) == -1);
    biDelete(a);

    check(ok, 1);
}

void test2() {
    cout << "test 2: ";
    cout.flush();
    bool ok = 1;

    BigInt a, b, c;
    a = biFromInt(2);
    b = biFromInt(3);
    biAdd(a, b);
    c = biFromInt(5);
    check(biCmp(a, c) == 0);
    biDelete(a);
    biDelete(b);
    biDelete(c);

    check(ok, 1);
}

void test3() {
    cout << "test 3: ";
    cout.flush();
    bool ok = 1;

    BigInt a1, a2, a3;
    a1 = biFromInt(7);
    a2 = biFromInt(7);
    a3 = biFromInt(0);
    biSub(a1, a2);
    ok &= check(biCmp(a1, a3) == 0);
    biDelete(a1);
    biDelete(a2);
    biDelete(a3);

    int n = 100;
    vector<int> v(n);
    for (int i = 0; i < n; i++) v[i] = rand() % 101 - 50;
    
    BigInt a = biFromInt(0);
    int sum = 0;
    for (int i = 0; i < n; i++) {
        BigInt b = biFromInt(v[i]);

        if (rand() % 2 == 0) {
            sum += v[i];
            biAdd(a, b);
        } else {
            sum -= v[i];
            biSub(a, b);
        }

        biDelete(b);

        for (int k = -1; k <= 1; k++) {
        //for (int k = 0; k <= 0; k++) {
            b = biFromInt(sum + k);
            ok &= check(biCmp(a, b) == -k);
            biDelete(b);
        }
    }

    check(ok, 1);
}

void test4() {
    cout << "test 4: ";
    cout.flush();
    bool ok = 1;

    int n = 1000;
    vector<unsigned long long> v(n);
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < 63; j++) {
            v[i] += ((unsigned long long)(rand() % 2)) << j;
        }
    }

    BigInt sum = biFromInt(0);
    for (int i = 0; i < n; i++) {
        BigInt x = biFromInt(v[i]);
        biAdd(sum, x);
        biDelete(x);
    }
    vector<BigInt> l(n), r(n);
    l[0] = biFromInt(v[0]);
    r[n - 1] = biFromInt(v[n - 1]);
    for (int i = 1; i < n; i++) {
        BigInt x = biFromInt(v[i]);
        l[i] = biAddNew(x, l[i - 1]);
        biDelete(x);
    }
    for (int i = n - 2; i >= 0; i--) {
        BigInt x = biFromInt(v[i]);
        r[i] = biAddNew(x, r[i + 1]);
        biDelete(x);
    }
    
    for (int i = 0; i + 1 < n; i++) {
        BigInt x;
        x = biAddNew(l[i], r[i + 1]);
        ok &= check(biCmp(x, sum) == 0);
        biDelete(x);
        x = biSubNew(sum, r[i + 1]);
        ok &= check(biCmp(x, l[i]) == 0);
        biDelete(x);
        x = biSubNew(sum, l[i]);
        ok &= check(biCmp(x, r[i + 1]) == 0);
        biDelete(x);
    }

    biDelete(sum);
    for (int i = 0; i < n; i++) {
        biDelete(l[i]);
        biDelete(r[i]);
    }

    check(ok, 1);
}

void test5() {
    cout << "test 5: ";
    cout.flush();
    bool ok = 1;

    BigInt a, b, c;
    a = biFromInt(0);
    b = biFromString("0");
    ok &= check(biCmp(a, b) == 0);
    biDelete(a);
    biDelete(b);

    a = biFromInt(5);
    b = biFromString("5");
    ok &= check(biCmp(a, b) == 0);
    biDelete(a);
    biDelete(b);

    a = biFromInt(-777777777777777777);
    b = biFromString("-777777777777777777");
    ok &= check(biCmp(a, b) == 0);
    biDelete(a);
    biDelete(b);

    a = biFromInt(-777777777777777777);
    b = biFromString("777777777777777777");
    c = biFromString("-0000000000000000000");
    biAdd(a, b);
    ok &= check(biCmp(a, c) == 0);
    ok &= check(biCmp(b, c) == 1);
    biDelete(a);
    biDelete(b);
    biDelete(c);

    a = biFromString("-");
    ok &= check(a == NULL);

    a = biFromString("");
    ok &= check(a == NULL);
    
    a = biFromString("-0");
    ok &= check(a != NULL);
    biDelete(a);

    check(ok, 1);
}

void test6() {
    cout << "test 6: ";
    cout.flush();
    bool ok = 1;

    int n = 100;
    vector<string> v(n);
    for (int i = 0; i < n; i++) {
        v[i] = genRandNumber(1000);
    }

    BigInt sum = biFromInt(0);
    for (int i = 0; i < n; i++) {
        BigInt x = biFromString(v[i].c_str());
        biAdd(sum, x);
        biDelete(x);
    }
    vector<BigInt> l(n), r(n);
    l[0] = biFromString(v[0].c_str());
    r[n - 1] = biFromString(v[n - 1].c_str());
    for (int i = 1; i < n; i++) {
        BigInt x = biFromString(v[i].c_str());
        l[i] = biAddNew(x, l[i - 1]);
        biDelete(x);
    }
    for (int i = n - 2; i >= 0; i--) {
        BigInt x = biFromString(v[i].c_str());
        r[i] = biAddNew(x, r[i + 1]);
        biDelete(x);
    }
    
    for (int i = 0; i + 1 < n; i++) {
        BigInt x;
        x = biAddNew(l[i], r[i + 1]);
        ok &= check(biCmp(x, sum) == 0);
        biDelete(x);
        x = biSubNew(sum, r[i + 1]);
        ok &= check(biCmp(x, l[i]) == 0);
        biDelete(x);
        x = biSubNew(sum, l[i]);
        ok &= check(biCmp(x, r[i + 1]) == 0);
        biDelete(x);
    }

    biDelete(sum);
    for (int i = 0; i < n; i++) {
        biDelete(l[i]);
        biDelete(r[i]);
    }

    check(ok, 1);
}

void test7() {
    cout << "test 7: ";
    cout.flush();
    bool ok = 1;

    BigInt a;
    char c[1000];
    a = biFromInt(0);
    biToString(a, c, 1000);
    ok &= check((string)c == "0");
    biDelete(a);

    a = biFromInt(5);
    biToString(a, c, 1000);
    ok &= check((string)c == "5");
    biDelete(a);

    a = biFromInt(123);
    biToString(a, c, 1000);
    ok &= check((string)c == "123");
    biDelete(a);

    a = biFromInt(-777);
    biToString(a, c, 1000);
    ok &= check((string)c == "-777");
    biDelete(a);

    a = biFromString("100000000000000000000");
    biToString(a, c, 1000);
    ok &= check((string)c == "100000000000000000000");
    biDelete(a);


    a = biFromString("43425452362856925692456924562568246836516062562");
    biToString(a, c, 1000);
    ok &= check((string)c == "43425452362856925692456924562568246836516062562");
    biDelete(a);

    check(ok, 1);
}

void test8(int test, int cnt, int iters, int len) {
    cout << "test " << test << ": ";
    cout.flush();
    bool ok = 1;
    
    const int sz = 10000;
    char c[sz];

    BigInt a;
    a = biFromInt(0);
    mpz_class a2 = 0;

    for (int it = 0; it < iters; it++) {
        string s = genRandNumber(len);
        BigInt b = biFromString(s.c_str());

        //int o = rand() % cnt;
        int o = (it > 0) * (1 + (test == 10));
        if (o == 0) {
            if (rand() % 2) {
                biAdd(a, b);
            } else {
                biAdd(b, a);
                swap(a, b);
            }
            a2 += mpz_class(s);
        }
        if (o == 1) {
            biSub(a, b);
            a2 -= mpz_class(s);
        }
        if (o == 2) {
            biMul(a, b);
            a2 *= mpz_class(s);
        }

        biToString(a, c, sz);
        string c1 = c;
        string c2 = a2.get_str();
        ok &= check(c1 == c2);

        biDelete(b);
    }

    biDelete(a);

    check(ok, 1);
}

void test9() {
    cout << "test 9: ";
    cout.flush();
    bool ok = 1;

    const int mx = 10000;
    char c[mx];

    BigInt a, b;
    a = biFromInt(0);
    b = biFromInt(0);
    biMul(a, b);
    biToString(a, c, mx);
    ok &= check((string)c == "0");
    biDelete(a);
    biDelete(b);

    a = biFromInt(2);
    b = biFromInt(3);
    biMul(a, b);
    biToString(a, c, mx);
    ok &= check((string)c == "6");
    biDelete(a);
    biDelete(b);

    a = biFromString("-100000");
    b = biFromString("100000");
    biMul(a, b);
    biToString(a, c, mx);
    ok &= check((string)c == "-10000000000");
    biDelete(a);
    biDelete(b);

    a = biFromString("-100000000000000000000");
    b = biFromString("-100000000000000000000");
    biMul(a, b);
    biToString(a, c, mx);
    ok &= check((string)c == "10000000000000000000000000000000000000000");
    biDelete(a);
    biDelete(b);

    a = biFromString("543534651454354353461464534");
    b = biFromString("986825976248623595236852396");
    biMul(a, b);
    biToString(a, c, mx);
    ok &= check((string)c == "536374113046398593484849759421413903658458498546923464");
    biDelete(a);
    biDelete(b);

    a = biFromString("-10000000000000000000000000000000000000000");
    b = biFromString("-10000000000000000000000000000000000000001");
    biMul(a, b);
    biToString(a, c, mx);
    ok &= check((string)c == "100000000000000000000000000000000000000010000000000000000000000000000000000000000");
    biDelete(a);
    biDelete(b);
    

    check(ok, 1);
}

void test11() {
    cout << "test 11: ";
    cout.flush();
    bool ok = 1;

    BigInt a, b;
    a = biFromInt(1);
    b = biFromInt(0);
    BigInt c, d;
    biDivRem(&c, &d, a, b);
    ok &= check(c == 0 && d == 0);
    biDelete(a);
    biDelete(b);
    
    check(ok, 1);
}

void test12() {
    cout << "test 12: ";
    cout.flush();
    bool ok = 1;

    BigInt bi1, bi2, bi3, bi4, bi5;
    bi1 = biFromInt(2ll);
    bi2 = biFromInt(-123ll);
    bi3 = biFromInt(-123ll);
    biAdd(bi1, bi2);
    biSub(bi1, bi2);
    ok &= check(biCmp(bi2, bi3) == 0);
    biDelete(bi1);
    biDelete(bi2);
    biDelete(bi3);

    bi1 = biFromInt(0xffffffffll);
    bi2 = biFromInt(0xffffffffll);
    bi5 = biFromInt(0xffffffffll + 0xffffffffll);
    biAdd(bi1, bi2);
    ok &= check(biCmp(bi1, bi5) == 0);
    biDelete(bi1);
    biDelete(bi2);
    biDelete(bi5);

    bi1 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137215"); // 2**1024 -1
    bi2 = biFromInt(-1ll);
    biSub(bi1, bi2);
    biDelete(bi2);
    ok &= check(bi1 != NULL);
    bi2 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216"); // 2**1024
    ok &= check(biCmp(bi1, bi2) == 0);
    biDelete(bi1);
    biDelete(bi2);

    check(ok, 1);
}

int main() {
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8(8, 2, 1000, 1000);
    test9();
    test8(10, 3, 100, 100);
    //test11();
    test12(); 
    return 0; 
}
