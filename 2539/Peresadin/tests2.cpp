#include <bits/stdc++.h>
#include "bigint.h"
#include <gmpxx.h>

using namespace std;
#ifdef __cplusplus
extern "C" {
#endif

/** Copies given BigInt
 */
BigInt biCopy(BigInt a);

/** return a + b */
BigInt biAddNew(BigInt a, BigInt b);



/** return a - b */
BigInt biSubNew(BigInt a, BigInt b);


/** return a * b */
BigInt biMulNew(BigInt a, BigInt b);

/** Compute quotient and remainder by divising numerator by denominator.
 *  quotient * denominator + remainder = numerator
 *
 *  \param remainder must be in range [0, denominator) if denominator > 0
 *                                and (denominator, 0] if denominator < 0.
 */
void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);

#ifdef __cplusplus
}
#endif

bool check(bool f, bool print = false) {
    if (print) cout << (f ? "OK" : "FAIL") << endl;
    return f;
}

string genRandNumber(int len) {
    string res = "";
    if (rand() % 2) res += "-";
    res += (char)('1' + rand() % 9);
    for (int j = 1; j < len; j++) {
        res += (char)('0' + rand() % 10);
    }
    return res;
}

void test1() {
    cout << "test 1: ";
    cout.flush();
    bool ok = 1;
    BigInt a, b, c;

    a = biFromInt(15);
    ok &= check(biSign(a) == 1);
    b = biCopy(a);
    ok &= check(biSign(b) == 1);
    c = biAddNew(a, b);
    ok &= check(biSign(c) == 1);
    biDelete(a);
    biDelete(b);
    biDelete(c);

    a = biFromInt(0);
    ok &= check(biSign(a) == 0);
    biDelete(a);

    a = biFromInt(-1000000000000LL);
    ok &= check(biSign(a) == -1);
    biDelete(a);

    check(ok, 1);
}

void test2() {
    cout << "test 2: ";
    cout.flush();
    bool ok = 1;

    BigInt a, b, c;
    a = biFromInt(2);
    b = biFromInt(3);
    biAdd(a, b);
    c = biFromInt(5);
    check(biCmp(a, c) == 0);
    biDelete(a);
    biDelete(b);
    biDelete(c);

    check(ok, 1);
}

void test3() {
    cout << "test 3: ";
    cout.flush();
    bool ok = 1;

    BigInt a1, a2, a3;
    a1 = biFromInt(7);
    a2 = biFromInt(7);
    a3 = biFromInt(0);
    biSub(a1, a2);
    ok &= check(biCmp(a1, a3) == 0);
    biDelete(a1);
    biDelete(a2);
    biDelete(a3);

    int n = 100;
    vector<int> v(n);
    for (int i = 0; i < n; i++) v[i] = rand() % 101 - 50;
    
    BigInt a = biFromInt(0);
    int sum = 0;
    for (int i = 0; i < n; i++) {
        BigInt b = biFromInt(v[i]);

        if (rand() % 2 == 0) {
            sum += v[i];
            biAdd(a, b);
        } else {
            sum -= v[i];
            biSub(a, b);
        }

        biDelete(b);

        for (int k = -1; k <= 1; k++) {
        //for (int k = 0; k <= 0; k++) {
            b = biFromInt(sum + k);
            ok &= check(biCmp(a, b) == -k);
            biDelete(b);
        }
    }
    biDelete(a);

    check(ok, 1);
}

void test4(int n) {
    cout << "test 4: ";
    cout.flush();
    bool ok = 1;

    vector<unsigned long long> v(n);
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < 63; j++) {
            v[i] += ((unsigned long long)(rand() % 2)) << j;
        }
    }

    BigInt sum = biFromInt(0);
    for (int i = 0; i < n; i++) {
        BigInt x = biFromInt(v[i]);
        biAdd(sum, x);
        biDelete(x);
    }
    vector<BigInt> l(n), r(n);
    l[0] = biFromInt(v[0]);
    r[n - 1] = biFromInt(v[n - 1]);
    for (int i = 1; i < n; i++) {
        BigInt x = biFromInt(v[i]);
        l[i] = biAddNew(x, l[i - 1]);
        biDelete(x);
    }
    for (int i = n - 2; i >= 0; i--) {
        BigInt x = biFromInt(v[i]);
        r[i] = biAddNew(x, r[i + 1]);
        biDelete(x);
    }
    
    for (int i = 0; i + 1 < n; i++) {
        BigInt x;
        x = biAddNew(l[i], r[i + 1]);
        ok &= check(biCmp(x, sum) == 0);
        biDelete(x);
        x = biSubNew(sum, r[i + 1]);
        ok &= check(biCmp(x, l[i]) == 0);
        biDelete(x);
        x = biSubNew(sum, l[i]);
        ok &= check(biCmp(x, r[i + 1]) == 0);
        biDelete(x);
    }

    biDelete(sum);
    for (int i = 0; i < n; i++) {
        biDelete(l[i]);
        biDelete(r[i]);
    }

    check(ok, 1);
}

