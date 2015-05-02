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

    BigInt a = biFromString("-123897129837129837216298371629837162983716928736");
    BigInt b = biFromString("123897129837129837216298371629837162983716928736");

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

    BigInt a = biFromString("-");
    cout << a << endl;
    cout << biCmp(a, a) << endl; 

    

    return 0;
}
