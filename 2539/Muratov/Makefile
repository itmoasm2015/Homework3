makeall: clean test
#makeall: clean libhw.a

test: test.o libhw.a
	g++ -Wall -msse -g -o $@ $^ 
	./test

test.o:
	g++ test.cpp -Wall -g -c -o $@

libhw.a: bigint.o
	ar rcs $@ $^

bigint.o: 
	yasm -felf64 -gdwarf2 bigint.asm -o $@

clean:
	rm -f test
	rm -f test.o
	rm -f libhw.a
	rm -f bigint.o