void test5() {
    cout << "test 5: ";
    cout.flush();
    bool ok = 1;

    BigInt a, b, c;
    a = biFromInt(0);
    b = biFromString("0");
    ok &= check(biCmp(a, b) == 0);
    biDelete(a);
    biDelete(b);

    a = biFromInt(5);
    b = biFromString("5");
    ok &= check(biCmp(a, b) == 0);
    biDelete(a);
    biDelete(b);

    a = biFromInt(-777777777777777777);
    b = biFromString("-777777777777777777");
    ok &= check(biCmp(a, b) == 0);
    biDelete(a);
    biDelete(b);

    a = biFromInt(-777777777777777777);
    b = biFromString("777777777777777777");
    c = biFromString("-0000000000000000000");
    biAdd(a, b);
    ok &= check(biCmp(a, c) == 0);
    ok &= check(biCmp(b, c) == 1);
    biDelete(a);
    biDelete(b);
    biDelete(c);

    a = biFromString("-");
    ok &= check(a == NULL);

    a = biFromString("");
    ok &= check(a == NULL);
    
    a = biFromString("-0");
    ok &= check(a != NULL);
    biDelete(a);

    check(ok, 1);
}

void test6() {
    cout << "test 6: ";
    cout.flush();
    bool ok = 1;

    int n = 100;
    vector<string> v(n);
    for (int i = 0; i < n; i++) {
        v[i] = genRandNumber(1000);
    }

    BigInt sum = biFromInt(0);
    for (int i = 0; i < n; i++) {
        BigInt x = biFromString(v[i].c_str());
        biAdd(sum, x);
        biDelete(x);
    }
    vector<BigInt> l(n), r(n);
    l[0] = biFromString(v[0].c_str());
    r[n - 1] = biFromString(v[n - 1].c_str());
    for (int i = 1; i < n; i++) {
        BigInt x = biFromString(v[i].c_str());
        l[i] = biAddNew(x, l[i - 1]);
        biDelete(x);
    }
    for (int i = n - 2; i >= 0; i--) {
        BigInt x = biFromString(v[i].c_str());
        r[i] = biAddNew(x, r[i + 1]);
        biDelete(x);
    }
    
    for (int i = 0; i + 1 < n; i++) {
        BigInt x;
        x = biAddNew(l[i], r[i + 1]);
        ok &= check(biCmp(x, sum) == 0);
        biDelete(x);
        x = biSubNew(sum, r[i + 1]);
        ok &= check(biCmp(x, l[i]) == 0);
        biDelete(x);
        x = biSubNew(sum, l[i]);
        ok &= check(biCmp(x, r[i + 1]) == 0);
        biDelete(x);
    }

    biDelete(sum);
    for (int i = 0; i < n; i++) {
        biDelete(l[i]);
        biDelete(r[i]);
    }

    check(ok, 1);
}

const int size = 100000;
char c[size];

void test7() {
    cout << "test 7: ";
    cout.flush();
    bool ok = 1;

    BigInt a, b;
//    const int size = 100000;
//    char c[size];

    a = biFromInt(0);
    biToString(a, c, size);
    ok &= check((string)c == "0");
    biDelete(a);

    a = biFromInt(5);
    biToString(a, c, size);
    ok &= check((string)c == "5");
    biDelete(a);

    a = biFromInt(123);
    biToString(a, c, size);
    ok &= check((string)c == "123");
    biDelete(a);

    a = biFromInt(-777);
    biToString(a, c, size);
    ok &= check((string)c == "-777");
    biDelete(a);

    a = biFromString("100000000000000000000");
    biToString(a, c, size);
    ok &= check((string)c == "100000000000000000000");
    biDelete(a);


    a = biFromString("43425452362856925692456924562568246836516062562");
    biToString(a, c, size);
    ok &= check((string)c == "43425452362856925692456924562568246836516062562");
    biDelete(a);

    a = biFromString("100000000000000000000");
    b = biFromString("90000000000000000000");
    biSub(a, b);
    biToString(a, c, size);
    ok &= check((string)(c) == "10000000000000000000");
    biDelete(a);
    biDelete(b);

    check(ok, 1);
}

