AVRPROG = usbtiny
AVRCHIP = atmega328p

CC = avr-gcc
OBJCOPY = avr-objcopy

CFLAGS = -Os -mmcu=$(AVRCHIP) -Wall -Wno-maybe-uninitialized
LDFLAGS = -mmcu=$(AVRCHIP)
DEFINES = -DF_CPU=16000000UL
LIBS = -Wl,-u,vfprintf -lprintf_flt -lm

all: booster.hex detector.hex


main_booster.o: main.c
	$(CC) $(CFLAGS) $(DEFINES) -DBOOSTER -o $@ -c $<

main_detector.o: main.c
	$(CC) $(CFLAGS) $(DEFINES) -DDETECTOR -o $@ -c $<

.c.o:
	$(CC) $(CFLAGS) $(DEFINES) -o $@ -c $<


booster.elf: main_booster.o
	$(CC) $(LDFLAGS) $(LIBS) -o $@ $^

detector.elf: main_detector.o
	$(CC) $(LDFLAGS) $(LIBS) -o $@ $^


.elf.hex:
	$(OBJCOPY) -O ihex -R .eeprom $< $@

.SUFFIXES: .hex .elf


clean:
	-rm booster.hex booster.elf main_booster.o
	-rm detector.hex detector.elf main_detector.o

flash_booster: booster.hex
	avrdude -c $(AVRPROG) -p $(AVRCHIP) -U flash:w:$<

flash_detector: detector.hex
	avrdude -c $(AVRPROG) -p $(AVRCHIP) -U flash:w:$<

.PHONY: all clean flash_booster flash_detector
