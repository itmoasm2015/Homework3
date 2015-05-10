#include <iostream>
#include <cstdio>
#include <bigint.h>
#include <cassert>
#include <string.h>
#include <sys/mman.h>

using namespace std;

extern "C" {
    void add_short(BigInt src, int64_t num);
    void mul_short(BigInt src, int64_t num);
    int64_t div_short(BigInt, int64_t);
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
    cerr << "---COMPLETE----" << endl;
}

void test_add() {
    //2^1024 + (-(2^1024 - 1)) ≠ 1
    BigInt b = biFromInt(1LL << 32);
    BigInt c = biFromInt(1LL << 32);
    for (int i = 0; i < 31; ++i) {
        biMul(b, c);
    }
    BigInt d = biFromString("-179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137215");

    biAdd(b, d);
    assert(biCmp(b, biFromInt(1)) == 0);
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
    cerr << "---TEST_BI_SUB_CMP----" << endl;
    BigInt n5 = biFromString("1");
    BigInt n6 = biFromString("100000000000000000000000000000000000000000000000000000000000000000000000");

    biSub(n5, n6);

    n6 = biFromString("1");
    n5 = biFromString("100000000000000000000000000000000000000000000000000000000000000000000000");

    biSub(n5, n6);

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

    BigInt bi1 = biFromInt(2ll);
    BigInt bi2 = biFromInt(-123ll);
    BigInt bi3 = biFromInt(-123ll);
    biAdd(bi1, bi2);
    biSub(bi1, bi2);
    assert(biCmp(bi2, bi3) == 0);
    assert(biCmp(bi1, biFromString("2")) == 0);

    n1 = biFromString("-00000000000");
    n2 = biFromString("-1293847102398471029384710293487102394871327409128374");
    biSub(n1, n2);
    biMul(n2, biFromString("-00000000000001"));
    assert(biCmp(n1, n2) == 0);
    cerr << "---COMPLETE---" << endl;
}

void test_mul() {
    cerr << "---TEST_BI_MUL----" << endl;
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
    cerr << "---COMPLETE----" << endl;

    n1 = biFromString("-9999999999999999999999999999999999999");
    n2 = biFromString("0");
    biMul(n1, n2);
    biMul(n2, biFromInt(-1));
    biMul(n1, biFromInt(-1));
    n3 = biFromInt(0);
    assert(biCmp(n1, n3) == 0);
    cerr << "---COMPLETE----" << endl;
}

void testBiToString() {
    cerr << "---TEST_BI_TOSTRING----" << endl;
    char buf[1000];
    const char* expected = "-179769313486231590123123";
    BigInt d = biFromString("-179769313486231590123123");
    biToString(d, buf, 1000);
    assert(strcmp(buf, expected) == 0);

    d = biFromString("-0000000000000000000");
    expected = "0";
    biToString(d, buf, 1000);
    assert(strcmp(buf, expected) == 0);

    d = biFromString("-12");
    expected = "-12";
    biToString(d, buf, 1000);
    assert(strcmp(buf, expected) == 0);

    d = biFromString("12901283740192837410293847102938471203948712039487");
    expected = "12901283740192837410293847102938471203948712039487";
    biToString(d, buf, 1000);
    assert(strcmp(buf, expected) == 0);

    d = biFromString("817234098712309847120394871203984710239847012938471029384710293847102978356873425689732416981237409821374098273410872340912834709128347012938470127956281374612837462139847612983746218937460213847210384720193874892173658927136402173407281340129384709128374");
    expected = "817234098712309847120394871203984710239847012938471029384710293847102978356873425689732416981237409821374098273410872340912834709128347012938470127956281374612837462139847612983746218937460213847210384720193874892173658927136402173407281340129384709128374";
    biToString(d, buf, 1000);
    assert(strcmp(buf, expected) == 0);

    d = biFromString("-9");
    expected = "-9";
    biToString(d, buf, 1000);
    assert(strcmp(buf, expected) == 0);

    d = biFromString("-9");
    expected = "-9";
    biToString(d, buf, 1000);
    assert(strcmp(buf, expected) == 0);

    d = biFromString("-90000000000000");
    expected = "-90000000000000";
    biToString(d, buf, 1000);
    assert(strcmp(buf, expected) == 0);

    mprotect(buf, 3, PROT_NONE);
    d = biFromString("-90000000000000");
    expected = "-0";
    biToString(d, buf, 3);
    assert(strcmp(buf, expected) == 0);

    d = biFromString("-90000000000000");
    expected = "";
    biToString(d, buf, 1);
    assert(strcmp(buf, expected) == 0);
    cerr << "---COMPLETE----" << endl;
}

void testBiDivRem() {
    char buf[1000];

    BigInt *quotient = new BigInt;
    BigInt *remainder = new BigInt;
    BigInt numerator =   biFromString("123412341232323111971182973469812376491287346912837469182734698127346912873461298376491237469123746129374612983476129834761298347612983476129348761982374619238476192384761928374612938476");
    BigInt denominator = biFromString("123412341232323111971182973469812376491287346912837469182734698127346912873461298376491237469123746129374612983476129834761298347612983476129348761982374619238476192384761928374612938476");
    biDivRem(quotient, remainder, numerator, denominator);

    biToString(*quotient, buf, 1000);
    assert(strcmp(buf, "1") == 0);
    biToString(*remainder, buf, 1000);
    assert(strcmp(buf, "0") == 0);

    numerator =   biFromString("123412341232323111971182973469812376491287346912837469182734698127346912873461298376491237469123746129374612983476129834761298347612983476129348761982374619238476192384761928374612938476");
    denominator = biFromString("1234123412323231119711829734698123764912873469128374691827346981");
    biDivRem(quotient, remainder, numerator, denominator);

    biToString(*quotient, buf, 1000);
    assert(strcmp(buf, "100000000000000000000000000000000000000000000000000000000000000022158977457514457461106527797179625052226443748212692472818") == 0);
    biToString(*remainder, buf, 1000);
    assert(strcmp(buf, "538293099788998710480841943349964917718564816630015869216076018") == 0);


    numerator =   biFromString("1234123412323231119711829734698123764");
    denominator = biFromString("1234123412323231119711829734698123764912873469128374691827346981");
    biDivRem(quotient, remainder, numerator, denominator);

    biToString(*quotient, buf, 1000);
    assert(strcmp(buf, "0") == 0);
    biToString(*remainder, buf, 1000);
    assert(strcmp(buf, "1234123412323231119711829734698123764") == 0);


    numerator =   biFromString("0");
    denominator = biFromString("1234123412323231119711829734698123764912873469128374691827346981");
    biDivRem(quotient, remainder, numerator, denominator);

    biToString(*quotient, buf, 1000);
    assert(strcmp(buf, "0") == 0);
    biToString(*remainder, buf, 1000);
    assert(strcmp(buf, "0") == 0);

    numerator =   biFromInt(-10);
    denominator = biFromInt(3);
    biDivRem(quotient, remainder, numerator, denominator);

    biToString(*quotient, buf, 1000);
    assert(strcmp(buf, "-4") == 0);
    biToString(*remainder, buf, 1000);
    assert(strcmp(buf, "2") == 0);
}

void test_cmp() {
    BigInt a =   biFromString("12341234123232311191");
    BigInt b =   biFromInt(1);
    assert(biCmp(b, a) == -1);
}

int main() {
    testBiDivRem();

    test_cmp();
    test_constructors();
    test_add();
    test_sub();
    test_mul();
    testBiToString();

    return 0;
}
