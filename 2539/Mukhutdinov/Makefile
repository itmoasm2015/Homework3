CXX=g++
CXXFLAGS=-Wall -g -O3 -std=c++11 -I../../include
LDFLAGS=-lboost_unit_test_framework -lgmpxx -lgmp
YASM=yasm
YFLAGS=-f elf64 -g dwarf2
AR=ar rcs

all: lib

test: test.o vector.o bigint.o
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $^

lib: vector.o bigint.o
	$(AR) libhw.a $^

%.o: %.asm
	$(YASM) $(YFLAGS) -o $@ $^

clean:
	rm -f *.o *.a test
