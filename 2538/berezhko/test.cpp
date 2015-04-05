#include "unistd.h"
#include "include/bigint.h"
#include <iostream>
#include <cstring>
#include <cassert>
#include <cstdlib>
#include <ctime>
#include <cstring>

using namespace std;

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
    sign=0;
    if (sign == 1) {
        s[0] = '-';
    }
    int curDig;
    curDig = rand() % 9;
    s[0+sign] = '1' + curDig;
    for (int i = 1; i < len; i++) {
        curDig = rand() % 10;
        s[i+sign] = '0' + curDig;
    }
    s[len+sign] = 0;
}

void genStuff(char *s, int len) {

}

char s[1005];
char buf[1005];

void test1() {
    for (int t = 0; t < 1; t++) {
        //int len = rand() % 1000 + 1;
        int len = 1000;
        genBigIntAsString(s, len);
        BigInt a = biFromString(s);
        cout << biToString(a, buf, 1000) << "\n";
        //assert(myStrCmp(buf, s) == true);
        if (!myStrCmp(buf, s)) {
            cout << len << "\n";
            break;
        }
        biDelete(a);
    }
}

int main() {
    srand(time(NULL));
    test1();
    return 0;
}
