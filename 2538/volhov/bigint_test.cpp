#include <algorithm>
#include <cassert>
#include <cstdlib>
#include <vector>
#include <iostream>
#include <utility>
#include <bigint.h>

using namespace std;

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
    cout << biSign(one) << endl;
    biDelete(one);
    BigInt zero = biFromInt(0);
    cout << biSign(zero) << endl;
    biDelete(zero);
}
