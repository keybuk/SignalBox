//
//  main.c
//  SignalBox
//
//  Created by Scott James Remnant on 6/1/20.
//

#include <avr/interrupt.h>
#include <avr/io.h>

#include <stdint.h>

#include "uart.h"


#define DCC       PORTD2

#define ENABLE    PORTC1
#define BRAKE     PORTC2
#define PWM       PORTC3

// Absolute delta between two unsigned values.
#define DELTA(_a, _b) ((_a) > (_b) ? (_a) - (_b) : (_b) - (_a))


// MARK: Initialization.

static inline void init() {
    // Configure INT0 to generate interrupts for any logical change.
    EICRA |= _BV(ISC00);
    EIMSK |= _BV(INT0);

    // To analyze the DCC signal we need a timer on which we can measure, with
    // reasonable precision, the time in microseconds between edges. Set up TIMER1
    // in CTC mode with 0.5µs (8 prescale) ticks, and a TOP of the maximum permitted
    // length of a high or low period (10,000µs).
    //
    // We'll reset TCNT1 whenever an edge in the input is detected, meaning a timer
    // interrupt is generated when the maximum length of a zero-bit high or low period
    // has been exceeded, indicating loss of signal.
    TCCR1A = 0;
    TCCR1B = _BV(WGM12);
    TCCR1C = 0;
    TIMSK1 = _BV(OCIE1A);
    TCNT1 = 0;
    OCR1A = 10000 * 2;
    TCCR1B |= _BV(CS11);

    // Use C1-3 as outputs for Enabled, Brake and PWM respectively. Set
    // the initial pattern to "No Signal" mode.
    DDRC |= _BV(DDC1) | _BV(DDC2) | _BV(DDC3);
    PORTC &= ~_BV(ENABLE);
    PORTC |= _BV(BRAKE) | _BV(PWM);

    // Turn on the builtin LED.
    DDRB |= _BV(DDB5);
    PORTB |= _BV(PB5);
}


// MARK: DCC Signal Input

// DCC Signal Timing
// -----------------
// The DCC signal is a a series of high/low periods where the length of the
// high and low parts indicate whether it's a zero-bit or a one-bit. Either
// the high or low can come first, depending on the wiring:
//
//    __    __   _   _        __    __    _   _
// __|  |__|  |_| |_| |  or  |  |__|  |__| |_| |_  =>  0011
//
// We use a single timer to both measure the time in microseconds between
// edges, and to detect a loss of signal.
//
// TIMER1 counts the number of 0.5µs ticks in TCNT1, and the INT0 (D2) ISR
// is fired on edges, storing this value in `edge` for the main loop to
// retrieve. TCNT1 is then reset to zero, to begin counting again for the
// next edge.
//
// The value of TOP for TIMER1 is set to the maximum permitted time for a
// zero-bit high or low period, when exceeeded the timer ISR is triggered
// indicating a loss of signal.

volatile unsigned int edge;

// INT0 Interrupt.
// Fires when the input signal on INT0 (D2) changes.
//
// Reads TCNT1 and resets it, clears any loss of signal status.
ISR(INT0_vect)
{
    edge = TCNT1;
    TCNT1 = 0;

    PORTC |= _BV(ENABLE);
    PORTC &= ~_BV(BRAKE);
}

// TIMER1 Comparison Interrupt.
// Fires when TIMER1 reaches TOP.
//
// Indicates a timeout waiting for the input signal to change.
ISR(TIMER1_COMPA_vect)
{
    PORTC &= ~_BV(ENABLE);
    PORTC |= _BV(BRAKE);
}

// Wait for an edge and return the length.
static inline unsigned int wait_for_edge() {
    unsigned int length;
    uint8_t sreg;

    while (!edge)
        ;

    sreg = SREG;
    cli();

    length = edge;
    edge = 0;

    SREG = sreg;
    return length;
}


// MARK: Main Loop

enum parser_state {
    SEEKING_PREAMBLE,
    PACKET_START,
    PACKET_A,
    PACKET_B
};

