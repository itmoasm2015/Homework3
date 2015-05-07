#include "big_integer.h"
#include "small_vector.h"

#include <stdexcept>
#include <algorithm>
#include <memory.h>

using namespace std;

//invariant: zero <=> digits.empty() && signum = 1
void big_integer::trim_zero() {
    while (!digits.empty() && digits.back() == 0)
        digits.pop_back();
    if (is_zero())
        signum = 1;
}

big_integer::big_integer() {
    signum = 1;
}

big_integer::big_integer(big_integer const& other) {
    digits = other.digits;
    signum = other.signum;
}

big_integer& big_integer::operator=(big_integer const& other) {
    if (this == &other)
        return *this;
    digits = other.digits;
    signum = other.signum;
    return *this;
}

big_integer::big_integer(int a) {
    signum = (a < 0 ? -1 : 1);
    unsigned temp = unsigned(a < 0 ? -a : a);  
    while (temp > 0) {
        digits.push_back(temp & (BASE - 1));
        temp >>= SIZE;
    }
}

big_integer::big_integer(std::string const& str) {   
    if (str.empty()) {
        signum = 1;
        return;
    }
    int sig = 1;
    size_t pos = 0;
    while (pos < str.size() && (str[pos] == '-' || str[pos] == '+')) {
        if (str[pos] == '-')
            sig = -sig;
        pos++;
    }
    for (size_t i = pos; i < str.length(); i++) {
        if (str[i] < '0' || str[i] > '9') {
            throw std::runtime_error("invalid string");
        }
        *this *= 10;
        *this += str[i] - '0';
    }
    signum = sig;
    trim_zero();
}

big_integer::~big_integer() {
    digits.clear();
}

big_integer& big_integer::operator+=(int value) {
    if (signum * value >= 0) {
        unsigned carry = (value < 0 ? -value : value);
        for (size_t i = 0; i < digits.size() || carry; i++) {
            if (i == digits.size())
                digits.push_back(0);
            carry += digits[i];
            digits[i] = carry & (BASE - 1);
            carry >>= SIZE;
            if (!carry)
                break;
        }     
        return *this;
    }
    return *this -= -value;
}


big_integer& big_integer::operator-=(int value) {
    return *this -= big_integer(value);   
}

void big_integer::shift_left(unsigned new_digit) {
    if (is_zero() && new_digit == 0)
        return;
    digits.push_back(0);
    for (size_t i = digits.size() - 1; i >= 1; i--)
        digits[i] = digits[i - 1];
    digits[0] = new_digit & (BASE - 1);
}

void big_integer::shift_right() {
    if (is_zero())
        return;
    for (size_t i = 0; i < digits.size() - 1; i++) {
        digits[i] = digits[i + 1];
    }
    digits.pop_back();
    trim_zero();
}

big_integer& big_integer::operator*=(int value) {
    if (value < 0) {
        signum = -signum;
        value = -value;
    }
    unsigned long long carry = 0;
    for (size_t i = 0; i < digits.size() || carry; i++) {
        if (i == digits.size())
            digits.push_back(0);
        carry += value * 1LL * digits[i];
        digits[i] = carry & (BASE - 1);
        carry >>= SIZE;
    }
    trim_zero();

    return *this;
}

big_integer& big_integer::operator/=(int value) {
    if (value < 0) {
        signum = -signum;
        value = -value;
    }
    remainder = 0;
    for (int i = (int) digits.size() - 1; i >= 0; i--) {
        remainder = remainder * BASE + digits[i];
        digits[i] = remainder / value;
        remainder = remainder % value;
    }
    trim_zero();
    return *this;
}

void big_integer::add_vector(small_vector & first, small_vector const & second) const {
    size_t max_size = first.size() > second.size() ? first.size() : second.size();
    unsigned carry = 0;
    for (size_t i = 0; i < max_size; i++) {
        if (i == first.size())
            first.push_back(0);
        first[i] += carry + (i < second.size() ? second[i] : 0);;
        carry = (first[i] >= BASE ? 1 : 0);
        if (carry)
            first[i] -= BASE;
    }
}

