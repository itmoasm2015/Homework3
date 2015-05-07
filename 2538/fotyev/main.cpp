#include "bigint.h"

#include "big_integer.h"

#include <iostream>
#include <string>

#include <cstdlib>

const big_integer two_64 = big_integer(1) << 64;
const big_integer two_63 = big_integer(1) << 63;

big_integer rand_bi(int size) // size in bytes
{
  big_integer t(0);
  for(int i = 0; i < size; i++)
  {
    unsigned char byte = rand() & 0xff;
    t <<= 8;
    t += byte;
  }
  return t;
}


big_integer numbers[] = {
  0,
  1,
  2,
  3,
  two_63,
  two_63 + 1,
  two_64 - 1,
  two_64,
  two_64 + 1,
  two_64 * two_64 - 1,
  two_64 * two_64,
  two_64 * two_64 * two_64,
  two_64 << 2048 + 1,
  rand_bi(1000),
  //rand_bi(2006),
};

using intp = std::pair<big_integer, BigInt>;







void test_pair(const intp& p)
{
  /**/
  std::string str1 = to_string(p.first);
  char str[100000];
  biToString(p.second, str, sizeof(str));
  if(str1 != str)
  {
    std::cerr << str << '\n';
    std::cerr << str1 << '\n';
    abort();
  }
}

void add(intp& dst, const intp& src)
{
  dst.first += src.first;
  biAdd(dst.second, src.second);
  test_pair(dst);
}

void sub(intp& dst, const intp& src)
{
  dst.first -= src.first;
  biSub(dst.second, src.second);
  test_pair(dst);
}

void mul(intp& dst, const intp& src)
{
  dst.first *= src.first;
  biMul(dst.second, src.second);
  test_pair(dst);
}

void cmp(intp& lhs, intp& rhs)
{
  if(big_integer::compare(lhs.first, rhs.first)
     != biCmp(lhs.second, rhs.second))
    abort();
}


void print(const intp& i, std::ostream& out)
{
  char str[1000];
  biToString(i.second, str, sizeof(str));
  out << i.first << '\n' << str << '\n';
}

intp from_string(const std::string& s)
{
  return {big_integer(s), biFromString(s.c_str())};
}


void test(const big_integer& n1, const big_integer& n2)
{
  std::string s1 = to_string(n1), s2 = to_string(n2);
  std::cout << "testing " << s1 << " and " << s2 << '\n';
  intp p1 = from_string(s1), p2 = from_string(s2);
  std::cout << "cmp" << '\n';
  cmp(p1, p2);
  std::cout << "add " << p1.second->size << ' ' << p2.second->size << '\n';
  add(p1, p2);
  std::cout << "sub " << p1.second->size << ' ' << p2.second->size << '\n';
  sub(p1, p2);
  std::cout << "mul " << p1.second->size << ' ' << p2.second->size << '\n';
  mul(p1, p2);
  std::cout << "del" << '\n';
  biDelete(p1.second);
  biDelete(p2.second);

}

void test_all()
{
  for(const auto& number1 : numbers)
  {
    for(const auto& number2 : numbers)
    {
      test(number1, number2);
      test(-number1, number2);
      test(number1, -number2);
      test(-number1, -number2);
    }
  }
}

#if 1
int main(int argc, const char * argv[])
{
  if(biFromString("") || biFromString("-"))
    abort();
  test_all();
}
#else
int main(int argc, const char * argv[])
{

  std::string s1, s2;
  if(argc >= 3)
  {
    s1 = argv[1];
    s2 = argv[2];
  }
  else
    std::cin >> s1 >> s2;


  auto a = from_string(s1);
  auto b = from_string(s2);

  std::cout << "A: " << normal_size(a.second) << ' ';

  //printf("%llu %p %llu\n", a.second->size, a.second->ptr, a.second->sign);

  //printf("%llu %p %llu\n", a.second->size, a.second->ptr, a.second->sign);
  print(a, std::cout);
  //printf("%llu %p %llu\n", a.second->size, a.second->ptr, a.second->sign);
  std::cout << "B: " << normal_size(b.second) << ' ';
  //printf("%llu %p %llu\n", b.second->size, b.second->ptr, b.second->sign);

  print(b, std::cout);


  mul(a, b);
  //biAdd(a.second, b.second);

  //sub(a, b);
  printf("%llu %p %llu %016llX\n", a.second->size, a.second->ptr, a.second->sign, a.second->ptr[0]);


  print(a, std::cout);

  biDelete(a.second);
}
#endif
