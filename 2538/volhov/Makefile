all: libhw.a

libhw.a: bigint.o
	ar rcs libhw.a bigint.o

bigint.o: bigint.asm
	yasm -felf64 -gdwarf2 -Werror -o bigint.o bigint.asm

test: libhw.a bigint_test.cpp
	g++ -std=c++11 -g -o test bigint_test.cpp -fpermissive -I../../include/  -L. -lhw

clean:
	rm -rf *.o *.a test
