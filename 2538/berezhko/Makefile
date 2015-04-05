all: asm test

ar: asm
	ar rcs libhw.a bigint.o

test: ar test.cpp
	g++ -o test test.cpp libhw.a

asm: bigint.asm
	yasm -felf64 -gdwarf2 bigint.asm

clean:
	rm libhw.a
	rm *.o
	rm test
