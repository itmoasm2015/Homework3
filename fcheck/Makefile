CXXFLAGS= -g -std=c++11

all: libhwwrapped.a

.PHONY: ../$(STUDENT_DIR)/libhw.a

../$(STUDENT_DIR)/libhw.a:
	cd ../$(STUDENT_DIR); make

HW_TARGET=../$(STUDENT_DIR)/libhw.a
TARGET=libhw.a
WRAPPER=stack-wrapper.o

libhw.a: $(HW_TARGET)
	objcopy --prefix-symbols hw_ $< $@

libhwwrapped.a: regchk.o $(WRAPPER) libhw.a
	mkdir -p temp; cd temp; rm -rf *; ar -x ../libhw.a
	ar rcs $@ regchk.o $(WRAPPER) temp/*.o


%.o: %.asm
	yasm -f elf64 -g dwarf2 -o $@ $^
