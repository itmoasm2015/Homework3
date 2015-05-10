#include <algorithm>
#include <cassert>
#include <cstdlib>
#include <vector>
#include <string>
#include <iostream>
#include <utility>
#include <bigint.h>

using namespace std;

#define _assert(cond) (if (!(cond)) { cerr << "FAILED AT: " << __func__ << endl; })

extern "C" {
    unsigned long int* biDump(BigInt x);
    size_t biSize(BigInt x);
    void biExpand(BigInt x, size_t size);
    void biCutTrailingZeroes(BigInt a);
    void biAddUnsigned(BigInt a, BigInt b);
    BigInt biFromUInt(unsigned long int x);
}

void dump(BigInt a) {
    unsigned long int* data = biDump(a);
    if (biSign(a) < 0) cout << "-";
    if (biSize(a) == 0) cout << "0";
    for (int i = 0; i < biSize(a); i++) {
        cout << data[i]  << " ";
    }
    cout << endl;
}

void assertion(string s, bool res) {
    if (!res) {
        cerr << s << endl;
        assert(false);
    }
}

void test_sign() {
    for (int i = -50; i < 50; i++) {
        BigInt a = biFromInt(i);
        string s = ("test_sign(): for int i = " + to_string(i));
        assertion(s,
                biSign(a)<0 && i<0 ||
                biSign(a)==0 && i==0 ||
                biSign(a)>0 && i>0);
        biDelete(a);
    }
    cout << "PASSED " << __func__ << endl;
}

void test_expand() {
    BigInt a = biFromInt(55);
    assertion(__func__, (biSize(a) == 1));
    for (int i = 2; i < 100; i++) {
        biExpand(a, i);
        assertion(__func__, biSize(a) == i);
    }
    biDelete(a);
    cout << "PASSED " << __func__ << endl;
}

void test_addition_zeroes() {
    BigInt one = biFromInt(1);
    BigInt one2 = biFromInt(1);
    BigInt minus_one = biFromInt(-1);
    BigInt minus_one2 = biFromInt(-1);
    BigInt zero = biFromInt(0);
    BigInt zero2 = biFromInt(0);
    biAddUnsigned(zero, zero);
    biAddUnsigned(zero, zero);
    assert(biCmp(zero, zero2) == 0);
    biAddUnsigned(zero2, zero);
    biAddUnsigned(zero, zero2);
    assert(biCmp(zero, zero2) == 0);
    biAddUnsigned(one, zero);
    assert(biCmp(one, one2) == 0);
    biAddUnsigned(minus_one, zero2);
    assert(biCmp(minus_one, minus_one2) == 0);
    biDelete(one);
    biDelete(one2);
    biDelete(minus_one);
    biDelete(minus_one2);
    biDelete(zero);
    biDelete(zero2);
    cout << "PASSED " << __func__ << endl;
}

void test_addition_unsigned() {
    for (unsigned long int i = 0; i < 10000; i++) {
        unsigned long int ia = rand() % 0xffffffffff;
        unsigned long int ib = rand() % 0xffffffffff;
        BigInt a = biFromUInt(ia);
        BigInt b = biFromUInt(ib);
        biAddUnsigned(a, b);
        assert(biCmp(a, biFromUInt(ia + ib)) == 0);
        biAddUnsigned(b, a);
        assert(biCmp(b, biFromUInt(ib + ib + ia)) == 0);
    }
    cout << "PASSED " << __func__ << endl;
}

int main() {
    test_sign();
    test_expand();
    test_addition_zeroes();
    test_addition_unsigned();
    BigInt a = biFromUInt(0xffffffffffffffff);
    dump(a);
    for (int i = 0; i < 65; i++) {
        cout << i << endl;
        if (i == 63) {
            cout << "";
        }
        biAddUnsigned(a, a);
        dump(a);
    }
}
