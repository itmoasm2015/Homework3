#include "unistd.h"
#include "include/bigint.h"
#include <iostream>
#include <cstring>
#include <cassert>
#include <cstdlib>
#include <ctime>
#include <cstring>
#include "bigint/BigIntegerLibrary.hh"

using namespace std;

int64_t genInt() {
    return 1LL * rand() * rand() * rand() * rand();
}

void intToString(int64_t x, char *s) {
    if (x < 0) {
        x = -x;
        *s = '-';
        s++;
    }
    char tmp[40];
    int i = 0;
    do {
        tmp[i++] = '0' + (x%10);
        x /= 10;
    } while (x != 0);
    i--;
    for (; i >= 0; i--) {
        *s = tmp[i];
        s++;
    }
    *s = 0;
}

bool myStrCmp(const char *s1, const char *s2) {
    if (strlen(s1) != strlen(s2)) return false;
    int len = strlen(s1);
    for (int i = 0; i < len; i++) {
        if (s1[i] != s2[i]) {
            return false;
        }
    }
    return true;
}

void genBigIntAsString(char *s, int len) {
    int sign = rand() % 2;
    if (sign == 1) {
        s[0] = '-';
    }
    int curDig;
    curDig = rand() % 9;
    s[sign] = '1' + curDig;
    for (int i = 1; i < len; i++) {
        curDig = rand() % 10;
        s[i+sign] = '0' + curDig;
    }
    s[len+sign] = 0;
}

void genStuff(char *s, int len) {
    char c;
    do {
        c = rand() % 255 + 1;
    } while (c >= '0' && c <= '9' || c == '-');
    int pos = rand() % len;
    s[pos] = c;
}

char s[10000005];
char s1[10000005];
char s2[10000005];
char buf[10000005];
BigInteger aa, bb;

void test1() {
    cout << "From and to string ... ";
    for (int t = 0; t < 100; t++) {
        int len = rand() % 1000000 + 1;
        genBigIntAsString(s, len);
        BigInt a = biFromString(s);
        biToString(a, buf, len + 5);
        assert(myStrCmp(buf, s) == true);
        biDelete(a);
    }
    cout << " OK\n";
}

void test2() {
    cout << "Add ... ";
    for (int t = 0; t < 100; t++) {
        int len1 = rand() % 1000 + 1;
        int len2 = rand() % 1000 + 1;
        genBigIntAsString(s1, len1);
        BigInt a = biFromString(s1);
        genBigIntAsString(s2, len2);
        BigInt b = biFromString(s2);

        aa = stringToBigInteger(s1);
        bb = stringToBigInteger(s2);
        aa += bb;

        biAdd(a, b);
        biToString(a, buf, len1+len2+5);

        assert(myStrCmp(buf, bigIntegerToString(aa).c_str()) == true);

        biDelete(a);
        biDelete(b);
    }
    cout << " OK\n";
}

void test3() {
    cout << "Sub ... ";
    for (int t = 0; t < 100; t++) {
        int len1 = rand() % 1000 + 1;
        int len2 = rand() % 1000 + 1;
        genBigIntAsString(s1, len1);
        BigInt a = biFromString(s1);
        genBigIntAsString(s2, len2);
        BigInt b = biFromString(s2);

        aa = stringToBigInteger(s1);
        bb = stringToBigInteger(s2);
        aa -= bb;

        biSub(a, b);
        biToString(a, buf, len1+len2+5);
        assert(myStrCmp(buf, bigIntegerToString(aa).c_str()) == true);

        biDelete(a);
        biDelete(b);
    }
    cout << " OK\n";
}

void test4() {
    cout << "Cmp ... ";
    for (int t = 0; t < 1000; t++) {
        int len1 = rand() % 1000 + 1;
        int len2 = rand() % 1000 + 1;
        genBigIntAsString(s1, len1);
        BigInt a = biFromString(s1);
        genBigIntAsString(s2, len2);
        BigInt b = biFromString("0");

        aa = stringToBigInteger(s1);
        bb = stringToBigInteger(s2);



       // assert(biCmp(a, b) == aa.compareTo(bb));

        biDelete(a);
        biDelete(b);
    }
    cout << " OK\n";
}

void test5() {
    cout << "Sign ... ";
    for (int t = 0; t < 100; t++) {
        int len = rand() % 1000 + 1;
        genBigIntAsString(s, len);
        BigInt a = biFromString(s);

        aa = stringToBigInteger(s);

        assert(biSign(a) == aa.getSign());

        biDelete(a);
    }
    cout << " OK\n";
}

