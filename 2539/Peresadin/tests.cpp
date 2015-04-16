#include "tmatrix.h"
#include "matrix.h"
#include <cstdio>
#include <cmath>
#include <cstdlib>
#include <ctime>
#include <cassert>

#ifdef __cplusplus
extern "C" {
#endif
Matrix matrixTranspose(Matrix a);
#ifdef __cplusplus
}
#endif

bool equals(const Matrix& a, const TMatrix& b) {
	if (matrixGetRows(a) != b.rows() || matrixGetCols(a) != b.cols()) {
		printf("diff dim\n");
		return false;
	}
	int n = b.rows();
	int m = b.cols();
	for (int i = 0; i < n; ++i) 
		for (int j = 0; j < m; ++j)
            if (fabs(b.get(i, j) - matrixGet(a, i, j)) > 0.01) {
				//printf("%.3f\n", b.get(i, j));
				//printf("%d %d %.2f\n", i, j, fabs(b.get(i, j) - matrixGet(a, i, j)));
                return false;
			}
    return true;
}

Matrix randMatrxix(int n, int m) {
	Matrix ret = matrixNew(n, m);
	for (int i = 0; i < n; ++i)
		for (int j = 0; j < m; ++j)
			//matrixSet(ret, i, j, 1);
			matrixSet(ret, i, j, float(rand() * 1.0 / RAND_MAX));
	return ret;
}

float randFloat() {
	int sign = 1;
	if (rand()%2) sign = -1;
	return sign * float(rand() * 1.0 / RAND_MAX);
}

int randInt(int l, int r) {
	int x = rand() % (r - l + 1);
	if (x < 0) x = -x;
	return x + l;
}

TMatrix randTMatrxix(int n, int m) {
	TMatrix ret(n, m);
	for (int i = 0; i < n; ++i)
		for (int j = 0; j < m; ++j)
			ret.set(i, j, randFloat());
	return ret;
}

void stressConstructor(int tests) {
	printf("===stress constructor===\n");
	for (int test = 0; test < tests; ++test) {
		int n = randInt(1000, 3000);
		int m = randInt(1000, 3000);
		Matrix a = matrixNew(n, m);
		TMatrix b(n, m);
		assert(equals(a, b));
		printf("test = %d\n", test + 1);
		matrixDelete(a);
	}
}


void stressScale(int tests) {
	printf("===stress scale===\n");
	for (int test = 0; test < tests; ++test) {
		int n = randInt(1000, 5000);
		int m = randInt(1000, 5000);
		float k = randFloat();
		Matrix a = randMatrxix(n, m);
		TMatrix v(a);
		int l = clock();
		Matrix my = matrixScale(a, k);
		double tmy = (clock() - l) * 1.0 / CLOCKS_PER_SEC;
		
		l = clock();
		TMatrix ok = v.scale(k);
		double tok = (clock() - l) * 1.0 / CLOCKS_PER_SEC;
		
		assert(equals(my, ok));
		printf("test = %d: diff time = %.3f\n", test + 1, tok - tmy);
		matrixDelete(a);
	}
}

void stressAdd(int tests) {
	printf("===stress add===\n");
	for (int test = 0; test < tests; ++test) {
		int n = randInt(1000, 5000);
		int m = randInt(1000, 5000);
		Matrix a = randMatrxix(n, m);
		Matrix b;
		bool diff = false;
		if (randInt(1, 2) == 1)
			b = randMatrxix(n, m);
		else {
			b = randMatrxix(randInt(1000, 5000), randInt(1000, 5000));
			diff = true;
		}
		int l = clock();
		Matrix my = matrixAdd(a, b);
		double tmy = (clock() - l) * 1.0 / CLOCKS_PER_SEC;
		
		if (!diff) {
			l = clock();
			TMatrix ok = TMatrix(a).add(b);
			double tok = (clock() - l) * 1.0 / CLOCKS_PER_SEC;
			
			assert(equals(my, ok));
			printf("test = %d: diff time = %.3f\n", test + 1, tok - tmy);
		} else
			printf("test = %d: diff dims\n", test + 1);
		matrixDelete(a);
		matrixDelete(b);
	}
}

