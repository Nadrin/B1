# B1 ROM makefile

CA65 ?= ca65
LD65 ?= ld65

.PHONY: clean

rom.bin: font.o bios.o jmon.o demo.o basic.o
	$(LD65) -vm -m rom.map -C layout.cfg -o $@ $^

font.o: font/font.s
	$(CA65) font/font.s -o font.o

bios.o: bios/bios.s bios/isr.s
	$(CA65) bios/bios.s -o bios.o

jmon.o: jmon/jmon.s jmon/disasm.s jmon/miniasm.s jmon/trace.s jmon/info.s jmon/memtest4.s jmon/sound.s
	$(CA65) jmon/jmon.s -o jmon.o

demo.o: demo/demo.s
	$(CA65) demo/demo.s -o demo.o

basic.o: basic/basic.s
	$(CA65) --feature labels_without_colons -o basic.o basic/basic.s

clean:
	$(RM) *.o *.bin *.map
