CXX_FLAGS = -std=c11 -g -L. -I.

all: libhw.a

libhw.a: bigint.o
	ar rcs libhw.a bigint.o 

test: test.c libhw.a
	gcc -g test.c libhw.a -std=c11 -o test

stack_test: test.c libhwwrapped.a
	gcc -g test.c libhwwrapped.a -std=c11 -o stack_test

bigint.o: bigint.asm
	yasm bigint.asm -felf64 -gdwarf2 -o bigint.o

wrap:
	./wrap.sh

stack: wrap stack_test
	./stack_test

run: test
	./test

memtest: all test
	valgrind --vgdb=full --leak-check=full ./test

lite: wrap testlite.c
	gcc -o lite $(CXX_FLAGS) testlite.c -lhwwrapped

clean:
	rm -f test
	rm -f stack_test
	rm -f bigint.o
	rm -f libhw.a
	rm -f libhwwrapped.a
