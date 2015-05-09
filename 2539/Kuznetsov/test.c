#include "bigint.h"
#include "stdio.h"
#include <stdlib.h>
#include <string.h>

typedef int bool;
#define true 1
#define false 0

#define green "\033[0;32m" 
#define nocolor "\033[0m"
#define red "\033[0;31m"

void biRawMulShort(BigInt dst, uint64_t arg);
void biRawAddShort(BigInt dst, uint64_t arg);
uint64_t biRawDivRemShort(BigInt dst, uint64_t arg);

typedef struct bigint_c {
	unsigned long long sign;
	struct {
		unsigned long long size, capacity, *data_ptr;
	} *vector;
} bigint_c;

void print_long(BigInt bi) {
	bigint_c* bic = (bigint_c*) bi;
	printf("bi {s=%llu, size=%llu, cap=%llu} [", bic->sign, bic->vector->size, bic->vector->capacity);
	for(int i = 0; i < bic->vector->size; i++) {
		printf("%llx, ", bic->vector->data_ptr[i]);
	}
	printf("]\n");
}

#define TEST(a, ...) test_result = a(__VA_ARGS__); if(!test_result) {passed++; printf(green "Test " #a " passed" nocolor "\n");} else {failed++; printf(red "Test " #a " failed at iteration %d" nocolor "\n", test_result);}

int create_cmp(int n) {
	int rz = 1;
	for(int i = 0; i < n; i++) {
		BigInt a = biFromInt(i * 1007);
		BigInt b = biFromInt(i * 1007);
		BigInt c = biFromInt(i * 1007 + 1);
		bool rv1 = biCmp(a, b);
		bool rv2 = biCmp(a, c);
		biDelete(a);
		biDelete(b);
		biDelete(c);
		if((rv1 != 0) || (rv2 == 0))
			return i + 1;
	}
	return 0;
}

int short_add(int n) {
	for(int i = 0; i < n; i++) {
		BigInt a = biFromInt(i * 1007);
		BigInt b = biFromInt(i * 997);
		BigInt c = biFromInt(i * (1007 + 997));
		biAdd(a, b);
		bool rv2 = biCmp(a, c);
		biDelete(a);
		biDelete(b);
		biDelete(c);
		if(rv2 != 0)
			return i + 1;
	}
	return 0;
}

int longer_add(int n) {
	BigInt a = biFromInt(0);
	BigInt b = biFromInt(0);
	bool result = 0;
	for(int i = 0; i < n; i++) {
		BigInt c = biFromInt(0x7ffffffffffffffdll);
		BigInt d = biFromInt(0x0ffffffffffffffdll);
		biAdd(a, c);
		biAdd(a, d);
		biAdd(b, d);
		biAdd(b, c);
		biDelete(c);
		biDelete(d);
		int cr = biCmp(a, b);
		if(cr != 0) {
			result = i + 1;
			break;
		}
	}
	biDelete(a);
	biDelete(b);
	return result;
}

int unequal_cmp_test(int n) {
	for(int i = 1; i < n; i++) {
		BigInt a = biFromInt(i);
		BigInt b = biFromInt(i + 1);
		int cmp1 = biCmp(a, b);
		int cmp2 = biCmp(b, a);
		if(cmp1 >= 0 || cmp2 <= 0)
			return i;
		biDelete(a);
		biDelete(b);
	}
	return 0;
}

int different_signs_add(int n) {
	BigInt zero = biFromInt(0);
	for(int i = 1; i < n; i++) {
		BigInt a = biFromInt(i *  1007);
		BigInt b = biFromInt(i * -997);
		BigInt c = biFromInt(i * 1007);
		BigInt ans1 = biFromInt(i * (1007 - 997));
		biAdd(a, b);
		biAdd(b, c);
		bool rv1 = biCmp(a, ans1);
		bool rv2 = biCmp(b, ans1);
		biDelete(a);
		biDelete(b);
		biDelete(c);
		biDelete(ans1);
		if(rv2 != 0 || rv1 != 0)
			return i;
	}
	biDelete(zero);
	return 0;
}

int shortmul_add_2(int n) {
	BigInt one1 = biFromInt(1);
	BigInt one2 = biFromInt(1);
	for(int i = 1; i < n; i++) {
		biAdd(one1, one1);
		biRawMulShort(one2, 2);
		if(biCmp(one1, one2)) {
			print_long(one1);
			print_long(one2);
			return i;
		}
	}
	biDelete(one1);
	biDelete(one2);
	return 0;
}

