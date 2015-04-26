#ifndef BIG_INTEGER_H
#define BIG_INTEGER_H

#include <ostream>
#include <cstdint>
#include <vector>
#include <limits>
#include <climits>

#if defined(__GNUC__) && defined(__x86_64__) // gnu extension - "128-bit" integers 
typedef unsigned __int128 uintmax;
typedef uint64_t uinthalfmax;
#else
typedef uint64_t uintmax;
typedef uint32_t uinthalfmax;
#endif

class big_integer
{
private:
	typedef uinthalfmax integer_t;

	static_assert(!std::numeric_limits<integer_t>::is_signed, "integer_t should be unsigned");
	static_assert(sizeof(integer_t) <= (2 * sizeof(uintmax)), "cant handle overflows!");

	typedef std::vector<integer_t> array_t;
private:
	// array of blocks; the least signiicant block is the first
	array_t blocks;

	enum sign_t
	{
		NEGATIVE = -1,
		POSITIVE = 1,
	} sign = POSITIVE;
	
	enum : integer_t
	{
		BLOCK_BITS = CHAR_BIT * sizeof(integer_t)
	};
private:
	void sum(const array_t& arr); // unsigned sum
	void sub(const array_t& arr); // unsigned sum
	void mul(const array_t& arr); // unsigned sum
	void mul_by_integer(integer_t x);
	
	integer_t div_by_integer(integer_t x);
	static std::pair<big_integer, big_integer> div(const big_integer& n, const big_integer& d);


	static std::pair<integer_t, integer_t> mul_integers(integer_t a, integer_t b);
	static std::pair<integer_t, bool> sum_integers(integer_t a, integer_t b, bool cf = false);
	static std::pair<integer_t, bool> sub_integers(integer_t a, integer_t b, bool cf = false);
	static integer_t lshift_integers(integer_t i, integer_t right, int bits);
	static integer_t rshift_integers(integer_t i, integer_t left, int bits);


	static bool getbit_integer(integer_t x, int pos)
	{
		return (x >> pos) & integer_t(1);
	}
	static integer_t setbit_integer(integer_t x, int pos, bool value)
	{
		return value ? (x | (integer_t(1) << pos)) : (x & ~(integer_t(1) << pos));
	}

	bool getbit(int pos) const
	{
		if(pos / BLOCK_BITS >= blocks.size())
			return false; // zero
		return getbit_integer(blocks.at(pos / BLOCK_BITS), pos % BLOCK_BITS);
	}
	
	void setbit(int pos, bool value)
	{
		if(pos / BLOCK_BITS >= blocks.size())
		{
			if(value) // insert leading zeroes
				blocks.insert(blocks.end(), pos / BLOCK_BITS - blocks.size() + 1, 0);
			else
				return; // noop 
		}
		integer_t& block = blocks.at(pos / BLOCK_BITS);
		block = setbit_integer(block, pos % BLOCK_BITS, value);
		normalize();
	}
	

	// invariant: integer is in normal form, i.e. it has no leading zeroes, if integer is zero then sign is POSITIVE
	void normalize();

	bool is_zero() const
	{
		return blocks.empty();
	}

	static int compare(const big_integer& a, const big_integer& b);
	static int compare_abs(const big_integer& a, const big_integer& b);

		
	void negate()
	{
		if(!is_zero()) // do not change sign if zero
			sign = (sign == NEGATIVE) ? POSITIVE : NEGATIVE;
	}

	
public:
	big_integer() = default;
	big_integer(big_integer const& other) = default;
	big_integer(big_integer&& other) = default;
	big_integer(int a);
	explicit big_integer(std::string const& str);
	~big_integer() = default;

	big_integer& operator=(big_integer const& other) = default;
	big_integer& operator=(big_integer&& other) = default;

	big_integer& operator+=(big_integer const& rhs);
	big_integer& operator-=(big_integer const& rhs);
	big_integer& operator*=(big_integer const& rhs);
	big_integer& operator/=(big_integer const& rhs);
	big_integer& operator%=(big_integer const& rhs);

	big_integer& operator&=(big_integer const& rhs);
	big_integer& operator|=(big_integer const& rhs);
	big_integer& operator^=(big_integer const& rhs);

	big_integer& operator<<=(int rhs);
	big_integer& operator>>=(int rhs);

	big_integer operator+() const;
	big_integer operator-() const;
	big_integer operator~() const;

	big_integer& operator++();
	big_integer operator++(int);

	big_integer& operator--();
	big_integer operator--(int);

	friend bool operator==(big_integer const& a, big_integer const& b);
	friend bool operator!=(big_integer const& a, big_integer const& b);
	friend bool operator<(big_integer const& a, big_integer const& b);
	friend bool operator>(big_integer const& a, big_integer const& b);
	friend bool operator<=(big_integer const& a, big_integer const& b);
	friend bool operator>=(big_integer const& a, big_integer const& b);

	friend std::string to_string(big_integer a);

};

big_integer operator+(big_integer a, big_integer const& b);
big_integer operator-(big_integer a, big_integer const& b);
big_integer operator*(big_integer a, big_integer const& b);
big_integer operator/(big_integer a, big_integer const& b);
big_integer operator%(big_integer a, big_integer const& b);

big_integer operator&(big_integer a, big_integer const& b);
big_integer operator|(big_integer a, big_integer const& b);
big_integer operator^(big_integer a, big_integer const& b);

big_integer operator<<(big_integer a, int b);
big_integer operator>>(big_integer a, int b);

bool operator==(big_integer const& a, big_integer const& b);
bool operator!=(big_integer const& a, big_integer const& b);
bool operator<(big_integer const& a, big_integer const& b);
bool operator>(big_integer const& a, big_integer const& b);
bool operator<=(big_integer const& a, big_integer const& b);
bool operator>=(big_integer const& a, big_integer const& b);

std::string to_string(big_integer a);
std::ostream& operator<<(std::ostream& s, big_integer const& a);

#endif // BIG_INTEGER_H
