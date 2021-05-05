
all: kernel

kernel: kernel.s
	vasm -z80asm -Fbin -o kernel.bin kernel.s
upload: monitor
	minipro -p at28c64b -P -w kernel.bin
