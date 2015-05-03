#include <iostream>
#include <cstdlib>
#include <cstdint>
#include <cmath>
#include <bigint.h>


using namespace std;


// Asm imports.
extern "C" {
    BigInt biFromBigInt(BigInt bi);
}


#define TEST(t, test)   int __result##test = test(t); \
                        all_tests++; \
                        if (__result##test) { \
                            passed_tests++; \
                        } else { \
                            cerr << "FAILED: " #test " (t=" << (t) << ")\n"; \
                        }

#define EXPECT(cond)    if (__result && !(cond)) { \
                            cerr << "Assertion `" #cond "` failed\n"; \
                            __result = false; \
                        }

#define BEGIN()         bool __result = true;
#define END()           return __result;


uint64_t get_digit(BigInt bi, unsigned digit) {
    return ((uint64_t*)(*(int*)((char*)bi + 1)))[2 + digit];
}

bool bigint_short_creation(int n) {
    BEGIN();

    BigInt bi1 = biFromInt(n);
    BigInt bi2 = biFromInt(n);
    BigInt bi3 = biFromBigInt(bi2);

    EXPECT(biCmp(bi1, bi2) == 0);
    EXPECT(biCmp(bi1, bi3) == 0);

    biDelete(bi1);
    biDelete(bi2);
    biDelete(bi3);

    END();
}

bool bigint_short_comparison(int n) {
    BEGIN();

    // general cases
    BigInt bi1 = biFromInt(n);
    BigInt bi2 = biFromInt(n + 4);
    BigInt bi3 = biFromInt(n - 2);

    EXPECT(biCmp(bi1, bi2) < 0);
    EXPECT(biCmp(bi1, bi3) > 0);
    
    biDelete(bi1);
    biDelete(bi2);
    biDelete(bi3);

    // corner cases
    BigInt const3 = biFromInt(3);
    BigInt const5 = biFromInt(5);
    BigInt constm3 = biFromInt(-3);
    BigInt constm5 = biFromInt(-5);

    EXPECT(biCmp(constm5, const3) < 0);
    EXPECT(biCmp(const3, constm5) > 0);
    EXPECT(biCmp(const3, constm3) > 0);

    biDelete(const3);
    biDelete(const5);
    biDelete(constm3);
    biDelete(constm5);

    END();
}

int n_prev = 0;
bool bigint_short_addition(int n) {
    BEGIN();

    BigInt a = biFromInt(n);
    BigInt b = biFromInt(n_prev);
    BigInt c = biFromInt(n + n_prev); 

    biAdd(a, b);
    EXPECT(biCmp(a, c) == 0);

    biDelete(a);
    biDelete(b);
    biDelete(c);

    n_prev = n;
    END();
}

bool bigint_short_from_string(int n) {
    BEGIN();

    char buf[16];

    sprintf(buf, "%d", n);

    BigInt bi1 = biFromInt(n);
    BigInt bi2 = biFromString(buf);

    EXPECT(bi2 != NULL);
    EXPECT(biCmp(bi1, bi2) == 0);
    
    biDelete(bi1);
    if (bi2 != NULL) {
        biDelete(bi2);
    }

    END();
}

bool bigint_long_creation(int n) {
    BEGIN();

    char big_number[] = "93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000";
    BigInt bi1 = biFromString(big_number);
    BigInt bi2 = biFromString("1");

    for (int i = 1; i <= 100; i++) {
        BigInt biHelper = biFromInt(i);
        biMul(bi2, biHelper);
        biDelete(biHelper);
    }

    EXPECT(biCmp(bi1, bi2) == 0);

    biDelete(bi1);
    biDelete(bi2);

    END();
}

