#include <bits/stdc++.h>
#include <gmp.h>
#include <gmpxx.h>
#include "bigint.h"




using namespace std;

#define db(x) cerr << #x << " = " << x << endl
#define mp make_pair

const int N = 1e6;
char s[1000];

void p(void * ptr, int k = 0) {
    long long * x = (long long *)ptr; 
    for (int i = 0; i < k; i++)
        x++;
    cout << (*x) << endl;
}
void detailPrint(BigInt);

void print(BigInt c, bool flag = false) {
    if (flag) {
        detailPrint(c);
        return;
    }
    char s[10000];
    biToString(c, s, 1000);
    cout << s << endl;
}

int sign(int x) {
    if (x == 0) return 0;
    if (x < 0) return -1;
    return 1;
}

void equal(BigInt a, string s) {
    char t[N];
    biToString(a, t, N); 
    string tt(t);
    if (tt != s) {
        db(tt);
        db(s);
    }
    assert(tt == s);
}

void testCmp() {
    /// test cmp
    if (0) {
        BigInt aa = biFromInt(100);
        BigInt bb = biFromInt(11);
        //cerr << "dd\n";
        cerr << biCmp(aa, bb) << endl;
        //cerr << "dd\n";
    }
    else {
        for (int i = 0; i < 100; i++) {
            //cerr << "test: " << i << endl;
            int T = 10;
            int a = rand() % T - T / 2;
            int b = rand() % T - T / 2;
            BigInt aa = biFromInt(a);
            BigInt bb = biFromInt(b);
            int r1 = sign(a - b);
            int r2 = biCmp(aa, bb);
            assert(r1 == r2);
        } 
        cerr << "cmp short OK\n";
    }
    exit(0);
}

void t1() {
    char s[100];
    freopen("in", "r", stdin);
    scanf("%s", s);
    //sprintf(s, "%d", 3);
    //cerr << "before\n";
    if (0) {
        long long T = 7993;
        BigInt c = biFromInt(T);
        for (int i = 0; i < 20; i++) {
            biMulShort(c, T);
            //cerr << biDivShort(c, 100000) << endl;
            print(c);    
        }
        //biAddShort(c, 1008);
        cerr << "---\n";
        print(c);    
    }
    else {
        BigInt b = biFromString(s);
        cerr << "after\n";
        print(b);
    }
    exit(0);
}

void printPtr(void * p1, int k = 0) {
    auto p = (long long *) p1;
    for (int i = 0; i < k; i++) 
        p++;
    cout << (*p) << endl;
}

void detailPrint(void * _p) {
    auto p = (long long *)_p;
    int sz = p[1];
    cerr << "size: " << p[1] << endl;
    cerr << "cap : " << p[2] << endl;
    cerr << "sign: " << p[3] << endl;
    auto v = (long long *)(*p);
    for (int i = 0; i < sz; i++)
        cerr << (unsigned long long)v[i] << " ";
    cerr << endl;
}

void t3() {
    if (1) {
        //if (1) {
            //string s = "18446744073709551616";
            //BigInt tmp = biFromInt(0);
            //for (int i = 0; i < (int)s.size(); i++) {
                //biMulShort(tmp, 10);
                //biAddShort(tmp, s[i] - '0');
                ////print(tmp);
            //}
            //print(tmp); 
            //detailPrint(tmp);
        //}
        //else {
            //cerr << "--------------\n";
            //BigInt r = biFromInt(0);
            //long long T = 1e18;
            //for (int i = 0; i < 20; i++) {
                //biAddShort(r, T);
                //print(r);
            //}
        //}
        string s, t;
        s = "10000000000000000000000000000000000000000000000000000000000000000000";
        //s = "6277101735386680763835789423207666416102355444464034512896";
        //s = "340282366920938463463374607431768211456";
        //
        //
        //s = "18446744073709551616";
        //
        //string s = "18446744073709551616";
        t = "100000000000000000000000000000000000000";
        //t = "1";
        //BigInt a = biFromInt(1000);
        //BigInt b = biFromInt(10001);
        BigInt a = biFromString(s.c_str());
        BigInt b = biFromString(t.c_str());
        print(a);
        print(b);
        //cerr << "before\n";
        BigInt c = biSubMy(b, a);
        print(c);
        detailPrint(c);
    }
    exit(0);

}

