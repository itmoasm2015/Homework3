#include <iostream>
#include <cstdio>
#include <cassert>
#include <cstdlib>
#include <ctime>
#include <cstddef>
#include <gmpxx.h>
#include <bigint.h>

using namespace std;

string rand_bi(int size) 
{
    string res;
    if (rand() % 2) {
        res.push_back('-');
        size--;
    }

    int tmp = 0;
    while ((tmp = rand() % 10) == 0);
    res.push_back(tmp + '0');
    size--;

    for (int i = 0; i < size; ++i) {
        char c = rand() % 10 + '0';
        res.push_back(c);
    }
    return res;
}

const int buf_size = 10000;
char buf[buf_size];

int ii = 0;
int myrand() {
    if (!ii) {
        ii++;
        return 2;  
    } else {
        return 0;
    }
}

void do_rand_op(pair<BigInt, BigInt> num1, pair<mpz_class&, mpz_class&> num2, 
                pair<BigInt*, BigInt*> res1, pair<mpz_class&, mpz_class&> res2) 
{
    return;
    switch (rand() % 4) {
        case 0:                // +
            cerr << '+' << endl;
            biAdd(num1.first, num1.second);
            num2.first += num2.second;
            break;
        case 1:                // -
            cerr << '-' << endl;
            biSub(num1.first, num1.second);
            num2.first -= num2.second;
            break;
        case 2:
            cerr << '*' << endl;
            biMul(num1.first, num1.second);
            num2.first *= num2.second;
            break;
        case 3:
            cerr << '/' << endl;
            biDivRem(res1.first, res1.second, num1.first, num1.second);
            if (num2.second == 0) {
                if (*res1.first != NULL || res1.second != NULL) {
                    cerr << "in divide: " << endl;
                    cerr << num2.first << endl << num2.second << endl;
                    exit(1);
                }
                break;
            }
            res2.first = num2.first / num2.second;
            res2.second = num2.first % num2.second;
            if (num2.first > 0) {
                if (num2.second < 0) {
                    res2.first = -(res2.first + 1);
                    res2.second += num2.second;
                }
            } else { // num2.first < 0
                if (num2.second < 0) {
                    res2.second *= -1;
                } else {
                    res2.first = -(res2.first + 1);
                    res2.second = num2.second - res2.second;
                }
            }
            break;
    }

    biToString(num1.first, buf, buf_size);
    assert(strcmp(buf, num2.first.get_str(10).c_str()) == 0);

    biToString(num1.second, buf, buf_size);
    assert(strcmp(buf, num2.second.get_str(10).c_str()) == 0);
}

void test(string num1, string num2, int cnt_op = 1000) {
    BigInt b1 = biFromString(num1.c_str());
    BigInt b2 = biFromString(num2.c_str());
    BigInt* b_q = new BigInt;
    BigInt* b_r = new BigInt;
    *b_q = NULL;
    *b_r = NULL;

    mpz_class m1(num1);
    mpz_class m2(num2);
    mpz_class m_q;
    mpz_class m_r;


    for (int i = 0; i < cnt_op; ++i) {
        do_rand_op({b1, b2}, {m1, m2}, {b_q, b_r}, {m_q, m_r});
    }

    biToString(b1, buf, buf_size);
    assert(strcmp(buf, m1.get_str(10).data()) == 0);

    biToString(b2, buf, buf_size);
    assert(strcmp(buf, m2.get_str(10).data()) == 0);

    if (*b_q != NULL) {
        biToString(b_q, buf, buf_size);
        assert(strcmp(buf, m_q.get_str(10).data()) == 0);

        biToString(b_r, buf, buf_size);
        assert(strcmp(buf, m_r.get_str(10).data()) == 0);
    }
}

void stress(int cnt_test = 10, int cnt_op = 1000, int max_num_len = 1000) 
{
    for (int i = 0; i < cnt_test; ++i) {
        cerr << "TEST #" << i << endl;
        int num_len1 = 1;
        while ((num_len1 = rand() % max_num_len) < 2);
        string num1 = rand_bi(num_len1);

        int num_len2 = 1;
        while ((num_len2 = rand() % max_num_len) < 2);
        string num2 = rand_bi(num_len2);

        test(num1, num2, cnt_op);
    }
}


int main() {
    if (1) {
        srand(time(NULL));
        stress(100, 100000, buf_size);
        cout << "GOOD! " << endl;
    } else {
    }

    return 0;
}
