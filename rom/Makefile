.PHONY: clean

rom.bin: font.o bios.o jmon.o
	ld65 -vm -m rom.map -C layout.cfg -o rom.bin font.o bios.o jmon.o

font.o: font/font.s
	ca65 font/font.s -o font.o

bios.o: bios/bios.s bios/isr.s
	ca65 bios/bios.s -o bios.o

jmon.o:	jmon/jmon.s jmon/disasm.s jmon/miniasm.s jmon/trace.s jmon/info.s jmon/memtest4.s jmon/sound.s
	ca65 jmon/jmon.s -o jmon.o

clean:
	$(RM) *.o *.bin *.map
