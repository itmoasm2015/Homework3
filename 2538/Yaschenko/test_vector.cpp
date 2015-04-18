#include "gtest.h"

#include "myvec.h"

#include <iostream>
#include <cstdlib>

using std::cout;

TEST(correctness, vector_size)
{
	Vector v;
	for (size_t sz = 1; sz < 1e6; sz *= 10) {
		v = vectorNew(sz);
		EXPECT_EQ(vectorSize(v), sz);
		vectorDelete(v);
	}
}
/*
#define TEST(size, test_func) \
	cerr << "TESTING: " #test_func "\n"; \
	int result##test_func = test_func(size); \
	total_tests++; \
	if (result##test_func) { \
		passed_tests++; \
	} else { \
		cerr << "FAILED: " #test_func " for size = " << (size) << "\n\n\n"; \
	}

#define ENSURE(condition) \
	if (!(condition)) { \
		cerr << "Assertion '" #condition " failed\n"; \
		return false; \
	}

#define ENSURE_EQ(x, y) \
	if ((x) != (y)) { \
		cerr << "\tAssertion '" #x " == " #y "' failed\n" \
				"\tExpected: " << x << ", but: " << y << "\n"; \
		return false; \
	}


int passed_tests = 0;
int total_tests = 0;

bool test_vectorNew(size_t size) {
	Vector v = vectorNew(5);
	ENSURE(v != NULL);

	vectorDelete(v);

	return true;
}

bool test_vectorSize(size_t size) {
	Vector v = vectorNew(size);

	ENSURE(vectorSize(v) == size);

	return true;
}

bool test_vectorPushBack(size_t size) {
	Vector v = vectorNew(1);

	for (unsigned i = 0; i < size; i++) {
		vectorPushBack(v, i);
		ENSURE_EQ(vectorSize(v), i + 1);
	}

	for (unsigned i = 0; i < size; i++) {
		ENSURE_EQ(vectorGet(v, i), i);
	}

	return true;
}

bool test_vectorBack(size_t size) {
	Vector v = vectorNew(1);

	for (unsigned i = 0; i < size; i++) {
		vectorPushBack(v, i);
		ENSURE_EQ(vectorBack(v), i);
	}

	return true;
}

void tmp() {
	const size_t N = 5;
	Vector v = vectorNew(N);
	cout << vectorSize(v) << endl;
	for (int i = 0; i < (int)N; i++) {
		vectorSet(v, i, i);
	}
	for (int i = 0; i < (int)N; i++) {
		cout << vectorGet(v, i) << ' ';
	}
	vectorDelete(v);
}

int main() {
	srand(345678U);

	for (size_t i = 1; i <= 1e6; i *= 10) {
		int sz = i + rand() % 256;
		TEST(sz, test_vectorNew);
		TEST(sz, test_vectorSize);
		TEST(sz, test_vectorPushBack);
		TEST(sz, test_vectorBack);
	}

	cout << "OK " << passed_tests << "/" << total_tests << " tests\n";

	return 0;
}*/