#include <stdio.h>
#include <vector>
#include <iostream>
#include <string>
#include "bigint.h"
#include <math.h>
using namespace std;

unsigned long long base = 4294967296L;

unsigned div_by_short(vector<unsigned int>& v, unsigned int b) {
	unsigned long long carry = 0;
	for (int i = (int)v.size() - 1; i >= 0; i--) {
		unsigned long long  cur = v[i] + (carry << 32);
		v[i] =(unsigned int) (cur / b);
		carry = (unsigned long long) (cur % b);
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

void test1(string s, int sign, BigInt b) {
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

void testConstrAndSign() {
	cout << "Testint constructor and sign\n";
	BigInt m = biFromInt(123);
	string s = "123";
	test1(s, 1, m);
	biDelete(m);


	m = biFromInt(0);
	s = "0";
	test1(s, 0, m);
	biDelete(m);

	m = biFromInt(-123);
	s = "-123";
	test1(s, -1, m);
	biDelete(m);


	s = "123";
	m = biFromString(s.c_str());
	test1(s, 1, m);
	biDelete(m);

	s = "123123123123123123";
	m = biFromString(s.c_str());
	test1(s, 1, m);
	biDelete(m);


	s = "123123123123123123123";
	m = biFromString(s.c_str());
	test1(s, 1, m);
	biDelete(m);

	s = "-123123123123123123123";
	m = biFromString(s.c_str());
	test1(s, -1, m);
	biDelete(m);

	s = "-123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123123";
	m = biFromString(s.c_str());
	test1(s, -1, m);
	biDelete(m);

	s = "0";
	m = biFromString(s.c_str());
	test1(s, 0, m);
	biDelete(m);
}

void test2(string s1, string s2, int status) {
	cout << "Comparing " << s1 << " " << s2 << endl;
	BigInt m = biFromString(s1.c_str());
	BigInt n = biFromString(s2.c_str());
	int res;
	
	if (status == 0) {
		if ((res = biCmp(m, n)) == 0)
			cout << "OK cmp \n";
		else
			cout << "Fail cmp: expected: zero, found: " << res << endl;
	}
	if (status == 1) {
		if ((res = biCmp(m, n)) > 0)
			cout << "OK cmp \n";
		else
			cout << "Fail cmp: expected: positive, found: " << res << endl;
	}
	if (status == -1) {
		if ((res = biCmp(m, n)) < 0)
			cout << "OK cmp \n";
		else
			cout << "Fail cmp: expected: negative, found: " << res << endl;
	}
	biDelete(m);
	biDelete(n);
}

void testCompare() {
	test2("123456", "123456", 0);
	test2("1234567", "123456", 1);
	test2("123456", "1234567", -1);
	test2("0", "12", -1);
	test2("123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456", "123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456", 0);
	test2("0", "0", 0);
	test2(
		"123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456",
		"123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456", -1);
	test2(
		"123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456",
		"123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456", 1);
	test2(
		"12345612345612356123456123456123456123456123456123456123456123456123456123456123456123456123456123456",
		"123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456", -1);

	test2("-123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456", "-123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456", 0);
	test2("-123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456", "-123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456", 1);
	test2("-123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456", "-123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456", -1);
	test2("0", "-123456123456123456123456123456123456123456123456123456123456123456123456123456123456123456", 1);
	test2("-1029339123123312311231231231231231231231231239999999132094872039842098420938402938402938420", "-123456123456123456123456123456123456123456123456123456123456123456123456123456123456", -1);
}

void test3(string s1, string s2, string s3) {
	BigInt m1 = biFromString(s1.c_str());
	BigInt m2 = biFromString(s2.c_str());
	biAdd(m1, m2);
	string res;
	
	cout << "Sum: " << s1 << " " << s2 << endl;
	if ((res = toString(m1)) == s3) 
		cout << "OK\n";
	else
		cout << "Fail add: expected: " << s3 << ", found: " << res << endl;
	biDelete(m1);
	biDelete(m2);
}

void testSumSameSign() {
	test3("1", "2", "3");
	test3("20938471209837409218374", "47230987410298374021", "20985702197247707592395");
	test3("51027340918273409823650938746509328475198237918237982134709218374", "40921387409218347092138509109470374659871409283749328345169812736482376472136498", "40921387409218398119479427382880198310810155793077803543407730974464511181354872");

	test3("18723649832176498217365983276491", "3981274309872309847102", "18723649836157772527238293123593");
	test3("0", "40921387409218347092138509109470374659871409283749328345169812736482376472136498", "40921387409218347092138509109470374659871409283749328345169812736482376472136498");
	test3("-51027340918273409823650938746509328475198237918237982134709218374", "0", "-51027340918273409823650938746509328475198237918237982134709218374");
}
void test4(string s1, string s2, string s3) {
	BigInt m1 = biFromString(s1.c_str());
	BigInt m2 = biFromString(s2.c_str());
	biSub(m1, m2);
	string res;
	
	cout << "Sub: " << s1 << " " << s2 << endl;
	if ((res = toString(m1)) == s3) 
		cout << "OK\n";
	else
		cout << "Fail add: expected: " << s3 << ", found: " << res << endl;
	biDelete(m1);
	biDelete(m2);
}

void testSimpleSub() {
	test4("10", "1", "9");
	test4("1021039", "1000000", "21039");
	test4("8102398462837640298375093847509438750932", "491287398716498127648", "8102398462837640297883806448792940623284");
	test4("7502019438754876128357412570287561723407398475018235845", "2546519239847293874187165872645734959992", "7502019438754873581838172722993687536241525829283275853");
	test4("7502019438754876128357412570287561723407398475018235845", "7502019438754873581838172722993687536241525829283275853", "2546519239847293874187165872645734959992");
	test4("7502019438754876128357412570287561723407398475018235845", "1", "7502019438754876128357412570287561723407398475018235844");
}

void test5(string s1, string s2, string s3) {
	BigInt m1 = biFromString(s1.c_str());
	BigInt m2 = biFromString(s2.c_str());
	biMul(m1, m2);
	string res;
	
	cout << "Mul: " << s1 << " " << s2 << endl;
	if ((res = toString(m1)) == s3) 
		cout << "OK\n";
	else
		cout << "Fail add: expected: " << s3 << ", found: " << res << endl;
	biDelete(m1);
	biDelete(m2);
}

void testMul(){
	test5("1", "2", "2");
	test5("-1", "2", "-2");
	test5("1", "-2", "-2");
	test5("1", "-2", "-2");
	test5("17326482309174932874", "432098509819826219832", "7486747186214070009547392374903767557168");
	test5("1763498237498217509347509834592749365982384092137509370927498347612", "451238275098326498213928409375981098327948576094581209740345093847419827430983", "795757902827634590792401095128930274813935714638765026187130930566141859467869793948836161181830652141564101988241577832112148402592923472862596");
	test5("-1763498237498217509347509834592749365982384092137509370927498347612", "451238275098326498213928409375981098327948576094581209740345093847419827430983", "-795757902827634590792401095128930274813935714638765026187130930566141859467869793948836161181830652141564101988241577832112148402592923472862596");
	test5("-1763498237498217509347509834592749365982384092137509370927498347612", "-451238275098326498213928409375981098327948576094581209740345093847419827430983", "795757902827634590792401095128930274813935714638765026187130930566141859467869793948836161181830652141564101988241577832112148402592923472862596");
	test5("0", "-451238275098326498213928409375981098327948576094581209740345093847419827430983", "0");
	
}

int main() {
	
	testConstrAndSign();
	testCompare();
	testSumSameSign();
	testSimpleSub();
	testMul();

	return 0;
}
