ASM=vasmz80_oldstyle

all: testpio testpsg testkbd testkbdread testtft testtimer testgetarg testscroll testcf


testpio:
	$(ASM) -z80asm -Fbin -o testpio.bin testpio.s

testpsg:
	$(ASM) -z80asm -Fbin -o testpsg.bin testpsg.s

testkbd:
	$(ASM) -z80asm -Fbin -o testkbd.bin testkbd.s

testkbdread:
	$(ASM) -z80asm -Fbin -o testkbdread.bin testkbdread.s

testtft:
	$(ASM) -z80asm -Fbin -o testtft.bin testtft.s

testtimer:
	$(ASM) -z80asm -Fbin -o test_timer.bin test_timer.s

testgetarg:
	$(ASM) -z80asm -Fbin -o testgetarg.bin testgetarg.s

testscroll:
	$(ASM) -z80asm -Fbin -o testscroll.bin testscroll.s

testcf:
	$(ASM) -z80asm -Fbin -o testcf.bin testcf.s
