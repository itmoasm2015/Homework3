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

    BigInt a = biFromInt(2ll);
    BigInt b = biFromInt(-123ll);
    BigInt c = biFromInt(-123ll);

    biAdd(a, b);
    biSub(a, b);

    cout << biCmp(b, c);

    printBigInt(a);

    return 0;
}
