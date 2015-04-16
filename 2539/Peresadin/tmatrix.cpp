#include <iostream>
#include <cstring>
#include <cassert>
#include "tmatrix.h"

TMatrix::TMatrix(const Matrix& oth)  {
	n = matrixGetRows(oth);
	m = matrixGetCols(oth);
	data = new float*[n];
	for (int i = 0; i < n; ++i) { 
		data[i] = new float[m];
		for (int j = 0; j < m; ++j)
			data[i][j] = matrixGet(oth, i, j);
		}
}

TMatrix::TMatrix(unsigned int n, unsigned int m): n(n), m(m) {
	data = new float*[n];
	for (int i = 0; i < n; ++i) { 
		data[i] = new float[m];
		memset(data[i], 0, 4 * m);
	}
}

void TMatrix::swap(TMatrix& oth) {
	std::swap(n, oth.n);
	std::swap(m, oth.m);
	std::swap(data, oth.data);
}

TMatrix& TMatrix::operator = (const TMatrix& oth) {
	TMatrix tmp(oth);
	swap(tmp);
	return *this;
}

TMatrix::TMatrix(const TMatrix& oth):n(oth.n), m(oth.m) {
	data = new float*[n];
	for (int i = 0; i < n; ++i) {
		data[i] = new float[m];
		for (int j = 0; j < m; ++j)
			data[i][j] = oth.data[i][j];
	}
}

void TMatrix::set(int i, int j, float x) {
	data[i][j] = x;
}

float TMatrix::get(int i, int j) const {
	return data[i][j];
}

unsigned int TMatrix::rows() const {
	return n;
}

unsigned int TMatrix::cols() const {
	return m;
}

TMatrix TMatrix::scale(float k) const {
	TMatrix ret(n, m);
	for (int i = 0; i < n; ++i)
		for (int j = 0; j < m; ++j)
			ret.data[i][j] = data[i][j] * k;
	return ret;
}

TMatrix TMatrix::add(const TMatrix& oth) const {
	assert(oth.n == n && oth.m == m);
	TMatrix ret(n, m);
	for (int i = 0; i < n; ++i)
		for (int j = 0; j < m; ++j)
			ret.data[i][j] = data[i][j] + oth.data[i][j];
	return ret;
}

TMatrix TMatrix::transpose() const {
	TMatrix ret(m, n);
	for (int i = 0; i < n; ++i)
		for (int j = 0; j < m; ++j)
			ret.data[j][i] = data[i][j];
	return ret;
}

TMatrix TMatrix::mul(const TMatrix& oth) {
	assert(m == oth.n);
	TMatrix ret(n, oth.m);
	TMatrix tr = oth.transpose();
	for (int i = 0; i < ret.n; ++i)
		for (int j = 0; j < ret.m; ++j)
			for (int k = 0; k < m; ++k)
				ret.data[i][j] += data[i][k] * tr.data[j][k];
	return ret;
}

TMatrix::~TMatrix() {
	for (int i = 0; i < n; ++i)
		delete[] data[i];
	delete[] data;
}
