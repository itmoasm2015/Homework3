#include "bigint.h"
#include <stdio.h>
#include <cstdlib>
#include <random>
#include <ctime>

const int MAX_INT = 1000;
const int LEN_BUF = 100;
char out[LEN_BUF];

void testSum() {
	for (int i = 1; i < MAX_INT; i++) {
		for (int j = 1; j < MAX_INT; j++) {
			i = 2;
			j = 689;
			printf("TEST %d %d\n", i, j);	
			BigInt aa = biFromInt((int64_t)i);
			BigInt bb = biFromInt((int64_t)j);
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			biAdd(aa, bb);
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			BigInt result  = biFromInt((int64_t)(i + j));
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			int cmp = biCmp(aa, result);
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			if (cmp != 0) {	
				printf("FAIL\n");
				printf("a = %d, b = %d\n", i, j);
				biToString(aa, out, LEN_BUF);
				printf("result = %d, but not %s\n", i + j, out);
				return;
			} else {
				printf("OK ");
				biToString(aa, out, LEN_BUF);
				printf("%d + %d = %s\n", i, j, out);

			}
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			biDelete(bb);
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);	
			biDelete(aa);
		}		
	}
}

void testSub() {
	for (int i = 1; i < MAX_INT; i++) {
		for (int j = 1; j < MAX_INT; j++) {
			printf("TEST %d %d\n", i, j);	
			BigInt aa = biFromInt((int64_t)i);
			BigInt bb = biFromInt((int64_t)j);
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			biSub(aa, bb);
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			BigInt result  = biFromInt((int64_t)(i - j));
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			int cmp = biCmp(aa, result);
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			if (cmp != 0) {	
				printf("FAIL\n");
				printf("a = %d, b = %d\n", i, j);
				biToString(aa, out, LEN_BUF);
				printf("result = %d, but not %s\n", i - j, out);
				return;
			} else {
				printf("OK ");
				biToString(aa, out, LEN_BUF);
				printf("%d - %d = %s\n", i, j, out);

			}
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			biDelete(bb);
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);	
			biDelete(aa);
		}		
	}
}

void testMul() {
	for (int i = 1; i < MAX_INT; i++) {
		for (int j = 1; j < MAX_INT; j++) {
			printf("TEST %d %d\n", i, j);	
			BigInt aa = biFromInt((int64_t)i);
			BigInt bb = biFromInt((int64_t)j);
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			biMul(aa, bb);
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			BigInt result  = biFromInt((int64_t)(i * j));
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			int cmp = biCmp(aa, result);
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			if (cmp != 0) {	
				printf("FAIL\n");
				printf("a = %d, b = %d\n", i, j);
				biToString(aa, out, LEN_BUF);
				printf("result = %d, but not %s\n", i * j, out);
				return;
			} else {
				printf("OK ");
				biToString(aa, out, LEN_BUF);
				printf("%d * %d = %s\n", i, j, out);

			}
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);
			biDelete(bb);
//			printf("b = %d, a = %d\n", (int*)bb, (int*)aa);	
			biDelete(aa);
		}		
	}
}

int main() {
	srand(time(NULL));
	printf("START TEST\n");
	testSum();
	testSub();
	testMul();
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
