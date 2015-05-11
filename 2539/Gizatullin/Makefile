C_FLAGS = -O2 -std=c++11 -L. -I../../include -g
all: libhw.a tester

tester: test
	./test

test: test.o
	g++ -o test $(C_FLAGS) test.o -lhw -lgmp

test.o: test.cpp
	g++ -o test.o $(C_FLAGS) -c test.cpp 

libhw.a: libhw.o
	ar rcs libhw.a libhw.o

libhw.o: libhw.asm
	yasm -o libhw.o -f elf64 -g dwarf2 -Werror libhw.asm

clean:
	rm -f libhw.a
	rm -f *.o
	rm -f ./test