AVRPROG = usbtiny
AVRCHIP = atmega328p


all: test1.hex

test1.elf: test1.o uart.o
	avr-gcc -mmcu=atmega328p -Wl,-u,vfprintf -lprintf_flt -lm -o $@ $^

.elf.hex:
	avr-objcopy -O ihex -R .eeprom $< $@

.SUFFIXES: .hex .elf

.c.o:
	avr-gcc -Os -DF_CPU=16000000UL -mmcu=atmega328p -o $@ -c $<

clean:
	-rm test1.hex test1.elf test1.o uart.o

flash: test1.hex
	avrdude -c $(AVRPROG) -p $(AVRCHIP) -U flash:w:$<

.PHONY: all clean flash
