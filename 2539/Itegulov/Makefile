CXX = g++
C = gcc
ASM = yasm
AR = ar
CXX_OPTS = -g -Wall -Wextra -std=c++11 -m64 -L. -I../../include
C_OPTS = -g -Wall -Wextra -std=c99 -m64 -L. -I../../include
ifeq ($(shell uname), Darwin)
ASM_OPTS = -f macho64 --prefix=_
CXX_OPTS += -Wl,-no_pie
C_OPTS += -Wl,-no_pie
else
ASM_OPTS = -g dwarf2 -f elf64
endif

all: vector_test bigint_test

clean:
	rm -f vector_test
	rm -f vector_test.o
	rm -f bigint_test
	rm -f bigint_test.o
	rm -f libhw.a
	rm -f ivector.o
	rm -f bigint.o

vector_test: libhw.a vector_test.o
	$(CXX) -o $@ $(CXX_OPTS) vector_test.o -lhw

bigint_test: libhw.a bigint_test.o
	$(CXX) -o $@ $(CXX_OPTS) bigint_test.o -lhw

vector_test.o: vector_test.cpp
	$(CXX) -o $@ -c $(CXX_OPTS) $^

bigint_test.o: bigint_test.c
	$(C) -o $@ -c $(C_OPTS) $^

libhw.a: ivector.o bigint.o
	$(AR) rcs $@ $^

ivector.o: ivector.asm
	$(ASM) -o $@ $(ASM_OPTS) $^

bigint.o: bigint.asm
	$(ASM) -o $@ $(ASM_OPTS) $^
