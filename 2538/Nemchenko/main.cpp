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


void test_constructors() {
    cerr << "---TEST_BI_CONSTRUCT----" << endl;
    BigInt n1 = biFromString("112379");
    BigInt n2 = biFromInt(112379);
    assert(biCmp(n1, n2) == 0);

    n1 = biFromString("-199912379");
    n2 = biFromInt(-199912379);
    assert(biCmp(n1, n2) == 0);

    n1 = biFromString("-0");
    n2 = biFromInt(0);
    assert(biCmp(n1, n2) == 0);

    n2 = biFromInt(1LL << 63);
    n1 = biFromString("-9223372036854775808");
    assert(biCmp(n1, n2) == 0);
    cerr << "---END_BI_CONSTRUCT----" << endl;
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

    biDelete(n1);
    biDelete(n2);
    biDelete(n3);
    biDelete(n4);
    biDelete(n5);
    biDelete(n6);
    biDelete(n7);
    biDelete(n8);
    cerr << "---COMPLETE---" << endl;

    //TBD; sub needed
    n1 = biFromString("12341234981273409182570918237409128347");
    n2 = biFromString("-12341234981273409182570918237409128347");
    biAdd(n2, n1);
    assert(biCmp(n2, n1) == -1);
    assert(biCmp(n1, n2) == 1);
    assert(biCmp(n2, biFromInt(0)) == 0);
    assert(biCmp(n2, biFromString("-00000000000000000000000")) == 0);

    //n3 = biFromString("-12341234981273409182570918237409128347");
    //n4 = biFromString("871264891273649182376192834761293487");
    //biAdd(n3, n4);

    //n1 = biFromString("-12341234981273409182570918237409128347");
    //n2 = biFromString("871264891273649182376192834761293487");
    //biAdd(n2, n1);
    //assert(biCmp(n3, n2) == 0);
}

void test_sub() {
    BigInt n5 = biFromString("1");
    BigInt n6 = biFromString("100000000000000000000000000000000000000000000000000000000000000000000000");

    biSub(n5, n6);

    n6 = biFromString("1");
    n5 = biFromString("100000000000000000000000000000000000000000000000000000000000000000000000");

    biSub(n5, n6);

    cerr << "---TEST_BI_SUB_CMP----" << endl;
    BigInt n1 = biFromString("-1");
    BigInt n2 = biFromString("100000000000000000000000000000000000000000000000000000000000000000000000");

    BigInt n3 = biFromString("-1");
    BigInt n4 = biFromString("-100000000000000000000000000000000000000000000000000000000000000000000000");

    biSub(n1, n2);
    biAdd(n3, n4);
    assert(biCmp(n1, n3) == 0);

    assert(biCmp(n1, n2) == -1);
    assert(biCmp(n1, n1) == 0);
    assert(biCmp(n2, n2) == 0);

    n1 = biFromString("12341234981273409182570918237409128347");
    n2 = biFromString("-12341234981273409182570918237409128347");
    biAdd(n2, n1);
    assert(biCmp(n2, n1) == -1);
    assert(biCmp(n1, n2) == 1);
    assert(biCmp(n2, biFromInt(0)) == 0);
    assert(biCmp(n2, biFromString("-00000000000000000000000")) == 0);
    cerr << "---COMPLETE---" << endl;


    n1 = biFromString("12341234981273409182570918237409128347");
    n2 = biFromString("182570918237409128347");
    biSub(n1, n2);
    n3 = biFromString("12341234981273409000000000000000000000");
    assert(biCmp(n1, n3) == 0);
    assert(biCmp(n1, n2) == 1);
    assert(biCmp(n2, n1) == -1);

    n1 = biFromString("12312312312394871230948172304982");
    n2 = biFromString("1238974102384710238412312312312394871230948172304982");
    biSub(n1, n2);
    n3 = biFromString("-1238974102384710238400000000000000000000000000000000");
    assert(biCmp(n1, n3) == 0);
    assert(biCmp(n1, n2) == -1);
    assert(biCmp(n2, n1) == 1);

    n1 = biFromString("12312312312394871230948172304982");
    n2 = biFromString("-1238974102384710238412312312312394871230948172304982");
    biSub(n1, n2);

    n3 = biFromString("12312312312394871230948172304982");
    n4 = biFromString("1238974102384710238412312312312394871230948172304982");
    biAdd(n3, n4);

    assert(biCmp(n1, n3) == 0);
    assert(biCmp(n1, n2) == 1);
    assert(biCmp(n2, n1) == -1);
    cerr << "---COMPLETE---" << endl;
}

void test_mul() {
    BigInt n1 = biFromString("99");
    BigInt n2 = biFromString("99");
    BigInt n3 = biFromString("99999999999999999999999999999999999980000000000000000000000000000000000001");
    BigInt n4 = biFromInt(99 * 99);
    biMul(n1, n2);
    assert(biCmp(n1, n4) == 0);

    n1 = biFromString("9999999999999999999999999999999999999");
    n2 = biFromString("9999999999999999999999999999999999999");
    biMul(n1, n2);
    assert(biCmp(n1, n3) == 0);

    n1 = biFromString("-9999999999999999999999999999999999999");
    n2 = biFromString("9999999999999999999999999999999999999");
    biMul(n1, n2);
    biMul(n3, biFromInt(-1));
    assert(biCmp(n1, n3) == 0);

    n1 = biFromString("-9999999999999999999999999999999999999");
    n2 = biFromString("9999999999999999999999999999999999999");
    biMul(n1, n2);
    biMul(n3, biFromInt(-1));
    biMul(n1, biFromInt(-1));
    assert(biCmp(n1, n3) == 0);
}

int main() {
    //void* temp =calloc(10, 8);
    //free(temp);
    //BigInt bi1 = biFromInt(2ll);
    //cout << "asdfasdfasdf" << endl;
    //BigInt bi2 = biFromInt(-123ll);
    //BigInt bi3 = biFromInt(-123ll);
    //biAdd(bi1, bi2);
    //biSub(bi1, bi2);
    //assert(biCmp(bi2, bi3) == 0);
    
    test_constructors();
    test_add();
    test_sub();
    test_mul();
    return 0;
}
