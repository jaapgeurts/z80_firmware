CC=sdcc
LINK=sdcc
CFLAGS=-mz80 --no-std-crt0 -c
# --nostdinc --nostdlib
LFLAGS=-mz80 --no-std-crt0  --code-loc 0x4000 
# --nostdinc --nostdlib

.PHONY: clean

all: view setdate hello hangman tables

setdate: rtc_setdate.s
	vasmz80_oldstyle -z80asm -Fbin -o setdate.com rtc_setdate.s

view: view.s
	vasmz80_oldstyle -z80asm -Fbin -o view.com view.s

hello: out/hello.rel out/sea80.rel
	$(LINK) $(LFLAGS) -o $@.ihx $^
	sdobjcopy -I ihex $@.ihx -O binary $@.com

tables: out/tables.rel out/sea80.rel
	$(LINK) $(LFLAGS) -o $@.ihx $^
	sdobjcopy -I ihex $@.ihx -O binary $@.com

hangman: out/hangman.rel out/sea80.rel
	$(LINK) $(LFLAGS) -o $@.ihx $^
	sdobjcopy -I ihex $@.ihx -O binary $@.com

out/%.rel: %.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f *.asm *.lk *.map *.mem *.rst *.lst *.rel *.noi *.ihx *.sym *.bin *.com out/*
