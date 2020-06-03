AVRPROG = usbtiny
AVRCHIP = atmega328p

FLAGS = -DF_CPU=16000000UL -DWITH_UART=1

DEPS =
ifneq (,$(findstring -DWITH_UART=1,$(FLAGS)))
	DEPS += uart.o
endif
ifneq (,$(findstring -DWITH_LCD=1,$(FLAGS)))
	DEPS += lcd.o
endif

all: booster.hex

booster.elf: booster.o $(DEPS)
	avr-gcc -mmcu=atmega328p -Wl,-u,vfprintf -lprintf_flt -lm -o $@ $^

.elf.hex:
	avr-objcopy -O ihex -R .eeprom $< $@

.SUFFIXES: .hex .elf

uart.o: uart.h
lcd.o: lcd.h
booster.o: uart.h lcd.h

.c.o:
	avr-gcc -Os $(FLAGS) -mmcu=atmega328p -o $@ -c $<

clean:
	-rm booster.hex booster.elf booster.o lcd.o uart.o

flash: booster.hex
	avrdude -c $(AVRPROG) -p $(AVRCHIP) -U flash:w:$<

.PHONY: all clean flash
