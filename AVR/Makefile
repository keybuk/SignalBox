AVRPROG = usbtiny
AVRPORT =
AVRCHIP = atmega328p

CC      = avr-gcc
OBJCOPY = avr-objcopy
AVRDUDE = avrdude

CFLAGS  = -mmcu=$(AVRCHIP) -Wall -Wno-maybe-uninitialized
LDFLAGS = -mmcu=$(AVRCHIP)
DEFINES = -DF_CPU=16000000UL
LIBS    = -Wl,-u,vfprintf -lprintf_flt -lm

ifeq ($(strip $(DEBUG)),0)
CFLAGS  += -Os
else
CFLAGS  += -Og -g
DEFINES += -DDEBUG=1
endif

AVRDUDEFLAGS = -p $(AVRCHIP)
ifneq ($(strip $(AVRPROG)),)
AVRDUDEFLAGS += -c $(AVRPROG)
endif
ifneq ($(strip $(AVRPORT)),)
AVRDUDEFLAGS += -P $(AVRPORT)
endif


all: booster.hex

booster.elf: main.o uart.o
	$(CC) $(LDFLAGS) $(LIBS) -o $@ $^


.c.o:
	$(CC) $(CFLAGS) $(DEFINES) -o $@ -c $<

.elf.hex:
	$(OBJCOPY) -O ihex -R .eeprom $< $@

.SUFFIXES: .hex .elf


clean:
	-rm *.hex *.elf *.o

flash_%: %.hex
	$(AVRDUDE) $(AVRDUDEFLAGS) -U flash:w:$<

.PHONY: all clean
