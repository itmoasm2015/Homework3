#include "include/matrix.h"
#include <iostream>
#include <cassert>
#include <cstdlib>
#include <ctime>
#include <cstdio>
#include <stdexcept>
#include <vector>

using namespace std;

struct Tester {
public:
    typedef void(*test_function)();
    typedef pair <string, test_function> test;

    Tester() {}
    int run(void(*test)()) {
        int start = clock();
        test();
        int end = clock();
        return end - start;
    }
    void runner(vector <test> tests, bool interrupt = true) {
        int duration;
        pair <int, int> max_duration(0, 0);
        for(int i = 0; i < (int)tests.size(); i++) {
            printf("TEST %20s ... ", tests[i].first.c_str());
            try {
                duration = run(tests[i].second);
                printf("OK\n");

                if (duration > max_duration.first) {
                    max_duration = make_pair(duration, i);
                }
            } catch (exception& e) {
                printf("\n  Exception: %s\n", e.what());
            }
            printf("==== %.3lf s.\n\n", 1.0*duration/1000000);
        }
    }
};

int main() {
    vector <Tester::test> tests = {};
    Tester tester;
    tester.runner(tests);
    return 0;
}