void big_integer::sub_vector(small_vector & first, small_vector const & second, int & res_signum) const {
    bool first_gr = false;
    if (first.size() != second.size())
        first_gr = first.size() > second.size();
    else {
        for (int i = (int) first.size() - 1; i >= 0; i--)
            if (first[i] != second[i]) {
                first_gr = first[i] > second[i];
                break;
            }
    }
    if (first_gr) {
        unsigned carry = 0;
        res_signum = 1;
        for (size_t i = 0; i < first.size() || carry; i++) {
            int cur = first[i] - carry - (i < second.size() ? second[i] : 0);
            carry = (cur < 0 ? 1 : 0);
            if (carry)
                first[i] = unsigned(cur + BASE);
            else
                first[i] = unsigned(cur);
        }
    } else {
        unsigned carry = 0;
        res_signum = -1;
        for (size_t i = 0; i < second.size() || carry; i++) {
            if (i == first.size())
                first.push_back(0);
            int cur = second[i] - carry - first[i];
            carry = (cur < 0 ? 1 : 0);
            if (carry)
                first[i] = unsigned(cur + BASE);
            else
                first[i] = unsigned(cur);
        }
    }
}

big_integer& big_integer::operator+=(big_integer const& rhs) {
    if (rhs.is_zero())
        return *this;
    if (signum == rhs.signum) {
        add_vector(digits, rhs.digits);
    } else {
        int res_signum;
        sub_vector(digits, rhs.digits, res_signum);
        signum = signum * res_signum;
    }
    trim_zero();
    return *this;
}

big_integer& big_integer::operator-=(big_integer const& rhs) {
    if (rhs.is_zero())
        return *this;
    if (signum != rhs.signum) {
        add_vector(digits, rhs.digits);
    } else {
        int res_signum;
        sub_vector(digits, rhs.digits, res_signum);
        signum = signum * res_signum;
    }
    trim_zero();
    return *this;
}

big_integer& big_integer::operator*=(big_integer const& rhs) {
    if (rhs.is_zero())
        return *this = rhs;
    small_vector res_digits(digits.size() + rhs.digits.size());
    for (size_t i = 0; i < digits.size(); i++) {
        unsigned long long carry = 0;
        for (size_t j = 0; j < rhs.digits.size() || carry; j++) {
            if (j < rhs.digits.size())
                carry += digits[i] * 1LL * rhs.digits[j];
            carry += res_digits[i + j];
            res_digits[i + j] = carry & (BASE - 1);
            carry >>= SIZE;
        }
    }
    signum *= rhs.signum;
    digits = res_digits; 

    trim_zero();
    return *this;
}

void big_integer::divide(big_integer & a1, big_integer const & b1) {
    if (a1.is_zero())
        return;
    if (b1.is_zero())
        throw std::runtime_error("division by zero");
    if (b1.digits.size() == 1) {
        a1 /= b1.digits[0];
        a1.signum *= b1.signum;
        return;
    }
    int norm = BASE / (b1.digits.back() + 1);
    int res_signum = a1.signum * b1.signum;
    
    a1 *= norm * a1.signum;
    big_integer b = b1;
    b *= norm * b1.signum;

    big_integer r;
    unsigned b_last = b.digits.back();
    size_t b_size = b.digits.size();

    big_integer temp;
    for (int i = (int) a1.digits.size() - 1; i >= 0; i--) {
        r.shift_left(a1.digits[i]);
        unsigned s1 = b_size < r.digits.size() ? r.digits[b_size] : 0;
        unsigned s2 = b_size - 1 < r.digits.size() ? r.digits[b_size - 1] : 0;
        unsigned d = (BASE * 1LL * s1 + s2) / b_last;

        temp = b;
        temp *= d;
        r -= temp;

        while (r.signum < 0) {
            r += b;
            d--;
        }
        a1.digits[i] = d;
    }
    a1.signum = res_signum;
    a1.trim_zero();
}

