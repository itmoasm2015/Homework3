#include "big_integer.h"
 
#include <cstring>
#include <algorithm>
#include <utility>
#include <tuple>
#include <cassert>

void big_integer::sum(const array_t& other)
{
	if(other.empty())
		return; // + 0
	bool carry = false;
	if(blocks.size() < other.size()) // insert leading zeroes
		blocks.insert(blocks.end(), other.size() - blocks.size(), 0);
	for(std::size_t i = 0; i < blocks.size(); i++)
	{
		integer_t summand = 0;
		if(i < other.size())
			summand = other[i];
		else if(!carry)
			break;
		std::tie(blocks[i], carry) = sum_integers(blocks[i], summand, carry);
	}
	if(carry)
		blocks.push_back(1);
}

void big_integer::sub(const array_t& other)
{
	if(other.empty())
		return; // - 0
	// precondition: *this >= other
	bool borrow = false;
	for(std::size_t i = 0; i < blocks.size(); i++)
	{
		integer_t s = 0;
		if(i < other.size())
			s = other[i];
		else if(!borrow)
			break;
		std::tie(blocks[i], borrow) = sub_integers(blocks[i], s, borrow);
	}
	//assert(!borrow);
}

void big_integer::mul(const array_t& other)
{
	if(other.size() == 1) // optimization
	{
		mul_by_integer(other[0]);
		return;
	}
	if(other.empty())
	{
		// * 0
		*this = 0;
		return;
	}
	big_integer result = 0;
	result.blocks.reserve(blocks.size() + other.size()); // opt
	result.sign = sign;
	for(int i = 0; i < other.size(); i++)
	{
		big_integer copy = *this;
		copy.blocks.reserve(copy.blocks.size() + 1 + i); // opt
		copy.mul_by_integer(other[i]);
		copy <<= i * BLOCK_BITS;
		result.sum(copy.blocks);
	}
	*this = std::move(result);
	normalize();
}

void big_integer::mul_by_integer(integer_t x)
{
	if(x == 1)
		return;
	if(x == 0)
	{
		*this = 0;
		return;
	}
	integer_t carry = 0;
	for(integer_t& elem : blocks)
	{
		integer_t result, newcarry;
		std::tie(result, newcarry) = mul_integers(elem, x);
		bool sumcarry;
		std::tie(elem, sumcarry) = sum_integers(result, carry);
		// no overflow: worst case 0xff * 0xff + 1 <= 0xffff
		carry = newcarry + sumcarry;
	}
	if(carry)
		blocks.push_back(carry);
}

big_integer::integer_t big_integer::div_by_integer(integer_t x)
{
	if(x == 1)
		return 0;
	if(x == 0 || is_zero())
	{
		// a / 0 = 0; a % 0 = 0; 0 / x = 0; 0 % x = 0x
		*this = 0;
		return 0;
	}

	uintmax remainder = 0;
	for(int i = int(blocks.size()) - 1; i >= 0; i--)
	{
		uintmax divident = uintmax(blocks[i]) | (remainder << BLOCK_BITS);
		blocks[i] = divident / uintmax(x);
		remainder = divident % uintmax(x);
		assert(remainder < x);
	}
	normalize();
	return remainder;
}

// (result, carry)
std::pair<big_integer::integer_t, big_integer::integer_t> big_integer::mul_integers(integer_t a, integer_t b)
{
	uintmax result = uintmax(a) * uintmax(b);
	return {result, result >> BLOCK_BITS};
}


std::pair<big_integer::integer_t, bool> big_integer::sum_integers(integer_t a, integer_t b, bool cf)	
{
	uintmax result = uintmax(a) + uintmax(b) + cf;
	return {result, result >> BLOCK_BITS};
}

std::pair<big_integer::integer_t, bool> big_integer::sub_integers(integer_t a, integer_t b, bool cf)
{
	uintmax result = uintmax(a) - uintmax(b) - cf;
	return {result, result >> BLOCK_BITS};
}

big_integer::integer_t big_integer::lshift_integers(integer_t i, integer_t right, int bits)
{
	integer_t result = i << bits;
	result |= (right >> (BLOCK_BITS - bits));
	return result;
}


big_integer::integer_t big_integer::rshift_integers(integer_t i, integer_t left, int bits)
{
	integer_t result = i >> bits;
	result |= (left & ((1 << bits) - 1)) << (BLOCK_BITS - bits);
	return result;
}


void big_integer::normalize()
{
	// remove leading zeroes
	
	for(int i = blocks.size() - 1; i >= 0; i--)
	{
		if(blocks[i] != 0)
			break;
		//blocks.erase(blocks.begin() + i);
		blocks.pop_back();
	}
	if(blocks.empty())
		sign = POSITIVE; // zero
}

