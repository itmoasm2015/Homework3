#include "gtest.h"

#include "myvec.h"
#include "bigint.h"

#include <iostream>
#include <cassert>
#include <cstdlib>
#include <vector>
#include <utility>
#include <climits>

using std::cout;

namespace {
	int const MAX_SIZE = 1e6;
}

TEST(vector, size)
{
	Vector v;
	for (size_t sz = 1; sz < MAX_SIZE; sz *= 10) {
		v = vectorNew(sz);
		EXPECT_EQ(vectorSize(v), sz);
		vectorDelete(v);
	}
}

TEST(vector, push_back)
{
	Vector v;
	v = vectorNew(0);
	for (int i = 0; i < MAX_SIZE; i++) {
		vectorPushBack(v, i + 1);
		EXPECT_EQ(vectorSize(v),   i + 1);
		EXPECT_EQ(vectorGet(v, i), i + 1);
	}
	for (int i = 0; i < MAX_SIZE; i++) {
		EXPECT_EQ(vectorGet(v, i), i + 1);
	}
	vectorDelete(v);
}

TEST(vector, get_default)
{
	Vector v;
	v = vectorNew(MAX_SIZE);
	for (int i = 0; i < MAX_SIZE; i++) {
		EXPECT_EQ(vectorGet(v, i), 0);
	}
	vectorDelete(v);
}

TEST(vector, set_get_const)
{
	Vector v;
	v = vectorNew(MAX_SIZE);
	for (int i = 0; i < MAX_SIZE; i++) {
		vectorSet(v, i, 456U);
	}
	for (int i = 0; i < MAX_SIZE; i++) {
		EXPECT_EQ(vectorGet(v, i), 456U);
	}
	vectorDelete(v);
}

TEST(vector, set_get_rand)
{
	Vector v;
	v = vectorNew(MAX_SIZE);
	std::vector<unsigned> t(MAX_SIZE);

	for (int i = 0; i < MAX_SIZE; i++) {
		unsigned x = rand();
		vectorSet(v, i, x);
		t[i] = x;
	}
	for (int i = 0; i < MAX_SIZE; i++) {
		EXPECT_EQ(vectorGet(v, i), t[i]);
	}
	vectorDelete(v);
}

TEST(vector, pop_back) {
	Vector v;
	v = vectorNew(0);
	for (int i = 0; i < MAX_SIZE; i++) {
		vectorPushBack(v, i + 1);
		EXPECT_EQ(vectorBack(v),   i + 1);
	}
	for (int i = MAX_SIZE - 1; i >= 0; i--) {
		EXPECT_EQ(vectorBack(v),   i + 1);
		vectorPopBack(v);
	}
	vectorDelete(v);
}

TEST(bigint, to_string_int) {
	const size_t BUF_SIZE = 256;
	BigInt b;
	char x[BUF_SIZE], y[BUF_SIZE];

	std::vector<int> test_ints { 0 , -1, 1, 5, 999, -5643, 123456789, -876478, INT_MAX, INT_MIN };
	for (auto i : test_ints) {
		b = biFromInt(i);
		biToString(b, x, BUF_SIZE);
		biDelete(b);

		sprintf(y, "%d", i);

		EXPECT_STREQ(x, y);
	}
}

TEST(bigint, to_string_long_long) {
	const size_t BUF_SIZE = 256;
	BigInt b;
	char x[BUF_SIZE], y[BUF_SIZE];

	std::vector<long long> test_long_longs { 0LL, -1LL, 1LL, 234567654345678LL, -5297682377823095LL, LLONG_MIN, LLONG_MAX };
	for (auto i : test_long_longs) {
		b = biFromInt(i);
		biToString(b, x, BUF_SIZE);
		biDelete(b);

		sprintf(y, "%lld", i);

		EXPECT_STREQ(x, y);
	}
}

TEST(bigint, cmp_ints) {
	std::vector<int> test_ints { 0 , -1, 1, 5, 999, 4531, -987152, -5643, 123456789, -876478, INT_MAX, INT_MIN };
	for (auto i : test_ints) {
		for (auto j : test_ints) {
			BigInt a = biFromInt(i);
			BigInt b = biFromInt(j);

			int x = (i < j ? -1 : ((i == j) ? 0 : 1));
			int y = biCmp(a, b);

			biDelete(a);
			biDelete(b);

			ASSERT_EQ(x, y);
		}
	}
}

