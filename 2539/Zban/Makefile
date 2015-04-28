CXXFLAGS=-g -O2

OBJS=test.o libhw.o

YASM_FLAGS=-f elf64 -g dwarf2

all: test
	ar rcs libhw.a libhw.o

test: $(OBJS)
	g++ $(CXXFLAGS) -o $@ $^ -lgmp

libhw.o: libhw.asm
	yasm libhw.asm $(YASM_FLAGS) -o libhw.o

clean:
	rm *.o
	rm ./test
	rm *.a
