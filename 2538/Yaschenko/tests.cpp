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
	std::vector<int> test_ints { 0 , -1 };//, 1, 5, 999, 4531, -987152, -5643, 123456789, -876478, INT_MAX, INT_MIN };
	//std::vector<int> test_ints { INT_MAX, INT_MIN };
	for (auto i : test_ints) {
		for (auto j : test_ints) {
			//i = -1, j = 0;
			BigInt a = biFromInt(i);
			BigInt b = biFromInt(j);

			int x = (i < j ? -1 : ((i == j) ? 0 : 1));
			int y = biCmp(a, b);

			biDelete(a);
			biDelete(b);

			std::cout << i << ' ' << j << std::endl;
			ASSERT_EQ(x, y);
		}
	}
}