TEST(bigint, cmp_long_long) {
	std::vector<long long> test_long_longs { 0LL, -1LL, 1LL, 234567654345678LL, -5297682377823095LL, 6523792561283132LL, LLONG_MIN, LLONG_MAX };
	for (auto i : test_long_longs) {
		for (auto j : test_long_longs) {
			BigInt a = biFromInt(i);
			BigInt b = biFromInt(j);

			int x = (i < j ? -1 : ((i == j) ? 0 : 1));
			int y = biCmp(a, b);

			biDelete(a);
			biDelete(b);

			ASSERT_EQ(x, y);
		}
	}
}

TEST(bigint, sign) {
	std::vector<long long> test_long_longs { 0LL, -1LL, 1LL, 234567654345678LL, -5297682377823095LL, 6523792561283132LL, LLONG_MIN, LLONG_MAX };
	for (auto i : test_long_longs) {
		BigInt a = biFromInt(i);

		int x = (i < 0 ? -1 : ((i == 0) ? 0 : 1));
		int y = biSign(a);

		biDelete(a);

		ASSERT_EQ(x, y);
	}
}

TEST(bigint, mul) {
	BigInt a = biFromInt(2000000005LL);
	BigInt b = biFromInt(-3000000009LL);

	biMul(a, b);

	const size_t BUF_SIZE = 256;
	char buf[BUF_SIZE];
	biToString(a, buf, BUF_SIZE);

	biDelete(a);
	biDelete(b);

	ASSERT_STREQ(buf, "-6000000033000000045");
}

TEST(bigint, mul2) {
	BigInt a = biFromInt(1152921504606846976LL);
	BigInt b = biFromInt(1152921504606846976LL);

	biMul(a, b);

	const size_t BUF_SIZE = 256;
	char buf[BUF_SIZE];
	biToString(a, buf, BUF_SIZE);

	biDelete(a);
	biDelete(b);

	ASSERT_STREQ(buf, "1329227995784915872903807060280344576");
}

TEST(bigint, mul_2_1024) {
	BigInt a = biFromInt(1);
	BigInt b = biFromString("2");
	BigInt pw = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216");


	for (int i = 0; i < 1024; i++) {
		biMul(a, b);
	}

	int cmp = biCmp(a, pw);
	biDelete(a);
	biDelete(b);
	biDelete(pw);

	ASSERT_EQ(cmp, 0);
}

TEST(bigint, add_1000) {
	BigInt a = biFromInt(0);
	BigInt b = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216");
	BigInt c = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216000");

	for (int i = 0; i < 1000; i++) {
		biAdd(a, b);
	}

	int cmp = biCmp(a, c);
	biDelete(a);
	biDelete(b);
	biDelete(c);

	ASSERT_EQ(cmp, 0);
}

TEST(bigint, sub_1000) {
	BigInt a = biFromInt(0);
	BigInt b = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216");
	BigInt c = biFromString("-179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216000");

	for (int i = 0; i < 1000; i++) {
		biSub(a, b);
	}

	int cmp = biCmp(a, c);
	biDelete(a);
	biDelete(b);
	biDelete(c);

	ASSERT_EQ(cmp, 0);
}

TEST(bigint, add) {
	std::vector<long long> test_long_longs { 0LL, 11LL, -121233LL, -6464344324LL, 34567431LL, 5634654235754LL, 234567654345678LL, 5297682377823095LL, 6523792561283132LL };
	for (auto i : test_long_longs) {
		for (auto j : test_long_longs) {

			BigInt a = biFromInt(i);
			BigInt b = biFromInt(j);

			for (int it = 1; it <= 5; it++) {
				biAdd(a, b);
				BigInt c = biFromInt(i + j * it);
				int cmp = biCmp(a, c);

				ASSERT_EQ(cmp, 0);
				biDelete(c);
			}
			biDelete(a);
			biDelete(b);
		}
	}
}

