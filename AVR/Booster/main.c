//
//  main.c
//  Booster
//
//  Created by Scott James Remnant on 6/1/20.
//

#include <avr/interrupt.h>
#include <avr/io.h>

#include <stdint.h>

#include "uart.h"


// MARK: H-Bridge Outputs

// Outputs
// -------
// The H-Bridge receives the DCC signal directly with the AVR only monitoring
// it passively, but we do need to control braking of the H-Bridge during
// exception conditions.
//
// CONDITION       PWM DIR BRAKE DRIVERS
// Normal           H   X    L   Controlled by DIR
// Exception        L   X    H   None, DIR ignored
//
// BRAKE is always the opposite of PWM. H-Bridge outputs when BRAKE or PWM only are
// used short either the sourcing or sink output transistors. Shorting is inappropriate
// for overheat or overload where we need the load on the H-Bridge to go away;
// doesn't provide a useful circuit for RailCom responses so can't be used for the cutout;
// and isn't especially helpful over no outputs for a loss of signal either.
//
// Since the different conditions can overlap, we take care to track the
// conditions active on the pins rather than just toggling the pins directly.
// For example a loss of signal can occur during a RailCom cutout, and we don't
// want the end of cutout timer turning the power back on while we don't have a signal.

#define BRAKE  PORTC1
#define PWM    PORTC2

static inline void
output_init()
{
    // Use C1 and C2 as outputs for PWM and BRAKE respectively.
    DDRC |= _BV(DDC1) | _BV(DDC2);
}

enum condition {
    NORMAL,
    CUTOUT,
    NO_SIGNAL,
    OVERHEAT,
    OVERLOAD
};

volatile int condition = NO_SIGNAL;

__attribute__((always_inline))
static inline void
output_set()
{
    // Clear PWM before BRAKE to consistently short by source rather than
    // letting the DIR pin decide whether short by source or sink. Likewise
    // release BRAKE first for the same reason.
    if (condition) {
        PORTC &= ~_BV(PWM);
        PORTC |= _BV(BRAKE);
    } else {
        PORTC &= ~_BV(BRAKE);
        PORTC |= _BV(PWM);
    }
}


// MARK: H-Bridge Inputs

// Inputs
// ------
// The H-Bridge provides us two inputs, an active-low THERMAL flag on D3 which we
// use an ISR to watch, and a current sense we place on ADC0 to detect overloads.

#define THERMAL  PORTD3

// Overload threshold of 3A, where we pull the power.
#define HARD_OVERLOAD  512

static inline void
input_init()
{
    // Configure INT1 to generate interrupts for any logical change.
    EICRA |= _BV(ISC10);
    EIMSK |= _BV(INT1);

    // Check for initial overhead condition.
    if (!bit_is_set(PIND, THERMAL)) {
        condition |= _BV(OVERHEAT);
        output_set();
    }

    // Configure the ADC in free-running mode, reading from ADC0, generating
    // interrupts on new data, and with a clock pre-scalar of 128 (125kHz).
    ADMUX = _BV(REFS0);
    ADCSRA = _BV(ADEN) | _BV(ADSC) | _BV(ADATE) | _BV(ADIE) | _BV(ADPS2) | _BV(ADPS1) | _BV(ADPS0);
}

// INT1 Interrupt.
// Fires when the THERMAL signal on INT1 (D3) changes.
//
// The THERMAL pin is active-low when an OVERHEAD condition exists.
ISR(INT1_vect)
{
    if (!bit_is_set(PIND, THERMAL)) {
        if (!bit_is_set(condition, OVERHEAT)) {
            condition |= _BV(OVERHEAT);
            output_set();
        }
    } else if (bit_is_set(condition, OVERHEAT)) {
        condition &= ~_BV(OVERHEAT);
        output_set();
    }
}

