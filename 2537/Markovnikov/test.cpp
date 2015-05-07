#include "bigint.h"
#include <stdio.h>
#include <cstdlib>
#include <climits>
#include <cmath>
#include <string>
#include <string.h>
using namespace std;

int64_t get_random_int(int64_t l, int64_t r);
string get_random_string();
string get_random_string_from_ints();

int64_t get_random_int(int64_t l, int64_t r) {
        return rand() % r + l;
}

string get_random_string() {
    string res = "";
    int n = (int) get_random_int(0, 512);
    for (int i = 0; i < n; i++)
        res += (char)(get_random_int(15, 180));
    return res;
}

string get_random_string_from_ints() {
    string res = "";
    int n = (int) get_random_int(0, 512);
    if (get_random_int(0, 1) == 0)
        res += '-';
    for (int i = 0; i < n; i++) 
        res += (char)('0' + get_random_int(0, 9));
    return res;
}

#define TEST(test)  if (test()) \
                            printf("%s %s\n", #test, "OK"); \
                    else \
                        printf("%s %s\n", #test, "FAILED"); \

bool biFromInt_test() {
    BigInt a = biFromInt(get_random_int(-1000, 1000000));
    return true;
}

bool biFromString_test() {
    BigInt a = biFromString("000000001000000000000000000000123");
    BigInt b = biFromString("-19000000000000001212121212");
    BigInt c = biFromString("1lffdlkjkfdjkfdjk3434kjdkf");
    if (c != 0)
        return false;
    BigInt d = biFromString("");
    if (d != 0)
        return false;
    BigInt e = biFromString("-");
    if (e != 0)
        return false;
    BigInt f = biFromString("22-2");
    if (f != 0)
        return false;
    return true;
}

bool biToString_test() {
    for (int i = 0; i < 10; i++) {
        string t = get_random_string_from_ints();
        BigInt a = biFromString(t.c_str());
        char* buffer = new char[t.length()];
        biToString(a, buffer, t.length() + 1);
        string res(buffer);
        if (res != t) {
            printf("%s\n%s\n", t.c_str(), res.c_str());
           // return false;
        }
    }

    for (int i = 0; i < 10; i++) {
        int64_t t = get_random_int(-100000, 100000);
        BigInt a = biFromInt(t);
        char* buffer = new char[8];
        biToString(a, buffer, 8);
        printf("%d\n%s\n", (int)t, buffer);
    }

    return true;
}

bool biSign_test() {
    BigInt a = biFromString("3249832482374823789472389748923");
    int sign = biSign(a);
    if (sign <= 0)
        return false;
    BigInt b = biFromString("-283748923489237487328478923789");
    if (biSign(b) >= 0)
        return false;
    BigInt c = biFromString("0");
    if (biSign(c) != 0)
        return false;
    biDelete(a);
    biDelete(b);
    biDelete(c);
    return true;
}

bool biAdd_test() {
    BigInt a = biFromInt(1234);
    BigInt b = biFromInt(4321);
    biAdd(a, b);
    char* buffer = new char[5];
    biToString(a, buffer, 5);
    printf("%s\n", buffer);
    return true;
}

bool biSub_test() {
    BigInt a = biFromInt(3500);
    BigInt b = biFromInt(2200);
    biSub(a, b);
    char* buffer = new char[5];
    biToString(a, buffer, 5);
    printf("%s\n", buffer);
    a = biFromInt(100);
    biSub(a, b);
    buffer = new char[5];
    biToString(a, buffer, 6);
    printf("%s\n", buffer);
    return true;
}

bool biMul_test() {
    BigInt a = biFromInt(25);
    BigInt b = biFromInt(-765);
    biMul(a, b);
    char* buffer = new char[7];
    biToString(a, buffer, 7);
    printf("%s\n", buffer);
    return true;
}

bool biCmp_test() {
    BigInt a = biFromInt(12345);
    BigInt b = biFromInt(343);
    if (biCmp(a, b) != 1)
        return false;
    if (biCmp(b, a) != -1)
        return false;
    if (biCmp(a, a) != 0)
        return false;
    return true;
}

int main() {
    TEST(biFromInt_test);
    TEST(biFromString_test);
    TEST(biToString_test);
    TEST(biSign_test);
    TEST(biAdd_test);
    TEST(biSub_test);
    TEST(biMul_test);
    TEST(biCmp_test);
    return 0;
}
