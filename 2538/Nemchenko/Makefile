CC=g++
TARGET=libhw.a
OBJECTS=bigint_impl.o
CXXFLAGS=-Wall -Wextra -g3 -std=c++1y -I../../include/
DEPS=../../include/bigint.h

$(TARGET): $(OBJECTS)  
	ar rcs $@ $<

bigint_impl.o: bigint_impl.asm
	rm -f $(TARGET)
	yasm -f elf64 -g dwarf2 $^ -o $@

clean:
	rm -f $(TARGET)
	rm -f *.o

