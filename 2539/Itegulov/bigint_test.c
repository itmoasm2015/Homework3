#include "bigint.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

void biUAdd(BigInt, BigInt);
int biUCmp(BigInt, BigInt);
void biDump(BigInt);

int main() {
	BigInt big = biFromInt(100LL);
	BigInt two = biFromInt(2LL);
	BigInt result = biFromInt(102LL);
	BigInt negative = biFromInt(-10LL);
	assert(big != NULL && two != NULL);
	biUAdd(big, two);
	biDump(big);
	biDump(two);
	biDump(result);
	biDump(negative);
	assert(biUCmp(big, result) == 0);
	assert(biUCmp(two, result) == -1);
	assert(biUCmp(big, two) == 1);
	biDelete(result);
	biDelete(big);
	biDelete(two);
	return 0;
}
