AVRPROG = usbtiny
AVRCHIP = atmega328p

FLAGS = -DF_CPU=16000000UL -DWITH_UART=1

all: detector.hex

DEPS =
HEADERS =
ifneq (,$(findstring -DWITH_UART=1,$(FLAGS)))
DEPS += uart.o
HEADERS += uart.h

uart.o: uart.h
endif
ifneq (,$(findstring -DWITH_LCD=1,$(FLAGS)))
DEPS += lcd.o
HEADERS += lcd.h

lcd.o: lcd.h
endif


detector.elf: detector.o $(DEPS)
	avr-gcc -mmcu=atmega328p -Wl,-u,vfprintf -lprintf_flt -lm -o $@ $^

.elf.hex:
	avr-objcopy -O ihex -R .eeprom $< $@

.SUFFIXES: .hex .elf

detector.o: $(HEADERS)

.c.o:
	avr-gcc -Os $(FLAGS) -mmcu=atmega328p -o $@ -c $<

clean:
	-rm detector.hex detector.elf detector.o lcd.o uart.o

flash: detector.hex
	avrdude -c $(AVRPROG) -p $(AVRCHIP) -U flash:w:$<

.PHONY: all clean flash