int raw_add_short(int n) {
	unsigned long long ac = 0xffffffffffffebll;
	BigInt acc1 = biFromInt(0);
	BigInt acc2 = biFromInt(0);
	BigInt bigac = biFromInt(ac);
	for(int i = 1; i < n; i++) {
		biAdd(acc1, bigac);
		biRawAddShort(acc2, ac);
		if(biCmp(acc1, acc2)) {
			print_long(acc1);
			print_long(acc2);
			return i;
		}
	}
	biDelete(acc1);
	biDelete(acc2);
	biDelete(bigac);
	return 0;
}

int from_string(int n) {
	char stry[50];
	for(int i = 1; i < n; i++) {
		long long cn = i * 0xffffffffffffll;
		sprintf(stry, "%lld", cn);
		BigInt a = biFromInt(cn);
		BigInt b = biFromString(stry);
		if(!b) {
			printf("failed at %s %lld\n", stry, cn);
			return -i;
		}
		if(biCmp(a, b)) {
			printf("%s %lld\n", stry, cn);
			print_long(a);
			print_long(b);
			return i;
		}
		biDelete(a);
		biDelete(b);
	}
	return 0;
}

int mul_long_short(int n) {
	BigInt acc1 = biFromInt(1);
	BigInt acc2 = biFromInt(1);
	for(int i = 1; i < n; i++) {
		unsigned long long multipler = i * 1007;
		biRawMulShort(acc1, multipler);
		BigInt c = biFromInt(multipler);
		biMul(acc2, c);
		biDelete(c);
		if(biCmp(acc1, acc2)) {
			print_long(acc1);
			print_long(acc2);
			return i;
		}
		
	}
	biDelete(acc1);
	biDelete(acc2);
	return 0;
}

BigInt randomLong() {
	char string[100];
	for(int i = 0; i < 90; i++) {
		string[i] = '0' + (rand() % 10);
	}
	string[90] = 0;
	return biFromString(string);
}

BigInt veryRandomLong() {
	char string[100];
	int len = rand() % 50 + 25;
	for(int i = 0; i < len; i++) {
		string[i] = ('0' + (i <= 1)) + (rand() % (10 - (i <= 1)));
	}
	if(rand() % 2)
		string[0] = '-';
	string[len] = 0;
	return biFromString(string);
}

int mul_long_order(int n) {
	BigInt acc1 = biFromInt(1);
	BigInt acc2 = biFromInt(1);
	for(int i = 1; i < n; i++) {
		BigInt a = randomLong();
		BigInt b = randomLong();
		biMul(acc1, a);
		biMul(acc1, b);
		biMul(acc2, b);
		biMul(acc2, a);
		biDelete(a);
		biDelete(b);
		if(biCmp(acc1, acc2)) {
			print_long(acc1);
			print_long(acc2);
			return i;
		}
	}
	biDelete(acc1);
	biDelete(acc2);
	return 0;
}

int short_div_rem_mul(int n) {
	uint64_t lel = 0xffffffffffffebll;
	for(int i = 1; i < n; i++) {
		BigInt a = randomLong();
		BigInt b = biFromInt(0);
		biAdd(b, a);
		biRawMulShort(a, lel);
		uint64_t lal;
		if(lal = biRawDivRemShort(a, lel)) {
			print_long(a);
			printf("%llu\n", lal);
			return -i;
		}
		if(biCmp(a, b)) {
			print_long(a);
			print_long(b);
			return i;
		}
		biDelete(a);
		biDelete(b);
	}
	return 0;
}

int short_div_rem_mul2(int n) {
	uint64_t lel = 0xcafebabe;
	for(int i = 1; i < n; i++) {
		BigInt a = randomLong();
		BigInt b = biFromInt(0);
		biAdd(b, a);
		unsigned long long rem = biRawDivRemShort(b, lel);
		biRawMulShort(b, lel);
		biRawAddShort(b, rem);
		if(biCmp(a, b)) {
			print_long(a);
			print_long(b);
			return i;
		}
		biDelete(a);
		biDelete(b);
	}
	return 0;
}

int to_string(int n) {
	char stringy[100];
	char out1[100];
	char out2[10];
	for(int i = 1; i < n; i++) {
		char *out = stringy;
		if(rand()%2) {
			*(out++) = '-';
		}
		for(int j = 0; j < 90; j++) {
			*(out++) = '0' + (j == 0) + rand() % (10 - (j == 0));
		}
		*(out++) = 0;
		BigInt a = biFromString(stringy);
		biToString(a, out1, 100);
		biToString(a, out2, 10);
		biDelete(a);
		if(out2[9] != 0) {
			return -i;
		}
		if(strcmp(stringy, out1)) {
			printf("%s\n%s\n", stringy, out1);
			return i;
		}
	}
	return 0;
}

