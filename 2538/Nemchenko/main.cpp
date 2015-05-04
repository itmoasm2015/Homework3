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
    int size = 15;
    unsigned long long* b = new unsigned long long[4];
    b[0] = 20;   // capacity
    b[1] = size; // size
    b[2] = 1;    // sign
    b[3] = (unsigned long long) new unsigned long long[size];      // data

    unsigned long long* data = (unsigned long long*) b[3];
    for (int i = 0; i < size; ++i) {
        data[i] = -1;
    }

    cout << endl;
    cout << biAdd(bb, b) << endl;
    cout << endl;
    printbBigNum(bb);
    
    return 0;
}
