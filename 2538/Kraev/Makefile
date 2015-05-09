ASM_FLAGS = -felf64 -gdwarf2
CXX_FLAGS = -std=c11 -L. -I.

all: libhw.a


clean:
	rm -f libhw.a
	rm -f hw.o
	rm -f test

test: libhw.a test.c
	gcc -g -O2 -o test $(CXX_FLAGS) test.c -lhw 
tests: libhw.a test.c
	gcc -O2 -S -masm=intel -o tests $(CXX_FLAGS) test.c -lhw
libhw.a: hw.o
	ar rcs libhw.a hw.o

hw.o: bigint.asm
	yasm -o hw.o $(ASM_FLAGS) bigint.asm