int binary_power(uint64_t n) {
	BigInt two = biFromInt(2);
	for(int i = 1; i < n; i++) {
		BigInt acc1 = biFromInt(1);
		BigInt acc2 = biFromInt(2);
		for(uint64_t j = 0; j < (1 << i); j++) {
			biMul(acc1, two);
		}
		for(uint64_t j = 0; j < i; j++) {
			biMul(acc2, acc2);
		}
		if(biCmp(acc1, acc2)) {
			print_long(acc1);
			print_long(acc2);
			return i;
		}
		biDelete(acc1);
		biDelete(acc2);
	}
	biDelete(two);
	return 0;
}

int basis_7(int n, int64_t basis) {
	BigInt seven = biFromInt(basis);
	BigInt six = biFromInt(basis - 1);
	BigInt one = biFromInt(1);
	for(int i = 2; i < n; i++) {
		BigInt stuff[i];
		for(int j = 0; j < i; j++) {
			stuff[j] = biFromInt(1);
			for(int k = 0; k < j; k++) {
				biMul(stuff[j], seven);
			}
		}
		BigInt sixSum = biFromInt(0);
		for(int j = 0; j < i - 1; j++) {
			biMul(stuff[j], six);
			biAdd(sixSum, stuff[j]);
			biSub(stuff[i - 1], stuff[j]);
		}
		if(biCmp(stuff[i - 1], one)) {
			print_long(sixSum);
			print_long(stuff[i - 1]);
			return i;
		}
		biDelete(sixSum);
		for(int j = 0; j < i; j++) {
			biDelete(stuff[j]);
		}
	}
	biDelete(seven);
	biDelete(six);
	biDelete(one);
	return 0;
}

int div_long_short(int n) {
	for(int i = 1; i < n; i++) {
		BigInt a = biFromInt(i * 1007);
		BigInt b = biFromInt(i * 997);
		BigInt q, r;
		biDivRem(&q, &r, a, b);
		uint64_t r2 = biRawDivRemShort(a, i * 997);
		BigInt rem2 = biFromInt(r2);
		
		if(biCmp(q, a) || biCmp(r, rem2)) {
			printf("divving %llx by %llx\ngot:\n", i * 1007ll, i * 997ll);
			print_long(q);
			print_long(r);
			printf("expected:\n");
			print_long(a);
			print_long(rem2);
			return i;
		}
		
		biDelete(a);
		biDelete(b);
		biDelete(q);
		biDelete(r);
		biDelete(rem2);
	}
	return 0;
}

int factorial(int n, int64_t base) {
	BigInt one = biFromInt(base);
	for(int i = 1; i < n; i++) {
		BigInt acc1 = biFromInt(base);
		BigInt acc2 = biFromInt(base);
		for(int j = 2; j < n; j++) {
			BigInt arg = biFromInt(j);
			biMul(acc1, arg);
			biDelete(arg);
			biRawMulShort(acc2, j);
			if(biCmp(acc1, acc2)) {
				print_long(acc1);
				print_long(acc2);
				return i;
			}
		}
		for(int j = 2; j < n; j++) {
			BigInt arg = biFromInt(j);
			BigInt quot, rem;
			biDivRem(&quot, &rem, acc1, arg);
			if(biSign(rem)) {
				print_long(acc1);
				print_long(arg);
				print_long(quot);
				print_long(rem);
				return -i - n;
			}
			biDelete(acc1);
			acc1 = quot;
			biDelete(rem);
			biDelete(arg);
			if(biRawDivRemShort(acc2, j)) {
				return -i - n - n;
			}
			if(biCmp(acc1, acc2)) {
				print_long(acc1);
				print_long(acc2);
				return -i - n - n - n;
			}
		}
		if(biCmp(acc1, one)) {
			return i + n;
		}
		if(biCmp(acc2, one)) {
			return i + n + n;
		}
		biDelete(acc1);
		biDelete(acc2);
	}
	biDelete(one);
	return 0;
}

