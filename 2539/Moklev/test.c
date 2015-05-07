#include "bigint.h"
#include "stdio.h"
#include <stdlib.h>
#include <string.h>

#define bool int
#define true 1
#define false 0

#define uint64_t long long unsigned int
#define int64_t long long int

#define passed(s) printf("%s\n", "\033[0;32mTest " #s " passed\033[0m")
#define failed(s) printf("%s\n", "\033[0;31mTest " #s " failed\033[0m")
#define report(flag, test) if (flag) passed(test); else failed(test);

bool flag;
const char * small_numbers[20] = {
    "0", 
    "-0", 
    "42", 
    "-69", 
    "127", 
    "-128", 
    "32767", 
    "-32768", 
    "2147483647", 
    "-2147483648", 
    "9223372036854775807", 
    "-9223372036854775808", 
    "000000001232141967", 
    "-00000001112436791231", 
    "00000000000000000127", 
    "-0000000000000000000128", 
    "00000000000000000000002147483647", 
    "-00000000000000000002147483648", 
    "00000000000000000000009223372036854775807", 
    "-0000000000000000009223372036854775808"
};

int64_t numbers[20] = {
    0, 
    0, 
    42, 
    -69, 
    127, 
    -128, 
    32767, 
    -32768, 
    2147483647, 
    -2147483648, 
    0x7FFFFFFFFFFFFFFFll, 
    0x8000000000000000ll, 
    1232141967ll, 
    -1112436791231ll, 
    127, 
    -128, 
    2147483647, 
    -2147483648, 
    0x7FFFFFFFFFFFFFFFll, 
    0x8000000000000000ll 
};

const char * huge_numbers[10] = {
    "461928734691287",
    "94786129387461928374691283579127384691327846",
    "65623497694273191687234698712364981723694871269387469128734691287364987123469713269487",
    "71987346912783469182734691827369418726912873469128736051273469829364978127834807917823460982173407123694712364987123640",
    "83457269347826398472569804372364928365468923486123846512798340101237846012873461892746981273498127364987123694781326949",
    "93801182377469218374698127364987123694871269384769128734698127348218376489723694876192873469817234698712369487612398479",
    "35723694857693284756982374598734695873269847569837246957832694875697384650813208147019283740981273049872013984702987302"
    "45762398745692387456938274569837245698374659873469587632948756983274569872346958761320761230461239765938476598273469587"
    "34572693847569837459857203849570392845709328475098234759083274058702348957039824750289347508932740589273045870234895709",
    "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    "15763743543253453234532452456234534523453245324532451433631400000000000000000000000000000000000000000000000000000000000"
    "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    "00000000000000000000000000000000000000000000042342342143126394786912387469128734691287346912738400000000000000000000000"
    "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000123421340000000000000000"
    "00000000000000000000000000000000000000000000123421342134213400000000000000000000000000000000000000000012341234000000000",
    "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
};

const char * malformed_string[6] = {
    "lalka",
    "--123",
    " 123",
    "21930129380129830192830982130-",
    "+12367",
    "-"
};

void print_long(BigInt a, bool flag) {
    unsigned long long * p = (unsigned long long *) a;
    unsigned long long * d = (unsigned long long *) p[3];
    if (p[0])
        printf("-");
    else
        printf("+");
    int limit = p[1];
    if (flag)
        limit = p[2];
    for (int i = 0; i < limit; i++)
        printf("%llu ", d[i]); 
    printf("\n");
}

long long lalka(unsigned long long a);

