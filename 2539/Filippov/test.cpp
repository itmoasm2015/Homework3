#include <bits/stdc++.h>
#include "bigint.h"
#include <gmpxx.h>

const size_t MAX_SIZE = 100000;
const size_t INF = 1e9; 
const int64_t MAX_VALUE = 9223372036854775807LL;
const int64_t MIN_VALUE = -9223372036854775807LL;

char out[MAX_SIZE];

void assertEquals(BigInt a, int x) {
	assertEquals(a, (int64_t)x);
}

void assertEquals(BigInt a, int64_t x) {
	assert(a != 0);
	biToString(a, out, INF);
	assert(!strcmp(out, std::to_string(x).c_str()));
}

void assertEquals(BigInt a, std::string &x) {
	assert(a != 0);
	biToString(a, out, INF);
	assert(!strcmp(out, x.c_str()));
}

int randomNumber(int l, int r) {
	return l + rand() % (r - l + 1);
}

std::string randomStringNumber(int length) {
	std::string result = "";
	result += randomNumber(1, 9) + '0';
	for (int i = 0; i + 1 != length; ++i) {
		result += randomNumber(0, 9) + '0';
	}
	return result;
}

void testBiFromInt() {
	printf("=========================\n");
    printf("Running testBiFromInt\n");

	std::vector<int64_t> numbers;
	numbers.push_back(0);
	numbers.push_back(MAX_VALUE);
	numbers.push_back(MIN_VALUE);
	for (int test = 0; test != 100; ++test) {
		int64_t number = (rand() * rand()) * ((rand() & 1) ? 1 : -1);
		numbers.push_back(number);
	}
	for (int64_t x : numbers) {
		BigInt a = biFromInt(x);
		assertEquals(a, x);
		biDelete(a);
	}
	
	printf("All tests passed\n");
	printf("=========================\n");
}

void testIncorrectBiFromString() {
	printf("========================\n");
	printf("Running testIncorrectBiFromString\n");
	std::vector<std::string> numbers;
	numbers.push_back("-");
	numbers.push_back("--");
	numbers.push_back("");
	numbers.push_back("123-");
	numbers.push_back("--123");
	numbers.push_back("+123");
	numbers.push_back("+");
	numbers.push_back("123" + char('0' - 1));
	numbers.push_back("123-456");
	for (std::string x : numbers) {
		BigInt a = biFromString(x.c_str());
		assert(!a);
	}
	printf("========================\n");
	printf("All tests passed!\n");
}

void testBiFromString() {
    printf("============================\n");
    printf("Running testBiFromString\n");

	std::vector<std::pair<std::string, std::string>> numbers;
	numbers.push_back(std::make_pair("00000000000000000000000000000000000000000000000000000000000", "0"));
	numbers.push_back(std::make_pair("-0000000000000000000000000000000000000000000000000000000000", "0"));
	numbers.push_back(std::make_pair(std::to_string(MAX_VALUE), std::to_string(MAX_VALUE)));
	numbers.push_back(std::make_pair(std::to_string(MIN_VALUE), std::to_string(MIN_VALUE)));
	std::string backZeroesNumber = "900000000000000000000000000000000000000";
	numbers.push_back(std::make_pair(backZeroesNumber, backZeroesNumber));
    for (int test = 0; test != 100; ++test) {
		int length = rand() % 1000 + 1;
		std::string number = randomStringNumber(length);
		std::string beforeNumber = number;
		int zeroes = rand() % 1000;
		std::reverse(number.begin(), number.end());
		for (int it = 0; it != zeroes; ++it) {
			number += '0';
		}
		std::reverse(number.begin(), number.end());
		if (rand() & 1) {
			number = '-' + number;
			beforeNumber = '-' + beforeNumber;
		}
		numbers.push_back(std::make_pair(number, beforeNumber));
	}
	for (std::pair<std::string, std::string> x : numbers) {
		BigInt a = biFromString(x.first.c_str());
		assertEquals(a, x.second);
		biDelete(a);
	}
	printf("All tests passed\n");
    printf("============================\n");
}

