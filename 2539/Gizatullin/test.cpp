#include <assert.h>
#include <bigint.h>
#include <boost/multiprecision/gmp.hpp>
#include <boost/multiprecision/random.hpp>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <iostream>
#include <random>

#define LL long long

using namespace std;
using namespace boost::multiprecision;

const int NUM_SIZE = 100500;
const int TEST_NUMBER = 3000;

std::random_device rd;
std::mt19937 gen(rd());

mpz_int randBig() {
    boost::random::uniform_int_distribution<mpz_int> dis(0, mpz_int(1) << 2048);
    if (rand() % 6 == 0) 
        return 0;
    return ((dis(gen) % 2 == 1) ? -1 : 1) * dis(gen);
}

LL randInt() {
    std::uniform_int_distribution<LL> dis(0, 1LL << 60);
    LL res = dis(gen);
    res = dis(gen) % 2 == 1 ? -res : res;
    return res;
}

int test_cmp() {
    printf("====== TESTING COMPARISON ======\n");
    BigInt bi1 = biFromInt(0xffffffffll);
    BigInt bi2 = biFromInt(0xffffffffll);
    BigInt bi5 = biFromInt(0xffffffffll + 0xffffffffll);
    biAdd(bi1, bi2);
    assert(biCmp(bi1, bi5) == 0);
    bi1 = biFromInt(2ll);
    bi2 = biFromInt(-123ll);
    BigInt bi3 = biFromInt(-123ll);
    biAdd(bi1, bi2);
    biSub(bi1, bi2);
    assert(biCmp(bi2, bi3) == 0);
    for (int lp = 0; lp < TEST_NUMBER; lp++) {
        LL i1 = randInt();
        LL i2 = randInt();
        BigInt b1 = biFromInt(i1);
        BigInt b2 = biFromInt(i2);
        if (biCmp(b1, b1) != 0) {
            printf("test: %d failure, equals %lld\n", lp + 1, i1);
            return 0;
        }
        LL g1 = randInt();
        LL g2 = randInt();
        g2 += g1;
        if (g1 < g2) {
            LL tmp = g1;
            g1 = g2;
            g2 = tmp;
        }
        // g1 > g2
        BigInt bg1 = biFromInt(g1);
        BigInt bg2 = biFromInt(g2);
        if (biCmp(bg1, bg2) != 1) {
            printf("test: %d failure, greater %lld %lld %d\n", lp + 1, g1, g2, g1 > g2);
            return 0;
        }
        if (biCmp(bg2, bg1) != -1) {
            printf("test: %d failure, less\n", lp + 1);
            return 0;
        }
        biDelete(b1);
        biDelete(b2);
        biDelete(bg1);
        biDelete(bg2);

        mpz_int m1 = randBig();
        mpz_int m2 = randBig();
        BigInt bm1 = biFromString(m1.str().c_str());
        BigInt bm2 = biFromString(m2.str().c_str());
        if (biCmp(bm1, bm1) != 0) {
            printf("test: %d failure equals %lld\n", lp + 1, i1);
            return 0;
        }
        if (m1 > m2 &&  biCmp(bm1, bm2) != 1) {
            printf("test: %d failure greater\n", lp + 1);
            return 0;
        } else if (m1 < m2 && biCmp(bm1, bm2) != -1) {
            printf("test: %d failure less\n%s\n%s\nRes: %d\n", lp + 1, 
                    m1.str().c_str(), m2.str().c_str(), biCmp(bm1, bm2));
            return 0;
        }
        biDelete(bm1);
        biDelete(bm2);
    }
    printf("Verdict: OK\n");
    return 1;
}

int test_str() {
    printf("====== TESTING STRING BUILD ======\n");
    char str[NUM_SIZE];
    size_t str_size = NUM_SIZE;
    BigInt bi1 = biFromString("-");
    assert(bi1 == NULL);
    for (int lp = 0; lp < TEST_NUMBER; lp++) {
        mpz_int var = randBig();
        BigInt bvar = biFromString(var.str().c_str());
        biToString(bvar, str, str_size);
        if (strcmp(str, var.str().c_str()) != 0) {
            printf("test: %d failure on %d\nMy: %s\nGM: %s\n", lp + 1, 
                    strcmp(str, var.str().c_str()), str, var.str().c_str());
            return 0;
        }
        biDelete(bvar);
    }
    printf("Verdict: OK\n");
    return 1;
}

