ASM_FLAGS = -f elf64 -g dwarf2
CFLAGS = -O2 -L. -I../../include

all: libhw.a clean

libhw.a: libhw.o
	ar rcs libhw.a libhw.o

libhw.o: libhw.a
	yasm -o libhw.o $(ASM_FLAGS) bigint.asm

clean:
	rm -f libhw.o
	
