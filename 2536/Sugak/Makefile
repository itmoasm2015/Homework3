CPP_FLAGS = -Wall -fno-omit-frame-pointer -fsanitize=address -g -L. -I../include -std=c++11 
ASM_FLAGS = -g dwarf2 -f elf64 

all: libhw.a

libhw.a: libhw.o
	ar rcs libhw.a libhw.o

libhw.o: bigint.asm
	yasm -o libhw.o $(ASM_FLAGS) bigint.asm

clean:
	rm -f libhw.a
	rm -f libhw.o