//(quotient, remainder)
std::pair<big_integer, big_integer> big_integer::div(const big_integer& n, const big_integer& d)
{
	if(d.is_zero()) // division by zero
		return {0, 0};
	if(compare_abs(n, d) < 0) // n < d
		return {0, n};
	if(d.blocks.size() == 1) // optimization
	{
		big_integer q = n;
		big_integer r = q.div_by_integer(d.blocks[0]);
		return {q, r};
	}
	// long division algorithm
	big_integer q = 0, r = 0;
	r.blocks.reserve(d.blocks.size());
	q.blocks.reserve(n.blocks.size());
	for(int i = n.blocks.size() * BLOCK_BITS - 1; i >= 0; i--)
	{
		r <<= 1;
		r.setbit(0, n.getbit(i));
		if(compare_abs(r, d) >= 0) //(r >= d)
		{
			r.sub(d.blocks);
			q.setbit(i, true);
		}
	}
	q.normalize();
	r.normalize();
	return {q, r};
}

// 0 -> a == b
// < 0 -> a < b
// > 0 -> a > b

int big_integer::compare(const big_integer& a, const big_integer& b)
{
	if(a.sign < b.sign)
		return -1;
	else if(a.sign > b.sign)
		return 1;
	return compare_abs(a, b);
}

int big_integer::compare_abs(const big_integer& a, const big_integer& b)
{
	if(a.blocks.size() < b.blocks.size())
		return -1;
	else if(a.blocks.size() > b.blocks.size())
		return 1;
	
	for(int i = int(a.blocks.size()) - 1; i >= 0; i--) // compare most significant digits first
	{
		if(a.blocks[i] < b.blocks[i])
			return -1;
		else if(a.blocks[i] > b.blocks[i])
			return 1;
	}
	return 0; // equal
}

big_integer::big_integer(int a)
{
	if(a < 0)
	{
		sign = NEGATIVE;
		if(a == std::numeric_limits<int>::min())
			blocks.push_back(integer_t(std::numeric_limits<int>::max()) + 1);
		else
			blocks.push_back(-a);
	}
	else
	{
		sign = POSITIVE;
		if(a != 0)
			blocks.push_back(a);
	}
}

big_integer::big_integer(std::string const& str)
{
	sign = POSITIVE;
	for(char digit : str)
	{
		if(digit >= '0' && digit <= '9')
		{
			//*this *= 10;
			mul_by_integer(10);
			*this += digit - '0';
		}
	}
	if(!str.empty() && str.front() == '-')
		sign = NEGATIVE;
	normalize();
}


std::string to_string(big_integer a)
{
	
	std::string result;
	// 10 ~= 9.63 = log10(2^32)
	// 19 ~= 19.27 = log10(2^64)
	result.reserve(a.blocks.size() * ((big_integer::BLOCK_BITS == 64) ? 19 : 10) + 1);

	const bool negative = (a.sign == big_integer::NEGATIVE);
	

	do
	{
		auto r = a.div_by_integer(10);
		result += r + '0';
	}
	while(!a.is_zero());

	if(negative)
		result += '-';
	
	std::reverse(result.begin(), result.end());
	return result;
}

/***************************** OPERATORS ********************************/

std::ostream& operator<<(std::ostream& s, big_integer const& a)
{
	return s << to_string(a);
}

big_integer& big_integer::operator+=(big_integer const& rhs)
{
	//if(rhs.is_zero())
	//return *this;
	if(sign == rhs.sign)
		sum(rhs.blocks);
	else if(compare_abs(*this, rhs) < 0)
	{
		big_integer t = rhs;
		t.sub(blocks);
		*this = std::move(t);
		//negate();
	}
	else
		sub(rhs.blocks);
	normalize();
	return *this;
}

big_integer& big_integer::operator-=(big_integer const& rhs)
{
	if(sign != rhs.sign)
		sum(rhs.blocks);
	else if(compare_abs(*this, rhs) < 0)
	{
		big_integer t = rhs;
		t.sub(blocks);
		*this = std::move(t);
		negate();
	}
	else
		sub(rhs.blocks);
	normalize();
	return *this;
}

big_integer& big_integer::operator*=(big_integer const& rhs)
{
	mul(rhs.blocks);
	sign = (sign == rhs.sign) ? POSITIVE : NEGATIVE;
	normalize();
	return *this;
}

big_integer& big_integer::operator/=(big_integer const& rhs)
{
	auto result = div(*this, rhs);
	result.first.sign = (sign == rhs.sign) ? POSITIVE : NEGATIVE; 
	*this = std::move(result.first);
	normalize();
	return *this;
}

big_integer& big_integer::operator%=(big_integer const& rhs)
{
	sign_t newsign = sign;
	*this = div(*this, rhs).second;
	sign = newsign;
	normalize();
	return *this;
}

big_integer& big_integer::operator&=(big_integer const& rhs)
{
	blocks.resize(std::min(rhs.blocks.size(), blocks.size()));
	
	for(int i = 0; i < blocks.size(); i++)
	{
		// simulate two's complement
		if(sign == NEGATIVE) 
			blocks[i] = ~blocks[i] + 1;
		integer_t arg = rhs.blocks[i];
		if(rhs.sign == NEGATIVE)
			arg = ~arg + 1;
		
		blocks[i] &= arg;
	}
	
	normalize();
	return *this;
}

