ASM_FLAGS = -f elf64 -g dwarf2
CFLAGS = -fsanitize=address -g -L. -I../../include
#CFLAGS = -O2 -L. -I../../include -I.

all: tests

tests: libhw.a tests.o
	g++ -o tests $(CFLAGS) tests.o -lhw

tests.o: tests.cpp
	g++ -o tests.o tests.cpp $(CFLAGS) -c 
	
libhw.a: libhw.o vectorint.o
	ar rcs libhw.a libhw.o vectorint.o

libhw.o: libhw.asm
	yasm -o libhw.o $(ASM_FLAGS) libhw.asm 

vectorint.o: vectorint.asm
	yasm -o vectorint.o $(ASM_FLAGS) vectorint.asm

clean:
	rm -f libhw.a
	rm -f libhw.o
	rm -f tests.o
	rm -f tests
	rm -f vectorint.o
