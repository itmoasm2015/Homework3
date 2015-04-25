ASM = yasm
ASFLAGS = -f elf64

CFLAGS = -Wall -I./include -L.

all: libhw.a main test_vector

# Debug flags
debug: CFLAGS += -g
debug: ASFLAGS += -g dwarf2
debug: all

# Targets
main: main.cpp libhw.a
	$(CC) $(CFLAGS) $^ -o $@ -lhw -lstdc++

test_vector: gtest-all.o gtest_main.o libmyvec.o test_vector.o
	$(CC) $^ -o $@ $(CFLAGS) -lstdc++ -lpthread

# Explicit rule to include vector
libhw.a: libhw.o libmyvec.o
	ar rcs $@ $^

# Clean up
.PHONY: clean clean_obj clean_lib

clean: clean_obj clean_lib
	rm -f test_vector
	rm -f main

clean_obj:
	rm -f *.o

clean_lib:
	rm -f *.a

# Recipes
%.o: %.cc
	$(CC) $(CFLAGS) -c $^ -o $@ -std=c++11

%.o: %.cpp
	$(CC) $(CFLAGS) -c $^ -o $@

%.a: %.o
	ar rcs $@ $^

%.o: %.asm
	$(ASM) $(ASFLAGS) -o $@ $^
