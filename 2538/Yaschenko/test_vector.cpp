#include "gtest.h"

#include "myvec.h"

#include <iostream>
#include <cassert>
#include <cstdlib>
#include <vector>
#include <utility>

using std::cout;

namespace {

	int const MAX_SIZE = 1e6;

}

TEST(correctness, vector_size)
{
	Vector v;
	for (size_t sz = 1; sz < MAX_SIZE; sz *= 10) {
		v = vectorNew(sz);
		EXPECT_EQ(vectorSize(v), sz);
		vectorDelete(v);
	}
}

TEST(correctness, vector_push_back)
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

TEST(correctness, vector_get_default)
{
	Vector v;
	v = vectorNew(MAX_SIZE);
	for (int i = 0; i < MAX_SIZE; i++) {
		EXPECT_EQ(vectorGet(v, i), 0);
	}
	vectorDelete(v);
}

TEST(correctness, vector_set_get_const)
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

TEST(correctness, vector_get_set_rand)
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

