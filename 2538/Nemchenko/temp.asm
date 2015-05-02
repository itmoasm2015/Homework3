calee-save RBX, RBP, R12-R15
rdi , rsi ,
rdx , rcx , r8 ,
r9 , zmm0 - 7

stored bigNumber like this:
struct *bigNum {
  unsigned long long capacity;   8 bytes
  unsigned long long size;       8 bytes
  unsigned long long sign;       8 byte
  unsigned long long *digits   
}
 
forall i < capacity: digits[i] < BASE
sign = 1 | 0 | -1

byte  - 1 byte
word  - 2 bytes
dword - 4 bytes  
qword - 8 bytes 


void createBigInt(long long cnt)
void put_back(BigInt*, long long arg);
long long get_max_size(BigInt*, BigInt*)
BigInt biFromInt(int64_t x);
