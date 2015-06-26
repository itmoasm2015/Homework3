#include <cmath>
#include <iostream>
#include <assert.h>
#include <algorithm>
#include "bigint.h"

using namespace std;

int main()
{
    char buffer[1000] = "";
    string test = "";
    int testnum = 0;
    BigInt b3 = biFromInt((unsigned long long)2000000000000000000);
    assert(biSign(b3) == 1);
    printf("Test %d: OK \n", testnum);
    testnum++;
    biToString(b3, buffer, 40);
    test = buffer;
    assert(test == "2000000000000000000");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b2 = biFromInt((unsigned long long) 123456);
    biToString(b2, buffer, 5);
    test = buffer;
    assert(test == "1234"); 
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b8 = biFromString("ddjskhfc123");
    biToString(b8, buffer, 40);
    assert(b8 == NULL);
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b4 = biFromString("123111111111111111117");
    biToString(b4, buffer, 40);
    test = buffer;
    assert(test == "123111111111111111117");
    printf("Test %d: OK \n", testnum);
    testnum++;
    BigInt b5 = biFromString("12311111111111111111111111111111111111111111111111111111111111111111111117");
    biToString(b5, buffer, 400);
    test = buffer;
    assert(test == "12311111111111111111111111111111111111111111111111111111111111111111111117");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b6 = biFromString("-111111111111111111111111111111111111111111111117");
    biToString(b6, buffer, 100);
    test = buffer;
    assert(test == "-111111111111111111111111111111111111111111111117");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b7 = biFromString("-111111111111111111111111111111111111111111117");
    biToString(b7, buffer, 3);
    test = buffer;
    assert(test == "-1");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b9 = biFromInt((long long) -100000007);
    biToString(b9, buffer, 100);
    test = buffer;
    assert(test == "-100000007");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b10 = biFromInt((long long) -123456);
    biToString(b10, buffer, 5);
    test = buffer;
    assert(test == "-123");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b1 = biFromInt((unsigned long long) 123);
    biToString(b1, buffer, 40);
    test = buffer;
    assert(test == "123");
    printf("Test %d: OK \n", testnum);
    testnum++;
    biToString(b1, buffer, 40);
    test = buffer;
    assert(test == "123");
    printf("Test %d: OK \n", testnum);
    testnum++;
    biToString(b1, buffer, 40);
    test = buffer;
    assert(test == "123");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b11 = biFromString("123111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111117");
    biToString(b11, buffer, 400);
    test = buffer;
    assert(test == "123111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111117");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b12 = biFromString("1211111111111111111111111111111111117");
    BigInt b13 = biFromString("1211111111111111111111111111111111118");
    assert(biCmp(b12, b13) == -1);
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b14 = biFromInt(100);
    BigInt b15 = biFromString("-100");
    assert(biCmp(b14, b15) == 1);
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b16 = biFromInt((unsigned long long) 8000000000000000000);
    BigInt b17 = biFromInt((unsigned long long) 8000000000000000000);
    biAdd(b16, b17);
    biToString(b16, buffer, 100);
    test = buffer;
    assert(test == "16000000000000000000");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b18 = biFromString("11111111111111111111111111111111111111111111111111111111111");
    BigInt b19 = biFromString("222222222222222222222222222222222222222222222222222222222222");
    biAdd(b18, b19);
    biToString(b18, buffer, 100);
    test = buffer;
    assert(test == "233333333333333333333333333333333333333333333333333333333333");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b20 = biFromInt((unsigned long long) 11111111111);
    BigInt b21 = biFromString("11111111111111111111111111111111111111111111111111111111111111111");
    biAdd(b20, b21);
    biToString(b20, buffer, 100);
    test = buffer;
    assert(test ==  "11111111111111111111111111111111111111111111111111111122222222222");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b22 = biFromInt((long long) 100);
    BigInt b23 = biFromInt((long long) 110);
    biSub(b22, b23);
    biToString(b22, buffer, 100);
    test = buffer;
    assert(test == "-10");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b24 = biFromString("12000000000000000000");
    BigInt b25 = biFromString("6000000000000000000");
    biSub(b24, b25);
    biToString(b24, buffer, 100);
    test = buffer;
    assert(test == "6000000000000000000");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b26 = biFromString("12000000000000000000");
    BigInt b27 = biFromString("1");
    assert(biCmp(b26, b27) == 1);
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b28 = biFromString("-100");
    BigInt b29 = biFromInt(100);
    biSub(b28, b29);
    biToString(b28, buffer, 100);
    test = buffer;
    assert(test == "-200");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b30 = biFromInt(0xffffffffll);
    BigInt b31 = biFromInt(0xffffffffll);
    BigInt b32 = biFromInt(0xffffffffll + 0xffffffffll);
    biAdd(b30, b31);
    assert(biCmp(b30, b32) == 0);
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b33 = biFromInt(2ll);
    BigInt b34 = biFromInt(-123ll);
    BigInt b35 = biFromInt(-123ll);
    biAdd(b33, b34);
    biSub(b33, b34);
    assert(biCmp(b34, b35) == 0);
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b36 = biFromInt(10);
    BigInt b37 = biFromInt(100);
    biMul(b36, b37);
    biToString(b36, buffer, 100);
    test = buffer;
    assert(test == "1000");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b38 = biFromInt(1000000000);
    BigInt b39 = biFromInt((unsigned long long)2000000000000000000);
    biMul(b38, b39);
    biToString(b38, buffer, 100);
    test = buffer;
    assert(test == "2000000000000000000000000000");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b40 = biFromString("10000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    BigInt b41 = biFromString("100000000000000000000000000000000");
    biMul(b40, b41);
    biToString(b40, buffer, 400);
    test = buffer;
    assert(test == "1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    printf("Test %d: OK \n", testnum);
    testnum++;
    biToString(b41, buffer, 200);
    test = buffer;
    assert(test == "100000000000000000000000000000000");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b42 = biFromString("1000000000000000000000000000000");
    BigInt b43 = biFromString("1000000000000000000000000000000");
    biMul(b42, b43);
    biToString(b42, buffer, 400);
    test = buffer;
    assert(test == "1000000000000000000000000000000000000000000000000000000000000");
    printf("Test %d: OK \n", testnum);
    testnum++;
    biToString(b43, buffer, 200);
    test = buffer;
    assert(test == "1000000000000000000000000000000");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt b44 = biFromString("100000000000000000000000000000000000000000000000000000000000000000");
    biToString(b44, buffer, 100);
    test = buffer;
    assert(test == "100000000000000000000000000000000000000000000000000000000000000000");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    BigInt bi1 = biFromInt(-1);
    biToString(bi1, buffer, 2);
    test = buffer;
    assert(test == "-");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    bi1 = biFromString("-");
    assert(bi1 == NULL);
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    bi1 = biFromString("-0");
    assert(biSign(bi1) == 0);
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    biToString(bi1, buffer, 10);
    test = buffer;
    assert(test == "0");
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    bi1 = biFromString("22-2");
    assert(bi1 == NULL);
    printf("Test %d: OK \n", testnum);
    testnum++;
    
    bi1 = biFromString("");
    assert(bi1 == NULL);
    printf("Test %d: OK \n", testnum);
    testnum++;


    bi1 = biFromInt(1);
    for (int i = 0; i < 100; i++) {
    	biMul(bi1, biFromInt(2));
    }    
    biToString(bi1, buffer, 100000);
    printf("%s\n", buffer);
	return 0;
}