
ASRC:= $(wildcard *.asm)
CSRC:=$(wildcard *.c)
CXXSRC:=$(wildcard *.cpp)

AOBJ:=$(ASRC:%.asm=obja/%.o)
COBJ:=$(CSRC:%.c=objc/%.o)
CXXOBJ:=$(CXXSRC:%.cpp=objcxx/%.o)

ifeq ($(OS),Windows_NT)
YASM_FLAGS=-f win64 -P win64.inl

else

OS:=$(shell uname)


ifeq ($(OS), Darwin)
YASM_FLAGS=-f macho64 # mac os
else
YASM_FLAGS=-f elf64 -g dwarf2 # linux
endif

YASM_FLAGS += -P sysv.inl
endif

.PHONY: all clean
all: libhw.a 

clean:
	-rm $(AOBJ) $(COBJ) $(CXXOBJ)  main libhw.a

objc objcxx obja:
	-mkdir $@


objc/%.o: %.c  | objc
	gcc -std=c11 -c -m64 -g  -o $@ $<
objcxx/%.o: %.cpp |  objcxx
	g++ -std=c++11 -c -m64 -g -o $@ $<

obja/%.o: %.asm  | obja
	yasm $(YASM_FLAGS) -o $@ $<

libhw.a: $(AOBJ)
	ar rcs $@ $^

main:  $(COBJ) $(CXXOBJ) $(AOBJ)
	g++ -g -m64 $^  -o $@
