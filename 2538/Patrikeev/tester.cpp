#include "bigint.h"
#include <cmath>
#include <iostream>
#include <stdlib.h>

using namespace std;

typedef unsigned int uint;
typedef unsigned long long ull;

#define EPS 1e-6

const int N = 1000;

char buf[N];

void printBigInt(BigInt a) {
    biToString(a, buf, N);
    cout << buf << endl;
}

void testDivision() {
    BigInt * q = new BigInt();
    BigInt * r = new BigInt();

    BigInt a = biFromString("340282366920938463463374607431768211456");
    BigInt b = biFromString("340282366920938463463374607431768211455");

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

    testDivision();    

    return 0;
}
