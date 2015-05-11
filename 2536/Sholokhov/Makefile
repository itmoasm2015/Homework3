CC = gcc
ASM = yasm
AR = ar
CC_OPTS = -Wall -Wextra -std=c99 -m64 -O2 -L. -I../../include
ASM_OPTS = -f elf64 -g dwarf2

all: libhw.a

clean:
	rm -f tester
	rm -f tester.o
	rm -f libhw.a
	rm -f asmimpl.o

libhw.a: asmimpl.o
	$(AR) rcs $@ $<

asmimpl.o: asmimpl.asm
	$(ASM) -o $@ $(ASM_OPTS) $^

