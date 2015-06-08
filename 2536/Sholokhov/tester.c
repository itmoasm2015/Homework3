#include <bigint.h>
#include <stdlib.h>
#include <stdio.h>

int main() {
	char out[3];
        BigInt bi3 = biFromString("5634002667680754350229513540");
        BigInt bi4 = biFromString("-112770188065645873042730879462335281972720");
	for (int i = 0; i < 5000; i++) {
		biMul(bi3, bi4);
		biToString(bi3, out, 3);
		printf("%d: %s \n",i, out);
	}
	printf("OK \n");
}
