CC = gcc
ASM = yasm
AR = ar

CFLAGS = -Wall -Wextra -std=c99 -g -L. -I.
ASMFLAGS = -f elf64 -gdwarf2



RM = rm -f

LIB = libhw.a
TARGET = tests
C_SRS = tests.c
ASM_SRS = bigint.s
OBJ = bigint.o tests.o

all: $(TARGET)

clean:
	$(RM) $(TARGET) $(LIB) $(OBJ)

$(TARGET): $(LIB) tests.o
	$(CC) -o $@ $(CFLAGS) tests.o -lhw

tests.o: tests.c
	$(CC) -o $@ -c $(CFLAGS) $^

$(LIB): bigint.o
	$(AR) rcs $@ $<

bigint.o: bigint.s
	$(ASM) -o $@ $(ASMFLAGS) $^