bool bigint_long_power_two(int n) {
    // calculate a^n in two ways
    BEGIN();

    int base = ((n % 100) + 100) % 100;
    int pow = floor(sqrt(fabs(1.0f * n)));
    
    // firstly, calculate by fast exponentiation
    int exp = pow;
    BigInt bi1 = biFromString("1");
    BigInt bi1Base = biFromInt(base);
    while (exp > 0) {
        if (exp & 1) {
            biMul(bi1, bi1Base);
        }
        exp >>= 1;
        biMul(bi1Base, bi1Base);
    }

    // secondly, calculate by iterative multiplication
    BigInt bi2 = biFromString("1");
    BigInt bi2Base = biFromInt(base);
    for (int i = 0; i < pow; i++) {
        biMul(bi2, bi2Base);
    }

    EXPECT(biCmp(bi1, bi2) == 0);

    biDelete(bi1);
    biDelete(bi1Base);
    biDelete(bi2);
    biDelete(bi2Base);

    END();
}

bool bigint_from_mail(int n) {
    BEGIN();

    // test #1
    {
        BigInt bi1 = biFromInt((int64_t) -n / 2);
        BigInt bi2 = biFromInt((int64_t) n);
        BigInt bi3 = biFromInt((int64_t) n);
        
        biAdd(bi1, bi2);
        biSub(bi1, bi2);
        
        EXPECT(biCmp(bi2, bi3) == 0);

        biDelete(bi1);
        biDelete(bi2);
        biDelete(bi3);
    }

    // test #2
    {
        BigInt bi1 = biFromInt(0xffffffffll);
        BigInt bi2 = biFromInt(0xffffffffll);
        BigInt bi5 = biFromInt(0xffffffffll + 0xffffffffll);
        
        biAdd(bi1, bi2);
        
        EXPECT(biCmp(bi1, bi5) == 0);

        biDelete(bi1);
        biDelete(bi2);
        biDelete(bi5);
    }

    // test #3
    {
        BigInt huge = biFromInt(1);
        BigInt base = biFromInt(2);
        for (int i = 0; i < 1024; i++) {
            biMul(huge, base);
        }

        BigInt invHuge = biFromInt(1);
        biSub(invHuge, huge);

        BigInt result = biFromBigInt(huge);
        biAdd(result, invHuge);

        BigInt one = biFromInt(1);
        EXPECT(biCmp(result, one) == 0);

        biDelete(huge);
        biDelete(base);
        biDelete(invHuge);
        biDelete(result);
        biDelete(one);
    }

    // test #4
    {
        EXPECT(biFromString("-") == NULL);
        EXPECT(biFromString("22-2") == NULL);
        EXPECT(biFromString("-100-") == NULL);

        BigInt a = biFromString("000000100500");
        BigInt b = biFromString("100500");

        EXPECT(biCmp(a, b) == 0);

        biDelete(a);
        biDelete(b);
    }

    // test #5
    {
        BigInt bi1 = biFromInt(123ll);
        BigInt bi2 = biFromString("123");

        EXPECT(biCmp(bi1, bi2) == 0);

        biDelete(bi1);
        biDelete(bi2);
    }

    // test #6
    {
        BigInt huge = biFromInt(1ll);
        BigInt base = biFromInt(2ll);
        for (int i = 0; i < 1024; i++) {
            biMul(huge, base);
        }

        BigInt almostHuge = biFromBigInt(huge);
        BigInt one = biFromInt(1);
        biSub(almostHuge, one);

        BigInt minusOne = biFromInt(-1ll);

        BigInt result = biFromBigInt(almostHuge);
        biSub(result, minusOne);

        EXPECT(biCmp(result, huge) == 0);

        biDelete(huge);
        biDelete(base);
        biDelete(almostHuge);
        biDelete(one);
        biDelete(minusOne);
        biDelete(result);
    }

    END();
}


int main() {
    int all_tests = 0;
    int passed_tests = 0;

    srand(time(NULL));

    for (int t = -1e7; t <= 1e7; t = t < 0 ? t / 10 + 1 : t * 10) {
        int salt = rand() % 256;
        TEST(t + salt, bigint_short_creation);
        TEST(t + salt, bigint_short_comparison);
        TEST(t + salt, bigint_short_addition);
        TEST(t + salt, bigint_short_from_string);
        
        TEST(t + salt, bigint_long_creation);
        TEST(t + salt, bigint_long_power_two);

        TEST(t + salt, bigint_from_mail);
    }

    cout << "OK " << passed_tests << "/" << all_tests << " tests\n";

    return !(passed_tests == all_tests);
}
