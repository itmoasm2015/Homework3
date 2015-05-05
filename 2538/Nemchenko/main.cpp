#include <iostream>
#include <cstdio>
#include <bigint.h>

using namespace std;

extern "C" {
    void add_short(BigInt src, int64_t num);
    void mul_short(BigInt src, int64_t num);
}

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
    //BigInt a = biFromInt(112480259271058691LL);
    //printbBigNum(a);
    //mul_short(a, 82);
    //printbBigNum(a);
    //mul_short(a, 10);
    //printbBigNum(a);
    //int64_t t = 1ULL << 63;
    //cout << t << endl;
    //printbBigNum(biFromInt(t));

    //BigInt bb = biFromInt(1LL << 62);
    //mul_short(bb, 2);
    //BigInt bc = biFromInt(1LL << 62);
    //mul_short(bc, 2);
    //printbBigNum(bb);
    //printbBigNum(bc);

    //for (int i = 0; i < 1000000; ++i) {
        //biAdd(bb, bc);
    //}
    //printbBigNum(bb);

    //bb = biFromInt(1ULL << 62);
    //mul_short(bb, 2);
    //unsigned long long a = 1LL << 63;
    //for (int i = 0; i < 1000000; ++i) {
        //add_short(bb, a);
    //}
    //printbBigNum(bb);

    BigInt nn = biFromString("08l0");
    cout << nn << endl;
    printbBigNum(nn);



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
