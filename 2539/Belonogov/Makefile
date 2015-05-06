CC=g++
TARGET=test
OBJECTS=libhw.o test.o
CXXFLAGS=-Wall -Wextra -lgmpxx -lgmp -g -std=c++1y -I../../include/ 
DEPS=../../include/bigint.h

$(TARGET): $(OBJECTS)
	$(CC) $(CXXFLAGS) $^ -o $@ -lgmpxx -lgmp 

libhw.o: libhw.asm
	rm -f $(TARGET)
	yasm -f elf64 -g dwarf2 $^ -o $@ 

test.o: test.cpp $(DEPS)
	rm -f $(TARGET)
	$(CC) $(CXXFLAGS) -c $< -o $@ 

clean:
	rm -f $(TARGET)
	rm -f *.o
