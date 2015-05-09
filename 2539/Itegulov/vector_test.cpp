#include <iostream>
#include <cstdlib>
#include <cstdint>


using namespace std;


typedef void * vector;


// Asm imports.
extern "C" {
    vector vecNew();
    vector vecAlloc(uint64_t size);
    void vecFree(vector vec);
    void vecPush(vector vec, uint64_t value);
    uint64_t vecSize(vector vec);
    uint64_t vecCapacity(vector vec);
    uint64_t vecGet(vector vec, uint64_t index);
    void vecSet(vector vec, uint64_t index, uint64_t value);
}


#define TEST(t, test)   int result##test = test(t); \
                        all_tests++; \
                        if (result##test) { \
                            passed_tests++; \
                        } else { \
                            cerr << "FAILED: " #test " (t=" << (t) << ")\n"; \
                        }

#define EXPECT(cond)    if (!(cond)) { \
                            cerr << "Assertion `" #cond "` failed\n"; \
                            return false; \
                        }


bool vector_creation(int n) {
    vector vec = vecNew();
    EXPECT(vec != nullptr);

    vector vec2 = vecAlloc(n);
    EXPECT(vec2 != nullptr);

    vecFree(vec);
    vecFree(vec2);

    return true;
}

bool vector_iteration(unsigned n) {
    vector vec = vecNew();

    // Fill `vec` in with integers.
    for (unsigned i = 0; i < n; i++) {
        vecPush(vec, i + 1);
        EXPECT(vecSize(vec) == i + 1);
        EXPECT(vecSize(vec) <= vecCapacity(vec));
    }

    // Rotate `vec`.
    for (unsigned i = 0; i < n / 2; i++) {
        uint64_t tmp = vecGet(vec, i);
        vecSet(vec, i, vecGet(vec, n - i - 1));
        vecSet(vec, n - i - 1, tmp);
    }

    // Check `vec` for correctness.
    for (unsigned i = 0; i < n; i++) {
        EXPECT(vecGet(vec, i) == n - i);
    }

    vecFree(vec);

    return true;
}

bool vector_transformation(unsigned n) {
    vector vec = vecAlloc(n);

    // Assign initial values.
    for (unsigned i = 0; i < n; i++) {
        vecSet(vec, i, i + 1);
    }

    // Play with `vec` size.
    //unsigned step = rand() % (n / 1000 + 1) + n / 1000 + 1;
    //for (unsigned sz = 0; sz < n; sz += step) {
    //    vec = vecResize(vec, sz + 5);
    //}

    // Initial elements should be present.
    for (unsigned i = 0; i < n; i++) {
        EXPECT(vecGet(vec, i) == i + 1);
    }

    vecFree(vec);

    return true;
}


int main() {
    int all_tests = 0;
    int passed_tests = 0;

    srand(time(NULL));

    for (unsigned t = 1; t <= 1000; t++) {
        int salt = 10;
        TEST(t + salt, vector_creation);
		TEST(t + salt, vector_iteration);
        TEST(t + salt, vector_transformation);
    }

    cout << "OK " << passed_tests << "/" << all_tests << " tests\n";

    return 0;
}
