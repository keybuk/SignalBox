//
//  detector.c
//  SignalBox
//
//  Created by Scott James Remnant on 06/05/17.
//
//

#include <avr/interrupt.h>
#include <avr/io.h>

#include <stdio.h>
#include <string.h>

#include "uart.h"


// Input Signal Timing
// -------------------
// The DCC signal is a a series of high/low periods where the length of the
// high and low parts indicate whether it's a zero-bit or a one-bit. Either
// the high or low can come first, depending on the wiring:
//
//    __    __   _   _        __    __    _   _
// __|  |__|  |_| |_| |  or  |  |__|  |__| |_| |_  =>  0011
//
// We use a pair of interrupts to measure the time, in microseconds, between
// edges. TIMER0 counts the number of 4µs ticks in TCNT0, and the ISR counts
// the number of times it overflows; thus we can combine the two values to
// calculate the number of microseconds that have passed.
//
// INT0 is fired on the edges, and makes this calculation, comparing it to the
// previous edge time, and storing the result in `delta`. The `edge` flag is
// set on each new edge.

static inline void init() {
	// To analyze the DCC signal we need a timer on which we can count,
	// with reasonable precision, microseconds. Set up TIMER0 for 4µs
	// ticks (64 prescale) which is reasonable enough.
	TCCR0A = _BV(WGM01) | _BV(WGM00);
	TCCR0B = _BV(CS01) | _BV(CS00);
	TIMSK0 = _BV(TOIE0);

	// Configure D2 (INT0) for input, disable the pull-up.
	DDRD &= ~_BV(DDD2);
	PORTD &= ~_BV(PORTD2);

	// Configure INT0 to generate an interrupt for any logical change.
	EICRA |= _BV(ISC00);
	EIMSK |= _BV(INT0);
} 

volatile unsigned long timer0_ovf_count;

// TIMER0 Overflow Interrupt.
//
// Keep count of overflows, store in `timer0_ovf_count`.
ISR(TIMER0_OVF_vect)
{
	++timer0_ovf_count;
}

volatile unsigned long last_micros, delta;
volatile uint8_t edge;

// INT0 Interrupt.
// Fires when the input signal on INT0 (D2) changes.
//
// Tracks the deltas between edges using TIMER0.
ISR(INT0_vect)
{
	unsigned long ovf, micros;
	uint8_t tcnt;

	ovf = timer0_ovf_count;
	tcnt = TCNT0;

	// Check if the timer has overflowed without ticking.
	if ((TIFR0 & _BV(TOV0)) && (tcnt != 0xff))
		++ovf;

	micros = (ovf << 10) | (tcnt << 2);
	delta = micros - last_micros;
	edge = 1;
	last_micros = micros;
}


// Main Loop
// ---------
// There are three basic passes to analyzing the incoming DCC signal.
//
// The first is to determine the phase. When we start to receive incoming
// bits, we do not yet know where the boundary between each bits high and low
// part occurs; a stream of zero-bits or one-bits looks the same when you're
// in phase and out of phase. To synchronize we look for the point at which
// the period length changes:
//
//                   :
//   _   _   _   _    __    __   _   _ 
// _| |_| |_| |_| |__|  |__|  |_| |_| |
//                   :
//         length change means we
//         must be now in Phase A
//
// The second pass is packet and byte extraction. Initially that means locating
// a preamble, ignoring bits until we find a sequence of one-bits of the right
// length. Once found, the packet structure can then be followed logically and
// byte and packet boundaries followed provided the input conforms to
// specification.
//
//    ?    preamble.   byte     byte.    byte
//        +--------+ +------+ +------+ +------+
// 1101000111111111101010101001111000000101101011111...
//                  :        :        :        :
//                  +--byte end bits--+    packet end bit
//
// The third and final pass is taking the bytes within the packet and
// determining the DCC instructions contained within.

#define DELTA(_a, _b) ((_a) > (_b) ? (_a) - (_b) : (_b) - (_a))

#define UNKNOWN 0
#define A 1
#define B 2

#define SEEKING_PREAMBLE 0
#define PREAMBLE 1
#define PACKET 2

