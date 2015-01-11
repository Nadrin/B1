.PHONY: clean

rom.bin: font.o bios.o jmon.o demo.o basic.o
	ld65 -vm -m rom.map -C layout.cfg -o rom.bin font.o bios.o jmon.o demo.o basic.o

font.o: font/font.s
	ca65 font/font.s -o font.o

bios.o: bios/bios.s bios/isr.s
	ca65 bios/bios.s -o bios.o

jmon.o:	jmon/jmon.s jmon/disasm.s jmon/miniasm.s jmon/trace.s jmon/info.s jmon/memtest4.s jmon/sound.s
	ca65 jmon/jmon.s -o jmon.o

demo.o: demo/demo.s
	ca65 demo/demo.s -o demo.o

basic.o: basic/basic.s
	ca65 --feature labels_without_colons -o basic.o basic/basic.s

clean:
	$(RM) *.o *.bin *.map
