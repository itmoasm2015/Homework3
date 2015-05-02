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

    BigInt a = biFromString("1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111");
    BigInt b = biFromString("100000000000000000000000000000000");

    printBigInt(a);
    return;

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
}
