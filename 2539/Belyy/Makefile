CXX = g++
ASM = yasm
AR = ar
CXX_OPTS = -g -Wall -Wextra -std=c++11 -m64 -O2 -L. -I../../include
ASM_OPTS = -g dwarf2 -f elf64

all: bigint_test intvector_test

clean:
	rm -f bigint_test
	rm -f bigint_test.o
	rm -f intvector_test
	rm -f intvector_test.o
	rm -f libhw.a
	rm -f bigint.o
	rm -f intvector.o

bigint_test: libhw.a bigint_test.o
	$(CXX) -o $@ $(CXX_OPTS) bigint_test.o -lhw

bigint_test.o: bigint_test.cpp
	$(CXX) -o $@ -c $(CXX_OPTS) $^

intvector_test: libhw.a intvector_test.o
	$(CXX) -o $@ $(CXX_OPTS) intvector_test.o -lhw

intvector_test.o: intvector_test.cpp
	$(CXX) -o $@ -c $(CXX_OPTS) $^

libhw.a: intvector.o bigint.o
	$(AR) rcs $@ $^

bigint.o: bigint.asm
	$(ASM) -o $@ $(ASM_OPTS) $^

intvector.o: intvector.asm
	$(ASM) -o $@ $(ASM_OPTS) $^
