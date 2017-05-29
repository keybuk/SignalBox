AVRPROG = usbtiny
AVRCHIP = atmega328p


all: powerstation.hex

powerstation.elf: powerstation.o lcd.o uart.o
	avr-gcc -mmcu=atmega328p -Wl,-u,vfprintf -lprintf_flt -lm -o $@ $^

.elf.hex:
	avr-objcopy -O ihex -R .eeprom $< $@

.SUFFIXES: .hex .elf

uart.o: uart.h
lcd.o: lcd.h
powerstation.o: uart.h lcd.h

.c.o:
	avr-gcc -Os -DF_CPU=16000000UL -mmcu=atmega328p -o $@ -c $<

clean:
	-rm powerstation.hex powerstation.elf powerstation.o lcd.o uart.o

flash: powerstation.hex
	avrdude -c $(AVRPROG) -p $(AVRCHIP) -U flash:w:$<

.PHONY: all clean flash
