#include <algorithm>
#include <cassert>
#include <cstdlib>
#include <vector>
#include <iostream>
#include <utility>
#include <bigint.h>

using namespace std;
extern "C" {
    unsigned long int* biDump(BigInt x);
    size_t biSize(BigInt x);
    void biExpand(BigInt x, size_t size);
    void biCutTrailingZeroes(BigInt a);
    void biAddUnsigned(BigInt a, BigInt b);
}

void dump(BigInt a) {
    unsigned long int* data = biDump(a);
    if (biSign(a) < 0) cout << "-";
    if (biSize(a) == 0) cout << "0";
    for (int i = 0; i < biSize(a); i++) {
        cout << data[i]  << " ";
    }
    cout << endl;
}
int main() {
    //for (int i = -50; i < 50; i++) {
    //    BigInt a = biFromInt(i);
    //    if (biSign(a) < 0 && i < 0 || biSign(a) == 0 && i == 0 || biSign > 0 && i > 0) {}
    //    else {
    //        cout << "FAILED: " << i << " " << biSign(a) << endl;
    //    }
    //    biDelete(a);
    //}
    BigInt one = biFromInt(1);
    BigInt zero = biFromInt(0);
    BigInt zero2 = biFromInt(0);
    BigInt a = biFromInt(0xfffffffffffffff);
    BigInt b = biFromInt(0xfffffffffffffff);
    biAddUnsigned(zero, zero2);
    dump(zero);
}
