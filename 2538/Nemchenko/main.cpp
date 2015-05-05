#include <iostream>
#include <cstdio>
#include <bigint.h>

using namespace std;

void printbBigNum(BigInt x) {
    cout << "-----BEGIN--------" << endl;
    unsigned long long* res = (unsigned long long*) x;
    unsigned long long size;
    cout << "capacity: " << *(res++) << endl; 
    cout << "size: " << (size = *(res++)) << endl; 
    cout << "sign: " << *(long long*)(res++) << endl; 
    
    res = (unsigned long long*) *res;
    for (unsigned long long i = 0; i < size; ++i) {
        cout << "dig[" << i << "] = " << *(res++) << endl;
    }
    cout << "------END-------" << endl;
}


int main() {
    //int64_t t = 1ULL << 63;
    //cout << t << endl;
    //printbBigNum(biFromInt(t));

    BigInt bb = biFromInt(1LL << 62);
    BigInt bc = biFromInt(1LL << 62);
    printbBigNum(bb);
    printbBigNum(bc);

    BigInt cc = biFromInt(1LL << 63);
    printbBigNum(cc);
    BigInt cb = biFromInt(-100);
    printbBigNum(cb);
    for (int i = 0; i < 1000000 - 1; ++i) {
        biAdd(bb, bc);
    }
    printbBigNum(bb);

    //int size = 15;
    //unsigned long long* b = new unsigned long long[4];
    //b[0] = 20;   // capacity
    //b[1] = size; // size
    //b[2] = 1;    // sign
    //b[3] = (unsigned long long) new unsigned long long[size];      // data

    //unsigned long long* data = (unsigned long long*) b[3];
    //for (int i = 0; i < size; ++i) {
        //data[i] = -1;
    //}

    //cout << endl;
    //cout << biAdd(bb, b) << endl;
    //cout << endl;
    //printbBigNum(bb);
    
    return 0;
}
