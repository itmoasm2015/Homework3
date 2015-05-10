ASM_FLAGS = -felf64 -g dwarf2

all: bigint

bigint:	bigint.o test.o

bigint.o: bigint.asm
	yasm -o bigint.o $(ASM_FLAGS) bigint.asm
	ar rcs libhw.a bigint.o

test.o: test.cpp bigint.asm
	g++ -o test.o -O2 -std=c++11 -L. -c test.cpp
	g++ -o test -L. -O2 test.o -lhw

clean:
	rm -f libhw.a
	rm -f bigint.o
	rm -f test.o
	rm -f bigint
	rm -f test

