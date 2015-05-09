GCC = gcc
CPP = g++
ASM = yasm
CPP_FLAGS = -Wall -g -L. -std=c++11 -lgmp
ASM_FLAGS = -g dwarf2 -f elf64 

all: tester

tester: libhw.a tester.o
	$(CPP) tester.o -o tester $(CPP_FLAGS)  bigint.h libhw.o

tester.o: tester.cpp
	$(CPP) tester.cpp -c -o tester.o $(CPP_FLAGS) 

libhw.a: libhw.o
	ar rcs libhw.a libhw.o

libhw.o: asm_impl.asm
	$(ASM) -o libhw.o $(ASM_FLAGS) asm_impl.asm

clean:
	rm -f libhw.a
	rm -f libhw.o
	rm -f tester.o
	rm -f tester
