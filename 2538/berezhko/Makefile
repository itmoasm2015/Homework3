all: asm test

ar: asm
	ar rcs libhw.a bigint.o
	ar rcs libbig.a bigint/*.o

test: ar test.cpp
	g++ -o test -w test.cpp libhw.a libbig.a

asm: bigint.asm
	yasm -felf64 -gdwarf2 bigint.asm

clean:
	rm *.a
	rm *.o
	rm test
