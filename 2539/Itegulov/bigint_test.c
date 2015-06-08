#include "bigint.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

void biUSub(BigInt, BigInt);
void biDump(BigInt);
BigInt biCopy(BigInt);

int test_count = 0;

void test_add(long long first, long long second) {
	test_count++;
	long long result = first + second;
	BigInt resultBig = biFromInt(result);
	BigInt firstBig = biFromInt(first);
	BigInt secondBig = biFromInt(second);
	biAdd(firstBig, secondBig);
	assert(biCmp(firstBig, resultBig) == 0 && biCmp(resultBig, firstBig) == 0);
	biDelete(resultBig);
	biDelete(firstBig);
	biDelete(secondBig);
}

int main() {
	for (int i = -100; i <= 100; i++) {
		for (int j = -100; j <= 100; j++) {
			test_add(i, j);
		}
	}
	printf("Passed %d tests\n", test_count);
	return 0;
}
