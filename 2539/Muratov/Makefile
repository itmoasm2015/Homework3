#makeall: clean test
makeall: clean libhw.a

test: test.o libhw.a
	g++ -Wall -msse -g -o $@ $^ 
	./test

test.o:
	g++ -o test.o -O2 -std=c++11 -g -c test.cpp 

libhw.a: bigint.o
	ar rcs $@ $^

bigint.o: 
	yasm -felf64 -gdwarf2 bigint.asm -o $@

clean:
	rm -f test
	rm -f test.o
	rm -f libhw.a
	rm -f bigint.o

