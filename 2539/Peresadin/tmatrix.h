#ifndef TMATRIX_H
#define TMATRIX_H
#include "matrix.h"

struct TMatrix {
private:
    float **data;
    unsigned int n;
    unsigned int m;
public:
	TMatrix(const Matrix& oth);
    TMatrix(unsigned int n, unsigned int m);
    void swap(TMatrix& oth);
    TMatrix& operator = (const TMatrix& oth);
    TMatrix(const TMatrix& oth);
    void set(int i, int j, float x);
    float get(int i, int j) const;
    unsigned int rows()  const;
    unsigned int cols() const;
    TMatrix scale(float k) const;
    TMatrix add(const TMatrix& oth) const;
    TMatrix transpose() const;
    TMatrix mul(const TMatrix& oth);
    ~TMatrix();
};

#endif