void testBiSign() {
	printf("===========================\n");
	printf("Running testBiSign\n");
	assert(biSign(biFromString("-123")) < 0);
	assert(biSign(biFromString("0000000000000000000000000000000000000000000000")) == 0);
	assert(biSign(biFromString("00000000000000000000000000000000000000000000001")) > 0);
	assert(biSign(biFromString("-0000000000000000000000000000000000000000000001")) < 0);
	assert(biSign(biFromString("-0")) == 0);
	assert(biSign(biFromInt(-3000000000000000000LL)) < 0);
	assert(biSign(biFromInt(0)) == 0);
	assert(biSign(biFromInt(9000000000000000000LL)) > 0);
	printf("All tests passed!\n");
	printf("============================\n");
}

void testBiCmp() {
	printf("============================\n");
    printf("Running testBiCmp\n");
	assert(biCmp(biFromInt(123LL), biFromString("123")) == 0);
	assert(biCmp(biFromString("000000000000000006"), biFromInt(6)) == 0);
	assert(biCmp(biFromInt(6), biFromString("007")) < 0);
    assert(biCmp(biFromString("555555555555555555555555555555"), biFromString("555555555555555555555555555556")) < 0);
	assert(biCmp(biFromString("555555555555555555555555555555"), biFromString("555555555555555555555555555554")) > 0);
	assert(biCmp(biFromString("555555555555555555555555555555"), biFromString("1")) > 0);
	assert(biCmp(biFromString("1"), biFromString("19837219372193217391879387981273921739")) < 0);
	assert(biCmp(biFromString("938721392173938710387213"), biFromString("1")) > 0);
	assert(biCmp(biFromString("-2"), biFromString("-1")) < 0);
	assert(biCmp(biFromString("-2"), biFromString("-3")) > 0);
	assert(biCmp(biFromString("-100000000000"), biFromString("-100000000001")) > 0);
	assert(biCmp(biFromString("-100000000000"), biFromString("-99999999999")) < 0);
	assert(biCmp(biFromString("-2"), biFromString("3")) < 0);
	assert(biCmp(biFromString("3"), biFromString("-2")) > 0);
	
	BigInt a;
	a = biFromString("9187393798798279387398217392372197");
	assert(biCmp(a, a) == 0);
	biDelete(a);
	a = biFromInt(9187123987213876232LL);
	assert(biCmp(a, a) == 0);
	biDelete(a);

    printf("All tests passed\n");
    printf("============================\n");
}

