CXX = g++
ASM = yasm
AR = ar
CXX_OPTS = -g -Wall -Wextra -std=c++11 -m64 -O2 -L. -I../../include
ASM_OPTS = -g dwarf2 -f elf64

all: vector_test

clean:
	rm -f vector_test
	rm -f vector_test.o
	rm -f libhw.a
	rm -f vector.o

vector_test: libhw.a vector_test.o
	$(CXX) -o $@ $(CXX_OPTS) vector_test.o -lhw

vector_test.o: vector_test.cpp
	$(CXX) -o $@ -c $(CXX_OPTS) $^

libhw.a: ivector.o
	$(AR) rcs $@ $^

ivector.o: ivector.asm
	$(ASM) -o $@ $(ASM_OPTS) $^
