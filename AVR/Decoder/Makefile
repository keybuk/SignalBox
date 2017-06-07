AVRPROG = usbtiny
AVRCHIP = atmega328p

FLAGS = -DF_CPU=16000000UL

all: decoder.hex


decoder.elf: decoder.o uart.o
	avr-gcc -mmcu=atmega328p -Wl,-u,vfprintf -lprintf_flt -lm -o $@ $^

.elf.hex:
	avr-objcopy -O ihex -R .eeprom $< $@

.SUFFIXES: .hex .elf

decoder.o: uart.h
uart.o: uart.h

.c.o:
	avr-gcc -Os $(FLAGS) -mmcu=atmega328p -o $@ -c $<

clean:
	-rm decoder.hex decoder.elf decoder.o uart.o

flash: decoder.hex
	avrdude -c $(AVRPROG) -p $(AVRCHIP) -U flash:w:$<

.PHONY: all clean flash
