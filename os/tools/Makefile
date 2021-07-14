CC=sdcc
LINK=sdcc
CFLAGS=-mz80 --no-std-crt0 -c 
# --nostdinc --nostdlib
LFLAGS=-mz80 --no-std-crt0 --code-loc 0x4000
# --nostdinc --nostdlib

hello_RELS=hello.rel sea80.rel
hello_OBJS=$(addprefix obj/,$(hello_RELS))

hangman_RELS=hangman.rel sea80.rel
hangman_OBJS=$(addprefix obj/,$(hangman_RELS))

tables_RELS=tables.rel sea80.rel
tables_OBJS=$(addprefix obj/,$(tables_RELS))

.PHONY: clean

all: view setdate hello hangman tables

setdate: rtc_setdate.s
	vasmz80_oldstyle -z80asm -Fbin -o setdate.com rtc_setdate.s

view: view.s
	vasmz80_oldstyle -z80asm -Fbin -o view.com view.s

hello: $(hello_OBJS)
	$(LINK) $(LFLAGS) -o obj/$@.ihx $^
	sdobjcopy -I ihex obj/$@.ihx -O binary $@.com

tables: $(tables_OBJS)
	$(LINK) $(LFLAGS) -o obj/$@.ihx $^
	sdobjcopy -I ihex obj/$@.ihx -O binary $@.com

hangman: $(hangman_OBJS)
	$(LINK) $(LFLAGS) -o obj/$@.ihx $^
	sdobjcopy -I ihex obj/$@.ihx -O binary $@.com

obj/%.rel: %.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f *.asm *.lk *.map *.mem *.rst *.lst *.rel *.noi *.ihx *.sym *.bin *.com obj/*
