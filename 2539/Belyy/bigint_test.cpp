#include <iostream>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <bigint.h>


using namespace std;


// Asm imports.
extern "C" {
    BigInt biFromBigInt(BigInt bi);
    uint64_t biDivShort(BigInt bi, uint64_t k);
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

int n_prev = 0;

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
    BigInt bi3 = biFromInt(n);

    for (int i = 1; i <= 100; i++) {
        BigInt biHelper = biFromInt(i);
        biMul(bi2, biHelper);
        biDelete(biHelper);
    }

    EXPECT(biCmp(bi1, bi2) == 0);

    for (int i = 0; i < 100; i++) {
        biAdd(bi1, bi3);
    }
    for (int i = 0; i < 100; i++) {
        biSub(bi1, bi3);
    }
    
    EXPECT(biCmp(bi1, bi2) == 0);

    biDelete(bi1);
    biDelete(bi2);
    biDelete(bi3);

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

bool bigint_short_division(int n) {
    BEGIN();

    int iterations = floor(sqrt(abs(1.0f * n)));
    BigInt result = biFromString("1");

    for (int i = 1; i <= iterations; i++) {
        BigInt biHelper = biFromInt(i);
        BigInt biPrev = biFromBigInt(result);
        biMul(result, biHelper);

        BigInt biDivved = biFromBigInt(result);
        BigInt biRemExpected = biFromInt(i - 1);
        biAdd(biDivved, biRemExpected);
        uint64_t rem = biDivShort(biDivved, i);
        BigInt biRemActual = biFromInt(rem);
        
        EXPECT(biCmp(biDivved, biPrev) == 0);
        EXPECT(biCmp(biRemExpected, biRemActual) == 0);

        biDelete(biHelper);
        biDelete(biPrev);
        biDelete(biDivved);
        biDelete(biRemExpected);
        biDelete(biRemActual);
    }

    biDelete(result);

    END();
}

bool bigint_to_string_simple(int n) {
    BEGIN();

    BigInt bi1 = biFromInt(n);
    BigInt bi2 = biFromInt(n);
    
    // one digit conversion
    {
        char bigint_buf[16];
        char sprintf_buf[16];
        biToString(bi1, bigint_buf, sizeof(bigint_buf));

        sprintf(sprintf_buf, "%d", n);

        EXPECT(strcmp(bigint_buf, sprintf_buf) == 0);
    }

    // limit = 0 or 1
    {
        char buf[2];
        
        biToString(bi1, buf, 0);
        EXPECT(buf[0] == 0);
        
        biToString(bi1, buf, 1);
        EXPECT(buf[0] == 0);
    }

    // various limits
    {
        char buf[4096];

        for (int i = 1; i < 10; i++) {
            biMul(bi2, bi1);
        }

        biToString(bi2, buf, sizeof(buf));
        size_t len = strlen(buf);

        for (size_t i = 1; i < sizeof(buf); i++) {
            biToString(bi2, buf, i);

            size_t partial_len = min(len + 1, i);
            EXPECT(strlen(buf) == partial_len - 1);
            EXPECT(buf[partial_len - 1] == 0);
        }
    }

    biDelete(bi1);
    biDelete(bi2);

    END();
}

bool bigint_to_string_hard(int n) {
    BEGIN();

    int N = floor(sqrt(abs(1.0f * n))) + 5;
    char * s = (char *) malloc(N + 1);
    char * ss = (char *) malloc(N + 1);
    
    // to_string(from_string(s)) == s
    // part 1: randomly generated strings
    {

        int first = rand() % 9;
        s[0] = first < 5 ? '1' + first : '-';
        s[1] = '1' + rand() % 9;
        for (int i = 2; i < N; i++) {
            s[i] = '0' + rand() % 10;
        }
        s[N] = 0;

        BigInt bi1 = biFromString(s);
        biToString(bi1, ss, N + 1);
        
        EXPECT(strcmp(s, ss) == 0);

        biDelete(bi1);
    }

    // to_string(from_string(s)) == s
    // part 2: special cases
    {
        // 10^N - 1
        {
            BigInt bi1 = biFromInt(1);
            BigInt one = biFromInt(1);
            BigInt ten = biFromInt(10);

            for (int i = 0; i < N; i++) {
                biMul(bi1, ten);
            }
            biSub(bi1, one);
            biToString(bi1, ss, N + 1);

            for (int i = 0; i < N; i++) {
                EXPECT(ss[i] == '9');
            }
            EXPECT(ss[N] == 0);

            biDelete(bi1);
            biDelete(one);
            biDelete(ten);
        }

        // 111...1
        {
            BigInt bi1 = biFromInt(0);
            BigInt one = biFromInt(1);
            BigInt ten = biFromInt(10);

            for (int i = 0; i < N; i++) {
                biMul(bi1, ten);
                biAdd(bi1, one);
            }
            biToString(bi1, ss, N + 1);

            for (int i = 0; i < N; i++) {
                EXPECT(ss[i] == '1');
            }
            EXPECT(ss[N] == 0);

            biDelete(bi1);
            biDelete(one);
            biDelete(ten);
        }
    }

    free(s);
    free(ss);

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

        BigInt minusOne = biFromInt(1ll);

        BigInt result = biFromBigInt(minusOne);
        biAdd(result, almostHuge);

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

bool bigint_various_tests(int n) {
    BEGIN();

    // test #1
    // combinations of signs in biMul()
    {
        int n1 = n & 1 ? n : -n;
        int n2 = n_prev & 1 ? n_prev : -n_prev;
        BigInt bi1 = biFromInt(n1);
        BigInt bi2 = biFromInt(n2);
        BigInt bi3 = biFromInt((int64_t) n1 * n2);
        biMul(bi1, bi2);

        EXPECT(biCmp(bi1, bi3) == 0);

        biDelete(bi1);
        biDelete(bi2);
        biDelete(bi3);
    }

    // test #2
    // sign of -0
    {
        BigInt bi1 = biFromString("-0");
        BigInt bi2 = biFromString("-1");

        EXPECT(biSign(bi1) == 0);
        EXPECT(biSign(bi2) <  0);

        biDelete(bi1);
        biDelete(bi2);
    }

    // test #3
    // 10^N - 1 for small N
    for (int N = 3; N < 50; N++) {
        BigInt bi1 = biFromInt(1);
        BigInt one = biFromInt(1);
        BigInt ten = biFromInt(10);

        for (int i = 0; i < 19; i++) {
            biMul(bi1, ten);
        }
        biSub(bi1, one);

        EXPECT(biSign(bi1) > 0);

        biDelete(bi1);
        biDelete(one);
        biDelete(ten);
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

        TEST(t + salt, bigint_short_division);
        
        TEST(t + salt, bigint_to_string_simple);
        TEST(t + salt, bigint_to_string_hard);

        TEST(t + salt, bigint_various_tests);
        TEST(t + salt, bigint_from_mail);

        n_prev = t + salt;
    }

    cout << "OK " << passed_tests << "/" << all_tests << " tests\n";

    return !(passed_tests == all_tests);
}
