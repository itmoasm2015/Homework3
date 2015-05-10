CC=g++
TARGET=test
OBJECTS=test.cpp bigint_impl.o
CXXFLAGS=-Wall -Wextra -g3 -std=c++1y -I../../include/ -fsanitize=address
DEPS=../../include/bigint.h
LDFLAGS=-lgmpxx -lgmp

$(TARGET): $(OBJECTS)   
	$(CC) $(CXXFLAGS) $^ $(LDFLAGS) -o $@

bigint_impl.o: bigint_impl.asm
	rm -f $(TARGET)
	yasm -f elf64 -g dwarf2 $^ -o $@

clean:
	rm -f $(TARGET)
	rm -f *.o

