CXXFLAGS=-g -Wall -Wextra 

YASM_FLAGS=-f elf64 -g dwarf2

all: test 

test: test.o libhw.a 
	g++ $(CXXFLAGS) -o test test.o libhw.o

libhw.a: libhw.o
	ar rcs libhw.a libhw.o

libhw.o: bigint.s
	yasm bigint.s $(YASM_FLAGS) -o libhw.o

clean:
	rm *.o
	rm ./test
	rm *.a