void test8(int test, int cnt, int iters, int len) {
    cerr << "test " << test << ": " << endl;
    cout.flush();
    bool ok = 1;
    
    BigInt a;
    a = biFromInt(0);
    mpz_class a2 = 0;

    for (int it = 0; it < iters; it++) {
        string s = genRandNumber(len);
        BigInt b = biFromString(s.c_str());

        int o = rand() % cnt;
        cerr << "it = " << it << " op = " << o << endl;
        if (o == 0) {
            if (rand() % 2) {
                biAdd(a, b);
            } else {
                biAdd(b, a);
                swap(a, b);
            }
            a2 += mpz_class(s);
        } else
        if (o == 1) {
            biSub(a, b);
            a2 -= mpz_class(s);
        } else 
        if (o == 2) {
            biMul(a, b);
            a2 *= mpz_class(s);
        }

        biToString(a, c, size);
        string c1 = c;
        string c2 = a2.get_str();
        ok &= check(c1 == c2);
        if (!ok) {
            cerr << "FAIL" << endl;
            return;
        }
        biDelete(b);
    }

    biDelete(a);

    check(ok, 1);
}

void test9() {
    cout << "test 9: ";
    cout.flush();
    bool ok = 1;

    BigInt a, b;
    a = biFromInt(0);
    b = biFromInt(0);
    biMul(a, b);
    biToString(a, c, size);
    ok &= check((string)c == "0");
    biDelete(a);
    biDelete(b);

    a = biFromInt(2);
    b = biFromInt(3);
    biMul(a, b);
    biToString(a, c, size);
    ok &= check((string)c == "6");
    biDelete(a);
    biDelete(b);

    a = biFromString("-100000");
    b = biFromString("100000");
    biMul(a, b);
    biToString(a, c, size);
    ok &= check((string)c == "-10000000000");
    biDelete(a);
    biDelete(b);

    a = biFromString("-100000000000000000000");
    b = biFromString("-100000000000000000000");
    biMul(a, b);
    biToString(a, c, size);
    ok &= check((string)c == "10000000000000000000000000000000000000000");
    biDelete(a);
    biDelete(b);

    a = biFromString("543534651454354353461464534");
    b = biFromString("986825976248623595236852396");
    biMul(a, b);
    biToString(a, c, size);
    ok &= check((string)c == "536374113046398593484849759421413903658458498546923464");
    biDelete(a);
    biDelete(b);

    a = biFromString("-10000000000000000000000000000000000000000");
    b = biFromString("-10000000000000000000000000000000000000001");
    biMul(a, b);
    biToString(a, c, size);
    ok &= check((string)c == "100000000000000000000000000000000000000010000000000000000000000000000000000000000");
    biDelete(a);
    biDelete(b);
    

    check(ok, 1);
}

void test11() {
    cout << "test 11: ";
    cout.flush();
    bool ok = 1;

    BigInt bi1, bi2, bi3, bi4, bi5;
    bi1 = biFromInt(2ll);
    bi2 = biFromInt(-123ll);
    bi3 = biFromInt(-123ll);
    biAdd(bi1, bi2);
    biSub(bi1, bi2);
    ok &= check(biCmp(bi2, bi3) == 0);
    biDelete(bi1);
    biDelete(bi2);
    biDelete(bi3);

    bi1 = biFromInt(0xffffffffll);
    bi2 = biFromInt(0xffffffffll);
    bi5 = biFromInt(0xffffffffll + 0xffffffffll);
    biAdd(bi1, bi2);
    ok &= check(biCmp(bi1, bi5) == 0);
    biDelete(bi1);
    biDelete(bi2);
    biDelete(bi5);

    bi1 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137215"); // 2**1024 -1
    bi2 = biFromInt(-1ll);
    biSub(bi1, bi2);
    biDelete(bi2);
    ok &= check(bi1 != NULL);
    bi2 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216"); // 2**1024
    ok &= check(biCmp(bi1, bi2) == 0);
    biSub(bi1, bi2);
    biToString(bi1, c, size);
    ok &= check((string)(c) == "0");
    biDelete(bi1);
    biDelete(bi2);

    bi1 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216");
    bi2 = biFromString("-179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137215");
    bi3 = biFromString("1");
    biAdd(bi1, bi2);
    biToString(bi1, c, size);
    ok &= check(biCmp(bi1, bi3) == 0);
    biDelete(bi1);
    biDelete(bi2);
    biDelete(bi3);

    check(ok, 1);
}

