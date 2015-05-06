#include <iostream>
#include <cstdio>
#include <bigint.h>
#include <cassert>

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
    cerr << "---TEST_BI_ADD_CMP----" << endl;
    BigInt n1 = biFromString("1");
    BigInt n2 = biFromString("100000000000000000000000000000000000000000000000000000000000000000000000");
    assert(biCmp(n1, n2) == -1);
    biAdd(n1, n2);
    assert(biCmp(n1, n2) == 1);
    assert(biCmp(n1, n1) == 0);
    assert(biCmp(n2, n2) == 0);

    BigInt n3 = biFromString("1");
    BigInt n4 = biFromString("100000000000000000000000000000000000000000000000000000000000000000000000");
    biAdd(n3, n4);
    assert(biCmp(n1, n3) == 0);

    BigInt n5 = biFromString("0");
    BigInt n6 = biFromString("100000000000000000000000000000000000000000000000000000000000000000000001");
    biAdd(n5, n6);
    assert(biCmp(n5, n3) == 0);
    assert(biCmp(n5, n1) == 0);
    assert(biCmp(n1, n5) == 0);

    BigInt n7 = biFromString("0");
    BigInt n8 = biFromString("100000000000000000000000000000000000000000000000000000000000000000000001");
    biAdd(n8, n7);
    assert(biCmp(n8, n1) == 0);
    assert(biCmp(n5, n8) == 0);

    n1 = biFromString("0");
    n2 = biFromString("0");
    biAdd(n2, n1);
    assert(biCmp(n2, biFromInt(0)) == 0);

    n1 = biFromString("0");
    n2 = biFromString("-871264891273649182376192834761293487");
    biAdd(n1, n2);
    assert(biCmp(n1, n2) == 0);

    n1 = biFromString("0");
    n2 = biFromString("-871264891273649182376192834761293487");
    biAdd(n2, n1);
    assert(biCmp(n2, n1) == -1);

    n1 = biFromString("-12341234981273409182570918237409128347");
    n2 = biFromString("-871264891273649182376192834761293487");
    assert(biCmp(n1, n2) == -1);
    assert(biCmp(n2, n1) == 1);
    biAdd(n2, n1);
    assert(biCmp(n1, n2) == 1);
    assert(biCmp(n2, n1) == -1);
    assert(biCmp(n2, n2) == 0);
    assert(biCmp(n1, n1) == 0);

    n1 = biFromString("12341234981273409182570918237409128347");
    n2 = biFromString("871264891273649182376192834761293487");
    biAdd(n2, n1);
    assert(biCmp(n2, n1) == 1);
    assert(biCmp(n1, n2) == -1);

    n1 = biFromString("-00000000");
    n2 = biFromString("000000000");
    biAdd(n2, n1);
    assert(biCmp(n2, n1) == 0);
    assert(biCmp(n1, n2) == 0);
    assert(biCmp(n1, biFromInt(0)) == 0);
    assert(biCmp(n1, biFromString("-00000000000")) == 0);
    cerr << "---COMPLETE---" << endl;

    //TBD; sub needed
    //n1 = biFromString("12341234981273409182570918237409128347");
    //n2 = biFromString("-12341234981273409182570918237409128347");
    //biAdd(n2, n1);
    //assert(biCmp(n2, n1) == -1);
    //assert(biCmp(n1, n2) == 1);
    //assert(biCmp(n2, biFromInt(0)) == 1);
    //assert(biCmp(n2, biFromString("-00000000000000000000000")) == 1);

    //n3 = biFromString("-12341234981273409182570918237409128347");
    //n4 = biFromString("871264891273649182376192834761293487");
    //biAdd(n3, n4);

    //n1 = biFromString("-12341234981273409182570918237409128347");
    //n2 = biFromString("871264891273649182376192834761293487");
    //biAdd(n2, n1);
    //assert(biCmp(n3, n2) == 0);
}
int main() {
    test_add();
    return 0;
}
