#include <iostream>
#include <cstdio>
#include <bigint.h>

using namespace std;

void printbBigNum(void* x) {
    unsigned long long* res = (unsigned long long*) x;
    int size;
    cout << "capacity: " << *(res++) << endl; 
    cout << "size: " << (size = *(res++)) << endl; 
    cout << "sign: " << *(res++) << endl; 
    
    res = (unsigned long long*) *res;
    for (int i = 0; i < size; ++i) {
        cout << "dig[" << i << "] = " << *(res++) << endl;
    }
}


int main() {
    //int64_t t = 1ULL << 63;
    //cout << t << endl;
    //printbBigNum(biFromInt(t));

    BigInt bb = biFromInt(777);
    printbBigNum(bb);
    unsigned long long* b = new unsigned long long[20];
    b[0] = 20;
    b[1] = 15;
    b[2] = 19;

    cout << endl;
    cout << biAdd(bb, b) << endl;
    cout << endl;
    printbBigNum(bb);
    
    return 0;
}
