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

int main() {    

    printBigInt(a);
    return 0;
}
