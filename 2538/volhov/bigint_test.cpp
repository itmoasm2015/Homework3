#include <algorithm>
#include <cassert>
#include <cstdlib>
#include <vector>
#include <string>
#include <string.h>
#include <iostream>
#include <utility>
#include <bigint.h>

using namespace std;

#define success (cout << " \033[32m[PASSED]\033[0m " << __func__ << endl)

extern "C" {
    unsigned long int* biDump(BigInt x);
    BigInt biFromUInt(unsigned long int x);
    BigInt biCopy(BigInt a);
    size_t biSize(BigInt x);
    void biExpand(BigInt x, size_t size);
    void biCutTrailingZeroes(BigInt a);
    void biAddUnsigned(BigInt a, BigInt b);
    void biSubUnsigned(BigInt a, BigInt b);
    void biAddShort(BigInt a, unsigned long int b);
    void biMulShort(BigInt a, unsigned long int b);
    int biDivShort(BigInt a, unsigned long int b);
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

void test_copy() {
    for (int i = 0; i < 100; i++) {
        long int temp = (rand() % 1000);
        BigInt a = biFromInt(temp);
        BigInt b = biCopy(a);
        assert(biCmp(a, b) == 0);
        biDelete(a);
        biDelete(b);
    }
    success;
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
        BigInt temp1 = biFromUInt(ia + ib);
        assert(biCmp(a, temp1) == 0);
        biAddUnsigned(b, a);
        BigInt temp2 = biFromUInt(ib + ib + ia);
        assert(biCmp(b, temp2) == 0);
        biDelete(a);
        biDelete(b);
        biDelete(temp1);
        biDelete(temp2);
    }
    success;
}

//strange test
void test_create_big_number(bool verbose = false) {
    BigInt a = biFromInt(51);
    if (verbose) dump(a);
    for (int i = 0; i < 1000; i++) {
        if (verbose) cout << i << endl;
        biAddUnsigned(a, a);
        if (verbose) dump(a);
    }
    biDelete(a);
    success;
}

void test_addition_same_sign() {
    for (int i = 0; i < 20000; i++) {
        long int ia = rand() % 0xff + 1;
        long int ib = rand() % 0xff + 1;
        if (rand() % 2 == 0) {
            ia = -ia;
            ib = -ib;
        }
        BigInt a = biFromInt(ia);
        BigInt b = biFromInt(ib);
        biAddUnsigned(a, b);
        BigInt temp1 = biFromInt(ia + ib);
        assert(biCmp(a, temp1) == 0);
        biAddUnsigned(b, a);
        BigInt temp2 = biFromInt(ib + ib + ia);
        assert(biCmp(b, temp2) == 0);
        biDelete(a);
        biDelete(b);
        biDelete(temp1);
        biDelete(temp2);
    }
    success;
}

