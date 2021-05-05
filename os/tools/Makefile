
all: monitor

monitor: rom_monitor.s
	vasm -z80asm -Fbin -o rom_monitor.bin rom_monitor.s
upload: monitor
	minipro -p at28c64b -P -w rom_monitor.bin

test:
	vasm -z80asm -Fbin -o test.bin test.s
	od -tx1 -An test.bin | tr [:lower:] [:upper:] > test.txt

rtc:
	vasm -z80asm -Fbin -o rtc.bin rtc.s

rtcsetdate:
	vasm -z80asm -Fbin -o rtc_setdate.bin rtc_setdate.s

testpio:
	vasm -z80asm -Fbin -o testpio.bin testpio.s

testpsg:
	vasm -z80asm -Fbin -o testpsg.bin testpsg.s

testkbd:
	vasm -z80asm -Fbin -o testkbd.bin testkbd.s

testkbdread:
	vasm -z80asm -Fbin -o testkbdread.bin testkbdread.s

testtft:
	vasm -z80asm -Fbin -o testtft.bin testtft.s

testtimer:
	vasm -z80asm -Fbin -o test_timer.bin test_timer.s

testgetarg:
	vasm -z80asm -Fbin -o testgetarg.bin testgetarg.s

view:
	vasm -z80asm -Fbin -o view.bin view.s

testcf:
	vasm -z80asm -Fbin -o testcf.bin testcf.s
