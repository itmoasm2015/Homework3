ASM_FLAGS = -felf64 -gdwarf2
CXX_FLAGS = -std=c11 -g -L. -I.

all: test

clean:
	rm -f libhw.a
	rm -f *.o
	rm -f test
	rm -f testlite

test: libhw.a test.c
	gcc -o test $(CXX_FLAGS) test.c -lhw

testlite: libhwwrapped.a testlite.c
	gcc -o testlite $(CXX_FLAGS) testlite.c -lhwwrapped

libhw.a: bigint.o vector.o
	ar rcs libhw.a bigint.o vector.o

bigint.o: bigint.asm
	yasm -o bigint.o $(ASM_FLAGS) bigint.asm

vector.o: vector.asm
	yasm -o vector.o $(ASM_FLAGS) vector.asm