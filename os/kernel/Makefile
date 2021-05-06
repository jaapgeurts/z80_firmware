# Make file for the kernel

ASM=vasmz80_oldstyle
LINK=vlink
CC=vbcc

AFLAGS=-z80asm -Fvobj
# output rawbinary
LFLAGS=-b rawbin1 -T kernel.ld

# define the C source files
SRCS := $(wildcard *.s)

# define the C object files 
OBJS := $(SRCS:.s=.o)

all: kernel

kernel: $(OBJS)
	$(LINK) $(LFLAGS) -o $@.bin $^

%.o: %.s
	$(ASM) $(AFLAGS) -o $@ $<

upload: kernel
	minipro -p at28c64b -P -w kernel.bin

.PHONY: clean

clean:
	rm -f $(OBJS) *.bin
