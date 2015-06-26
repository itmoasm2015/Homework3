CC=g++
TARGET=libhw.a
OBJECTS=bigint_impl.o
CXXFLAGS=-Wall -Wextra -g3 -std=c++1y -I../../include/ #-fsanitize=address
DEPS=../../include/bigint.h
LDFLAGS=-lgmpxx -lgmp

all: $(OBJECTS)  
	ar rcs $(TARGET) $<

test: test.cpp $(OBJECTS)   
	$(CC) $(CXXFLAGS) $^ $(LDFLAGS) -o $@

bigint_impl.o: bigint_impl.asm
	rm -f $(TARGET)
	yasm -f elf64 -g dwarf2 $^ -o $@

wrap: test.cpp
	$(CC) $(CXXFLAGS) $^ $(LDFLAGS) -L. -lhwwrapped -o $@


clean:
	rm -f $(TARGET)
	rm -f *.o
	rm -f test

