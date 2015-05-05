CC=gcc
CFLAGS=-Wall -m64 -g -O3 -std=c11 -I../../include
YASM=yasm
YFLAGS=-f elf64 -g dwarf2
AR=ar rcs

all: test lib

test: test.o vector.o
	$(CC) $(CFLAGS) -o $@ $^

lib: vector.o
	$(AR) libhw.a $^

%.o: %.asm
	$(YASM) $(YFLAGS) -o $@ $^

clean:
	rm -f *.o *.a test
