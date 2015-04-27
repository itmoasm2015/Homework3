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

    // BigInt a = biFromInt(0xffffffffll);
    // BigInt b = biFromInt(0xffffffffll);
    // BigInt c = biFromInt(0xffffffffll + 0xffffffffll);
    BigInt a = biFromString("-123123123");
    BigInt b = biFromString("12312312312783612873619823619827361982736981723691872369817263918726398123");
    cout << "a_address = " << (ull) a << endl;
    cout << "b_address = " << (ull) b << endl;

    printBigInt(a);
    printBigInt(b);

    cout << "CMP = " << biCmp(a, b) << endl;

    return 0;
}