void stressMul(int tests) {
	printf("===stress mul===\n");
	for (int test = 0; test < tests; ++test) {
		int n = randInt(500, 2000);
		int k = randInt(500, 2000);
		Matrix a = randMatrxix(n, k);
		Matrix b = randMatrxix(matrixGetCols(a), randInt(500, 2000));
		int l = clock();
		Matrix res = matrixMul(a, b);
		double tmy = (clock() - l) * 1.0 / CLOCKS_PER_SEC;
		
		l = clock();
		TMatrix ok = TMatrix(a).mul(b);
		double tok = (clock() - l) * 1.0 / CLOCKS_PER_SEC;
		
		assert(equals(res, ok));
		printf("test = %d : mytime = %.3f oktime = %.3f\n", test + 1, tmy, tok);
		matrixDelete(b);
		matrixDelete(a);
		matrixDelete(res);
	}
}

void stressAll(int tests) {
	printf("===stressAll===\n");
	const int T = 50;
	for (int test = 1; test <= tests; ++test) {
		Matrix a = randMatrxix(randInt(1, T), randInt(1, T));
		TMatrix ta(a);
		//printf("r c %d %d\n", ta.rows(), ta.cols());
		printf("test = %d:\n", test);
		fflush(stdout);
		for (int i = 0; i < 10; ++i) {
			int tp = randInt(1, 4);
			printf("%d ", tp);
			fflush(stdout);
			for (int i1 = 0; i1 < ta.rows(); ++i1) {
				for (int j1 = 0; j1 < ta.cols(); ++j1)
					printf("%.3f ", matrixGet(a, i1, j1));
				printf("\n");
			}
			if (tp == 1) {
				Matrix b = randMatrxix(matrixGetRows(a), matrixGetCols(a));
				TMatrix tb(b);
				Matrix res = matrixAdd(a, b);
				ta = ta.add(tb);
				matrixDelete(a);
				matrixDelete(b);
				a = res;
			} else if (tp == 2) {
				float k = randFloat();
				Matrix res = matrixScale(a, k);
				ta = ta.scale(k);
				matrixDelete(a);
				a = res;
			} else if (tp == 3) {
				Matrix res = matrixTranspose(a);
				ta = ta.transpose();
				matrixDelete(a);
				a = res;
			} else if (tp == 4) {
				Matrix b = randMatrxix(matrixGetCols(a), randInt(1, T));
				TMatrix tb(b);
				Matrix res = matrixMul(a, b);
				ta = ta.mul(tb);
				matrixDelete(a);
				matrixDelete(b);
				a = res;
			}
			if (!equals(a, ta)) {
				printf("\nfailed after %d\n", tp);
				fflush(stdout);
				assert(0);
			}
		}
		printf("\n");
	}
}
void stressTranspose(int tests) {
	printf("===stress transpose===\n");
	for (int test = 0; test < tests; ++test) {
		int n = randInt(500, 2000);
		int m = randInt(500, 2000);
		Matrix a = randMatrxix(n, m);
		int l = clock();
		Matrix my = matrixTranspose(a);
		double tmy = (clock() - l) * 1.0 / CLOCKS_PER_SEC;
		
		l = clock();
		TMatrix ok = TMatrix(a).transpose();
		double tok = (clock() - l) * 1.0 / CLOCKS_PER_SEC;
		
		assert(equals(my, ok));
		printf("test = %d: diff time = %.3f\n", test + 1,  tok - tmy);
		matrixDelete(a);
		
	}
}

int main() {
	srand(time(NULL));
	stressConstructor(10);
	stressScale(10);
	stressAdd(10);
	stressTranspose(10);
	stressMul(10);
	return 0;
}

