#include "bigint.h"
#include <cmath>
#include <iostream>
#include <stdlib.h>

using namespace std;

typedef unsigned int uint;

#define EPS 1e-6

const int N = 30;

char buf[N];

int main() {    

    BigInt a = biFromString("999999999999999999999999999999999");
    cout << "AA " << (unsigned long long) a << endl;
    biToString(a, buf, 30);

    cout << buf << endl;

    for (int i = 0; i < N; i++) {
        cout << (int) buf[i] << ' ';
    }
    cout << endl;


    return 0;
}
