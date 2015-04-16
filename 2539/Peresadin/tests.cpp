#include "bigint.h"
#include <cstdio>
#include <cmath>
#include <cstdlib>
#include <ctime>
#include <cassert>
#include "vectorint.h"
#include <vector>
#include <iostream>
using namespace std;
const int T = 30000000;

int main() {
    int l = clock();
    vector <int> a;
    for (int i = 0; i < T; ++i)
        a.push_back(i);
    int sum = 0;
    for (int i = 0; i < T; ++i)
        sum += a[i];
    for (int i = 0; i < T; ++i)
        a.pop_back();
    cout << 1.0 * (clock() - l) / CLOCKS_PER_SEC << endl;
/*    VectorInt a = newVector(10);
    vector <int> b(10);
    for (int i = 0; i < T; ++i) {
        pushBack(a, i);
        b.push_back(i);
    }

    for (int i = 0; i < b.size(); ++i) {
        int bi = b[i];
        int ai = element(a, i);
        assert(bi == ai);
    }

    for (int i = 0; i < 3 * T / 4; ++i) {
        popBack(a);
        b.pop_back();
    }

    for (int i = 0; i < b.size(); ++i) {
        int bi = b[i];
        int ai = element(a, i);
        assert(bi == ai);
    }

    pushBack(a, 1);
    deleteVector(a);*/
    return 0;
}