TEST(bigint, from_string) {
	std::vector<std::string> bad_strings = {
		"-",
		"--",
		"1-",
		"123--",
		"1-23",
		"1--23",
		"1-2-3",
		"a",
		"b",
		"1a",
		"123abc",
		"2345567-"
	};

	std::vector<std::string> good_strings = {
		"0",
		"-1",
		"1",
		"123",
		"-123",
		"1234567890",
		"-526341521837468127"
		"2345678900598687358324899203424503",
		"637757824873524700000000089452389234899784000000000000000000000000000000002347589032759324759803",
		"-637757824873524783548453894523089234899784523785000000000000000000000000000000758902347589032759324759803"
	};

	BigInt a;
	for (auto const& bs : bad_strings) {
		a = biFromString(bs.c_str());
		ASSERT_EQ(a, (BigInt)NULL);
	}
	char buf[300];
	for (auto const& bs : good_strings) {
		a = biFromString(bs.c_str());
		EXPECT_NE(a, (BigInt)NULL);
		biToString(a, buf, 300);

		biDelete(a);

		ASSERT_STREQ(bs.c_str(), buf);
	}
}

TEST(bigint, to_string_limit) {
	std::string s = "-637757824873524783548453894523089234899784523785000000000000000000000000000000758902347589032759324759803";
	//std::string s = "-53";
	const int N = 115;
	char buf[N];
	BigInt a = biFromString(s.c_str());
	for (int limit = N; limit >= 0; limit--) {
		biToString(a, buf, limit);

		int len = std::min(limit, (int)s.length());

		for (int i = 0; i < len - 1; i++) {
			ASSERT_EQ(s.c_str()[i], buf[i]);
		}
		ASSERT_EQ(buf[len], '\0');
	}
	biDelete(a);
}

TEST(git, add_minint) {
	BigInt a = biFromInt(0xffffffffll);
	BigInt b = biFromInt(0xffffffffll);
	BigInt c = biFromInt(0xffffffffll + 0xffffffffll);
	biAdd(a, b);

	int cmp = biCmp(a, c);

	biDelete(a);
	biDelete(b);
	biDelete(c);

	ASSERT_EQ(cmp, 0);
}

TEST(git, add_big) {
	// 2^1024
	BigInt a = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216");
	// -(2^1024 - 1)
	BigInt b = biFromString("-179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137215");

	biAdd(a, b);

	BigInt one = biFromInt(1);
	int cmp = biCmp(a, one);

	biDelete(a);
	biDelete(b);

	ASSERT_EQ(cmp, 0);
}

TEST(git, add_small) {
	BigInt a = biFromInt(2ll);
	BigInt b = biFromInt(-123ll);
	BigInt c = biFromInt(-123ll);
	biAdd(a, b);
	biSub(a, b);

	int cmp = biCmp(b, c);

	biDelete(a);
	biDelete(b);
	biDelete(c);

	ASSERT_EQ(cmp, 0);
}

TEST(git, sub_big) {
	// 2 ^ 1024 - 1
	char const *num = "179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137215";
	char const *answer = "179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216";
	BigInt a = biFromString(num);
	BigInt b = biFromInt(-1ll);
	biSub(a, b);

	char buf[350];
	biToString(a, buf, 350);

	ASSERT_STREQ(answer, buf);
}

TEST(git, eq_int_str) {
	BigInt a = biFromInt(123LL);
	BigInt b = biFromString("123");
	int cmp = biCmp(a, b);
	biDelete(a);
	biDelete(b);
	ASSERT_EQ(cmp, 0);
}

TEST(extra, mul) {
	std::vector<long long> ints { 0LL, -1LL, 1LL, 64LL, 83LL, -49LL, -56LL, -123LL, -4123LL, -123LL, 12345LL, -56789LL, 333123LL, };
	for (auto i : ints) {
		for (auto j : ints) {
			for (auto k : ints) {
				BigInt a = biFromInt(i);
				BigInt b = biFromInt(j);
				BigInt c = biFromInt(k);

				//std::cout << i << ' ' << j << ' ' << k << std::endl;

				biMul(a, b);
				biMul(a, c);

				long long x = i * j * k;
				BigInt s = biFromInt(x);
				int cmp = biCmp(a, s);

				biDelete(a);
				biDelete(b);
				biDelete(c);
				biDelete(s);

				ASSERT_EQ(cmp, 0);
			}
		}
	}
}

