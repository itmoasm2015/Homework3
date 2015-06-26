# Created by PaulChristmas
# 15.06.15

# Compilers
TESTC=g++
ASMC=yasm

# Flags
FLAGS=-f elf64 -g dwarf2

# Program name
NAME=biginteger

all: $(NAME).o
	ar rcs libhw.a $(NAME).o

test: test.o all
	$(TESTC) -g -O0 -o test test.o $(NAME).o -lgmp


biginteger.o: $(NAME).asm
	$(ASMC) $(NAME).asm $(FLAGS) -o $(NAME).o
	
clean:
	rm -f *.o
	rm -f *.a
	rm -f test