void test12() {
    cout << "test 12: ";
    cout.flush();
    bool ok = 1;

    BigInt a = biFromInt(3);
    ok &= check(biCmp(a, a) == 0);
    biDelete(a);

    check(ok, 1);
}

void test13() {
    cout << "test " << 13 << ": ";
    cout.flush();
    bool ok = 1;

    BigInt a = biFromInt(0);
    mpz_class a2 = 0;
    string s = genRandNumber(100);
    BigInt b = biFromInt(0);
    biAdd(a, b);
    a2 += mpz_class(s);
    biDelete(a);
    biDelete(b);
    
    check(ok, 1);
}

void gmpDivision(mpz_class a1, mpz_class a2, mpz_class &x1, mpz_class &x2) {
    x1 = a1 / a2;
    x2 = a1 % a2;
    if (a1 < 0 && a2 > 0) {
        if (x2 < 0) {
            x2 += a2;
            x1--;
        }
    } else
    if (a1 > 0 && a2 < 0) {
        if (x2 > 0) {
            x2 += a2;
            x1--;
        }
    }
    assert(x1 * a2 + x2 == a1);
    if (a2 < 0) assert(x2 <= 0);
}

void testDelete(string s1, string s2, bool &ok) {
    // s2 != 0
    BigInt a = biFromString(s1.c_str());
    BigInt b = biFromString(s2.c_str());
    BigInt x, y;
    biDivRem(&x, &y, a, b);
    mpz_class a1 = 0;
    a1 += mpz_class(s1);
    mpz_class a2 = 0;
    a2 += mpz_class(s2);

    mpz_class x1, x2;
    gmpDivision(a1, a2, x1, x2);
    s1 = x1.get_str();
    s2 = x2.get_str();

    biToString(x, c, size);
    string c1 = (string)(c);
    ok &= check(c1 == s1);

    biToString(y, c, size);
    string c2 = (string)(c);
    ok &= check(c2 == s2);

    biDelete(a);
    biDelete(b);
    biDelete(x);
    biDelete(y);
}

void test14() {
    cout << "test 14: ";
    cout.flush();
    bool ok = 1;

    BigInt a, b;
    BigInt x, y;

    a = biFromInt(1);
    b = biFromInt(0);
    biDivRem(&x, &y, a, b);
    ok &= check(x == 0 && y == 0);
    biDelete(a);
    biDelete(b);
    
    a = biFromInt(0);
    b = biFromInt(1);
    biDivRem(&x, &y, a, b);
    biToString(x, c, size);
    ok &= check((string)(c) == "0");
    biToString(y, c, size);
    ok &= check((string)(c) == "0");
    biDelete(a);
    biDelete(b);
    biDelete(x);
    biDelete(y);
    
    testDelete("3", "15", ok);
    testDelete("16", "3", ok);
    testDelete("-16", "3", ok);
    testDelete("-16", "-3", ok);
    testDelete("16", "-3", ok);
    testDelete("15", "3", ok);
    testDelete("-15", "3", ok);
    testDelete("-15", "-3", ok);
    testDelete("15", "-3", ok);
    testDelete("1000000000000000", "100000", ok);
    testDelete("10000000000000000000000000", "10000000000000000000000000", ok);
    testDelete("100000000000000000000", "1", ok);
    testDelete("100000000000000000000000000000000000000000000000000", "100000000000000000000", ok);

    a = biFromInt(534635);
    biDivRem(&x, &y, a, a);
    biToString(x, c, size);
    ok &= check((string)(c) == "1");
    biToString(y, c, size);
    ok &= check((string)(c) == "0");
    biDelete(a);
    biDelete(x);
    biDelete(y);
    
    check(ok, 1);
}

