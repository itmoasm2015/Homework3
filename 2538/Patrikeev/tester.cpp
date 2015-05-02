#include "bigint.h"
#include <cmath>
#include <iostream>
#include <stdlib.h>

using namespace std;

typedef unsigned int uint;
typedef unsigned long long ull;

#define EPS 1e-6

const int N = 3000;

char buf[N];

void printBigInt(BigInt a) {
    biToString(a, buf, N);
    // for (int i = 0; i < N; i++) {
        // cout << (int) buf[i] << ' ';
    // }
    cout << buf << endl;
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
    BigInt a = biFromString("1");
    biSign(a);

    // testDivision();
}
