CC=sdcc
LINK=sdcc
CFLAGS=-mz80 --no-std-crt0 --nostdinc --nostdlib -c
LFLAGS=-mz80 --no-std-crt0 --nostdinc --nostdlib --code-loc 0x4000 

.PHONY: clean

all: view rtc_setdate hello hangman

rtc_setdate: rtc_setdate.s
	vasmz80_oldstyle -z80asm -Fbin -o rtc_setdate.bin rtc_setdate.s

view: view.s
	vasmz80_oldstyle -z80asm -Fbin -o view.bin view.s

hello: out/hello.rel out/sea80.rel
	$(LINK) $(LFLAGS) -o $@.ihx $^
	sdobjcopy -I ihex $@.ihx -O binary $@.com

hangman: out/hangman.rel out/sea80.rel
	$(LINK) $(LFLAGS) -o $@.ihx $^
	sdobjcopy -I ihex $@.ihx -O binary $@.com

out/%.rel: %.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f *.asm *.lk *.map *.mem *.rst *.lst *.rel *.noi *.ihx *.sym *.bin *.com out/*
