# Make file for the kernel

ASM=vasmz80_oldstyle
LINK=vlink
CC=vbcc

AFLAGS=-z80asm -Fvobj -unsshift
# output rawbinary
LFLAGS=-b rawbin1 -T kernel.ld -M

# define the C source files
SRCS := $(wildcard *.s)

# define the C object files 
OBJS := $(SRCS:.s=.o)

all: kernel

kernel: $(OBJS)
	$(LINK) $(LFLAGS) -o $@.bin $^
	split -b 8192 $@.bin $@\-

%.o: %.s consts.inc
	$(ASM) $(AFLAGS) -o $@ $<

upload: kernel
	minipro -p at28c64b -P -w kernel.bin

upload1: kernel
	minipro -p at28c64b -P -w kernel-aa

upload2: kernel
	minipro -p at28c64b -P -w kernel-ab

.PHONY: clean

clean:
	rm -f $(OBJS) *.bin
