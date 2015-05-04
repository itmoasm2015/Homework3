ASRC:=$(wildcard *.asm)
CSRC:=$(wildcard *.c)
CXXSRC:=$(wildcard *.cpp)

AOBJ:=$(ASRC:%.asm=obja/%.o)
COBJ:=$(CSRC:%.c=objc/%.o)
CXXOBJ:=$(CXXSRC:%.cpp=objcxx/%.o)

OS:=$(shell uname)


ifeq ($(OS), Darwin)
YASM_FLAGS=-f macho64
AOBJ+=obja/osx-wrapper.o
else
YASM_FLAGS=-f elf64 -g dwarf2
endif

.PHONY: all clean
all: main libhw.a 

clean:
	-rm $(AOBJ) $(COBJ) $(CXXOBJ)  main libhw.a

objc objcxx obja:
	-mkdir $@


objc/%.o: %.c objc
	gcc -std=c11 -c -m64 -g -O0 -o $@ $<
objcxx/%.o: %.cpp objcxx
	g++ -std=c++11 -c -m64 -g -O0 -o $@ $<

obja/%.o: %.asm obja
	yasm $(YASM_FLAGS) -o $@ $<

libhw.a: $(AOBJ)
	ar rcs $@ $^

main:  $(COBJ) $(CXXOBJ) libhw.a
	g++ -O0 -g -m64 $^  -o $@
