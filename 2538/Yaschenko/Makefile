ASM = yasm
ASFLAGS = -f elf64

CFLAGS = -Wall -I./include -L.

all: test_vector


debug: CFLAGS += -g
debug: ASFLAGS += -g dwarf2
debug: test_vector

.PHONY: clean clean_obj clean_lib

clean: clean_obj clean_lib
	rm -f test_vector

clean_obj:
	rm -f *.o

clean_lib:
	rm -f *.a

test_vector: gtest-all.o gtest_main.o test_vector.o libmyvec.a
	$(CC) gtest-all.o gtest_main.o test_vector.o -o $@ $(CFLAGS) -lmyvec -lstdc++ -lpthread

%.o: %.cc
	$(CC) $(CFLAGS) -c $^ -o $@ -std=c++11

%.o: %.cpp
	$(CC) $(CFLAGS) -c $^ -o $@ 

%.a: %.o
	ar rcs $@ $^

%.o: %.asm
	$(ASM) $(ASFLAGS) -o $@ $^