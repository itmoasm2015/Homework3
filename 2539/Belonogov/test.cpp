#include <bits/stdc++.h>
#include <gmp.h>
#include <gmpxx.h>
#include "bigint.h"




using namespace std;

#define db(x) cerr << #x << " = " << x << endl

char s[1000];

void p(void * ptr, int k = 0) {
    long long * x = (long long *)ptr; 
    for (int i = 0; i < k; i++)
        x++;
    cout << (*x) << endl;
}

void print(BigInt c) {
    char s[10000];
    biToString(c, s, 1000);
    cout << s << endl;
}

int sign(int x) {
    if (x == 0) return 0;
    if (x < 0) return -1;
    return 1;
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

void t6() {
    BigInt a = biFromInt(2);
    BigInt b = biFromInt(-123);
    BigInt c = biFromInt(-123);
    biAdd(a, b); //(-121
    biSub(a, c); // 2
    cout << biCmp(b, c) << endl;
    exit(0);
}

void testDiv() {
    // check Div
    string s, t;
    s = "10000";
    t = "1000000000000000000000000000000000000000000000";
    BigInt a = biFromString(s.c_str());
    BigInt b = biFromString(t.c_str());
    BigInt c;
    if (0) {
        BigInt d = biDivRem(&c, NULL, a, b);
        cerr << "----------\n";;
        print(d);
        detailPrint(d);
    }
    else {
        biDivRem(&c, NULL, a, b);
        print(c);
        detailPrint(c);
    }
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

int main() {
    //t1();
    //testCmp();
    //t3();
    //t4();
    //t5();
    //t6();
    testDiv();
    //testSetBit();
    //testBigShl();
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






