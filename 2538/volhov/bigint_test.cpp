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
#define success (cout << "PASSED " << __func__ << endl)

extern "C" {
    unsigned long int* biDump(BigInt x);
    BigInt biFromUInt(unsigned long int x);
    size_t biSize(BigInt x);
    void biExpand(BigInt x, size_t size);
    void biCutTrailingZeroes(BigInt a);
    void biAddUnsigned(BigInt a, BigInt b);
    void biSubUnsigned(BigInt a, BigInt b);
    void biNegate(BigInt a);
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
    success;
}

void test_expand() {
    BigInt a = biFromInt(55);
    assertion(__func__, (biSize(a) == 1));
    for (int i = 2; i < 100; i++) {
        biExpand(a, i);
        assertion(__func__, biSize(a) == i);
    }
    biDelete(a);
    success;
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
    success;
}

void test_addition_unsigned() {
    for (unsigned long int i = 0; i < 10000; i++) {
        unsigned long int ia = rand() % 0xff;
        unsigned long int ib = rand() % 0xff;
        BigInt a = biFromUInt(ia);
        BigInt b = biFromUInt(ib);
        biAddUnsigned(a, b);
        assert(biCmp(a, biFromUInt(ia + ib)) == 0);
        biAddUnsigned(b, a);
        assert(biCmp(b, biFromUInt(ib + ib + ia)) == 0);
        biDelete(a);
        biDelete(b);
    }
    success;
}


//strange test
void test_create_big_number(bool verbose = false) {
    BigInt a = biFromInt(51);
    if (verbose) dump(a);
    for (int i = 0; i < 2000; i++) {
        if (verbose) cout << i << endl;
        biAddUnsigned(a, a);
        if (verbose) dump(a);
    }
    biDelete(a);
    success;
}

void test_addition_same_sign() {
    for (int i = 0; i < 2000000; i++) {
        long int ia = rand() % 0xff + 1;
        long int ib = rand() % 0xff + 1;
        if (rand() % 2 == 0) {
            ia = -ia;
            ib = -ib;
        }
        BigInt a = biFromInt(ia);
        BigInt b = biFromInt(ib);
        biAddUnsigned(a, b);
        if (biCmp(a, biFromInt(ia + ib)) != 0) {
            cout << "mda" << endl;
        }
        assert(biCmp(a, biFromInt(ia + ib)) == 0);
        biAddUnsigned(b, a);
        assert(biCmp(b, biFromInt(ib + ib + ia)) == 0);
        biDelete(a);
        biDelete(b);
    }
    success;
}

void test_negation() {
    for (int i = 0; i < 100000; i++) {
        int temp = rand() % 0xfffff - 0xffff;
        BigInt a = biFromInt(temp);
        biNegate(a);
        assert(biCmp(a, biFromInt(-temp)) == 0);
        biDelete(a);
    }
    success;
}

void test_sub_unsigned_zeroes() {
    BigInt zero = biFromInt(0);
    BigInt zero2 = biFromInt(0);
    BigInt a = biFromUInt(0xdeadbabe);
    BigInt b = biFromUInt(0xdeadbabe);
    biSubUnsigned(a, b);
    assert(biCmp(a, zero) == 0);
    biSubUnsigned(zero, zero2);
    assert(biCmp(zero, zero2) == 0);
    success;
}

void test_unsigned_add_sub() {
    for (int i = 0; i < 1000; i++) {
        int counter = rand() % 200;
        int ia = rand() % 0xffff;
        int ib = rand() % 0xffff;
        BigInt a = biFromUInt(ia);
        BigInt b = biFromUInt(ib);
        for (int j = 0; j < counter; j++) biAddUnsigned(a, b);
        for (int j = 0; j < counter; j++) biSubUnsigned(a, b);
        assert(biCmp(a, biFromUInt(ia)) == 0);
    }
    success;
}

int main() {
    test_sign();
    test_expand();
    test_addition_zeroes();
    test_addition_unsigned();
    test_create_big_number();
    test_addition_same_sign();
    test_negation();
    test_sub_unsigned_zeroes();
    test_unsigned_add_sub();
}