// ADC Interrupt.
// Fires when a new analog value is ready to be read.
//
// Reads the value and checks it for overload.
ISR(ADC_vect)
{
    int value = ADCL;
    value |= (ADCH << 8);

    if (value >= HARD_OVERLOAD) {
        if (!bit_is_set(condition, OVERLOAD)) {
            condition |= _BV(OVERLOAD);
            output_set();
        }
    } else if (bit_is_set(condition, OVERLOAD)) {
        condition &= ~_BV(OVERLOAD);
        output_set();
    }
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

#define DCC  PD2

static inline void
dcc_init()
{
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
    OCR1A = 10000 * 2;
}

static inline void
dcc_timer_start()
{
    TCNT1 = 0;
    TCCR1B |= _BV(CS11);
}

volatile unsigned int edge;

// INT0 Interrupt.
// Fires when the input signal on INT0 (D2) changes.
//
// Reads TCNT1 and resets it, clears any loss of signal status.
ISR(INT0_vect)
{
    edge = TCNT1;
    TCNT1 = 0;

    if (bit_is_set(condition, NO_SIGNAL)) {
        condition &= ~_BV(NO_SIGNAL);
        output_set();
    }
}

// TIMER1 Comparison Interrupt.
// Fires when TIMER1 reaches TOP.
//
// Indicates a timeout waiting for the input signal to change.
ISR(TIMER1_COMPA_vect)
{
    if (!bit_is_set(condition, NO_SIGNAL)) {
        condition |= _BV(NO_SIGNAL);
        output_set();
    }
}

// Wait for an edge and return the length.
static inline unsigned int
wait_for_edge()
{
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


// MARK: RailCom Cutout Generation

// RailCom Cutout
// --------------
// The RailCom cutout is a gap in the DCC signal where no power is present
// on the track, during which the decoder can transmit its own signal.
//
//    _   _              _   _
//  _| |_| '-++--++++-._| |_| |_
//
// We generate the cutout after we see the packet end bit to a valid packet,
// starting TIMER0 which triggers ISRs when the delay time for the cutout start
// and end (as measured from the end of the packet end bit) have passed.

// Inherent processing delay between the packet end bit coming from the input source
// and any changes we make to the H-Bridge Output pins to take effect. Subtracted from
// timer values to get the right period for the RailCom cutout.
#define RAILCOM_DELAY 12

static inline void
railcom_init()
{
    // For the RailCom cutout we need to measure both the time until cutout start and
    // end, and we need a reasonable degree of consistency, as for example a 64 prescale
    // would have a ≤4µs variance between delays as we can't reset the prescaler since it's
    // shared with TIMER1 which measures the incoming DCC signal.
    //
    // Instead we use TIMER0 with 0.5µs (8 prescale) ticks, but since it's an 8-bit timer
    // and we can't simply count to 454µs at that scale, we also count overflows. The timer
    // is set to Normal mode, with OCIE0 set to the delay for the cutout start, and OCIE0B
    // set to the (modulus) delay for the cutout end. Both generate interrupts, but both
    // also check the value of `timer_ovf_count` which is incremented by the overflow ISR.
    TCCR0A = 0;
    TCCR0B = 0;
    TIMSK0 = _BV(OCIE0A) | _BV(OCIE0B) | _BV(TOIE0);
    OCR0A = (26 - RAILCOM_DELAY) * 2;
    OCR0B = ((454 - RAILCOM_DELAY) * 2) % 256;
}

volatile int timer0_ovf_count;

static inline void
railcom_timer_start()
{
    timer0_ovf_count = 0;
    TCNT0 = 0;
    TCCR0B |= _BV(CS01);
}

static inline void
railcom_timer_stop()
{
    TCCR0B &= ~(_BV(CS02) | _BV(CS01) | _BV(CS00));
}

// TIMER0 Comparison Interrupt A.
// Fires when TIMER0 reaches OCR0A.
//
// Starts the RailCom cutout in the first timer period.
ISR(TIMER0_COMPA_vect)
{
    if (timer0_ovf_count == 0) {
        condition |= _BV(CUTOUT);
        output_set();
    }
}

// TIMER0 Comparison Interrupt B.
// Fires when TIMER0 reaches OCR0B.
//
// Stops the RailCom cutout and timer in the correct timer period.
ISR(TIMER0_COMPB_vect)
{
    if (timer0_ovf_count == ((454 - RAILCOM_DELAY) * 2) / 256) {
        condition &= ~_BV(CUTOUT);
        output_set();

        railcom_timer_stop();
    }
}

// TIMER0 Overflow Interrupt.
// Fires when TIMER0 reaches MAX.
//
// Increments the overflow count, allowing us to count periods of 128µs and longer.
ISR(TIMER0_OVF_vect)
{
    ++timer0_ovf_count;
}


// MARK: Main Loop

enum parser_state {
    SEEKING_PREAMBLE,
    PACKET_START,
    PACKET_A,
    PACKET_B
};

// Absolute delta between two unsigned values.
#define DELTA(_a, _b) ((_a) > (_b) ? (_a) - (_b) : (_b) - (_a))

int
main()
{
    cli();
    // To save power, enable pull-ups on all pins we're not using as input.
    PORTB = PORTC = ~0;
    PORTD = ~_BV(DCC);

    output_init();
    input_init();
    dcc_init();
    railcom_init();
    uart_init();
    sei();

    output_set();
    dcc_timer_start();

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
                    railcom_timer_start();

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
