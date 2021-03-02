
all: monitor

monitor: rom_monitor.s
	vasm -z80asm -Fbin -o rom_monitor.bin rom_monitor.s
upload: rom_monitor.bin
	minipro -p at28c16@dip24 -w rom_monitor.bin

test:
	vasm -z80asm -Fbin -o test.bin test.s
	od -tx1 -An test.bin | tr [:lower:] [:upper:] > test.txt
