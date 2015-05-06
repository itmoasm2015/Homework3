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


void test_add() {
    BigInt n1 = biFromString("1");
    BigInt n2 = biFromString("100000000000000000000000000000000000000000000000000000000000000000000000");
    biAdd(n1, n2);
    //printbBigNum(n1);

    n1 = biFromString("1");
    n2 = biFromString("100000000000000000000000000000000000000000000000000000000000000000000000");
    biAdd(n2, n1);
    //printbBigNum(n2);

    n1 = biFromString("0");
    n2 = biFromString("100000000000000000000000000000000000000000000000000000000000000000000001");
    biAdd(n1, n2);
    //printbBigNum(n1);

    n1 = biFromString("0");
    n2 = biFromString("100000000000000000000000000000000000000000000000000000000000000000000001");
    biAdd(n2, n1);
    //printbBigNum(n2);

    n1 = biFromString("0");
    n2 = biFromString("0");
    biAdd(n2, n1);
    //printbBigNum(n2);

    n1 = biFromString("0");
    n2 = biFromString("-871264891273649182376192834761293487");
    biAdd(n1, n2);
    printbBigNum(n1);
    printbBigNum(n2);

    n1 = biFromString("0");
    n2 = biFromString("-871264891273649182376192834761293487");
    biAdd(n2, n1);

    n1 = biFromString("-12341234981273409182570918237409128347");
    n2 = biFromString("-871264891273649182376192834761293487");
    biAdd(n2, n1);
    printbBigNum(n2);

    n1 = biFromString("12341234981273409182570918237409128347");
    n2 = biFromString("871264891273649182376192834761293487");
    biAdd(n2, n1);
    printbBigNum(n2);

    n1 = biFromString("-12341234981273409182570918237409128347");
    n2 = biFromString("871264891273649182376192834761293487");
    biAdd(n1, n2);
    //printbBigNum(n2);

    n1 = biFromString("12341234981273409182570918237409128347");
    n2 = biFromString("-871264891273649182376192834761293487");
    biAdd(n1, n2);
    //printbBigNum(n2);

}
int main() {
    test_add();
    return 0;
}