void t4() {
    string s, t;
    s = "-10000000000000000000000000000000000000000000000000000000000001";
    //t = "20000000000000000000000000000000000000000001";
    t = "-0";
    BigInt a = biFromString(s.c_str());
    BigInt b = biFromString(t.c_str());
    BigInt c = biMulMy(a, b);
    print(c); 
    exit(0);
}

void t5() {
    string s, t;
    s = "-10000000000000000000000000000000000000000000000000000000000001";
    t = "20000000000000000000000000000000000000000001";
    s = "3";
    t = "5";
    //t = "-0";
    BigInt a = biFromString(s.c_str());
    BigInt b = biFromString(t.c_str());
    print(a);
    print(b);
    biSub(a, b);
    print(a);
    print(b);
    exit(0);
}



void testSum() {
    string s, t;
    s = "14947181269259654621";
    t = "15677406474858260664";
    BigInt a = biFromString(s.c_str());
    BigInt b = biFromString(t.c_str());
    //biSubMy(a, b); //(-121
    //detailPrint(a);
    //detailPrint(b);

    biAdd(a, b); //(-121
    //detailPrint(a);
    cerr << "OK\n";
    //exit(0);
}

void testDiv() {
    // check Div
    string s, t;
    s = "0";
    t = "-62";
    BigInt a = biFromString(s.c_str());
    BigInt b = biFromString(t.c_str());
    BigInt c, e;
    if (0) {
        //BigInt d = biDivRem(&c, NULL, a, b);
        //cerr << "----------\n";;
        //print(d);
        //detailPrint(d);
    }
    else {
        biDivRem(&c, &e, a, b);
        cerr << "div:  ";
        detailPrint(c);
        cerr << "rem:  ";
        print(e);
        detailPrint(c);
    }
    exit(0);
}

void testSetBit() {
    /// check set bit
    BigInt a = biFromInt(0);
    print(a); 
    biSetBit(a, 40);
    biSetBit(a, 63);
    biSetBit(a, 2);
    print(a); 
    exit(0);
}

void testBigShl() {
    // bigshl
    string s = "-10000000000000000000000000000000000000000000000000000000000001";
    BigInt a = biFromString(s.c_str());
    biBigShl(a, 3);
    detailPrint(a);
    print(a);
}

string getRandString() {
    int n = 100;
    string s;
    if (rand() % 2) s += "-";
    for (int i = 0; i < n; i++) {
        char ch = (rand() % 10 + '0');
        if (ch == '0' && i == 0) ch = '1';
        s += ch;
    }
    return s;
}

pair < mpz_class, mpz_class > myDivRem(mpz_class a, mpz_class b) {  // r c
    if (a % b == 0) {
        return mp(a / b, mpz_class(0));
    }
    mpz_class c = abs(a) / abs(b);
    mpz_class r = abs(a) % abs(b);
    mpz_class C, R;
    if (a >= 0 && b >= 0) {
        C = c;
        R = r;
    } 
    if (a < 0 && b >= 0) {
        C = - c - 1;
        R = abs(b) - r;
        //return mp(-c - 1, b - r);
    }
    if (a >= 0 && b < 0) {
        C = - c - 1; 
        R = r - abs(b);
        //return mp(-c - 1, r - b);
    }
    if (a < 0 && b < 0) {
        C = c;
        R = -r;
    }
    //cerr << C << " " << R << endl;
    //return mp(c, -r);
    //cerr << a << endl;
    //cerr << b * C + R << endl;
    assert(a == b * C + R);
    return mp(C, R);
}

int sign(mpz_class a) {
    if (a == 0) return 0;
    if (a < 0) return -1;
    return 1;
}


void bigTest() {
    for (int ser = 0; ser < 200; ser++) {
        BigInt a = biFromInt(0);
        mpz_class b = 0;
        for (int t = 0; t < 100; t++) {
            //cerr << "================== " << t << endl;
            int type = rand() % 6;
            string ss = getRandString();
            //db(s);
            BigInt c = biFromString(ss.c_str());
            mpz_class d(ss);
            //db(type);
            //cerr << "a: ";
            //print(a);
            //cerr << "c: ";
            //print(c);
            if (type == 0) {
                biAdd(a, c);
                b += d; 
            }
            if (type == 1) {
                biSub(a, c);
                b -= d;
            }
            if (type == 2) {
                biMul(a, c);
                b *= d;
            }
            if (type == 3) {
                BigInt t1, t2;
                biDivRem(&t1, &t2, a, c);
                a = t1;
                b = myDivRem(b, d).first;
            }
            if (type == 4) {
                BigInt t1, t2;
                biDivRem(&t1, &t2, a, c);
                a = t2;
                b = myDivRem(b, d).second;
            }
            if (type == 5) {
                int x = biCmp(a, c);
                mpz_class r = (b - d);
                BigInt g = biSubMy(a, c);
                int y = biSign(g);
                assert(sign(r) == x && y == x);
                //db(x);
            }
            char s[N]; 
            biToString(a, s, N);     
            string mpzS = b.get_str(); 
            string tt(s);
            //db(tt);
            //db(mpzS);
            assert(tt == mpzS);
        }
        //cerr << "OK\n";
    }
    cerr << "OK\n";
}

