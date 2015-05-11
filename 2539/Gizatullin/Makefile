C_FLAGS = -O2 -std=c++11 -L. -I../../include -g
all: libhw.a

libhw.a: libhw.o
	ar rcs libhw.a libhw.o

libhw.o: libhw.asm
	yasm -o libhw.o -f elf64 -g dwarf2 -Werror libhw.asm

clean:
	rm -f libhw.a
	rm -f *.o
	rm -f ./test