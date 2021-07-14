CC=sdcc
LINK=sdcc
CFLAGS=-mz80 --no-std-crt0 -c
# --nostdinc --nostdlib
LFLAGS=-mz80 --no-std-crt0 --code-loc 0x4000 
# --nostdinc --nostdlib

.PHONY: clean

all: view setdate hello hangman tables

setdate: rtc_setdate.s
	vasmz80_oldstyle -z80asm -Fbin -o setdate.com rtc_setdate.s

view: view.s
	vasmz80_oldstyle -z80asm -Fbin -o view.com view.s

hello: hello.rel sea80.rel
	$(LINK) $(LFLAGS) -o obj $@.ihx $^
	sdobjcopy -I ihex obj/$@.ihx -O binary $@.com

tables: tables.rel sea80.rel
	$(LINK) $(LFLAGS) -o $@.ihx $^
	sdobjcopy -I ihex obj/$@.ihx -O binary $@.com

hangman: hangman.rel sea80.rel
	$(LINK) $(LFLAGS) -o $@.ihx $^
	sdobjcopy -I ihex obj/$@.ihx -O binary $@.com

%.rel: %.c
	$(CC) $(CFLAGS) -o obj/ $@ $<

clean:
	rm -f *.asm *.lk *.map *.mem *.rst *.lst *.rel *.noi *.ihx *.sym *.bin *.com out/*
