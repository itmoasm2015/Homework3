#include <bits/stdc++.h>
#include "bigint.h"

using namespace std;

bool check(bool f, bool print = false) {
    if (print) cout << (f ? "OK" : "FAIL") << endl;
    return f;
}

void test1() {
    cout << "testing 1 test: " << endl;
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
    cout << "test 1 is finished" << endl;
}

void test2() {
    cout << "testing 2 test: " << endl;
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
    cout << "test 2 is finished" << endl;
}

void test3() {
    cout << "testing 3 test: " << endl;
    bool ok = 1;

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
    cout << "test 3 is finished" << endl;
}

void test4() {
    cout << "testing 4 test: " << endl;
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
    cout << "test 4 is finished" << endl;
}

void test5() {
    cout << "testing 5 test: " << endl;
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


    check(ok, 1);
    cout << "test 5 is finished" << endl;    
}

void test6() {
    cout << "testing 6 test: " << endl;
    bool ok = 1;

    int n = 100;
    vector<string> v(n);
    for (int i = 0; i < n; i++) {
        if (rand() % 2) v[i] += "-";
        for (int j = 0; j < 1000; j++) {
            v[i] += (char)('0' + rand() % 10);
        }
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
    cout << "test 6 is finished" << endl;
}

int main() {
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
}
