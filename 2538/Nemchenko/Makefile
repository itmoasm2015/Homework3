CC=g++
TARGET=main
OBJECTS=bigint_impl.o main.o
CXXFLAGS=-Wall -Wextra -g -std=c++1y -I../../include/
DEPS=../../include/bigint.h

$(TARGET): $(OBJECTS)
	$(CC) $(CXXFLAGS) $^ -o $@

bigint_impl.o: bigint_impl.asm
	yasm -f elf64 -g dwarf2 $^ -o $@

main.o: main.cpp $(DEPS)
	$(CC) $(CXXFLAGS) -c $< -o $@ 

clean:
	rm -f $(TARGET)
	rm -f *.o

