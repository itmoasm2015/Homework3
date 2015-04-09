#include "unistd.h"
#include "include/bigint.h"
#include <iostream>
#include <cstring>
#include <cassert>
#include <cstdlib>
#include <ctime>
#include <cstring>

using namespace std;

#define calc(a, ans)        \
    int __b = a;            \
    int __res = 0;          \
                            \
    while (__b!=0) {        \
        __res++; __b /= 10; \
    }                       \
    ans = __res;            \

bool myStrCmp(const char *s1, const char *s2) {
    if (strlen(s1) != strlen(s2)) return false;
    int len = strlen(s1);
    for (int i = 0; i < len; i++) {
        if (s1[i] != s2[i]) {
            return false;
        }
    }
    return true;
}

void genBigIntAsString(char *s, int len) {
    int sign = rand() % 2;
    if (sign == 1) {
        s[0] = '-';
    }
    int curDig;
    curDig = rand() % 9;
    s[sign] = '1' + curDig;
    for (int i = 1; i < len; i++) {
        curDig = rand() % 10;
        s[i+sign] = '0' + curDig;
    }
    s[len+sign] = 0;
}

void genStuff(char *s, int len) {

}

char s[10000005];
char buf[10000005];

void test1() {
    for (int t = 0; t < 10; t++) {
        int len = rand() % 10000000 + 1;
        genBigIntAsString(s, len);
        BigInt a = biFromString(s);
        biToString(a, buf, len + 5);
        assert(myStrCmp(buf, s) == true);
        biDelete(a);
    }
}

int main() {
    srand(time(NULL));
    //test1();
    BigInt a = biFromString("0");
    BigInt b = biFromString("-167897656787656765678");
    cout << biAdd(a, b) << "\n";
    char s[1000];
   // biToString(a, s, 1000);
    cout << s << "\n";
    //cout << biCmp(a, b) << "\n";
    //cout << *((int*)a+1) << "\n";
    //cout << biSign(a) << "\n";
    return 0;
}
