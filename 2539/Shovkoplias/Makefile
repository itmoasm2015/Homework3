all: libhw.o
	ar rcs libhw.a libhw.o

test: test.o all
	g++ -g -o test test.o libhw.o


libhw.o: bigint.asm
	yasm bigint.asm -f elf64 -g dwarf2 -o libhw.o

clean:
	rm *.o
	rm ./test
	rm *.a