void test_negation() {
    for (int i = 0; i < 100000; i++) {
        int temp = rand() % 0xfffff - 0xffff;
        BigInt a = biFromInt(temp);
        biNegate(a);
        BigInt temp2 = biFromInt(-temp);
        assert(biCmp(a, temp2) == 0);
        biDelete(a);
        biDelete(temp2);
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
    biDelete(zero);
    biDelete(zero2);
    biDelete(a);
    biDelete(b);
}

void test_unsigned_add_sub() {
    for (int i = 0; i < 10000; i++) {
        int counter = rand() % 200;
        int ia = rand() % 0xffff;
        int ib = rand() % 0xffff;
        BigInt a = biFromUInt(ia);
        BigInt b = biFromUInt(ib);
        for (int j = 0; j < counter; j++) biAddUnsigned(a, b);
        for (int j = 0; j < counter; j++) biSubUnsigned(a, b);
        BigInt temp = biFromUInt(ia);
        assert(biCmp(a, temp) == 0);
        biDelete(a);
        biDelete(b);
        biDelete(temp);
    }
    success;
}

void test_sub_signed(bool verbose = false) {
    for (int i = 0; i < 200000; i++) {
        int ia = rand() % 1000 - 500;
        int ib = rand() % 1000 - 500;
        if (verbose) cout << ia << " " << ib << endl;
        BigInt a = biFromInt(ia);
        BigInt b = biFromInt(ib);
        biSub(a, b);
        BigInt temp = biFromInt(ia - ib);
        assert(biCmp(a, temp) == 0);
        biDelete(a);
        biDelete(b);
        biDelete(temp);
    }
    success;
}

void test_add_signed(bool verbose = false) {
    for (int i = 0; i < 200000; i++) {
        int ia = rand() % 1000 - 500;
        int ib = rand() % 1000 - 500;
        if (verbose) cout << ia << " " << ib << endl;
        BigInt a = biFromInt(ia);
        BigInt b = biFromInt(ib);
        biAdd(a, b);
        BigInt temp = biFromInt(ia + ib);
        assert(biCmp(a, temp) == 0);
        biDelete(a);
        biDelete(b);
        biDelete(temp);
    }
    success;
}

void test_mul_short() {
    // stage 1
    int ia = 277;
    BigInt a = biFromInt(ia);
    BigInt b = biFromInt(ia);
    biMulShort(a, 10000000);
    biMulShort(a, 10000000);
    biMulShort(a, 10000000);
    biMulShort(a, 10000000);
    biMulShort(b, 10000);
    biMulShort(b, 10000);
    biMulShort(b, 10000);
    biMulShort(b, 10000);
    biMulShort(b, 10000);
    biMulShort(b, 10000);
    biMulShort(b, 10000);
    assert(biCmp(a, b) == 0);
    biDelete(a);
    biDelete(b);
    //stage 2
    for (int i =0 ; i < 200000; i++) {
        unsigned long int ia = rand() % 10000;
        unsigned long int ib = rand() % 10000;
        BigInt temp = biFromUInt(ia);
        biMulShort(temp, ib);
        BigInt expected = biFromUInt(ia * ib);
        assert(biCmp(temp, expected) == 0);
        biDelete(temp);
        biDelete(expected);
    }
    success;
}


void test_from_string_visual() {
    string s = "100";
    for (int i = 0; i < 39; i++) {
        BigInt a = biFromString(s.c_str());
        dump(a);
        s += "0";
        biDelete(a);
    }
    //BigInt a = biFromString("12345678123456781234567812345678");
    //dump(a);
    //BigInt b = biFromString("81818181818181818181818181818181");
    //dump(b);
    //BigInt sum = biFromString("94163859941638599416385994163859");
    //dump(sum);
    //biAdd(a, b);
    //assert(biCmp(a, sum) == 0);
    //success;
}

void test_signed_mul_zeroes() {
    BigInt a = biFromString("-10012341234123412341324132412341234123412341234123");
    BigInt b = biFromString("0");
    biMul(b, a);
    BigInt res = biFromInt(0);
    assert(biCmp(b, res) == 0);
    biMul(a, b);
    assert(biCmp(a, res) == 0);
    biDelete(a);
    biDelete(b);
    biDelete(res);
    success;
}

void test_signed_mul() {
    BigInt a = biFromString("-10000000000000000000");
    BigInt b = biFromString("5555555555555555555553333333");
    biMul(a, b);
    BigInt res = biFromString("-55555555555555555555533333330000000000000000000");
    assert(biCmp(a, res) == 0);
    biDelete(a);
    biDelete(b);
    biDelete(res);
    success;
}

void test_long_signed_mul() {
    BigInt a = biFromString("19194234123412383847149128479218374912");
    BigInt b = biFromString("-228228228228228228412341234123412341234");
    biMul(a, b);
    BigInt res = biFromString("-4380666046184207728408784309748588993540755470196621944651726970242688721408");
    assert(biCmp(a, res) == 0);
    biDelete(a);
    biDelete(b);
    biDelete(res);
    success;
}

void test_to_string_adequate() {
    BigInt a = biFromString("-000123123123123123123123123123123123089871293879182739");
    char buf[20];
    biToString(a, buf, 5); // this should simply not segfault
    biDelete(a);
    success;
}

void test_to_string() {
    for (int i = 0; i < 10000; i++) {
        string input = "";
        if (rand() % 1) input += "-";
        input += (char) (rand() % 9 + '1'); // first sign must be >0
        int size = rand() % 200;
        for (int i = 0 ; i < size; i++) {
            input += (char) (rand() % 10 + '0');
        }
        BigInt a = biFromString(input.c_str());
        char buf[1000];
        biToString(a, buf, 1000);
        assert(strcmp(input.c_str(), buf) == 0);
        biDelete(a);
    }
    success;
}

int main() {
    test_copy();
    test_sign();
    test_expand();
    test_addition_zeroes();
    test_addition_unsigned();
    test_create_big_number();
    test_addition_same_sign();
    test_negation();
    test_sub_unsigned_zeroes();
    test_unsigned_add_sub();
    test_sub_signed();
    test_add_signed();
    test_mul_short();
    //test_from_string_visual();
    test_signed_mul_zeroes();
    test_signed_mul();
    test_long_signed_mul();
    test_to_string_adequate();
    test_to_string();
}