void tmpTest() {
    string s, t;
    s = "0";
    t = "4";
    BigInt a = biFromString(s.c_str());
    BigInt b = biFromString(t.c_str());
    BigInt t1, t2;
    print(a);
    print(b);
    biDivRem(&t1, &t2, a, b);
    
    print(t1); 
    print(t2); 


    //mpz_class a(10);
    //mpz_class b(-7); 
    //myDivRem(a, b);
}

void testsFromGitHub() {
    string s;
    s = "-";
    BigInt x = biFromString(s.c_str());
    assert(x == 0);
    s = "a";
    x = biFromString(s.c_str());
    assert(x == 0);
//2^1024 + (-(2^1024 - 1)) ≠ 1

    s = "179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216";
    BigInt a = biFromString(s.c_str());
    BigInt b = biFromString(s.c_str());
    biSub(b, biFromInt(1));
    biMul(b, biFromInt(-1));
    biAdd(a, b);
    assert(biCmp(a, biFromInt(1)) == 0);

    BigInt bi1, bi2, bi3, bi5;
    bi1 = biFromInt(2ll);
    bi2 = biFromInt(-123ll);
    bi3 = biFromInt(-123ll);
    biAdd(bi1, bi2);
    biSub(bi1, bi2);
    assert(biCmp(bi2, bi3) == 0);

    bi1 = biFromInt(0xffffffffll);
    bi2 = biFromInt(0xffffffffll);
    bi5 = biFromInt(0xffffffffll + 0xffffffffll);
    biAdd(bi1, bi2);
    assert(biCmp(bi1, bi5) == 0);

    bi1 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137215"); // 2**1024 - 1
    bi2 = biFromInt(-1ll);
    biSub(bi1, bi2);

    bi1 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137215"); // 2**1024 -1
    bi2 = biFromInt(-1ll);
    biSub(bi1, bi2);
    assert(bi1);
    bi2 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216"); // 2**1024
    assert(biCmp(bi1, bi2) == 0);

    bi1 = biFromInt(4611686018427387904ll);
    bi2 = biFromInt(-9223372036854775807LL);
    biAdd(bi2, bi1);
    biAdd(bi2, bi1);
    assert(biCmp(bi2, biFromInt(1)) == 0);
    cerr << "git test OK\n";

    bi1 = biFromInt(1);
    bi2 = biFromInt(0);
    BigInt bi4;
    biDivRem(&bi3, &bi4, bi1, bi2);
    assert(bi3 == NULL && bi4 == NULL);

    bi1 = biFromInt(10000000000001);
    bi2 = biFromInt(10000000000000001);
    biMul(bi1, bi2);
    //print(bi1);
    char ss[10];
    biToString(bi1, ss, 10);
    //cerr << ss << endl;
}

int main() {
    //t1();
    //testCmp();
    //t3();
    //t4();
    //t5();
    //testSum();
    //testDiv();
    //testSetBit();
    //testBigShl();
    bigTest();
    //tmpTest();
    testsFromGitHub();
    return 0;
    BigInt b = biFromInt(0);
    BigInt c = biCopy(b);
    p(c);
    p(c, 1);
    p(c, 2);
    p(c, 3);
    //BigInt c = biCopy(b);
    //cerr << "build\n";
    //db(3);
    db(biIsZero(b));
    //cout << biDivShort(b, 10) << endl;
    //cout << biDivShort(c, 10) << endl;
    memset(s, 0, sizeof(0));
    biToString(b, s, 100);
    for (int i = 0; i < 3; i++)
        cerr << (int)s[i] << " ";
    cerr << endl << s << endl;
}






