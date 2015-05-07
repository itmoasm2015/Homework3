#include <cstdio>
#include <cstdlib>
#include <bigint.h>
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
    boost::random::uniform_int_distribution<mpz_int> dis(0, mpz_int(1) << 2048);
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
    BigInt bi1 = biFromString("-");
    assert(bi1 == NULL);
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

void test_divide()
{
    printf("====== TESTING %s ======\n", "DIVISION");
    char str[100500];
    char str2[100500];
    size_t str_size = 100500;
    mpz_int t1("6703903964971298549787012499102923063739682910296196688861780721860882015023660034294811089951732299792782023528860199663493147528504713584320662571322642");
    mpz_int t2("57896044618658097711785492504343953926634992332820282019728792003956564819949");
    for (int lp = 0; lp < TEST_COUNT; lp++)
    {
        mpz_int var2 = randBig();
        mpz_int var = var2 * randBig() + randBig();
        // mpz_int p1 = randBig();
        // if (p1 < 0) p1 = -p1;
        // mpz_int p2 = randBig();
        // if (p2 < 0) p2 = -p2;
        // mpz_int p3 = randBig();
        // if (p3 < 0) p3 = -p3;
        // mpz_int p1("259117086013202627776246767922441530941818887553125427303974923161874019266586362086201209516800483406550695241733194177441689509238807017410377709597512042313066624082916353517952311186154862265604547691127595848775610568757931191017711408826252153849035830401185072116424747461823031471398340229288074545677907941037288235820705892351068433882986888616658650280927692080339605869308790500409503709875902119018371991620994002568935113136548829739112656797303241986517250116412703509705427773477972349821676443446668383119322540099648994051790241624056519054483690809616061625743042361721863339415852426431208737266591962061753535748892894599629195183082621860853400937932839420261866586142503251450773096274235376822938649407127700846077124211823080804139298087057504713825264571448379371125032081826126566649084251699453951887789613650248405739378594599444335231188280123660406262468609212150349937584782292237144339628858485938215738821232393687046160677362909315071");
        // mpz_int p2("1475979915214180235084898622737381736312066145333169775147771216478570297878078949377407337049389289382748507531496480477281264838760259191814463365330269540496961201113430156902396093989090226259326935025281409614983499388222831448598601834318536230923772641390209490231836446899608210795482963763094236630945410832793769905399982457186322944729636418890623372171723742105636440368218459649632948538696905872650486914434637457507280441823676813517852099348660847172579408422316678097670224011990280170474894487426924742108823536808485072502240519452587542875349976558572670229633962575212637477897785501552646522609988869914013540483809865681250419497686697771007");
        // mpz_int p3("446087557183758429571151706402101809886208632412859901111991219963404685792820473369112545269003989026153245931124316702395758705693679364790903497461147071065254193353938124978226307947312410798874869040070279328428810311754844108094878252494866760969586998128982645877596028979171536962503068429617331702184750324583009171832104916050157628886606372145501702225925125224076829605427173573964812995250569412480720738476855293681666712844831190877620606786663862190240118570736831901886479225810414714078935386562497968178729127629594924411960961386713946279899275006954917139758796061223803393537381034666494402951052059047968693255388647930440925104186817009640171764133172418132836351");
        // var = (rand()%2 == 0 ? -1 : 1) * (p1 * p2 + p3);
        // var2 = (rand()%2 == 0 ? -1 : 1) * p2;
        BigInt b1 = biFromString(var.str().c_str());
        BigInt b2 = biFromString(var2.str().c_str());
        BigInt quotient;
        BigInt remainder;
        BigInt q2;
        BigInt r2;
        mpz_int var3;
        biDivRem(&quotient, &remainder, b1, b2);
        if (var2 == 0)
        {
            assert(quotient == NULL);
            assert(remainder == NULL);
            continue;
        }
        biDivRem(&q2, &r2, b1, b2);
        if (biSign(r2) != 0)
        {
        //printf("%d\n%d\n", biSign(r2), biSign(b2));
            assert(biSign(r2) == biSign(b2));
        }
        // biToString(q2, str, str_size);
        // printf("Curre: %s\n", str);
        // biToString(b1, str, str_size);
        // printf("Right: %s\n", str);
        var3 = var / var2;
        mpz_int var4 = var % var2;
        biToString(quotient, str, str_size);
        biToString(remainder, str2, str_size);
        if (var4.sign() != var2.sign() && var4 != 0)
        {
            var4 += var2;
            var3 += -1;
        }
        // cout << "GMP: " << var3 << "\n";
        // printf("My : %s\n", str);
        // cout << "GMP: " << var4 << "\n";
        // printf("My : %s\n", str2);
        // biMul(q2, b2);
        // biToString(q2, str, str_size);
        // var3 *= var2;
        // assert(strcmp(str, var3.str().c_str()) == 0);
        // biAdd(q2, r2);
        // biToString(q2, str, str_size);
        // var3 += var4;
        // cout << "GMP: " << var3 << "\n";
        // printf("My : %s\n", str);
        // assert(strcmp(str, var3.str().c_str()) == 0);
        // assert(biCmp(q2, b1) == 0);
        if (strcmp(str, var3.str().c_str()) != 0
                || strcmp(str2, var4.str().c_str()) != 0)
        {
            cout << "First: " << var << "\n" 
                << "Secon: " << var2 << "\n";
            printf("test: %d failure \nMy: %s\nGM: %s\n", lp + 1, 
                    str, var3.str().c_str());
            biToString(remainder, str, str_size);
            var3 = var%var2;
            printf("GMP Rem: %s\nRemainder: %s\n", var3.str().c_str(), str);
            return;
        }
        biDelete(b1);
        biDelete(b2);
    }
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
    test_divide();
}
