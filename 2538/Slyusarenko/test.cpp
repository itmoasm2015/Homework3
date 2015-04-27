#include <cmath>
#include <iostream>
#include <assert.h>
#include <algorithm>
#include "../../include/bigint.h"

using namespace std;

int main()
{
    char buffer[1000] = "";
    string test = "";
    BigInt b3 = biFromInt((unsigned long long)2000000000000000000);
    assert(biSign(b3) == 1);
    cout << "OK 0" << endl;
    biToString(b3, buffer, 40);
    test = buffer;
    assert(test == "2000000000000000000");
    cout << "OK 1" << endl;

    BigInt b2 = biFromInt((unsigned long long) 123456);
    biToString(b2, buffer, 5);
    test = buffer;
    assert(test == "1234"); 
    cout << "OK 2" << endl;

    BigInt b8 = biFromString("ddjskhfc123");
    biToString(b8, buffer, 40);
    assert(b8 == NULL);
    cout << "OK 3" << endl;

    BigInt b4 = biFromString("123111111111111111117");
    biToString(b4, buffer, 40);
    test = buffer;
    assert(test == "123111111111111111117");
    cout << "OK 4" << endl;
    BigInt b5 = biFromString("12311111111111111111111111111111111111111111111111111111111111111111111117");
    biToString(b5, buffer, 400);
    test = buffer;
    assert(test == "12311111111111111111111111111111111111111111111111111111111111111111111117");
    cout << "OK 5" << endl;

    BigInt b6 = biFromString("-111111111111111111111111111111111111111111111117");
    biToString(b6, buffer, 100);
    test = buffer;
    assert(test == "-111111111111111111111111111111111111111111111117");
    cout << "OK 6" << endl;

    BigInt b7 = biFromString("-111111111111111111111111111111111111111111117");
    biToString(b7, buffer, 3);
    test = buffer;
    assert(test == "-1");
    cout << "OK 7" << endl;

    BigInt b9 = biFromInt((long long) -100000007);
    biToString(b9, buffer, 100);
    test = buffer;
    assert(test == "-100000007");
    cout << "OK 8" << endl;

    BigInt b10 = biFromInt((long long) -123456);
    biToString(b10, buffer, 5);
    test = buffer;
    assert(test == "-123");
    cout << "OK 9" << endl;

    BigInt b1 = biFromInt((unsigned long long) 123);
    biToString(b1, buffer, 40);
    test = buffer;
    assert(test == "123");
    cout << "OK 10" << endl;
    biToString(b1, buffer, 40);
    test = buffer;
    assert(test == "123");
    cout << "OK 11" << endl;
    biToString(b1, buffer, 40);
    test = buffer;
    assert(test == "123");
    cout << "OK 12" << endl;

    BigInt b11 = biFromString("123111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111117");
    biToString(b11, buffer, 400);
    test = buffer;
    assert(test == "123111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111117");
    cout << "OK 13" << endl;
    
    BigInt b12 = biFromString("1211111111111111111111111111111111117");
    BigInt b13 = biFromString("1211111111111111111111111111111111118");
    assert(biCmp(b12, b13) == -1);
    cout << "OK 14" << endl;

    BigInt b14 = biFromInt(100);
    BigInt b15 = biFromString("-100");
    assert(biCmp(b14, b15) == 1);
    cout << "OK 15" << endl;

    BigInt b16 = biFromInt((unsigned long long) 8000000000000000000);
    BigInt b17 = biFromInt((unsigned long long) 8000000000000000000);
    biAdd(b16, b17);
    biToString(b16, buffer, 100);
    test = buffer;
    assert(test == "16000000000000000000");
    cout << "OK 16" << endl;

    BigInt b18 = biFromString("11111111111111111111111111111111111111111111111111111111111");
    BigInt b19 = biFromString("222222222222222222222222222222222222222222222222222222222222");
    biAdd(b18, b19);
    biToString(b18, buffer, 100);
    test = buffer;
    assert(test == "233333333333333333333333333333333333333333333333333333333333");
    cout << "OK 17" << endl;

    BigInt b20 = biFromInt((unsigned long long) 11111111111);
    BigInt b21 = biFromString("11111111111111111111111111111111111111111111111111111111111111111");
    biAdd(b20, b21);
    biToString(b20, buffer, 100);
    test = buffer;
    assert(test ==  "11111111111111111111111111111111111111111111111111111122222222222");
    cout << "OK 18" << endl;

    BigInt b22 = biFromInt((long long) 100);
    BigInt b23 = biFromInt((long long) 110);
    biSub(b22, b23);
    biToString(b22, buffer, 100);
    test = buffer;
    assert(test == "-10");
    cout << "OK 19" << endl;

    BigInt b24 = biFromString("12000000000000000000");
    BigInt b25 = biFromString("6000000000000000000");
    biSub(b24, b25);
    biToString(b24, buffer, 100);
    test = buffer;
    assert(test == "6000000000000000000");
    cout << "OK 20" << endl;

    BigInt b26 = biFromString("12000000000000000000");
    BigInt b27 = biFromString("1");
    assert(biCmp(b26, b27) == 1);
    cout << "OK 21" << endl;

    BigInt b28 = biFromString("-100");
    BigInt b29 = biFromInt(100);
    biSub(b28, b29);
    biToString(b28, buffer, 100);
    test = buffer;
    assert(test == "-200");
    cout << "OK 22" << endl;

    BigInt b30 = biFromInt(0xffffffffll);
    BigInt b31 = biFromInt(0xffffffffll);
    BigInt b32 = biFromInt(0xffffffffll + 0xffffffffll);
    biAdd(b30, b31);
    assert(biCmp(b30, b32) == 0);
    cout << "OK 23" << endl;

    BigInt b33 = biFromInt(2ll);
    BigInt b34 = biFromInt(-123ll);
    BigInt b35 = biFromInt(-123ll);
    biAdd(b33, b34);
    biSub(b33, b34);
    assert(biCmp(b34, b35) == 0);
    cout << "OK 24" << endl;

    BigInt b36 = biFromInt(10);
    BigInt b37 = biFromInt(100);
    biMul(b36, b37);
    biToString(b36, buffer, 100);
    test = buffer;
    assert(test == "1000");
    cout << "OK 25" << endl;

    BigInt b38 = biFromInt(1000000000);
    BigInt b39 = biFromInt((unsigned long long)2000000000000000000);
    biMul(b38, b39);
    biToString(b38, buffer, 100);
    test = buffer;
    assert(test == "2000000000000000000000000000");
    cout << "OK 26" << endl;

    BigInt b40 = biFromString("10000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    BigInt b41 = biFromString("100000000000000000000000000000000");
    biMul(b40, b41);
    biToString(b40, buffer, 400);
    test = buffer;
    assert(test == "1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    cout << "OK 27" << endl;
    biToString(b41, buffer, 200);
    test = buffer;
    assert(test == "100000000000000000000000000000000");
    cout << "OK 28" << endl;

    BigInt b42 = biFromString("1000000000000000000000000000000");
    BigInt b43 = biFromString("1000000000000000000000000000000");
    biMul(b42, b43);
    biToString(b42, buffer, 400);
    test = buffer;
    assert(test == "1000000000000000000000000000000000000000000000000000000000000");
    cout << "OK 29" << endl;
    biToString(b43, buffer, 200);
    test = buffer;
    assert(test == "1000000000000000000000000000000");
    cout << "OK 30" << endl;

    BigInt b44 = biFromString("100000000000000000000000000000000000000000000000000000000000000000");
    biToString(b44, buffer, 100);
    test = buffer;
    assert(test == "100000000000000000000000000000000000000000000000000000000000000000");
    cout << "OK 31" << endl;

    BigInt b45 = biFromString("179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137215"); // 2**1024 - 1
    BigInt b46 = biFromInt(-1ll);
    biSub(b45, b46);
    biToString(b45, buffer, 500);
    test = buffer;
    assert(test == "179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216");
    cout << "OK 32" << endl;

    return 0;
}
