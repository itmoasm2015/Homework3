#include <stdio.h>
#include <vector>
#include <iostream>
#include <string>
#include "bigint.h"
#include <math.h>
using namespace std;

unsigned long long base = 4294967296;

unsigned div_by_short(vector<unsigned int>& v, unsigned int b) {
	unsigned int carry = 0;
	for (int i = (int)v.size() - 1; i >= 0; i--) {
		unsigned long long  cur = v[i] + carry * base;
		v[i] =(unsigned int) (cur / b);
		carry = (unsigned int) (cur % b);
	}
	
	while (v.size() > 0 && v.back() == 0)
		v.pop_back();
	return carry;
}

string toString(BigInt w) {
	unsigned long long* m = (unsigned long long*)w;
	unsigned long long size = *m;
	m++;
	unsigned int* idx = (unsigned int*)*m;
	unsigned int* curr = idx;
	vector <unsigned int> v;
	for (unsigned int i = 0; i < 2 * size; i++) {
		v.push_back(*curr);
		curr++;
	}

	m++;
	int sign = (int)*m;
	
	
	string s;
	s = "";
	while (!v.empty()) {
		unsigned int c = div_by_short(v, 10);
		char i = ('0' + c);
		s = i + s;
	}
	if (sign < 0)
		s = "-" + s;
	return s;
}

void test(string s, int sign, BigInt b) {
	cout << s << endl;
	string l;
	if ((l = toString(b)) == s)
		cout << "OK init" << endl;
	else
		cout << "Fail init: expected:" << s << " found: " << l << endl;
	int curr;
	if ((curr = biSign(b)) == sign) 
		cout << "OK sign" << endl;
	else
		cout << "Fail sign: expected:" << sign << " found: " << curr << endl;
}

int main() {
	
	BigInt m = biFromInt(123);
	string s = "123";
	test(s, 1, m);
	biDelete(m);


	m = biFromInt(0);
	s = "0";
	test(s, 0, m);
	biDelete(m);

	m = biFromInt(-123);
	s = "-123";
	test(s, -1, m);
	biDelete(m);


	s = "123";
	m = biFromString(s.c_str());
	test(s, 1, m);
	biDelete(m);

	s = "123123123123123123";
	m = biFromString(s.c_str());
	test(s, 1, m);
	biDelete(m);


	s = "123123123123123123123";
	m = biFromString(s.c_str());
	test(s, 1, m);
	biDelete(m);

	s = "-123123123123123123123";
	m = biFromString(s.c_str());
	test(s, -1, m);
	biDelete(m);

	s = "-123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123";
	m = biFromString(s.c_str());
	test(s, -1, m);
	biDelete(m);

	s = "0";
	m = biFromString(s.c_str());
	test(s, 0, m);
	biDelete(m);
	return 0;
}
