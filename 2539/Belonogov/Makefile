
CXXFLAGS=-g -O0

YASM_FLAGS=-f elf64 -g dwarf2

all: libhw.o
	ar rcs libhw.a libhw.o

test: test.o all
	g++ $(CXXFLAGS) -o test test.o libhw.o -lgmp


libhw.o: libhw.asm
	yasm libhw.asm $(YASM_FLAGS) -o libhw.o

clean:
	rm *.o
	rm ./test
	rm *.a
