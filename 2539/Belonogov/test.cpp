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


void t1() {
    char s[100];
    freopen("in", "r", stdin);
    scanf("%s", s);
    //sprintf(s, "%d", 3);
    //cerr << "before\n";
    if (1) {
        long long T = 7993;
        BigInt c = biFromInt(T);
        for (int i = 0; i < 20; i++) {
            biMulShort(c, T);
            //cerr << biDivShort(c, 100000) << endl;
            print(c);    
        }
        //biAddShort(c, 1008);
        //cerr << "---\n";
        print(c);    
    }
    else {
        //BigInt b = biFromString(s);
        //cerr << "after\n";
        //print(b);
    }
    exit(0);
}


int main() {
    t1();

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