int main() {
    cli();
    init();
    uart_init();
    sei();

    enum parser_state state = SEEKING_PREAMBLE;
    int preamble_half_bits = 0, last_bit;
    unsigned int last_length;
    uint8_t bitmask, byte, check_byte;
    for (;;) {
        // Wait for an edge from the input ISR and copy the length of the period.
        //
        // The specification says to allow 52-64µs periods for a one-bit, and
        // 90-10,000µs for zero-bit. The upper-bound is already handled by timer,
        // so only check for too-short or intermediate invalid period lengths.
        unsigned int length = wait_for_edge();
        int bit;
        if (length >= 90 * 2) {
            bit = 0;
        } else if ((length >= 52 * 2) && (length <= 64 * 2)) {
            bit = 1;
        } else {
            // On an invalid bit length, attempt to resynchronize.
            preamble_half_bits = 0;
            state = SEEKING_PREAMBLE;
            uprintf("\aBAD LEN %u\r\n", length);
            continue;
        }

        // Each bit has two periods, how we react to each depends on whether we've
        // detected the end of the preamble (and thus sychronized the phase), and
        // which phase that is.
        switch (state) {
            case SEEKING_PREAMBLE:
                // When we're looking for a preamble, we're looking for the first
                // stretch of at least 10 full one-bits, terminated by a full
                // zero-bit.
                if (bit) {
                    ++preamble_half_bits;
                } else if (preamble_half_bits >= 20) {
                    // End of preamble found, the next state is to consume the
                    // second half of the zero bit.
                    state = PACKET_START;
                } else {
                    preamble_half_bits = 0;
                }
                break;
            case PACKET_START:
                // If we see anything other than a zero high or low period here it means
                // we misdetected a period as a zero that shouldn't be, so return
                // back to seeking the preamble.
                if (bit) {
                    preamble_half_bits = 0;
                    state = SEEKING_PREAMBLE;
                } else {
                    bitmask = 1 << 7;
                    check_byte = 0;
                    state = PACKET_A;
                }
                break;
            case PACKET_A:
                // First period in a bit, save which bit it was and the length,
                // so we can double-check in the second phase next cycle.
                last_bit = bit;
                last_length = length;
                state = PACKET_B;
                break;
            case PACKET_B:
                if (last_bit != bit) {
                    // Bits must match between phases; if they don't, we've probably
                    // gone out of phase, so resynchronize again.
                    preamble_half_bits = 0;
                    state = SEEKING_PREAMBLE;
                    uprintf(" \aBAD MATCH %c%c\r\n", last_bit ? 'H' : 'L', bit ? 'H': 'L');
                } else if (bit && DELTA(length, last_length) > 6 * 2) {
                    // Double-check the delta of one-bit phases, if we go out of spec,
                    // treat it the same as if we had non-matching bits and
                    // resynchronize the phase.
                    preamble_half_bits = 0;
                    state = SEEKING_PREAMBLE;
                    uprintf(" \aBAD DELTA %u %u\r\n", last_length, length);
                } else if (bitmask) {
                    // Within the packet there are eight bits to a byte, followed by
                    // a zero-bit or a one-bit that determines whether more bytes
                    // follow, or a preamble.
                    if (bit) {
                        byte |= bitmask;
                    } else {
                        byte &= ~bitmask;
                    }
                    bitmask >>= 1;
                    state = PACKET_A;
                    uputc(bit ? '1' : '0');
                } else if (!bit) {
                    // Zero-bit goes between bytes, accumulate the check byte
                    // and prepare for the next.
                    check_byte ^= byte;
                    bitmask = 1 << 7;
                    state = PACKET_A;
                    uputc(' ');
                } else if (byte != check_byte) {
                    // Check byte doesn't match, but we otherwise kept sychronisation.
                    // Assume we can carry on, and go back to dumb preamble seeking mode
                    // and hope the next time the packet is sent, it comes in fine.
                    preamble_half_bits = 0;
                    state = SEEKING_PREAMBLE;
                    uputs(" \aERR\r\n");
                } else {
                    // Check byte matches the error check byte in the stream.
                    // Now we've reached the end of a packet, and go back into
                    // dumb preamble seeking mode.
                    state = SEEKING_PREAMBLE;
                    preamble_half_bits = 0;
                    uputs(" OK\r\n");
                }
                break;
        }
    }
}
