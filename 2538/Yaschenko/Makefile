ASM = yasm
ASFLAGS = -f elf64

CFLAGS = -Wall -I./include -L. -std=c++11

all: libhw.a main tests

# Debug flags
debug: CFLAGS += -g
debug: ASFLAGS += -g dwarf2
debug: all

# Targets
main: main.cpp libhw.a
	$(CC) $(CFLAGS) $^ -o $@ -lhw -lstdc++

tests: gtest-all.o gtest_main.o libmyvec.o libhw.o tests.o
	$(CC) $^ -o $@ $(CFLAGS) -lstdc++ -lpthread

# Explicit rule to include vector
libhw.a: libhw.o libmyvec.o
	ar rcs $@ $^

# Clean up
.PHONY: clean clean_obj clean_lib

clean: clean_obj clean_lib
	rm -f tests
	rm -f main

clean_obj:
	rm -f *.o

clean_lib:
	rm -f *.a

# Recipes
%.o: %.cc
	$(CC) $(CFLAGS) -c $^ -o $@

%.o: %.cpp
	$(CC) $(CFLAGS) -c $^ -o $@

%.a: %.o
	ar rcs $@ $^

%.o: %.asm
	$(ASM) $(ASFLAGS) -o $@ $^
