#include <avr/io.h>
#include <avr/interrupt.h>

#include <util/delay.h>

#include <stdio.h>
#include <string.h>

#if WITH_UART
#include "uart.h"
#endif


volatile unsigned long timer0_ovf_count;

// TIMER0 Overflow Interrupt.
//
// Keep count of overflows so that we can calculate deltas larger than
// 1.02ms.
ISR(TIMER0_OVF_vect)
{
	++timer0_ovf_count;
}

#define BMAX 8192

volatile unsigned long last_micros, last_delta;
volatile int last_bit = -1, phase = -1, bpos, invalid;
volatile uint8_t buffer[1024];

// INT0 Interrupt.
// Fires when the input signal on INT0 (D2) changes.
//
// Tracks the deltas between changes, to determine whether we just saw a valid
// 0-bit or 1-bit and pushes the value into the bit buffer for the main loop
// to process.
ISR(INT0_vect)
{
	unsigned long ovf, micros, delta;
	uint8_t tcnt;

	ovf = timer0_ovf_count;
	tcnt = TCNT0;

	// Check if the timer has overflowed without ticking.
	if ((TIFR0 & _BV(TOV0)) && (tcnt != 0xff))
		++ovf;

	micros = (ovf << 10) | (tcnt << 2);
	delta = micros - last_micros;
	last_micros = micros;

	// The specification says to allow 52-64µs for a one-bit, and 90-10,000µs
	// for a zero; since our timer resolution is only 4µs we allow +/- that
	// on top.
	int bit;
	if (delta >= 48 && delta <= 68) {
		bit = 1;
	} else if (delta >= 84 && delta <= 10004) {
		bit = 0;
	} else {
		// An invalid bit means we bail out and reset the state.
		invalid |= 1;
		last_bit = -1;
		phase = -1;
		return;
	}

	switch (phase) {
	case -1:
		// Initial phase requires that we see a transition between one and zero
		// before we can start processing bits.
		if (last_bit != -1 && last_bit != bit) {
			phase = 0;
		} else {
			last_bit = bit;
			break;
		}
		// Possibly fall-through from above.
	case 0:
		// Save the bit, delta, and move to the next phase in the next cycle.
		last_bit = bit;
		last_delta = delta;
		phase = 1;
		return;
	case 1:
		// Bits must match, otherwise we bail.
		if (last_bit != bit) {
			invalid |= 2;
			last_bit = -1;
			phase = -1;
			return;
		}

		// Double-check the delta of 1s, and treat as an invalid bit if we go out of spec.
		if (bit) {
			unsigned long diff = last_delta > delta ? last_delta - delta : delta - last_delta;
			if (diff > 8) {
				invalid |= 4;
				last_bit = -1;
				phase = -1;
				return;
			}
		}

		// Always move back to phase 0 if the bit was valid.
		// We don't need last_bit or last_delta in phase 0.
		phase = 0;
		break;
	}

	// Bit is valid at this point.
	if (bit) {
		buffer[bpos / 8] |= _BV(bpos % 8);
	} else {
		buffer[bpos / 8] &= ~_BV(bpos % 8);
	}

	bpos++;
	bpos %= BMAX;
}


#define SEEKING_PREAMBLE 0
#define PREAMBLE 1
#define PACKET 2

int main()
{
	cli();

	// To analyze the DCC signal we need a timer on which we can count,
	// with reasonable precision, microseconds. Set up TIMER0 for 4µs
	// ticks (64 prescale) which is reasonable enough.
	TCCR0A = _BV(WGM01) | _BV(WGM00);
	TCCR0B = _BV(CS01) | _BV(CS00);
	TIMSK0 = _BV(TOIE0);

	// Configure B5 for output, and set.
	DDRB |= _BV(DDB5);
	PORTB |= _BV(PORTB5);

	// Configure D2 (INT0) for input, disable the pull-up.
	DDRD &= ~_BV(DDD2);
	PORTD &= ~_BV(PORTD2);

	// Configure INT0 to generate an interrupt for any logical change.
	EICRA |= _BV(ISC00);
	EIMSK |= _BV(INT0);

	sei();

#if WITH_UART
	uart_init(UART_BAUD_SELECT(9600, F_CPU));
	uart_puts("Running\r\n");
#endif

	int bstart = 0, state = SEEKING_PREAMBLE, preamble_bits = 0, b = 0;
	uint8_t byte;
	for (;;) {
		uint8_t _SREG = SREG;
		int btop, is_invalid;

		// We only guard access to btop, and otherwise use the ring buffer
		// with interrupts still running. It takes over 0.8s to fill, so this
		// should be safe as long as the uint8_t access is atomic over the bit
		// set/clear.
		cli();
		btop = bpos;
		is_invalid = invalid;
		invalid = 0;
		SREG = _SREG;

		if (is_invalid) {
			char line[80];
			sprintf(line, "Invalid %x\r\n", is_invalid);
			uart_puts(line);
			_delay_ms(5000);
			continue;
		}

		for (int i = bstart; i != btop; i = (i + 1) % BMAX) {
			int bit = buffer[i / 8] & _BV(i % 8);

			switch (state) {
			case SEEKING_PREAMBLE:
				if (bit) {
					++preamble_bits;
				} else if (preamble_bits >= 10) {
					// End of preamble found.
					state = PACKET;

					char line[80];
					sprintf(line, "Preamble of %d bits\r\n", preamble_bits);
					uart_puts(line);
				} else {
					preamble_bits = 0;
				}
				break;
			case PREAMBLE:
				if (!bit) {
					state = PACKET;
					uart_puts("\r\n");
				}
				break;	
			case PACKET:
				if (b < 8) {
					if (bit) {
						byte |= _BV(7 - b);
					} else {
						byte &= ~_BV(7 - b);
					}
					++b;
				} else {
					// byte contains a valid byte.
					char line[80];
					for (int j = 0; j < 8; ++j)
						line[j] = byte & _BV(7 - j) ? '1' : '0';
					line[8] = ' ';
					line[9] = '\0';
					uart_puts(line);

					b = 0;
					if (bit)
						state = PREAMBLE;
				}
				break;
			}

		}

		bstart = btop;
	}
}