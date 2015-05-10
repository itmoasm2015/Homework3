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

void test2() {
    cout << "test 2: ";
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
    biDelete(a);

    check(ok, 1);
}

void test3() {
    cout << "test 3: ";
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

const int size = 100000;
char c[size];

void test4() {
    cout << "test 4: ";
    cout.flush();
    bool ok = 1;

    BigInt a, b;
//    const int size = 100000;
//    char c[size];

    a = biFromInt(0);
    biToString(a, c, size);
    ok &= check((string)c == "0");
    biDelete(a);

    a = biFromInt(5);
    biToString(a, c, size);
    ok &= check((string)c == "5");
    biDelete(a);

    a = biFromInt(123);
    biToString(a, c, size);
    ok &= check((string)c == "123");
    biDelete(a);

    a = biFromInt(-777);
    biToString(a, c, size);
    ok &= check((string)c == "-777");
    biDelete(a);

    a = biFromString("100000000000000000000");
    biToString(a, c, size);
    ok &= check((string)c == "100000000000000000000");
    biDelete(a);


    a = biFromString("43425452362856925692456924562568246836516062562");
    biToString(a, c, size);
    ok &= check((string)c == "43425452362856925692456924562568246836516062562");
    biDelete(a);

    a = biFromString("100000000000000000000");
    b = biFromString("90000000000000000000");
    biSub(a, b);
    biToString(a, c, size);
    ok &= check((string)(c) == "10000000000000000000");
    biDelete(a);
    biDelete(b);

    check(ok, 1);
}

void test5(int test, int cnt, int iters, int len) {
    cout << "test " << test << ": ";
    cout.flush();
    bool ok = 1;
    
    BigInt a;
    a = biFromInt(0);
    mpz_class a2 = 0;

    for (int it = 0; it < iters; it++) {
        string s = genRandNumber(len);
        BigInt b = biFromString(s.c_str());

        int o = rand() % cnt;
        if (o == 0) {
            if (rand() % 2) {
                biAdd(a, b);
            } else {
                biAdd(b, a);
                swap(a, b);
            }
            a2 += mpz_class(s);
        } else
        if (o == 1) {
            biSub(a, b);
            a2 -= mpz_class(s);
        } else 
        if (o == 2) {
            biMul(a, b);
            a2 *= mpz_class(s);
        }

        biToString(a, c, size);
        string c1 = c;
        string c2 = a2.get_str();
        ok &= check(c1 == c2);

        biDelete(b);
    }

    biDelete(a);

    check(ok, 1);
}

void test6() {
    cout << "test 6: ";
    cout.flush();
    bool ok = 1;

    BigInt a, b;
    a = biFromInt(0);
    b = biFromInt(0);
    biMul(a, b);
    biToString(a, c, size);
    ok &= check((string)c == "0");
    biDelete(a);
    biDelete(b);

    a = biFromInt(2);
    b = biFromInt(3);
    biMul(a, b);
    biToString(a, c, size);
    ok &= check((string)c == "6");
    biDelete(a);
    biDelete(b);

    a = biFromString("-100000");
    b = biFromString("100000");
    biMul(a, b);
    biToString(a, c, size);
    ok &= check((string)c == "-10000000000");
    biDelete(a);
    biDelete(b);

    a = biFromString("-100000000000000000000");
    b = biFromString("-100000000000000000000");
    biMul(a, b);
    biToString(a, c, size);
    ok &= check((string)c == "10000000000000000000000000000000000000000");
    biDelete(a);
    biDelete(b);

    a = biFromString("543534651454354353461464534");
    b = biFromString("986825976248623595236852396");
    biMul(a, b);
    biToString(a, c, size);
    ok &= check((string)c == "536374113046398593484849759421413903658458498546923464");
    biDelete(a);
    biDelete(b);

    a = biFromString("-10000000000000000000000000000000000000000");
    b = biFromString("-10000000000000000000000000000000000000001");
    biMul(a, b);
    biToString(a, c, size);
    ok &= check((string)c == "100000000000000000000000000000000000000010000000000000000000000000000000000000000");
    biDelete(a);
    biDelete(b);
    

    check(ok, 1);
}

void test8() {
    cout << "test 8: ";
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
    biSub(bi1, bi2);
    biToString(bi1, c, size);
    ok &= check((string)(c) == "0");
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216");
    bi2 = biFromString("-179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137215");
    bi3 = biFromString("1");
    biAdd(bi1, bi2);
    biToString(bi1, c, size);
    ok &= check(biCmp(bi1, bi3) == 0);
    biDelete(bi1);
    biDelete(bi2);
    biDelete(bi3);

    check(ok, 1);
}

void test9() {
    cout << "test 9: ";
    cout.flush();
    bool ok = 1;

    BigInt a = biFromInt(3);
    ok &= check(biCmp(a, a) == 0);
    biDelete(a);

    check(ok, 1);
}

void test10() {
    cout << "test " << 10 << ": ";
    cout.flush();
    bool ok = 1;

    BigInt a = biFromInt(0);
    mpz_class a2 = 0;
    string s = genRandNumber(100);
    BigInt b = biFromInt(0);
    biAdd(a, b);
    a2 += mpz_class(s);
    biDelete(a);
    biDelete(b);
    
    check(ok, 1);
}

void gmpDivision(mpz_class a1, mpz_class a2, mpz_class &x1, mpz_class &x2) {
    x1 = a1 / a2;
    x2 = a1 % a2;
    if (a1 < 0 && a2 > 0) {
        if (x2 < 0) {
            x2 += a2;
            x1--;
        }
    } else
    if (a1 > 0 && a2 < 0) {
        if (x2 > 0) {
            x2 += a2;
            x1--;
        }
    }
    assert(x1 * a2 + x2 == a1);
    if (a2 < 0) assert(x2 <= 0);
}

void testDelete(string s1, string s2, bool &ok) {
    // s2 != 0
    BigInt a = biFromString(s1.c_str());
    BigInt b = biFromString(s2.c_str());
    BigInt x, y;
    biDivRem(&x, &y, a, b);
    mpz_class a1 = 0;
    a1 += mpz_class(s1);
    mpz_class a2 = 0;
    a2 += mpz_class(s2);

    mpz_class x1, x2;
    gmpDivision(a1, a2, x1, x2);
    s1 = x1.get_str();
    s2 = x2.get_str();

    biToString(x, c, size);
    string c1 = (string)(c);
    ok &= check(c1 == s1);

    biToString(y, c, size);
    string c2 = (string)(c);
    ok &= check(c2 == s2);

    biDelete(a);
    biDelete(b);
    biDelete(x);
    biDelete(y);
}

void test11() {
    cout << "test 11: ";
    cout.flush();
    bool ok = 1;

    BigInt a, b;
    BigInt x, y;

    a = biFromInt(1);
    b = biFromInt(0);
    biDivRem(&x, &y, a, b);
    ok &= check(x == 0 && y == 0);
    biDelete(a);
    biDelete(b);
    
    a = biFromInt(0);
    b = biFromInt(1);
    biDivRem(&x, &y, a, b);
    biToString(x, c, size);
    ok &= check((string)(c) == "0");
    biToString(y, c, size);
    ok &= check((string)(c) == "0");
    biDelete(a);
    biDelete(b);
    biDelete(x);
    biDelete(y);
    
    testDelete("3", "15", ok);
    testDelete("16", "3", ok);
    testDelete("-16", "3", ok);
    testDelete("-16", "-3", ok);
    testDelete("16", "-3", ok);
    testDelete("15", "3", ok);
    testDelete("-15", "3", ok);
    testDelete("-15", "-3", ok);
    testDelete("15", "-3", ok);
    testDelete("1000000000000000", "100000", ok);
    testDelete("10000000000000000000000000", "10000000000000000000000000", ok);
    testDelete("100000000000000000000", "1", ok);
    testDelete("100000000000000000000000000000000000000000000000000", "100000000000000000000", ok);

    a = biFromInt(534635);
    biDivRem(&x, &y, a, a);
    biToString(x, c, size);
    ok &= check((string)(c) == "1");
    biToString(y, c, size);
    ok &= check((string)(c) == "0");
    biDelete(a);
    biDelete(x);
    biDelete(y);
    
    check(ok, 1);
}

void test12(int iterations, int size) {
    cout << "test 12: ";
    cout.flush();
    bool ok = 1;

    for (int it = 0; it < iterations; it++) {
        testDelete(genRandNumber(size * 2), genRandNumber(size), ok);
    }

    check(ok, 1);
}

int main() {
    test1();
    test2();
    test3();
    test4();
    test5(5, 2, 1000, 1000);
    test6();
    test5(7, 3, 100, 200);
    test8(); 
    test9();
    test10();
    test11();
    test12(1000, 100);
    return 0;
}