void test15(int iterations, int size) {
    cout << "test 15: ";
    cout.flush();
    bool ok = 1;

    for (int it = 0; it < iterations; it++) {
        testDelete(genRandNumber(size * 2), genRandNumber(size), ok);
    }

    check(ok, 1);
}

void test16(int iters, int n, int len) {
    cout << "test 16: ";
    cout.flush();
    bool ok = 1;

    vector<BigInt> v(n);
    vector<mpz_class> g(n);
    for (int i = 0; i < n; i++) {
        string s = genRandNumber(len);
        v[i] = biFromString(s.c_str());
        g[i] = 0;
        g[i] += mpz_class(s);
    }

    for (int it = 0; it < iters; it++) {
        int k = rand() % 3;
        int i = rand() % n;
        int j = rand() % n;
        if (k == 0) {
            g[i] += g[j];
            biAdd(v[i], v[j]);
        } else
        if (k == 1) {
            g[i] -= g[j];
            biSub(v[i], v[j]);
        } else
        if (k == 2) {
            g[i] *= g[j];
            biMul(v[i], v[j]);
        } else {
            int o = rand() % 2;
            if (g[j] == 0) continue;
            BigInt x, y;
            biDivRem(&x, &y, v[i], v[j]);
            mpz_class x1, x2;
            gmpDivision(g[i], g[j], x1, x2);
            if (o == 0) {
                g[i] = x1;
                swap(v[i], x);
            } else
            if (o == 1) {
                g[i] = x2;
                swap(v[i], y);
            }
            biDelete(x);
            biDelete(y);
        }
        biToString(v[i], c, size);
        string s = g[i].get_str();
        ok &= check((string)(c) == s);
    }
    for (int i = 0; i < n; i++) {
        biDelete(v[i]);
    }

    check(ok, 1);
}

string sa = "-5274059441834509699249091608271632098173384117739053644050290501833943319795703818412817945116011995810019729932767933642448947064191015219695263265467592088445106907659660941095524914332279487588262406534630738240160851649684527922074479014629354860928815381309608255149891541273759176211340310015830804121113701248149875330153211960698413887764987800302356456687548489331958179267150282899529485258697678516736357619092052799579199109880333974541361450870158271021089282510877129189566212249163344861117039736989212785002405283650160616911609327615453557987845043217111499801569005571936611206834660506699364925677877802627630583575574480592987188995993274429916783238655022155355197903328335005161510964689217838418485687222219402547093807809932013371242882396667402554355779171021675332894385595706663831633955254510074439619053266470563899026913800066410012673511196821926199929148295127723990638341561382316611679015590529386361096273992567949116619634506369359588906375272783741910089850270645";
string sb = "-7024742639063968796804208185490023699172091587358161503321983905266473604953810728889133441943489229719226517702682515070176636569652774647327707950758987542110206675150894884581678668534767897477182193772342401487232618419177087328895052494563488651712841550502383118370936274161434739816066216849697692411947292786887495236031000989133449480678459398013947269459484920069156912073077481307252312806803710633050360028359096427607519003068563621843888989554234187388604663145329607728673008717445428904428972034026014536327074818629263270405800701374907836439314432950110812884911623516359402845132363557735159431784630770067792249794487212155445908988104875199270618359864530321339169758288307380336214897929274191268218240908253085486290317046383116132154170470138958919736564075609936363322345433456549195604184299835387543307844498517279608239112853529979855214267986167100033510095982080501128138767477601254253963281253587391477137007324061367705042490150419442142006405553423157398303576410725";

char rndChar() {
    int x = rand();
    x %= 10;
    if (x < 0) x += 10;
    return x + '0';
}

#include "vectorint.h"
int main() {
  /*  test1();
    test2();
    test3();
    test4(2);
    test4(1000);
    test5();
    test6();
    test7();*/

/*BigInt c = biFromString(sa.c_str());
biSub(c, biFromString(sb.c_str()));
char buf[1005];
biToString(c, buf, 1005);

mpz_class xa = mpz_class(sa);
mpz_class xb = mpz_class(sb);
xa -= xb;
cout << (xa.get_str() == string(buf));*/

//    test8(8, 2, 1000, 1000);
    test8(10, 3, 100, 200);

/*    test11(); 
    test9();
    test12();
    test13();*/

    //test14();
    //test15(1000, 100);
//    test16(3000, 500, 100);
    return 0;
}