TEST(extra, mul_zero_one) {
	BigInt a = biFromString("1234567890987654321123456789098765432112345678909876543211234567890987654321");
	BigInt b = biFromString("-1029384756");
	BigInt c100 = biFromString("22350550979091367132605906984324775164340948895096019773769979438633808611002779401796387881125315041341602723135454025842790412579270135715217770050381096724531633923754701420208891863988225403459871469410134934862085886113872887407744804891661721168912751639848635123123877979030346432485273895237501067957308291726180947873822415317032488884917213522819217676145461939129659712660227101209366687708210287658254466020135347917786392445302536736356565023379067321298179022229471174669286494271985405465174185268333677957977819392080969892412906166572487147047234326940220432089040665698005159951484382287107863198387855838959007333827060382455367878258253502476549972901592271203258890470906463715073613895723443821732420277715374315837152566121827861339807657539726033952638437370491359942288426626508503245098143097578723863021335383946547619049932504946233357628763861177108620338773893013818251501817228902122630338173837757231179483490471936856872000373735251297955741696");
	BigInt c101 = biFromString("-23007316466077528057503951205217854507299967579186885911393385484563080050387794989840000700693539429254555631803724897341398503212051319311296329710175652958794395200885555925294583620441904593813541348330113213850084173528372830419236858493670807280001287632074187143149903091217926278999324142242224598888973214295331593838943405778454151214873217922387160819669883358718271615679777985482991232741044246157782084890047316203325653647427995124535439015589195510042099616042002761145976858600263094240329395199942457611355575868329337524944805665528115038176353428112183036072191695933618611263399722698425249704153862576149993058333779097991085544251109986632968789577112172104052479372224775250163905562087486661913734944865492827556694230012091639319279738643462443767184433408844530154300746124552358744880560228554158854527594746997983237878095723420547217961745825819415829932925401199199405450544761730007651712739273465311004928205045483046258591027949370465944854464535986176");

	for (int i = 0; i < 100; i++) {
		biMul(a, b);
	}
	int cmp = biCmp(a, c100);
	ASSERT_EQ(cmp, 0);

	biMul(a, b);
	cmp = biCmp(a, c101);
	ASSERT_EQ(cmp, 0);

	biDelete(a);
	biDelete(b);
	biDelete(c100);
	biDelete(c101);
}

TEST(extra, mul_wtf) {
	BigInt a = biFromString("1234567890987654321123456789098765432112345678909876543211234567890987654321");
	BigInt b = biFromString("-000000000000000");
	BigInt c = biFromString("0");

	biMul(a, b);
	int cmp = biCmp(a, c);
	biDelete(a);
	biDelete(b);
	biDelete(c);

	ASSERT_EQ(cmp, 0);
}

TEST(extra, construct) {
	BigInt a = biFromString("2");
	BigInt b = biFromString("000000000000000000002");

	int cmp = biCmp(a, b);
	biDelete(a);
	biDelete(b);

	ASSERT_EQ(cmp, 0);
}

TEST(extra, fail_mul) {
	BigInt bi1 = biFromInt(0xffffffffffffll);
	BigInt bi2 = biFromInt(0x123456789abcll);
	BigInt bi3 = biFromString("5634002667680754350229513540");
	BigInt bi4 = biFromString("112770188065645873042730879462335281972720");
	biMul(bi1, bi2);
	ASSERT_EQ(biCmp(bi1, bi3), 0);
	biMul(bi1, bi2);
	ASSERT_EQ(biCmp(bi1, bi4), 0);
	BigInt bi5 = biFromInt(-1ll);
	biMul(bi1, bi5);
	ASSERT_LE(biSign(bi1), 0);
	biMul(bi1, bi4);
	bi5 = biFromString("-12717115316361138893215167268288118108744759009945360365688272198554511014824198400");
	ASSERT_EQ(biCmp(bi1, bi5), 0); // <--- Failed here.
}