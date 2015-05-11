#include <bits/stdc++.h>
#include "bigint.h"
using namespace std;

void print(BigInt x) {
	char str[409600];
	memset(str, 0, 409600);
	biToString(x, str, 409599);
	printf("%s\n", str);
}

BigInt scan(int n) {
	BigInt cur = biFromInt(0);
	while (n --> 0) {
		int op;
		long long x;
		scanf("%d%lld", &op, &x);
		BigInt tmp = biFromInt(x);
		switch (op) {
			case 0:
				biAdd(cur, tmp);
				break;
			case 1:
				biSub(cur, tmp);
				break;
			case 2:
				biMul(cur, tmp);
				break;
		}
		biDelete(tmp);
	}
	return cur;
}

int n;
int main()
{
				BigInt bi1 = biFromInt(0xffffffffffffll);
        BigInt bi2 = biFromInt(0x123456789abcll);
        BigInt bi2t = biFromInt(0x123456789abcll);
        BigInt bi3 = biFromString("5634002667680754350229513540");
        BigInt bi4 = biFromString("112770188065645873042730879462335281972720");
        BigInt bi4t = biFromString("112770188065645873042730879462335281972720");
        biMul(bi1, bi2);
        assert(biCmp(bi1, bi3) == 0);
        assert(biCmp(bi2, bi2t) == 0);
        biMul(bi1, bi2);
        assert(biCmp(bi1, bi4) == 0);
        assert(biCmp(bi2, bi2t) == 0);
        BigInt bi5 = biFromInt(-1ll);
        BigInt bi5t = biFromInt(-1ll);
        biMul(bi1, bi5);
        assert(biCmp(bi5, bi5t) == 0);
        assert(biSign(bi1) < 0);
        biMul(bi1, bi4);
        assert(biCmp(bi4, bi4t) == 0);
        bi5 = biFromString("-12717115316361138893215167268288118108744759009945360365688272198554511014824198400");
        assert(biCmp(bi1, bi5) == 0);
	return 0;
	freopen("test.in", "r", stdin);
	freopen("test.out", "w", stdout);
	scanf("%d", &n);
	BigInt ans = biFromInt(0);
	while (n --> 0) {
		int k, op;
		scanf("%d%d", &k, &op);
		BigInt cur = scan(k);
		switch (op) {
			case 0:
				biAdd(ans, cur);
				break;
			case 1:
				biSub(ans, cur);
				break;
			case 2:
				biMul(ans, cur);
				break;
		}
		biDelete(cur);
	}
	print(ans);
	biDelete(ans);
	return 0;
}