void test6() {
    cout << "Stuff in string ...";
    BigInt tmp = biFromString("-");
    assert(tmp == NULL);
    for (int t = 0; t < 100; t++) {
        int len = rand() % 1000000 + 1;
        genBigIntAsString(s, len);
        genStuff(s, len);
        BigInt a = biFromString(s);
        assert(a == NULL);
    }
    cout << " OK\n";
}

void test7() {
    cout << "From int ...";
    for (int t = 0; t < 10000; t++) {
        int64_t x = genInt();
        BigInt a = biFromInt(x);
        biToString(a, buf, 1000);
        intToString(x, s);
        assert(myStrCmp(buf, s) == true);
        biDelete(a);
    }
    cout << " OK\n";
}

void test8() {
    cout << "Mul ... ";
    for (int t = 0; t < 100; t++) {
        int len1 = rand() % 1000 + 1;
        int len2 = rand() % 1000 + 1;
        genBigIntAsString(s1, len1);
        BigInt a = biFromString(s1);
        genBigIntAsString(s2, len2);
        BigInt b = biFromString(s2);

        aa = stringToBigInteger(s1);
        bb = stringToBigInteger(s2);
        aa *= bb;

        biMul(a, b);
        biToString(a, buf, len1+len2+5);

        /*if (myStrCmp(buf, bigIntegerToString(aa).c_str()) != true) {
            cout << s1 << " * " << s2 << " != " << buf << "\n";
            cout << s1 << " * " << s2 << " == " << bigIntegerToString(aa).c_str() << "\n";
            return;
        }*/

        assert(myStrCmp(buf, bigIntegerToString(aa).c_str()) == true);

        biDelete(a);
        biDelete(b);
    }
    cout << " OK\n";
}

void test9() {
    cout << "Saving test1 ... ";
    for (int t = 0; t < 1000; t++) {
        int len1 = rand() % 1000 + 1;
        int len2 = rand() % 1000 + 1;
        genBigIntAsString(s1, len1);
        BigInt a = biFromString(s1);
        BigInt a2 = biFromString(s1);;
        genBigIntAsString(s2, len2);
        BigInt b = biFromString(s2);
        BigInt b2 = biFromString(s2);
        biAdd(a, b);
        biSub(a, b);
        assert(biCmp(a, a2) == 0);
        assert(biCmp(b, b2) == 0);
    }
    cout << " OK\n";
}

void test10() {
    cout << "Saving test2 ... ";
    for (int t = 0; t < 1000; t++) {
        int len1 = rand() % 1000 + 1;
        int len2 = rand() % 1000 + 1;
        genBigIntAsString(s1, len1);
        BigInt a = biFromString(s1);
        BigInt a2 = biFromString(s1);;
        genBigIntAsString(s2, len2);
        BigInt b = biFromString(s2);
        BigInt b2 = biFromString(s2);
        biMul(a, b);
        assert(biCmp(b, b2) == 0);
        biMul(b, a2);
        assert(biCmp(b, a) == 0);
    }
    cout << " OK\n";
}

void test11() {
    cout << "Int operations test ... ";
    for (int t = 0; t < 1000; t++) {
        int64_t i1 = genInt() / 2ll;
        int64_t i2 = genInt() / 2ll;
        BigInt bi1 = biFromInt(i1);
        BigInt bi2 = biFromInt(i2);
        BigInt bi3 = biFromInt(i1+i2);
        BigInt bi4 = biFromInt(i1-i2);
        biAdd(bi1, bi2);
        assert(biCmp(bi1, bi3) == 0);
        biMul(bi2, biFromInt(2ll));
        biSub(bi1, bi2);
        assert(biCmp(bi1, bi4) == 0);
    }
    cout << " OK\n";
}

void testFail() {
    cout << "Test from mail ... ";
    BigInt bi1, bi2, bi3, bi4, bi5;
    bi1 = biFromInt(2ll);
    bi2 = biFromInt(-123ll);
    bi3 = biFromInt(-123ll);
    biAdd(bi1, bi2);
    biSub(bi1, bi2);
    assert(biCmp(bi2, bi3) == 0);


    bi1 = biFromInt(0xffffffffll);
    bi2 = biFromInt(0xffffffffll);
    bi5 = biFromInt(0xffffffffll + 0xffffffffll);
    biAdd(bi1, bi2);
    assert(biCmp(bi1, bi5) == 0);
    cout << " OK\n";
}

int main() {
    srand(time(NULL));
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8();
    test9();
    test10();
    test11();
    testFail();
    return 0;
}
