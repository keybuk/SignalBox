//
//  main.c
//  SignalBox
//
//  Created by Scott James Remnant on 6/1/20.
//

#include <avr/interrupt.h>
#include <avr/io.h>
#include <util/delay.h>

#include "uart.h"


#define DCC       PORTD2

#define ENABLE    PORTC1
#define BRAKE     PORTC2
#define PWM       PORTC3


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

    // Flash the builtin LED.
    DDRB |= _BV(DDB5);
    PORTB &= ~_BV(PB5);
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

int main() {
    cli();
    init();
    sei();

    for (;;) {
            _delay_ms(1000);
            PORTB ^= _BV(PB5);
    }
}
