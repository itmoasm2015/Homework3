#include <iostream>
#include <cstdio>
#include <bigint.h>

using namespace std;

void printbBigNum(void* x) {
    int* res = (int*) x;
    int size;
    cout << "capacity: " << *(res++) << endl; 
    cout << "size: " << (size = *(res++)) << endl; 
    cout << "sign: " << *(res++) << endl; 
    unsigned long long* res2 = (unsigned long long*) (++res);
    
    for (int i = 0; i < size; ++i) {
        cout << "dig[" << i << "] = " << *(res2 + i) << endl;
    }
}

int main() {
    int64_t t = 1ULL << 63;
    printbBigNum(biFromInt(t));
    
    return 0;
}
