#include <bits/stdc++.h>
#include "bigint.h"

using namespace std;

void check(bool f) {
    cout << (f ? "OK" : "FAIL") << endl;
}

void test1() {
    cout << "testing 1 test: " << endl;

    BigInt a, b;

    a = biFromInt(15);
    check(biSign(a) == 1);
    biDelete(a);

    a = biFromInt(0);
    check(biSign(a) == 0);
    biDelete(a);

    a = biFromInt(-1000000000000LL);
    check(biSign(a) == -1);
    b = biCopy(a);
    check(biSign(b) == -1);
    biDelete(b);
    biDelete(a);

    cout << "test 1 is finished" << endl;
}

int main() {
    test1();
}
