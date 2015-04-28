#include "bigint.h"
#include <cmath>
#include <iostream>
#include <stdlib.h>

using namespace std;

typedef unsigned int uint;
typedef unsigned long long ull;

#define EPS 1e-6

const int N = 500;

char buf[N];

void printBigInt(BigInt a) {
    biToString(a, buf, N);
    cout << buf << endl;
}

int main() {    

    BigInt a = biFromInt(123LL);
    BigInt b = biFromString("18446744073709551616");
    printBigInt(a);

    biMul(a, b);

    printBigInt(a);

    return 0;
}
