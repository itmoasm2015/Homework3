#include "bigint.h"
#include <stdio.h>
#include <cstdlib>
#include <random>
#include <ctime>

const int MAX_INT = 1000;
const int LEN_BUF = 10000000;
const int BASE = 1000000000;
char out[LEN_BUF];
char out1[LEN_BUF];

bool testSum() {
	for (int i = -MAX_INT; i < MAX_INT; i++) {
		for (int j = -MAX_INT; j < MAX_INT; j++) {
			long long a = (long long)BASE * i; 
			long long b = (long long)BASE * j;
			BigInt aa = biFromInt((int64_t)a);
			BigInt bb = biFromInt((int64_t)b);
//			biToString(aa, out, LEN_BUF);
//			printf("aa = %s\n", out);
//			biToString(bb, out, LEN_BUF);
//			printf("bb = %s\n", out);
			biAdd(aa, bb);
			BigInt result  = biFromInt((int64_t)(a + b));
			int cmp = biCmp(aa, result);
			if (cmp != 0) {	
				printf("FAIL ");
				biToString(aa, out, LEN_BUF);
				printf("%lld + %lld = %lld, but not %s\n", a, b, a + b, out);
				return false;
			} else {
				printf("OK ");
				biToString(aa, out, LEN_BUF);
				printf("%lld + %lld = %s\n", a, b, out);

			}
			biDelete(bb);
			biDelete(aa);
		}		
	}
	return true;
}

bool testSub() {
	for (int i = -MAX_INT; i < MAX_INT; i++) {
		for (int j = -MAX_INT; j < MAX_INT; j++) {
			long long a = (long long)BASE * i;
			long long b = (long long)BASE * j;
			BigInt aa = biFromInt((int64_t)a);
			BigInt bb = biFromInt((int64_t)b);
			biSub(aa, bb);
			BigInt result  = biFromInt((int64_t)(a - b));
			int cmp = biCmp(aa, result);
			if (cmp != 0) {	
				printf("FAIL ");
				biToString(aa, out, LEN_BUF);
				printf("%lld - %lld = %lld, but not %s\n", a, b, a - b, out);
				return false;
			} else {
				printf("OK ");
				biToString(aa, out, LEN_BUF);
				printf("%lld - %lld = %s\n", a, b, out);

			}
			biDelete(bb);
			biDelete(aa);
		}		
	}
	return true;
}

bool testMul() {
	for (int i = -MAX_INT; i < MAX_INT; i++) {
		for (int j = -MAX_INT; j < MAX_INT; j++) {
			long long a = (long long)(BASE / 1000 * i + i);
			long long b = (long long)(BASE / 1000 * j + j);
			BigInt aa = biFromInt((int64_t)a);
			BigInt bb = biFromInt((int64_t)b);
			biMul(aa, bb);
			BigInt result  = biFromInt((int64_t)(a * b));
			int cmp = biCmp(aa, result);
			if (cmp != 0) {	
				printf("FAIL ");
				biToString(aa, out, LEN_BUF);
				printf("%lld * %lld = %lld, but not %s\n", a, b, a * b, out);
				return false;
			} else {
				printf("OK ");
				biToString(aa, out, LEN_BUF);
				printf("%lld * %lld = %s\n", a, b, out);

			}
			biDelete(aa);
			biDelete(bb);
		}		
	}
	return true;
}

bool testCmp() {
	for (int i = 0; i < 10000; i++) {
		BigInt a = biFromInt((int64_t)-((long long)(i * BASE + i + 1)));
		BigInt b = biFromInt((int64_t)-((long long)(i * BASE + i + 1)));
		int cmp = biCmp(a, b);
		biToString(a, out, LEN_BUF);
		biToString(b, out1, LEN_BUF);
		if (cmp != 0) {
			printf("FAIL %d, a = %s, b = %s\n", cmp, out, out1);				return false;
		} else {
			printf("OK %d, a = %s, b = %s\n", cmp, out, out1);
		}
	}
	return true;
}

int main() {
	printf("START TEST\n");
//	testCmp();
//	if (testSum()) {
//		if (testSub()) {
//			testMul();
//		}
//	}
	//2^1024 -1 - (-1) = 2^1024
//	BigInt em = biFromString("");
//	printf("ads=!%d!\n", (int*)em);
	BigInt tt = biFromInt(2);
	biSub(tt, tt);
	biToString(tt, out, 10);
	printf("4 = %s\n", out);
	BigInt x = biFromInt(-123);
	biToString(x, out, 1);
	printf("x = %s\n", out);
	BigInt a = biFromInt(2ll);
	BigInt b = biFromInt(-123ll);
	BigInt c = biFromInt(-123ll);
	biAdd(a, b);
	int cmp = biCmp(b, c);
	biToString(b, out, LEN_BUF);
	biToString(c, out1, LEN_BUF);
	printf("%d, b = %s, c = %s\n", cmp, out, out1);
	BigInt two = biFromInt((int64_t)1);
	BigInt two2 = biFromInt((int64_t)2);
	for (int i = 0; i < 1024; i++) {
		biMul(two, two2);
//		biToString(two, out, LEN_BUF);
//		printf("%d = %s\n", i + 1, out);
	}
	printf("CMP %d\n", biCmp(two, two));
	BigInt ttwo = biFromInt((int64_t)1);
	biMul(ttwo, two);
	printf("CMP %d\n", biCmp(ttwo, two));
	biToString(two, out, LEN_BUF);
	printf("2^1024 = %s\n", out);
	biToString(ttwo, out, LEN_BUF);
	printf("2^1024 * 1 = %s\n", out);
	BigInt one = biFromInt((int64_t)1);
	BigInt mone = biFromInt((int64_t)-1);
	biAdd(two, one);
	biToString(two, out, LEN_BUF);
	printf("res1 = %s\n", out);
	biAdd(two, mone);
	biToString(two, out, LEN_BUF);
	printf("res == %s\n", out);
	printf("CMP %d\n", biCmp(ttwo, two));

/*	char ss[100];
	int i = 1;
	while (i < 10) {
		ss[i - 1] = '0' + i;
		i++;	
	}
	ss[9] = 0;
	a = biFromString(ss);
	BigInt a = biFromInt((int64_t)9990000);
	biToString(a, out, 20);
	printf("a=%s\n", out);
	BigInt b;
	b = biFromInt((int64_t)99900000);
	biToString(b, out, 20);
	printf("b=%s\n", out);

	biMul(a, b);
	biToString(a, out, 40);
	printf("a*b=%s\n", out);
	biToString(b, out, 20);
	printf("b=%s\n", out);
*/
	printf("END TEST\n");
	return 0;
}
