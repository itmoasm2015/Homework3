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


int main() {
	
	BigInt m = biFromInt(123);
	string s = "123";
	string l;
	if ((l = toString(m)) == s)
		cout << "OK" << endl;
	else
		cout << "False exp:" << s << " found: " << l << endl;
	
	string s2 = "123";
	BigInt m2 = biFromString(s2.c_str());
	string l2;
	if ((l2 = toString(m2)) == s2)
		cout << "OK" << endl;
	else
		cout << "False exp:" << s2 << " found: " << l2 << endl;


	
	string s3 = "123123123123123123";
	BigInt m3 = biFromString(s3.c_str());
	string l3;
	if ((l3 = toString(m3)) == s3)
		cout << "OK" << endl;
	else
		cout << "False exp:" << s3 << " found: " << l3 << endl;

	string s4 = "123123123123123123123";
	BigInt m4 = biFromString(s4.c_str());
	string l4;
	if ((l4 = toString(m4)) == s4)
		cout << "OK" << endl;
	else
		cout << "False exp:" << s4 << " found: " << l4 << endl;

	string s5 = "-123123123123123123123";
	BigInt m5 = biFromString(s5.c_str());
	string l5;
	if ((l5 = toString(m5)) == s5)
		cout << "OK" << endl;
	else
		cout << "False exp:" << s5 << " found: " << l5 << endl;


	string s6 = "-123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123";
	BigInt m6 = biFromString(s6.c_str());
	string l6;
	if ((l6 = toString(m6)) == s6)
		cout << "OK" << endl;
	else
		cout << "False exp:" << s6 << " found: " << l6 << endl;


	string s7 = "0";
	BigInt m7 = biFromString(s7.c_str());
	string l7;
	if ((l7 = toString(m7)) == s7)
		cout << "OK" << endl;
	else
		cout << "False exp:" << s7 << " found: " << l7 << endl;

	return 0;
}