int test_add(bool adding) {
    printf("====== TESTING %s ======\n", adding ? "ADDITION" : "SUBTRACTION" );
    char str[NUM_SIZE];
    size_t str_size = NUM_SIZE;
    mpz_int mi1 = 1;
    for (int i = 0; i < 1024; i++, mi1 <<= 1) {}
    mpz_int mi2 = mi1;
    BigInt b1 = biFromString(mi1.str().c_str());
    BigInt b2 = biFromString(mi2.str().c_str());
    BigInt b3 = biFromString("1");
    biSub(b2, b3);
    biSub(b1, b2);
    assert(biCmp(b1, b3) == 0);
    for (int lp = 0; lp < TEST_NUMBER; lp++) {
        mpz_int var = randBig();
        mpz_int var2 = randBig();
        BigInt b1 = biFromString(var.str().c_str());
        BigInt b2 = biFromString(var2.str().c_str());
        mpz_int var3;
        if (adding) {
            var3 = var + var2;
            biAdd(b1, b2);
        } else {
            var3 = var - var2;
            biSub(b1, b2);
        }
        biToString(b1, str, str_size);
        if (strcmp(str, var3.str().c_str()) != 0) {
            cout << "First: " << var << "\n" << "Second: " << var2 << "\n";
            printf("test: %d failure \nMine: %s\nGM: %s\n", lp + 1, str, var3.str().c_str());
            return 0;
        }
        biDelete(b1);
        biDelete(b2);
        
    }
    printf("Verdict: OK\n");
    return 1;
}

int test_mul() {
    printf("====== TESTING MULTIPLY ======\n");
    char str[NUM_SIZE];
    size_t str_size = NUM_SIZE;
    LL allGmp = 0;
    LL allMine = 0;
    for (int lp = 0; lp < TEST_NUMBER; lp++) {
        mpz_int var = randBig();
        mpz_int var2 = randBig();
        BigInt b1 = biFromString(var.str().c_str());
        BigInt b2 = biFromString(var2.str().c_str());
        mpz_int var3;
        LL tGmp = clock();
        var3 = var * var2;
        tGmp = (clock() - tGmp);
        LL tMine = clock();
        biMul(b1, b2);
        tMine = (clock() - tMine);
        allGmp += tGmp;
        allMine += tMine;
        biToString(b1, str, str_size);
        if (strcmp(str, var3.str().c_str()) != 0){
            cout << "First: " << var << "\n" << "Second: " << var2 << "\n";
            printf("test: %d failure \nMy: %s\nGM: %s\n", lp + 1, 
                    str, var3.str().c_str());
            return 0;
        }
        biDelete(b1);
        biDelete(b2);
    }
    //printf("Time, GMP: %lld\nTime, Mine: %lld\n", allGmp, allMine);
    //printf("%lld\n%lld\n", allGmp, allMine);
    printf("Verdict: OK\n");
    return 1;
}

int test_divide() {
    printf("====== TESTING DIVISION ======\n");
    char str[NUM_SIZE];
    char str2[NUM_SIZE];
    size_t str_size = NUM_SIZE;
    mpz_int t1("6703903964971298549787012499102923063739682910296196688861780721860882015023660034294811089951732299792782023528860199663493147528504713584320662571322642");
    mpz_int t2("57896044618658097711785492504343953926634992332820282019728792003956564819949");
    for (int lp = 0; lp < TEST_NUMBER; lp++) {
        mpz_int var2 = randBig();
        mpz_int var = var2 * randBig() + randBig();
        BigInt b1 = biFromString(var.str().c_str());
        BigInt b2 = biFromString(var2.str().c_str());
        BigInt quotient;
        BigInt remainder;
        BigInt q2;
        BigInt r2;
        mpz_int var3;
        biDivRem(&quotient, &remainder, b1, b2);
        if (var2 == 0) {
            assert(quotient == NULL);
            assert(remainder == NULL);
            continue;
        }
        biDivRem(&q2, &r2, b1, b2);
        if (biSign(r2) != 0)
            assert(biSign(r2) == biSign(b2));
        var3 = var / var2;
        mpz_int var4 = var % var2;
        biToString(quotient, str, str_size);
        biToString(remainder, str2, str_size);
        if (var4.sign() != var2.sign() && var4 != 0) {
            var4 += var2;
            var3 += -1;
        }
        if (strcmp(str, var3.str().c_str()) != 0 || strcmp(str2, var4.str().c_str()) != 0) {
            cout << "First: " << var << "\n" << "Second: " << var2 << "\n";
            printf("test: %d failure \nMy: %s\nGM: %s\n", lp + 1, str, var3.str().c_str());
            biToString(remainder, str, str_size);
            var3 = var % var2;
            printf("GMP Remainder: %s\nRemainder: %s\n", var3.str().c_str(), str);
            return 0;
        }
        biDelete(b1);
        biDelete(b2);
    }
    printf("Verdict: OK\n");
    return 1;
}

int main() {
    srand(time(NULL));
    int res = 0, expected = 0;
    res += test_str(), expected += 1;
    res += test_cmp(), expected += 1;
    res += test_add(true), expected += 1;
    res += test_add(false), expected += 1;
    res += test_mul(), expected += 1;
    res += test_divide(), expected += 1;
    printf("====== ALL: %s\n", res == expected ? "OK" : "FAILURE");
    return 0;
}