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

memtest: all
	valgrind --vgdb=full --leak-check=full ./test

clean:
	rm test
	rm stack_test
	rm bigint.o
	rm libhw.a
	rm libhwwrapped.a
