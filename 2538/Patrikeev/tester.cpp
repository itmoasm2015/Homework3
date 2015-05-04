#include "bigint.h"
#include <cmath>
#include <iostream>
#include <stdlib.h>

using namespace std;

typedef unsigned int uint;
typedef unsigned long long ull;

#define EPS 1e-6

const int N = 3000;


char s[10000005];
char s1[10000005];
char s2[10000005];
char buf[10000005];


void printBigInt(BigInt a) {
    biToString(a, buf, N);
    cout << buf << endl;
}

int64_t genInt() {
    return 1LL * rand() * rand() * rand() * rand();
}

const int MAX_LEN = 1000;

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

void test8() {
    cout << "Mul ... ";
    for (int i = 0; i < 1; i++) {
        int len1 = rand() % 1000 + 1;
        int len2 = rand() % 1000 + 1;
        genBigIntAsString(s1, len1);
        BigInt a = biFromString(s1);
        genBigIntAsString(s2, len2);
        BigInt b = biFromString(s2);

        BigInt * q = new BigInt();
        BigInt * r = new BigInt();

        biDivRem(q, r, a, b);
        biMul(a, b);
        // biToString(a, buf, len1+len2+5);

        /*if (myStrCmp(buf, bigIntegerToString(aa).c_str()) != true) {
            cout << s1 << " * " << s2 << " != " << buf << "\n";
            cout << s1 << " * " << s2 << " == " << bigIntegerToString(aa).c_str() << "\n";
            return;
        }*/

        biDelete(a);
        biDelete(b);
    }
    cout << " OK\n";
}

void testDivision() {
    BigInt * q = new BigInt();
    BigInt * r = new BigInt();

    BigInt a = biFromString("6703903964971298549787012499102923063739682910296196688861780721860882015023660034294811089951732299792782023528860199663493147528504713584320662571322642");
    BigInt b = biFromString("57896044618658097711785492504343953926634992332820282019728792003956564819949");

    biDivRem(q, r, a, b);

    if (*q == NULL) {
        cout << "quotient is NULL" << endl;
    } else {
        cout << "quotient = ";
        printBigInt(*q);
    }

    if (*r == NULL) {
        cout << "remainder is NULL" << endl;
    } else {
        cout << "remainder = ";
        printBigInt(*r);
    }
}

int main() {  
    srand(time(NULL));
    test8();
    testDivision();
}
