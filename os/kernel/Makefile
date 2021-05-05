
all: monitor

monitor: rom_monitor.s
	vasm -z80asm -Fbin -o rom_monitor.bin rom_monitor.s
upload: monitor
	minipro -p at28c64b -P -w rom_monitor.bin