void big_integer::modulo(big_integer & a1, big_integer const & b1) {
    if (a1.is_zero())
        return;
    if (b1.is_zero())
        throw std::runtime_error("division by zero");
    
    int norm = BASE / (b1.digits.back() + 1);
    int res_signum = a1.signum;
    
    a1 *= norm * a1.signum;
    big_integer b = b1;
    b *= norm * b1.signum;

    big_integer r;
    unsigned b_last = b.digits.back();
    size_t b_size = b.digits.size();

    for (int i = (int) a1.digits.size() - 1; i >= 0; i--) {
        r.shift_left(a1.digits[i]);
        unsigned s1 = b_size < r.digits.size() ? r.digits[b_size] : 0;
        unsigned s2 = b_size - 1 < r.digits.size() ? r.digits[b_size - 1] : 0;
        unsigned d = (BASE * 1LL * s1 + s2) / b_last;

        big_integer temp = b;
        temp *= d;
        r -= temp;

        while (r.signum < 0) {
            r += b;
            d--;
        }
    }
    a1 = r;
    a1 /= norm;
    a1.signum = res_signum;
    a1.trim_zero();
}


big_integer& big_integer::operator/=(big_integer const& rhs) {
    divide(*this, rhs);
    return *this;
}

big_integer& big_integer::operator%=(big_integer const& rhs) {
    modulo(*this, rhs);
    return *this;
}

void big_integer::invert_bits() {
    if (signum == -1) {
        for (size_t i = 0; i < digits.size(); i++)
            digits[i] ^= BASE - 1;
        --*this;        
    }
}

big_integer& big_integer::operator&=(big_integer const& rhs) {
    big_integer a = *this;
    big_integer b = rhs;
    size_t max_size = a.digits.size() > b.digits.size() ? a.digits.size() : b.digits.size();
    a.digits.resize(max_size);
    b.digits.resize(max_size);
    a.invert_bits();
    b.invert_bits();
    digits.resize(max_size);
    for (size_t i = 0; i < max_size; i++) {
        digits[i] = a.digits[i] & b.digits[i];
    }
    if (a.signum == -1 && b.signum == -1)
        signum = -1;
    else
        signum = 1;
    invert_bits();
    trim_zero();
    return *this;
}

big_integer& big_integer::operator|=(big_integer const& rhs) {
    big_integer a = *this;
    big_integer b = rhs;
    size_t max_size = a.digits.size() > b.digits.size() ? a.digits.size() : b.digits.size();
    a.digits.resize(max_size);
    b.digits.resize(max_size);
    a.invert_bits();
    b.invert_bits();
    digits.resize(max_size);
    for (size_t i = 0; i < max_size; i++) {
        digits[i] = a.digits[i] | b.digits[i];
    }
    if (a.signum == -1 || b.signum == -1)
        signum = -1;
    else
        signum = 1;
    invert_bits();
    trim_zero();
    return *this;
}

big_integer& big_integer::operator^=(big_integer const& rhs) {
    big_integer a = *this;
    big_integer b = rhs;
    size_t max_size = a.digits.size() > b.digits.size() ? a.digits.size() : b.digits.size();
    a.digits.resize(max_size);
    b.digits.resize(max_size);
    a.invert_bits();
    b.invert_bits();
    digits.resize(max_size);
    for (size_t i = 0; i < max_size; i++) {
        digits[i] = a.digits[i] ^ b.digits[i];
    }
    if (a.signum * b.signum == -1)
        signum = -1;
    else
        signum = 1;
    invert_bits();
    trim_zero();
    return *this;
}

big_integer big_integer::operator~() const {
    if (is_zero())
        return big_integer(-1);
    big_integer result = *this;
    result.invert_bits();
    for (size_t i = 0; i < result.digits.size(); i++)
        result.digits[i] ^= BASE - 1;
    result.signum = -result.signum;
    result.invert_bits();
    result.trim_zero();
    return result;
}


big_integer& big_integer::operator<<=(int rhs) {
    if (rhs < 0 || is_zero())
        return *this;
    int full = rhs / SIZE;
    rhs = rhs % SIZE;
    for (int i = 0; i < full; i++)
        shift_left(0);
    return *this *= (1 << rhs);
}

big_integer& big_integer::operator>>=(int rhs) {
    if (rhs < 0 || is_zero()) 
        return *this;
    int full = rhs / SIZE;
    for (int i = 0; i < full; i++)
        shift_right();
    rhs %= SIZE;
    *this /= (1 << rhs);
    if (signum == -1)
        --*this;
    return *this;
}

bool big_integer::is_zero() const {
    return digits.empty();
}

big_integer big_integer::operator+() const {
    return *this;
}