int weird_division(int n) {
	BigInt zero = biFromInt(0);
	for(int i = 1; i < n; i++) {
		BigInt a = biFromInt(i * 1007);
		BigInt b = biFromInt(i * 997);
		BigInt q, r;
		biDivRem(&q, &r, b, a);
		
		if(biCmp(q, zero) || biCmp(r, b)) {
			printf("divving %llx by %llx\ngot:\n", i * 997ll, i * 1007ll);
			print_long(q);
			print_long(r);
			printf("expected:\n");
			print_long(a);
			return i;
		}
		
		biDelete(a);
		biDelete(b);
		biDelete(q);
		biDelete(r);
	}
	biDelete(zero);
	return 0;
}

int division_contract(int n) {
	for(int i = 1; i < n; i++) {
		BigInt a = veryRandomLong();
		BigInt b = veryRandomLong();
		BigInt quot, rem;
		biDivRem(&quot, &rem, a, b);
		if(biSign(b) > 0) {
			if(biSign(rem) < 0) {
				return i;
			}
			if(biCmp(rem, b) >= 0) {
				return i + n + n;
			}
		} else {
			if(biSign(rem) > 0) {
				return n + i;
			}
			if(biCmp(rem, b) <= 0) {
				return i + n + n;
			}
		}
		biMul(quot, b);
		biAdd(quot, rem);
		if(biCmp(quot, a)) {
			return -i;
		}
		biDelete(a);
		biDelete(b);
		biDelete(quot);
		biDelete(rem);
	}
	return 0;
}

int div_mul_merge_split(int n) {
	BigInt one = biFromInt(1);
	for(int i = 1; i < n; i++) {
		BigInt stuff[i];
		BigInt acc1 = biFromInt(1);
		BigInt acc2 = biFromInt(1);
		for(int j = 0; j < i; j++) {
			stuff[j] = veryRandomLong();
		}
		
		for(int j = 0; j < i; j++) {
			biMul(acc1, stuff[j]);
			biMul(acc2, stuff[i - 1 - j]);
		}
		
		if(biCmp(acc1, acc2)) {
			return i;
		}
		
		for(int j = 0; j < n; j++) {
			int i1 = rand() % i;
			int i2 = rand() % i;
			BigInt tmp = stuff[i1];
			stuff[i1] = stuff[i2];
			stuff[i2] = tmp;
		}
		
		for(int j = 0; j < i; j++) {
			BigInt quot, rem;
			biDivRem(&quot, &rem, acc1, stuff[j]);
			if(biSign(rem)) {
				return -i -n;
			}
			biDelete(rem);
			biDelete(acc1);
			acc1 = quot;
			
			biDivRem(&quot, &rem, acc2, stuff[j]);
			if(biSign(rem)) {
				return -i -n -n;
			}
			biDelete(rem);
			biDelete(acc2);
			acc2 = quot;
		}
		
		if(biCmp(acc1, one) || biCmp(acc2, one)) {
			return -i;
		}
		
		for(int j = 0; j < i; j++) {
			biDelete(stuff[j]);
		}
		biDelete(acc2);
		biDelete(acc1);
	}
	biDelete(one);
	return 0;
}

int division_zero() {
	BigInt a = biFromInt(123);
	BigInt b = biFromInt(0);
	BigInt q = a, r = a;
	biDivRem(&q, &r, a, b);
	biDelete(a);
	biDelete(b);
	if(q || r) {
		return 1;
	}
	return 0;
}

int specific() { // the playground of stupid testing
	BigInt acc1 = biFromInt(1000);
	biRawMulShort(acc1, 0);
	print_long(acc1);
	biDelete(acc1);
	return 0;
}

int main() {
	int passed = 0;
	int failed = 0;
	int test_result;
	
	//TEST(specific);
	TEST(create_cmp, 10000);
	TEST(short_add, 10000);
	TEST(longer_add, 10000);
	TEST(unequal_cmp_test, 10000);
	TEST(different_signs_add, 10000);
	TEST(shortmul_add_2, 10000);
	TEST(raw_add_short, 10000);
	TEST(from_string, 10000);
	TEST(mul_long_short, 10000);
	TEST(mul_long_order, 100);
	TEST(short_div_rem_mul, 10000);
	TEST(short_div_rem_mul2, 10000);
	TEST(to_string, 10000);
	TEST(binary_power, 16);
	TEST(basis_7, 250, 7);
	TEST(basis_7, 250, 2);
	TEST(div_long_short, 10000);
	TEST(factorial, 100, 1ll);
	TEST(factorial, 100, -1ll);
	TEST(weird_division, 10000);
	TEST(division_contract, 10000);
	TEST(division_zero);
	TEST(div_mul_merge_split, 50);
	
	printf("Passed %d/%d tests\n", passed, passed + failed);
	
	return failed;
}
