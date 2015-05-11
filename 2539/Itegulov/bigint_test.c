#include "bigint.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

void biUAdd(BigInt, BigInt);
void biUSub(BigInt, BigInt);
void biDump(BigInt);
BigInt biCopy(BigInt);

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
	assert(biCmp(big, result) == 0);
	assert(biCmp(two, result) == -1);
	assert(biCmp(big, two) == 1);
	assert(biCmp(big, negative) == 1);
	assert(biCmp(negative, two) == -1);
	assert(biCmp(negative, negative) == 0);
	biUSub(result, two);
	assert(biCmp(result, biFromInt(100LL)) == 0); 
	biDump(result);
	BigInt temp = biCopy(result);
	//assert(biCmp(temp, result) == 0);
	biDump(temp);
	biDelete(negative);
	biDelete(result);
	biDelete(big);
	biDelete(two);
	return 0;
}
