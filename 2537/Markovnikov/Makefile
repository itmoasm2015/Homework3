ASM_FLAGS = -felf64 -gdwarf2
CXX_FLAGS = -std=c++11 -g3 -L. -I../../include

all: test

clean:
	rm -f *.a
	rm -f *.o
	rm -f test

test: libhw.a test.o
	g++ -o test $(CXX_FLAGS) test.o -lhw

test.o: test.cpp
	g++ -o test.o $(CXX_FLAGS) -c test.cpp

libhw.a: libhw.o
	ar rcs libhw.a libhw.o

libhw.o: bigint.asm
	yasm -o libhw.o $(ASM_FLAGS) bigint.asm