int main()
{
	cli();
	init();
	sei();

	uart_init(UART_BAUD_SELECT(115200, F_CPU));
	uart_puts("Running\r\n");

	unsigned long last_length = 0;
	int phase = UNKNOWN, last_bit = -1;
	int state, preamble_length, bit_num;
	uint8_t byte, check_byte;
	for (;;) {
		// Wait for an edge from the input ISR, and copy its length.
		unsigned long length;
		if (!edge) continue;

		cli();
		length = delta;
		edge = 0;
		sei();

		// The specification says to allow 52-64µs for a one-bit, and
		// 90-10,000µs for a zero-bit; since our timer resolution is only 4µs
		// we allow +/- that on top.
		int bit;
		if (length >= 48 && length <= 68) {
			bit = 1;
		} else if (length >= 84 && length <= 10004) {
			bit = 0;
		} else {
			// On an invalid bit length, attempt to resynchronize the phase.
			phase = UNKNOWN;
			last_bit = -1;
			goto next_edge;
		}

		// Each bit has two phases; we first need to train ourselves where
		// the phase-change occurs, and then consume the bit in each phase.
		switch (phase) {
		case UNKNOWN:
			// Wait for a transition between bit lengths before we start
			// processing bits.
			if (last_bit != -1 && last_bit != bit) {
				phase = A;

				state = SEEKING_PREAMBLE;
				preamble_length = 0;
			} else {
				last_bit = bit;
				goto next_edge;
			}
			// Possibly fall-through.
		case A:
			// Save the bit, length, and move to the next phase in next cycle.
			last_bit = bit;
			last_length = length;
			phase = B;
			goto next_edge;
		case B:
			// Bits must match between phases; if they don't, we've probably
			// gone out of phase, so resynchronize again.
			if (last_bit != bit) {
				phase = UNKNOWN;
				last_bit = -1;
				goto next_edge;
			}

			// Double-check the delta of one-bit phases, if we go out of spec,
			// treat it the same as if we had non-matching bits and
			// resynchronize the phase.
			if (bit && DELTA(length, last_length) > 8) {
				phase = UNKNOWN;
				last_bit = -1;
				goto next_edge;
			}

			// Back to phase A in next cycle, we won't need the last_bit or
			// last_length for that.
			phase = A;
			break;
		}

		// Once we reach here, `bit` contains a valid bit after both phases
		// have been seen. We can now locate the packet boundaries and perform
		// packet extraction.
		switch (state) {
		case SEEKING_PREAMBLE:
			// When we're looking for a preamble, we're looking for the first
			// stretch of at lest 10 one-bits.
			if (bit) {
				++preamble_length;
			} else if (preamble_length >= 10) {
				// End of preamble found.
				state = PACKET;
				bit_num = 0;
				check_byte = 0;
			} else {
				preamble_length = 0;
			}
			goto next_edge;
		case PREAMBLE:
			// In subsequent packets, we know where we are so we just handle
			// the preamble train as a check.
			if (!bit) {
				state = PACKET;
				bit_num = 0;
				check_byte = 0;
			}
			goto next_edge;
		case PACKET:
			// Within the packet there are eight bits to a byte, followed by
			// a zero-bit or a one-bit that determines whether more bytes
			// follow, or a preamble.
			if (bit_num < 8) {
				if (bit) {
					byte |= _BV(7 - bit_num);
				} else {
					byte &= ~_BV(7 - bit_num);
				}
				++bit_num;

				uart_putc(bit ? '1' : '0');
				goto next_edge;
			} else {
				if (bit)
					state = PREAMBLE;
				else
					bit_num = 0;
			}
			break;
		}

		// Once we reach here, we have a full `byte` that we can analyze. When
		// `bit` is one, this is the final byte in the instruction and is
		// checked for errors.
		if (bit) {
			// Last byte in the instruction is always the error check byte.
			if (byte != check_byte) {
				uart_puts(" ERR\r\n");
			} else {
				uart_puts(" OK\r\n");
			}
		} else {
			check_byte ^= byte;
			uart_putc(' ');
		}

next_edge:
		// Make sure no edge has occurred while we were processing. If one did
		// then either the signal is changing too fast, in which case it's not
		// DCC anymore; or we're taking too long to process it, in which case
		// it's better to start again than try to catch up.
		if (edge) {
			phase = UNKNOWN;
			last_bit = -1;
		}
	}
}
