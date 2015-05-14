#CC = g++-4.9
CC = clang++
OBJS = bigint.o
INCLUDE = ../../include

CFLAGS = -std=c++11 -Wall -Wextra -O2 -pedantic 

ifneq ($(CC), clang++)
CFLAGS += -fsanitize=address -fsanitize=undefined
endif

YASM_FLAGS = -p nasm

OS := $(shell uname)
ifeq ($(OS), Darwin)
YASM_FLAGS += -f macho64 
OBJS += osx-wrapper.o
else
YASM_FLAGS += -f elf64 -g dwarf2
endif

.PHONY: all

all: testit libhw.a

testit: test
	./test

test: libhw.a test.cc
	$(CC) -o test test.cc $(CFLAGS) -I$(INCLUDE) -L. -lhw 

libhw.a: $(OBJS)
	ar rcs libhw.a $(OBJS)

bigint.o: bigint.asm 
	yasm -o bigint.o $(YASM_FLAGS) bigint.asm

osx-wrapper.o: osx-wrapper.asm
	yasm -o osx-wrapper.o $(YASM_FLAGS) osx-wrapper.asm

libdump.so:
	$(CC) $(CFLAGS) -I$(INCLUDE) -shared -o libdump.so -fPIC aux_bigint.hh

clean:
	rm -f libhw.a
	rm -f *.o
	rm -rf *.dSYM
	rm -f test