big_integer big_integer::operator-() const {
    if (is_zero())
        return *this;
    big_integer result = *this;
    result.signum = -signum;
    return result;
}


big_integer& big_integer::operator++() {
    if (is_zero()) {
        digits.push_back(1);
    } else {
        bool carry = false;
        for (size_t i = 0; i < digits.size(); i++) {
            if (digits[i] < BASE - 1) {
                digits[i]++;
                break;
            } else {
                digits[i] = 0;
                carry = true;
            }
        }
        if (carry)
            digits.push_back(1);
    }
    return *this;
}

big_integer big_integer::operator++(int) {
    big_integer result = *this;
    ++*this;
    return result;
}

big_integer& big_integer::operator--() {
    if (is_zero()) {
        digits.push_back(1);
        signum = -1;
    } else {
        if (signum == 1) {
            for (size_t i = 0; i < digits.size(); i++) {
                if (digits[i] != 0) {
                    digits[i]--;
                    break;
                } else {
                    digits[i] = BASE - 1;
                }
            }
        } else {
            bool carry = false;
            for (size_t i = 0; i < digits.size(); i++) {
                if (digits[i] < BASE - 1) {
                    digits[i]++;
                    break;
                } else {
                    digits[i] = 0;
                    carry = true;
                }
            }
            if (carry)
                digits.push_back(1);
        }
    }
    return *this;
}

big_integer big_integer::operator--(int) {
    big_integer result = *this;
    --*this;
    return result;
}

big_integer operator+(big_integer a, big_integer const& b) {
    return a += b;
}

big_integer operator-(big_integer a, big_integer const& b) {
    return a -= b;
}

big_integer operator*(big_integer a, big_integer const& b) {
    return a *= b;
}

big_integer operator/(big_integer a, big_integer const& b) {
    return a /= b;
}

big_integer operator%(big_integer a, big_integer const& b) {
    return a %= b;
}

big_integer operator&(big_integer a, big_integer const& b) {
    return a &= b;
}

big_integer operator|(big_integer a, big_integer const& b) {
    return a |= b;
}

big_integer operator^(big_integer a, big_integer const& b) {
    return a ^= b;
}

big_integer operator<<(big_integer a, int b) {
    return a <<= b;
}

big_integer operator>>(big_integer a, int b) {
    return a >>= b;
}

bool operator==(big_integer const& a, big_integer const& b) {
    if (a.signum != b.signum)
        return false;
    if (a.digits.size() != b.digits.size())
        return false;
    for (size_t i = 0; i < a.digits.size(); i++)
        if (a.digits[i] != b.digits[i])
            return false;
    return true;
}

bool operator!=(big_integer const& a, big_integer const& b) {
    return !(a == b);
}

bool operator<(big_integer const& a, big_integer const& b) {
    if (a.signum != b.signum)
        return a.signum <= b.signum;
    if (a.signum >= 0) {
        if (a.digits.size() != b.digits.size())
            return a.digits.size() < b.digits.size();
        for (int i = (int) a.digits.size() - 1; i >= 0; i--)
            if (a.digits[i] != b.digits[i])
                return a.digits[i] < b.digits[i];
    } else {
        if (a.digits.size() != b.digits.size())
            return a.digits.size() > b.digits.size();
        for (int i = (int) a.digits.size() - 1; i >= 0; i--)
            if (a.digits[i] != b.digits[i])
                return a.digits[i] > b.digits[i];
    }
    return false;
}

bool operator>(big_integer const& a, big_integer const& b) {
    return b < a;
}

bool operator<=(big_integer const& a, big_integer const& b) {
    return a < b || a == b;
}

bool operator>=(big_integer const& a, big_integer const& b) {
    return a > b || a == b;     
}

std::string to_string(big_integer const& a) {
    if (a.is_zero()) 
        return "0";

    big_integer temp = a;

    temp.signum = 1;
    std::string result;
    while (!temp.is_zero()) {
        temp /= 10;
        result += char(temp.remainder + '0');
    }
    if (a.signum < 0)
        result += '-';

    std::reverse(result.begin(), result.end());
    return result;
}

std::ostream& operator<<(std::ostream& s, big_integer const& a) {
    s << to_string(a);
    return s;
}
