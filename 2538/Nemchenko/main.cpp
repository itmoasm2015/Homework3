#include <iostream>
#include <cstdio>
#include <bigint.h>

using namespace std;

int main() {
    void* res = biFromInt(10);      
    cout << (int64_t) res << endl;
    return 0;
}
