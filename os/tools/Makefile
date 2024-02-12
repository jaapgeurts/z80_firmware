CC=sdcc
LINK=sdcc
CFLAGS=-mz80 --no-std-crt0 -c
# --nostdinc --nostdlib
LFLAGS=-mz80 --no-std-crt0 --code-loc 0x4000
# --nostdinc --nostdlib

CPROGS = hello.com hangman.com tables.com woorden.com blink.com song.com
APROGS = view.com setdate.com

.PHONY: clean

all: $(CPROGS) $(APROGS)

.SECONDEXPANSION:

$(APROGS): $$(patsubst %.com,%.s,$$@)
	vasmz80_oldstyle -z80asm -Fbin -o $@ $^

$(CPROGS): $$(patsubst %.com,obj/%.rel,$$@) obj/sea80.rel
	$(LINK) $(LFLAGS) -o obj/$@.ihx $^
	sdobjcopy -I ihex obj/$@.ihx -O binary $@

obj/%.rel: %.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f *.asm *.lk *.map *.mem *.rst *.lst *.rel *.noi *.ihx *.sym *.bin *.com obj/*

#setdate: rtc_setdate.s
#	vasmz80_oldstyle -z80asm -Fbin -o setdate.com rtc_setdate.s

#view: view.s
#	vasmz80_oldstyle -z80asm -Fbin -o view.com view.s
#
# hello: $(hello_OBJS)
# 	$(LINK) $(LFLAGS) -o obj/$@.ihx $^
# 	sdobjcopy -I ihex obj/$@.ihx -O binary $@.com
#
# blink: $(blink_OBJS)
# 	$(LINK) $(LFLAGS) -o obj/$@.ihx $^
# 	sdobjcopy -I ihex obj/$@.ihx -O binary $@.com
#
# tables: $(tables_OBJS)
# 	$(LINK) $(LFLAGS) -o obj/$@.ihx $^
# 	sdobjcopy -I ihex obj/$@.ihx -O binary $@.com
#
# hangman: $(hangman_OBJS)
# 	$(LINK) $(LFLAGS) -o obj/$@.ihx $^
# 	sdobjcopy -I ihex obj/$@.ihx -O binary $@.com
#
# woorden: $(woorden_OBJS)
# 	$(LINK) $(LFLAGS) -o obj/$@.ihx $^
# 	sdobjcopy -I ihex obj/$@.ihx -O binary $@.com



# mkdosfs -F 16 -s 1 -n SEA80 /dev/sda1 -v
