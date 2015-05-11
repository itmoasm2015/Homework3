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
	BigInt a = biFromString("+123456780000000000000000000000000000000");
	if (a == 0)
		cerr << 0 << "\n";
	else 
		print(a);
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

