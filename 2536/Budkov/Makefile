all: libhw.a

libhw.a: libhw.o
	ar rcs libhw.a libhw.o

libhw.o: bigint_homework.asm
	yasm -o libhw.o -f elf64 bigint_homework.asm

clean:
	rm -rf *.o
	rm -rf libhw.a
