
all: view rtc_setdate

rtc_setdate: rtc_setdate.s
	vasmz80_oldstyle -z80asm -Fbin -o rtc_setdate.bin rtc_setdate.s

view: view.s
	vasmz80_oldstyle -z80asm -Fbin -o view.bin view.s

