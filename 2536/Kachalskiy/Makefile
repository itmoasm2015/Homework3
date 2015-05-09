CXXFLAGS=-g -O0

YASM_FLAGS=-f elf64 -g dwarf2

all: biginteger.o
	ar rcs biginteger.a biginteger.o

test: test.o all
	g++ $(CXXFLAGS) -o test test.o biginteger.o -lgmp


biginteger.o: biginteger.asm
	yasm biginteger.asm $(YASM_FLAGS) -o biginteger.o