big_integer& big_integer::operator|=(big_integer const& rhs)
{
	blocks.resize(std::max(rhs.blocks.size(), blocks.size()));
	
	for(int i = 0; i < blocks.size(); i++)
	{
		// simulate two's complement
		if(sign == NEGATIVE)
			blocks[i] = ~blocks[i] + 1;
		integer_t arg = rhs.blocks[i];
		if(rhs.sign == NEGATIVE)
			arg = ~arg + 1;

		blocks[i] |= arg;
	}
	if(sign == NEGATIVE || rhs.sign == NEGATIVE)
	{
		sign = POSITIVE;
		*this -= big_integer(1) << blocks.size() * BLOCK_BITS;
	}
	return *this;
}

big_integer& big_integer::operator^=(big_integer const& rhs)
{
	blocks.resize(std::max(rhs.blocks.size(), blocks.size()));

	for(int i = 0; i < blocks.size(); i++)
	{
		// simulate two's complement
		if(sign == NEGATIVE) 
			blocks[i] = ~blocks[i] + 1;
		integer_t arg = rhs.blocks[i];
		if(rhs.sign == NEGATIVE)
			arg = ~arg + 1;

		blocks[i] ^= arg;
	}
	if(sign == NEGATIVE || rhs.sign == NEGATIVE)
	{
		sign = POSITIVE;
		*this -= big_integer(1) << blocks.size() * BLOCK_BITS;
	}
	normalize();
	return *this;
}

big_integer& big_integer::operator<<=(int rhs)
{
        const int insert_blocks = rhs / BLOCK_BITS;
	// insert zeroes at front
	blocks.insert(blocks.begin(), insert_blocks, 0);
	
	const int bits = rhs % BLOCK_BITS;
	if(bits != 0)
	{
		blocks.push_back(0);
		for(int i = blocks.size() - 1; i >= 0; i--)
		{
			blocks[i] = lshift_integers(blocks[i], (i - 1 >= 0) ? blocks[i-1] : 0, bits);
		}
	}
	normalize();
	return *this;
}

big_integer& big_integer::operator>>=(int rhs)
{
        const int kill_blocks = rhs / BLOCK_BITS;
	// kill first blocks
	blocks.erase(blocks.begin(), blocks.begin() + kill_blocks);
	
	const int bits = rhs % BLOCK_BITS;
	if(bits != 0)
	{
		for(int i = 0; i < blocks.size(); i++)
		{
			blocks[i] = rshift_integers(blocks[i], (i + 1 < blocks.size()) ? blocks[i+1] : 0, bits);
		}
	}
	if(sign == NEGATIVE) // fix rounding (compatability with gmp)
		--*this;
	normalize();
	return *this;
}

big_integer big_integer::operator+() const
{
	return *this;
}

big_integer big_integer::operator-() const
{
	big_integer r = *this;
	r.negate();
	return r;
}

big_integer big_integer::operator~() const
{
	/*
	  big_integer r = *this;

	  //last block
	  for(int i = (r.blocks.size() - 1) * BLOCK_BITS; i < r.log2(); i++)
	  r.setbit(i, !r.getbit(i));
	  for(int i = r.blocks.size() - 2; i >= 0; i++)
	  r.blocks[i] = ~r.blocks[i];
	
	  return r;*/
	return -(*this) - 1;
}

big_integer& big_integer::operator++()
{
	*this += 1;
	return *this;
}

big_integer big_integer::operator++(int)
{
	big_integer r = *this;
	++*this;
	return r;
}

big_integer& big_integer::operator--()
{
	*this -= 1;
	return *this;
}

big_integer big_integer::operator--(int)
{
	big_integer r = *this;
	--*this;
	return r;
}

big_integer operator+(big_integer a, big_integer const& b)
{
	return a += b;
}

big_integer operator-(big_integer a, big_integer const& b)
{
	return a -= b;
}

big_integer operator*(big_integer a, big_integer const& b)
{
	return a *= b;
}

big_integer operator/(big_integer a, big_integer const& b)
{
	return a /= b;
}

big_integer operator%(big_integer a, big_integer const& b)
{
	return a %= b;
}

big_integer operator&(big_integer a, big_integer const& b)
{
	return a &= b;
}

big_integer operator|(big_integer a, big_integer const& b)
{
	return a |= b;
}

big_integer operator^(big_integer a, big_integer const& b)
{
	return a ^= b;
}

big_integer operator<<(big_integer a, int b)
{
	return a <<= b;
}

big_integer operator>>(big_integer a, int b)
{
	return a >>= b;
}

bool operator==(big_integer const& a, big_integer const& b)
{
	return (a.sign == b.sign && a.blocks == b.blocks);
}

bool operator!=(big_integer const& a, big_integer const& b)
{
	return !(a == b);
}

bool operator<(big_integer const& a, big_integer const& b)
{
	return big_integer::compare(a, b) < 0;
}

bool operator>(big_integer const& a, big_integer const& b)
{
	return big_integer::compare(a, b) > 0;
}

bool operator<=(big_integer const& a, big_integer const& b)
{
	return big_integer::compare(a, b) <= 0;
}

bool operator>=(big_integer const& a, big_integer const& b)
{
	return big_integer::compare(a, b) >= 0;
}
