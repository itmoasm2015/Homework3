yasm -f elf64 -g dwarf2 -o bigint.o bigint.asm
g++ -std=c++11 -O2 -m64 -c test.cpp bigint.h
g++ -m64 -o test test.o bigint.o

rm bigint.o
rm test.o
./test