int main() {
    // ?. Simple biDivRem test
    flag = true;
    for (int k = 0; k < 10000; k++) {
        #define N 100
        #define M 98
        char sa[N];
        char sb[N];
        char sd[M];
        for (int i = 0; i < N; i++) {
            sa[i] = '1' + rand() % 9;
            if (i < N - 1)
                sb[i] = '1' + rand() % 9;
            if (i < M)
                sd[i] = '0' + rand() % 10;
        }
        sa[N - 1] = '\0';
        sb[N - 1] = '\0';
        sd[M - 1] = '\0';

        BigInt a = biFromString(sa);
        BigInt c = biFromString(sa);
        BigInt b = biFromString(sb);
        BigInt d = biFromString(sd);
        biMul(a, b);
        biAdd(a, d);

        BigInt q = biFromInt(0);
        BigInt r = biFromInt(0);
        biDivRem(&q, &r, a, b);
        if (biCmp(c, q) != 0 || biCmp(r, d) != 0) {
            print_long(a, 1);
            print_long(b, 1);
            printf("%d %d\n", biCmp(c, q), biCmp(r, d));
            char sq[100];
            char sr[100];
            biToString(q, sq, 100);
            biToString(r, sr, 100);
            printf("\033[0;31mFailed:\033[0m\na = %s\nb = %s\nd = %s\nq = %s\nr = %s\n", sa, sb, sd, sq, sr);
            flag = false;
            break;
        } 
        biDelete(a);
        biDelete(b);
        biDelete(c);
        biDelete(d);
        biDelete(q);
        biDelete(r);
        #undef N
        #undef M
    }
    report(flag, simple_div_test);
    // ?. Signed biDivRem test
    signedlal: {
    }
    flag = true;
    for (int i = 0; i < 1000; i++) {
        #define N 1000
        int l1 = rand() % N + 3;
        int l2 = rand() % N + 3;
        char sa[l1 + 1];
        char sb[l2 + 1];
        for (int k = 0; k < l1; k++)
            sa[k] = '0' + rand() % 10;
        for (int k = 0; k < l2; k++)
            sb[k] = '0' + rand() % 10;
        if (sb[l2 - 1] == '0')
            sb[l2 - 1] = '1';
        sa[l1] = '\0';
        sb[l2] = '\0';
        if (rand() % 2)
            sa[0] = '-';
        if (rand() % 2)
            sb[0] = '-';

        BigInt a = biFromString(sa);
        BigInt b = biFromString(sb);
        BigInt q = biFromInt(0);
        BigInt r = biFromInt(0);
        biDivRem(&q, &r, a, b);
       
        flag &= biSign(r) == 0 || biSign(r) == biSign(b);
        if (!flag)
            printf("\033[0;31mFailed:\033[0m\nbiSign(r) = %d\nbiSign(b) = %d\n", biSign(r), biSign(b));
        biMul(q, b);
        biAdd(q, r);
        flag &= biCmp(a, q) == 0; 
        if (!flag) {
            printf("\033[0;31mFailed:\033[0m\n");
            print_long(a, true);
            print_long(q, true);
        }
        if (!flag) 
            break;
        biDelete(a);
        biDelete(b);
        biDelete(q);
        biDelete(r);
        #undef N
    }
    report(flag, sign_div_test);
    // ?. Huge biMul && biDelete test
    {
        BigInt a = biFromInt(1);
        BigInt b = biFromInt(1);
        BigInt c = biFromInt(1);
        BigInt r = biFromInt(0);
        BigInt z = biFromInt(0);
        for (int i = 0; i < 1000; i++) {
            biMul(a, b);
            biAdd(b, c);
        }
        for (int i = 0; i < 1000; i++) {
            biSub(b, c);
            biDivRem(&a, &r, a, b);
            flag = (biCmp(r, z) == 0);
            if (!flag)
                break;
        }
        report(flag && biCmp(a, c) == 0, huge_factorial_mul_div_test);
        biDelete(a);
        biDelete(b);
        biDelete(c);
        biDelete(r);
        biDelete(z);
    }
    // ?. Test for NULL result of biDivRem(_, _, _, 0)
    {
        BigInt q = biFromInt(42);
        BigInt r = biFromInt(69);
        BigInt _q = q;
        BigInt _r = r;
        BigInt a = biFromString("-19264123974691238746123978461927384691287312879346917283469127346");
        BigInt b = biFromInt(0);
        biDivRem(&q, &r, a, b);
        report(q == NULL && r == NULL, null_div_result);
        biDelete(a);
        biDelete(b);
        biDelete(_q);
        biDelete(_r);
    }
    // 1. Memory leak check
    for (int i = 0; i < 10000; i++) {
        BigInt a = biFromInt(0x7FFFFFFFFFFFFFFFll);
        biDelete(a);
    }
    passed(memory_leak_check);
    // 2. Test biCmp && biFromInt
    flag = true;
    for (int i = 4; i < 10000; i++) {
        int64_t ai = 0xFFFFFFFFFFFFFFFF / 10000 * i;
        int64_t bi = 0xFFFFFFFFFFFFFFFF / 777 * (4277 - i); 
        BigInt a = biFromInt(ai);
        BigInt b = biFromInt(bi);
        if (!((biCmp(a, b) < 0 && ai < bi) 
         ||  (biCmp(a, b) > 0 && ai > bi) 
         ||  (biCmp(a, b) == 0 && ai == bi))) {
            flag = false;
            printf("\033[0;31mFailed:\033[0m %lld %lld, got: %d %lld\n", ai, bi, biCmp(a, b), ai - bi);
        }
        biDelete(a);
        biDelete(b);
        if (!flag)
            break;
    }
    report(flag, cmp_from_int);
    // 3. Test biCmp && biFromString
    flag = true;
    for (int i = 0; i < 10; i++)
        for (int j = 0; j < 10; j++) {
            BigInt a = biFromString(huge_numbers[i]);
            BigInt b = biFromString(huge_numbers[j]);
            if (!(biCmp(a, b) < 0 && i < j) 
             && !(biCmp(a, b) > 0 && i > j) 
             && !(biCmp(a, b) == 0 && i == j))
                 flag = false;
            biDelete(a);
            biDelete(b);
            if (!flag)
                break;
        }
    report(flag, cmp_from_string);
    // 4. Test biCmp && biFromInt && biFromString
    flag = true;
    for (int i = 0; i < 10; i++)
        for (int j = 0; j < 10; j++) {
            BigInt a = biFromString(small_numbers[i]);
            BigInt b = biFromString(small_numbers[j]);
            BigInt c = biFromInt(numbers[i]);
            BigInt d = biFromInt(numbers[j]);
            if (!(biCmp(a, b) < 0 && numbers[i] < numbers[j]) 
             && !(biCmp(a, b) > 0 && numbers[i] > numbers[j]) 
             && !(biCmp(a, b) == 0 && numbers[i] == numbers[j])
             || biCmp(a, c) != 0 || biCmp(b, d) != 0) {
                flag = false;
                printf("\033[0;31mFailed:\033[0m %lld %lld, got: %d %d %d\n", numbers[i], numbers[j], biCmp(a, b), biCmp(a, c), biCmp(b, d));
                print_long(a, false);
                print_long(b, false);
                print_long(c, false);
                print_long(d, false);
            }
            biDelete(a);
            biDelete(b);
            biDelete(c);
            biDelete(d);
            if (!flag)
                break;
        }
    report(flag, cmp_string_int);
    // 5. Test biToString (no limit)
    flag = true;
    for (int test = 2; test < 1000; test++) {
        char* s = (char*) malloc(test + 1);
        for (int i = 0; i < test; i++) 
            s[i] = '0' + ((unsigned int)rand()) % 10;
        s[test] = 0;
        if (rand() % 2 == 1) 
            s[0] = '-';
        for (int i = 0; i < test; i++) {
            if (s[i] != '0' && s[i] != '-')
                break;
            s[i] = '1' + ((unsigned int)rand()) % 9;
        }
        BigInt a = biFromString(s);
        char* buffer  = (char*) malloc(test + 10);
        for (int i = 0; i < test + 1; i++)
            buffer[i] = 'Z';
        biToString(a, buffer, test + 1);
        if (strcmp(s, buffer) != 0) {
            flag = false;
            printf("\033[0;31mFailed:\033[0m\ngot: %s\nexpected: %s\n", buffer, s);
        }/* else {
            printf("\033[0;32mPassed:\033[0m\ngot: %s\nexpected: %s\n", buffer, s);
        }*/
        free(buffer);
        free(s);
        biDelete(a);
        if (!flag)
            break;  
    }
    report(flag, bi_to_string_test);
    // 6. Test biToString (with limit)
    flag = true;
    for (int test = 100; test < 1000; test++) {
        char* s = (char*) malloc(test + 1);
        for (int i = 0; i < test; i++) 
            s[i] = '0' + ((unsigned int)rand()) % 10;
        s[test] = 0;
        if (rand() % 2 == 1) 
            s[0] = '-';
        for (int i = 0; i < test; i++) {
            if (s[i] != '0' && s[i] != '-')
                break;
            s[i] = '1' + ((unsigned int)rand()) % 9;
        }
        BigInt a = biFromString(s);
        int limit = test / 2;
        s[limit - 1] = '\0';
        char* buffer  = (char*) malloc(limit);
        for (int i = 0; i < limit; i++)
            buffer[i] = 'Z';
        biToString(a, buffer, limit);
        if (strcmp(s, buffer) != 0) {
            flag = false;
            printf("\033[0;31mFailed:\033[0m\ngot: %s\nexpected: %s\n", buffer, s);
        }/* else {
            printf("\033[0;32mPassed:\033[0m\ngot: %s\nexpected: %s\n", buffer, s);
        }*/
        free(buffer);
        free(s);
        biDelete(a);
        if (!flag)
            break;     
    }
    report(flag, bi_to_string_limit_test);
    // 6.1. Test biToString with very small limit
    {
        char s[1];
        BigInt a = biFromInt(-1);
        biToString(a, s, 1);
        report(s[0] == 0, very_small_limit);
        biDelete(a);
    }
    // 7. Test biMul (calc 2^65536 with linear and bin power and compare)
    {
        BigInt a = biFromString("1");
        BigInt b = biFromString("2");
        for (int i = 0; i < 65536; i++) {
            //printf("%d\n", i);
            biMul(a, b);
        }
        for (int i = 0; i < 16; i++) 
            biMul(b, b);
        char* s = (char*) malloc(20000);
        char* t = (char*) malloc(20000);
        biToString(a, s, 20000);
        biToString(b, t, 20000);
        report(strcmp(s, t) == 0, huge_bin_power);
        free(s);
        free(t);
        biDelete(a);
        biDelete(b);
    }
    // 8. Test biMul and biSub
    {
        BigInt a[1024];
        BigInt b = biFromInt(7);
        BigInt c = biFromInt(6);
        for (int i = 0; i < 1024; i++) {
            a[i] = biFromInt(1);
            for (int j = 0; j < i; j++)
                biMul(a[i], b);
        }
        for (int i = 0; i < 1023; i++) {
            biMul(a[i], c);
            biSub(a[1023], a[i]);
        }
        char s[1000000];
        biToString(a[1023], s, 1000000);
        BigInt unit = biFromInt(1);
        report(biCmp(a[1023], unit) == 0, mul_sub_test);
        for (int i = 0; i < 1024; i++)
            biDelete(a[i]);
        biDelete(b);
        biDelete(c);
        biDelete(unit);
    }
    // 9. Test (-0).toString
    {
        flag = true;
        BigInt a = biFromString("0");
        BigInt b = biFromInt(-1);
        biMul(a, b);
        char s[10];
        biToString(a, s, 10);
        flag = strcmp(s, "0") == 0;
        biDelete(a);
        a = biFromInt(1);
        biAdd(b, a);
        biToString(b, s, 10); 
        flag &= (strcmp(s, "0") == 0);
        report(flag, minus_zero_test);
        biDelete(a);
        biDelete(b);
    }
    // 10. Test biFromString on malformed input
    {
        BigInt a;
        flag = true;
        for (int i = 0; i < 6; i++) {
            a = biFromString(malformed_string[i]);
            flag &= (a == 0);
        }
        report(flag, malformed_string_null_test);
    }
    // 11. Test biSign
    {
        flag = true;
        BigInt a = biFromInt(1);
        BigInt b = biFromInt(0);
        BigInt c = biFromInt(-1);
        BigInt d = biFromInt(1);
        BigInt e = biFromInt(1);
        BigInt f = biFromInt(-1);
        BigInt g = biFromString("18446744073709551615");
        biAdd(e, f);
        biAdd(f, d);
        flag &= (biSign(a) > 0) && (biSign(b) == 0) && (biSign(c) < 0)
             && (biSign(e) == 0) && (biSign(f) == 0) && (biSign(g) > 0);
        report(flag, bi_sign_test);
        biDelete(a); 
        biDelete(b); 
        biDelete(c);
        biDelete(d); 
        biDelete(e); 
        biDelete(f);
        biDelete(g);
    }
    // Finally, "valgrind --leak-check=full" must show
    // that there are no possible memory leaks
    return 0;
}
