#include "bigint.h"
#include <stdio.h>
	



int main(int argc, char const *argv[])
{
	BigInt t = biFromInt((long long) 123);
	printf("%d\n", t);	
	return 0;
}