void testBiAdd() {
	printf("============================\n");
	printf("Running testBiAdd\n");
	
	BigInt a, b;
	a = biFromString("2");
	b = biFromString("3");
	biAdd(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("0");
	b = biFromString("0");
	biAdd(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("0");
	b = biFromString("100");
	biAdd(a, b);
	biAdd(a, b);
	biAdd(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("101");
	b = biFromString("0");
	biAdd(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);

	a = biFromString("32");
	b = biFromString("64");
	biAdd(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);

	a = biFromString("-32");
	b = biFromString("-64");
	biAdd(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);

	a = biFromString("1");
	b = biFromString("103821038103802193891083829837219372193739217392172193871398");
	biAdd(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("109382103380183021983021382103821098309218309182039810298099");
	b = biFromString("1");
	biAdd(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("2");
	b = biFromString("-1");
	biAdd(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("1");
	b = biFromString("-2");
	biAdd(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("-2");
	b = biFromString("1");
	biAdd(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("2");
	b = biFromString("2");
	biAdd(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216");
	b = biFromString("-179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137215");
	biAdd(a, b);
	biToString(a, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("-39");
	b = biFromString("100");
	biAdd(a, b);
	biToString(a, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);

	a = biFromInt(0xffffffffLL);
	b = biFromInt(0xffffffffLL);
	BigInt c = biFromInt(0xffffffffLL + 0xffffffffLL);
	biAdd(a, b);
	assert(biCmp(a, c) == 0);
	biDelete(a);
	biDelete(b);
	biDelete(c);

	a = biFromString("-1");
	b = biFromString("10398210398302183098210921830938100");
	biAdd(a, b);
	biToString(a, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	printf("All tests passed!\n");
	printf("============================\n");			
}

void testBiSub() {
	printf("Running testBiSub\n");
	printf("=======================\n");

	BigInt a, b;

	a = biFromString("2");
	b = biFromString("2");
	biSub(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	BigInt d = biFromString("000000000000000000000000");
	BigInt c = biFromInt(0);
	biToString(c, out, 100);
	printf("%s\n", out);
	assert(biCmp(c, a) == 0);
	assert(biCmp(d, a) == 0);
	assert(biCmp(d, c) == 0);
	biDelete(a);
	biDelete(b);
	biDelete(c);
	biDelete(d);
		
	a = biFromString("2");
	b = biFromString("1");
	biSub(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("-2");
	b = biFromString("-1");
	biSub(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("-2");
	b = biFromString("1");
	biSub(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("1");
	b = biFromString("-2");
	biSub(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("239187397397397982173972198721378372198372193872139821739821721980");
	b = biFromString("1");
	biSub(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("1");
	b = biFromString("1237213098721398217398217392183721983739873098127309821730921730929");
	biSub(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	printf("All tests passed!\n");
	printf("=======================\n");
}

void testBiMul() {
	printf("=======================\n");
	printf("Running testBiMul\n");

	BigInt a, b;

	a = biFromString("00000000000");
	b = biFromInt(0);
	biMul(a, b);
	assert(!biCmp(a, biFromInt(0)));
	biDelete(a);
	biDelete(b);
	
	a = biFromString("2");
	b = biFromString("0");
	biMul(a, b);
	assert(!biCmp(a, biFromInt(0)));
	biDelete(a);
	biDelete(b);
	
	a = biFromString("0");
	b = biFromInt(3);
	biMul(a, b);
	assert(!biCmp(a, biFromString("0")));
	biDelete(a);
	biDelete(b);
	
	a = biFromString("2");
	b = biFromString("3");
	biMul(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("100");
	b = biFromString("1000000000000000");
	biMul(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("123456789123");
	b = biFromString("123456789123");
	biMul(a, b);
	biToString(a, out, 100);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("03810381039810398213091830981098309813092183");
	b = biFromString("2103981038302198303038302183098039218302198321039821092183098");
	biMul(a, b);
	biToString(a, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("9999999999999999999999999999999999999999999999999999999");
	b = biFromString("9999999999999999999999999999999999999999999999999999999");
	biMul(a, b);
	biToString(a, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("-2039813");
	b = biFromString("2091830183098");
	biMul(a, b);
	biToString(a, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("-23871309183209");
	b = biFromString("103810398");
	biMul(a, b);
	biToString(a, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("-0283109283098");
	b = biFromString("-2");
	biMul(a, b);
	biToString(a, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	
	a = biFromString("1");
	b = biFromString("2");
	for (int i = 0; i < 1024; i++) {
		biMul(a, b);
	}
	BigInt c = biFromString("1");
	for (int i = 0; i < 1024; i++) {
		biMul(c, b);
	}
	b = biFromString("1");
	biSub(c, b);
	b = biFromString("0");
	biSub(b, c);
	biAdd(a, b);
	biToString(a, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	biDelete(c);
		
	printf("All tests passed!\n");
	printf("=============================\n");
}

void testBiDivRem() {
	printf("=============================\n");
	printf("Running testBiDivRem\n");
	BigInt c = biFromInt(0), d = biFromInt(0);
	BigInt a, b;
	
	a = biFromInt(0);
	b = biFromInt(3);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);	
	biToString(c, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);

	a = biFromInt(3);
	b = biFromInt(0);
	biDivRem(&c, &d, a, b);
	assert(c == 0 && d == 0);
	
	a = biFromString("10");
	b = biFromString("5");
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);	
	biToString(c, out, INF);
	printf("%s ", out);
	biToString(d, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	biDelete(c);
	biDelete(d);
	
	a = biFromString("239");
	b = biFromString("100");
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biToString(c, out, INF);
	printf("%s ", out);
	biToString(d, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	biDelete(c);
	biDelete(d);

	a = biFromString("-239");
	b = biFromString("100");
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);	
	biToString(c, out, INF);
	printf("%s ", out);
	biToString(d, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	biDelete(c);
	biDelete(d);
	
	a = biFromString("239");
	b = biFromString("-100");
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biToString(c, out, INF);
	printf("%s ", out);
	biToString(d, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	biDelete(c);
	biDelete(d);

	a = biFromString("-239");
	b = biFromString("-100");
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biToString(c, out, INF);
	printf("%s ", out);
	biToString(d, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	biDelete(c);
	biDelete(d);
	
	a = biFromInt(28226LL * 86468 + 8597);
	b = biFromInt(86468);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biToString(c, out, INF);
	printf("%s ", out);
	biToString(d, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	biDelete(c);
	biDelete(d);
	
	a = biFromString("6703903964971298549787012499102923063739682910296196688861780721860882015023660034294811089951732299792782023528860199663493147528504713584320662571322642");
	b = biFromString("57896044618658097711785492504343953926634992332820282019728792003956564819949");
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biToString(c, out, INF);
	printf("%s ", out);
	biToString(d, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	biDelete(c);
	biDelete(d);

	a = biFromString("-6703903964971298549787012499102923063739682910296196688861780721860882015023660034294811089951732299792782023528860199663493147528504713584320662571322642");
	b = biFromString("57896044618658097711785492504343953926634992332820282019728792003956564819949");
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biToString(c, out, INF);
	printf("%s ", out);
	biToString(d, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	biDelete(c);
	biDelete(d);

	a = biFromString("6703903964971298549787012499102923063739682910296196688861780721860882015023660034294811089951732299792782023528860199663493147528504713584320662571322642");
	b = biFromString("-57896044618658097711785492504343953926634992332820282019728792003956564819949");
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biToString(c, out, INF);
	printf("%s ", out);
	biToString(d, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	biDelete(c);
	biDelete(d);
	
	a = biFromString("-6703903964971298549787012499102923063739682910296196688861780721860882015023660034294811089951732299792782023528860199663493147528504713584320662571322642");
	b = biFromString("-57896044618658097711785492504343953926634992332820282019728792003956564819949");
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biToString(c, out, INF);
	printf("%s ", out);
	biToString(d, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	biDelete(c);
	biDelete(d);
	
	a = biFromString("0821037982171293873982173973219837213982173982798372197213982173982173987219837213987392183721398217398217398217398127398217392187321983721973982173921873921837982173982173982173219837982173982173982137219837219837938217398372198739821739821372198372198372193872398217392173982137921837129837219837198372193872198372198321739821739812739821739999999999999999999999999999999999999999999");
	b = biFromString("1");
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biToString(c, out, INF);
	printf("%s ", out);
	biToString(d, out, INF);
	printf("%s\n", out);
	b = biFromString("-1");
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biToString(c, out, INF);
	printf("%s ", out);
	biToString(d, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	biDelete(c);
	biDelete(d);

	a = biFromString("-0821037982171293873982173973219837213982173982798372197213982173982173987219837213987392183721398217398217398217398127398217392187321983721973982173921873921837982173982173982173219837982173982173982137219837219837938217398372198739821739821372198372198372193872398217392173982137921837129837219837198372193872198372198321739821739812739821739999999999999999999999999999999999999999999");
	b = biFromString("1");
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biToString(c, out, INF);
	printf("%s ", out);
	biToString(d, out, INF);
	printf("%s\n", out);
	b = biFromString("-1");
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biDivRem(&c, &d, a, b);
	biToString(c, out, INF);
	printf("%s ", out);
	biToString(d, out, INF);
	printf("%s\n", out);
	biDelete(a);
	biDelete(b);
	biDelete(c);
	biDelete(d);

	printf("All tests passed!\n");
	printf("=============================\n");
}

int main() {
    srand(239017);
	testBiFromInt();
	testIncorrectBiFromString();
	testBiFromString();
	testBiSign();
	testBiCmp();
	testBiAdd();    
	testBiSub();
	testBiMul();
	testBiDivRem();
}

