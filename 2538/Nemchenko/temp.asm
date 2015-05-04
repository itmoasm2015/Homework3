calee-save RBX, RBP, R12-R15
rdi , rsi ,
rdx , rcx , r8 ,
r9 , zmm0 - 7 default rel

stored bigNumber like this:
struct BigInt {
  unsigned long long capacity;   8 bytes
  unsigned long long size;       8 bytes
  unsigned long long sign;       8 byte
  unsigned long long *data   
}
