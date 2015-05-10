#include "bigint.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

int main() {
	BigInt big = biFromInt(100LL);
	assert(big != NULL);
	return 0;
}
