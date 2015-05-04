CC=g++
TARGET=main
OBJECTS=bigint_impl.o main.o
CXXFLAGS=-Wall -Wextra -g3 -std=c++1y -I../../include/
DEPS=../../include/bigint.h

$(TARGET): $(OBJECTS)
	$(CC) $(CXXFLAGS) $^ -o $@

bigint_impl.o: bigint_impl.asm
	rm -f $(TARGET)
	yasm -f elf64 -g dwarf2 $^ -o $@

main.o: main.cpp $(DEPS)
	rm -f $(TARGET)
	$(CC) $(CXXFLAGS) -c $< -o $@ 

clean:
	rm -f $(TARGET)
	rm -f *.o

