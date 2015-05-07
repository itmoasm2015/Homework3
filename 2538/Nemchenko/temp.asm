mul rdx:rax -> rax = rax * src
calee-save RBX, RBP, R12-R15
rdi , rsi ,
rdx , rcx , r8 ,
r9 , zmm0 - 7 default rel

stored bigNumber like this:
struct BI {
  ull capacity;   8 bytes
  ull size;       8 bytes
  ll sign;        8 byte
  ull *data   
}
ll get_max_size(BI* first, BI* second)

void push_back(BI* src, ll arg);

void move_bigInt(BI* dest, BI* src)

BI* createBigInt(ll num_dig)

void set_or_pb(BI* src, ll new_value, ll position)

void copy_BigInt(BI* dest, BI* src)

void ensure_capacity(BI* src)

void realloc_data(BI* src, ll new_capacity)

void biAdd(BI* dst, BI* src);

BI biFromInt(int64_t x);

void biDelete(BI bi);

int biSign(BI bi);

