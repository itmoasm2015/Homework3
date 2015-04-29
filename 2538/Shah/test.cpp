#include <cstdio>
#include <cstdlib>
#include "bigint.h"
#include <boost/multiprecision/gmp.hpp>
#include <boost/multiprecision/random.hpp>
#include <random>
#include <iostream>
#include <ctime>
#include <assert.h>

using namespace std;
using namespace boost::multiprecision;

const int TEST_COUNT = 1000;
std::random_device rd;
std::mt19937 gen(rd());

mpz_int randBig()
{
    boost::random::uniform_int_distribution<mpz_int> dis(0, mpz_int(1) << 1024);
    if (rand() % 6 == 0) {
        return 0;
    }
    return ((dis(gen)%2 == 1) ? -1 : 1) * dis(gen);
}

long long randInt()
{
    std::uniform_int_distribution<long long> dis(0, 1LL << 60);
    long long res = dis(gen);
    if (dis(gen) % 2 == 1)
    {
        res = -res;
    }
    return res;
}

void test_cmp()
{
    printf("=============TESTING CMP==============\n");
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
    for (int lp = 0; lp < TEST_COUNT; lp++)
    {
        long long i1 = randInt();
        long long i2 = randInt();
        BigInt b1 = biFromInt(i1);
        BigInt b2 = biFromInt(i2);
        if (biCmp(b1, b1) != 0) 
        {
            printf("test: %d failure equals %lld\n", lp + 1, i1);
            return;
        }
        long long g1 = randInt();
        long long g2 = randInt();
        g2 += g1;
        if (g1 < g2)
        {
            long long tmp = g1;
            g1 = g2;
            g2 = tmp;
        }
        // g1 > g2
        BigInt bg1 = biFromInt(g1);
        BigInt bg2 = biFromInt(g2);
        if (biCmp(bg1, bg2) != 1) 
        {
            printf("test: %d failure greater %lld %lld %d\n", lp + 1, g1, g2, g1 > g2);
            return;
        }
        if (biCmp(bg2, bg1) != -1) 
        {
            printf("test: %d failure less\n", lp + 1);
            return;
        }
        biDelete(b1);
        biDelete(b2);
        biDelete(bg1);
        biDelete(bg2);

        mpz_int m1 = randBig();
        mpz_int m2 = randBig();
        BigInt bm1 = biFromString(m1.str().c_str());
        BigInt bm2 = biFromString(m2.str().c_str());
        if (biCmp(bm1, bm1) != 0) 
        {
            printf("test: %d failure equals %lld\n", lp + 1, i1);
            return;
        }
        if (m1 > m2)
        {
            if (biCmp(bm1, bm2) != 1) 
            {
                printf("test: %d failure greater\n", lp + 1);
                return;
            }
        }
        else if (m1 < m2)
        {
            if (biCmp(bm1, bm2) != -1) 
            {
                printf("test: %d failure less\n%s\n%s\nRes: %d\n", lp + 1, 
                        m1.str().c_str(), 
                        m2.str().c_str(),
                        biCmp(bm1, bm2));
                return;
            }
        }
        biDelete(bm1);
        biDelete(bm2);
    }
    printf("tests: OK\n");
}

void test_str()
{
    printf("====== TESTING STRING BUILD ======\n");
    char str[100500];
    size_t str_size = 100500;
    for (int lp = 0; lp < TEST_COUNT; lp++)
    {
        mpz_int var = randBig();
        BigInt bvar = biFromString(var.str().c_str());
        biToString(bvar, str, str_size);
        if (strcmp(str, var.str().c_str()) != 0)
        {
            printf("test: %d failure on %d\nMy: %s\nGM: %s\n", lp + 1, 
                    strcmp(str, var.str().c_str()), str, var.str().c_str());
            return;
        }
        biDelete(bvar);
    }
    printf("tests: OK\n");
}

void test_add(bool adding)
{
    printf("====== TESTING %s ======\n", adding ? "ADDING" : "SUBTRACT" );
    char str[100500];
    size_t str_size = 100500;
    mpz_int mi1 = 1;
    for (int i = 0; i < 1024; i++)
    {
        mi1 *= 2;
    }
    // 2^1024 - (2^1024 - 1) == 1 ?
    mpz_int mi2 = mi1;
    BigInt b1 = biFromString(mi1.str().c_str());
    BigInt b2 = biFromString(mi2.str().c_str());
    BigInt b3 = biFromString("1");
    biSub(b2, b3);
    biSub(b1, b2);
    assert(biCmp(b1, b3) == 0);
    for (int lp = 0; lp < TEST_COUNT; lp++)
    {
        mpz_int var = randBig();
        mpz_int var2 = randBig();
        BigInt b1 = biFromString(var.str().c_str());
        BigInt b2 = biFromString(var2.str().c_str());
        // cerr << var << "\n" << var2 << "\n";
        mpz_int var3;
        if (adding) {
            var3 = var + var2;
            biAdd(b1, b2);
        } else {
            var3 = var - var2;
            biSub(b1, b2);
        }
        biToString(b1, str, str_size);
        if (strcmp(str, var3.str().c_str()) != 0)
        {
            cout << "First: " << var << "\n" 
                << "Secon: " << var2 << "\n";
            printf("test: %d failure \nMy: %s\nGM: %s\n", lp + 1, 
                    str, var3.str().c_str());
            return;
        }
        // biAdd(b1, b2);
        // printf("%d\n", biCmp(b1, b2));
        biDelete(b1);
        biDelete(b2);
        
    }
    printf("tests: OK\n");
}

void test_mul()
{
    printf("====== TESTING %s ======\n", "MUL");
    char str[100500];
    size_t str_size = 100500;
    long long allGmp = 0;
    long long allMy = 0;
    for (int lp = 0; lp < TEST_COUNT; lp++)
    {
        mpz_int var = randBig();
        mpz_int var2 = randBig();
        BigInt b1 = biFromString(var.str().c_str());
        BigInt b2 = biFromString(var2.str().c_str());
        mpz_int var3;
        long long tGmp = clock();
        var3 = var * var2;
        tGmp = (clock() - tGmp);
        long long tMy = clock();
        biMul(b1, b2);
        tMy = (clock() - tMy);
        allGmp += tGmp;
        allMy += tMy;
        biToString(b1, str, str_size);
        if (strcmp(str, var3.str().c_str()) != 0)
        {
            cout << "First: " << var << "\n" 
                << "Secon: " << var2 << "\n";
            printf("test: %d failure \nMy: %s\nGM: %s\n", lp + 1, 
                    str, var3.str().c_str());
            return;
        }
        biDelete(b1);
        biDelete(b2);
        
    }
    printf("time GMP: %lld\ntime My : %lld\n", allGmp, allMy);
    printf("tests: OK\n");
}
int main() 
{
    srand(time(NULL));
    test_str();
    test_cmp();
    test_add(true);
    test_add(false);
    test_mul();
}
