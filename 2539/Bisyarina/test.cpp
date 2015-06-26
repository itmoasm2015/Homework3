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

void testSum() {
	test3("-1", "2", "1");
	test3("2897402398740923874092134", "-9", "2897402398740923874092125");
	test3("-51027340918273409823650938746509328475198237918237982134709218374", "-40921387409218347092138509109470374659871409283749328345169812736482376472136498", "-40921387409218398119479427382880198310810155793077803543407730974464511181354872");
	test3("0", "-40921387409218347092138509109470374659871409283749328345169812736482376472136498", "-40921387409218347092138509109470374659871409283749328345169812736482376472136498");
	test3("-40921387409218347092138509109470374659871409283749328345169812736482376472136498", "0", "-40921387409218347092138509109470374659871409283749328345169812736482376472136498");
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

void testSub() {
	test4("10", "1", "9");
	test4("1021039", "1000000", "21039");
	test4("8102398462837640298375093847509438750932", "491287398716498127648", "8102398462837640297883806448792940623284");
	test4("7502019438754876128357412570287561723407398475018235845", "2546519239847293874187165872645734959992", "7502019438754873581838172722993687536241525829283275853");
	test4("7502019438754876128357412570287561723407398475018235845", "7502019438754873581838172722993687536241525829283275853", "2546519239847293874187165872645734959992");
	test4("7502019438754876128357412570287561723407398475018235845", "1", "7502019438754876128357412570287561723407398475018235844");
	test4("9213740982374092187309857348573094750398750938753098412098343932104129384092", "412098343932104129384093", "9213740982374092187309857348573094750398750938753097999999999999999999999999");
	test4("100", "200", "-100");
	test4("-100", "-200", "100");
	test4("8357092892742837492834098324702983470293849523984", "421873482735482764832764823764982173649812736498723649872164398217364987213649872136498271643982736498", "-421873482735482764832764823764982173649812736498723641515071505474527494379551547433514801350133212514");
	test4("0", "421873482735482764832764823764982173649812736498723649872164398217364987213649872136498271643982736498", "-421873482735482764832764823764982173649812736498723649872164398217364987213649872136498271643982736498");

	test4("0", "-40921387409218347092138509109470374659871409283749328345169812736482376472136498", "40921387409218347092138509109470374659871409283749328345169812736482376472136498");
	test4("-40921387409218347092138509109470374659871409283749328345169812736482376472136498", "0", "-40921387409218347092138509109470374659871409283749328345169812736482376472136498");
	test4("-40921387409218347092138509109470374659871409283749328345169812736482376472136498", "-1", "-40921387409218347092138509109470374659871409283749328345169812736482376472136497");
	test4("-40921387409218347092138509109470374659871409283749328345169812736482376472136498", "1", "-40921387409218347092138509109470374659871409283749328345169812736482376472136499");
	test4("-71409283749328345169812736482376472136498", "1", "-71409283749328345169812736482376472136499");
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

void bigTest() {
	test3("13298409218347092837402198374019827340918237409182740938740921837401923874092384709218365987436587436879518798237409238049213842374682376482736482376481273648237469827364982736482376482173648273649182734692873469823746821736498217364928376428734698217346982736498273649823746921837469823764982736498237649283764928347", "921840198709283648732468247323840982198347987543875983470958347059874109823741982374019874019873401987019871098741092837409857984375045324507921847032984789710938749832470928347653847593874109487203984734876504389750938742138642375983475098346539847598436594387865584375846534875436554835645864564656556564875023984579384750918437509324875094387502938475092837405983475098347509827409857309283455555999287349871032", "921840198709283648732468247323840982198347987543875983470958347059874109823741982374019874019873415285429089445833930239608232004202386242745331029773923530632776151756345020732363065959861546074640864253674741798988987955981017058359957834828916328872084831857692949358583017251918728483919513747391249438344847731401121249135802437701303829085720285457829335679633298845269347297233622292019953793648571114799379");
	

	test4("13298409218347092837402198374019827340918237409182740938740921837401923874092384709218365987436587436879518798237409238049213842374682376482736482376481273648237469827364982736482376482173648273649182734692873469823746821736498217364928376428734698217346982736498273649823746921837469823764982736498237649283764928347", "921840198709283648732468247323840982198347987543875983470958347059874109823741982374019874019873401987019871098741092837409857984375045324507921847032984789710938749832470928347653847593874109487203984734876504389750938742138642375983475098346539847598436594387865584375846534875436554835645864564656556564875023984579384750918437509324875094387502938475092837405983475098347509827409857309283455555999287349871032", "-921840198709283648732468247323840982198347987543875983470958347059874109823741982374019874019873388688610652751648255435211483964547704406270512664292046048789101347908596835962944629227886672899767105216078266980512889528296267693606992361864163366324788356918038219393110052498954381187372215381921863691405200237757648252701072580948446359689285591492356339132333651351425672357586092326546957318350003584942685");

	test5("13298409218347092837402198374019827340918237409182740938740921837401923874092384709218365987436587436879518798237409238049213842374682376482736482376481273648237469827364982736482376482173648273649182734692873469823746821736498217364928376428734698217346982736498273649823746921837469823764982736498237649283764928347", "921840198709283648732468247323840982198347987543875983470958347059874109823741982374019874019873401987019871098741092837409857984375045324507921847032984789710938749832470928347653847593874109487203984734876504389750938742138642375983475098346539847598436594387865584375846534875436554835645864564656556564875023984579384750918437509324875094387502938475092837405983475098347509827409857309283455555999287349871032", "12259008196358453506681941385006923028925664980056774274341905280943958606911708553679891392771138713198081162083331674292700164899492872106452723120011312327695595833288932635780735948647026980510344045508036694895427842243114401556331079063532003726829340252666378089821684856185338469204398279655154310510932732061148155124432236698177255906685577310253617472748565257937628276474176408200488799865708056786263666716448643173558480831215446683156050654291203596450652805240625447505279646448576061337642808939242123502146314515276188343863845615053263286298772886066978181233362339239857193277645673965633471751718780076625257074283847326191329049208644421553638422570368287584349122361531559609254065139432257702984915170944104");
}

int main() {
	
	testConstrAndSign();
	testCompare();
	testSumSameSign();
	testMul();
	testSum();
	testSub();
	bigTest();
	BigInt m1 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216");
	BigInt m2 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216");
	BigInt m3 = biFromInt(1);
	BigInt m4 = biFromInt(1);
	biSub(m3, m2);
	biAdd(m1, m3);
	cout << biCmp(m4, m1);
	biDelete(m1);
	biDelete(m2);
	biDelete(m3);
	biDelete(m4);

	m1 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216");
	m2 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216");
	m3 = biFromInt(1);
	m4 = biFromInt(-1);
	BigInt m5 = biFromInt(0);
	biSub(m1, m3);
	biSub(m1, m4);
	cout << biCmp(m1, m2);
	biSub(m1, m2);
	cout << biCmp(m1, m5);
	
	biDelete(m1);
	biDelete(m2);
	biDelete(m3);
	biDelete(m4);
	biDelete(m5);

	m1 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216");
	m2 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216");
	m3 = biFromInt(1);
	m4 = biFromInt(-1);
	biSub(m1, m3);
	biSub(m1, m4);
	cout << biCmp(m1, m2);
	
	biDelete(m1);
	biDelete(m2);
	biDelete(m3);
	biDelete(m4);

	BigInt bi1 = biFromInt(2ll);
	BigInt bi2 = biFromInt(-123ll);
	BigInt bi3 = biFromInt(-123ll);
	biAdd(bi1, bi2);
	biSub(bi1, bi2);
	char s[5];
	cout << biCmp(bi2, bi3); //== 0);
	biToString(bi3, s, 10);
	cout << s << endl;
	biDelete(bi1);
	biDelete(bi2);
	biDelete(bi3);


	BigInt t = biFromString("-");
	if (t == 0) {
		cout << "From string OK\n";
	} else {
		cout << "From string fail " << "-" << endl;;
	}
	t = biFromString("22-2");
	if (t == 0) {
		cout << "From string OK\n";
	} else {
		cout << "From string fail " << "22-2" << endl;;
	}
	t = biFromString("");
	if (t == 0) {
		cout << "From string OK\n";
	} else {
		cout << "From string fail " << "" << endl;;
	}
	return 0;
}
