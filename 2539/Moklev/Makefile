all: test

test: test.c bigint.o lalka.o
	gcc -g test.c bigint.o lalka.o -std=c11 -o test

bigint.o: bigint.asm
	yasm bigint.asm -felf64 -gdwarf2 -o bigint.o

lalka.o: lalka.asm
	yasm lalka.asm -felf64 -gdwarf2 -o lalka.o

run: all
	./test

memtest: all
	valgrind --vgdb=full --leak-check=full ./test

clean:
	rm test
	rm bigint.o
