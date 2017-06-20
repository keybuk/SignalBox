//
//  main.c
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


#define DELTA(_a, _b) ((_a) > (_b) ? (_a) - (_b) : (_b) - (_a))

#define DCC       PD2

// Input parser states.
#define SEEKING_PREAMBLE 0
#define PACKET_START     1
#define PACKET_A         2
#define PACKET_B         3

volatile uint8_t cutout;

#if DETECTOR
#define CUTOUT    PD3
#endif // DETECTOR


static inline void init() {
    // To analyze the DCC signal we need a timer on which we can count,
    // with reasonable precision, microseconds. Set up TIMER0 for 4µs
    // ticks (64 prescale) which is reasonable enough.
    TCCR0A = _BV(WGM01) | _BV(WGM00);
    TCCR0B = _BV(CS01) | _BV(CS00);
    TIMSK0 = _BV(TOIE0);
    
    // Configure INT0 and INT3 to generate interrupts for any logical change.
    EICRA |= _BV(ISC00) | _BV(ISC10);
    EIMSK |= _BV(INT0) | _BV(INT1);
    
    // Configure USART for 250kbps (0x03) 8n1 operation, enable the
    // interrupt for receiving (but leaving reciving itself disabled until
    // a cutout) and enable transmitting (but again leave it disabled until
    // we have something to transmit).
    UCSR0B = _BV(RXCIE0) | _BV(TXEN0);
    UCSR0C = _BV(UCSZ01) | _BV(UCSZ00);
    UBRR0H = 0;
    UBRR0L = 0x03;
}


// MARK: -
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
// We use a pair of interrupts to measure the time, in microseconds, between
// edges. TIMER0 counts the number of 4µs ticks in TCNT0, and the ISR counts
// the number of times it overflows; thus we can combine the two values to
// calculate the number of microseconds that have passed.
//
// INT0 is fired on the edges, and makes this calculation, comparing it to the
// previous edge time, and storing the result in `delta`. The `edge` flag is
// set on each new edge.

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
    if (bit_is_set(TIFR0, TOV0) && (tcnt != 0xff))
        ++ovf;
    
    micros = (ovf << 10) | (tcnt << 2);
    delta = micros - last_micros;
    edge = 1;
    last_micros = micros;
}


// MARK: RailCom Input

// RailCom Input
// -------------
// The booster generates the RailCom cutout, a gap in the DCC signal where
// no power is present on the track, during which the decoder can transmit
// its own signal.
//
//    _   _              _   _
//  _| |_| '-++--++++-._| |_| |_
//
// An external window comparator is used to detect the cutout, since it's
// electrically indistinguishable from a long low logical period to the
// AVR. The output from this comparator is input onto INT1, on which we
// use an interrupt to detect the edges, and retrieve the value within
// to determine whether the cutout is beginning or ending.
//
// The signal from the decoder is electrically compatible with UART, so
// we use the ATmega328P's own USART to decode the signal, and receive an
// interrupt for each byte we receive.
//
// Whether receiving data is enabled is toggled by the INT1 interrupt so
// that noise outside of the cutout is ignored.

#if DETECTOR
volatile uint8_t rx;

// INT1 Interrupt.
// Fires when the input signal on INT1 (D3) changes.
//
// Check the value of the pin to determine whether we're in the cutout or
// not. Toggle whether RX is enabled on the USART accordingly.
ISR(INT1_vect)
{
    cutout = bit_is_set(PIND, CUTOUT);
    
    if (cutout) {
        UCSR0B |= _BV(RXEN0);
    } else {
        UCSR0B &= ~_BV(RXEN0);
        if (rx) {
            uart_putc('\r');
            uart_putc('\n');
            rx = 0;
        }
    }
}

// USART RX Complete Interrupt
// Fires when a newly received byte is available in UDR0.
//
// Collate RailCom response bytes.
ISR(USART_RX_vect) {
    uint8_t status, data;
    
    status = UCSR0A;
    data = UDR0;
    rx = 1;
    
    // TODO: check the error flags.
    // TODO: do something with the bytes.
    uart_putc(((data >> 4) > 9 ? '7' : '0') + (data >> 4));
    uart_putc(((data & 0xf) > 9 ? '7' : '0') + (data & 0xf));
    uart_putc(' ');
}
#endif // DETECTOR


// MARK: Main Loop

// Main Loop
// ---------
// There are two basic passes to analyzing the incoming DCC signal.
//
// The first is to determine the phase; when we start to receive incoming
// half-bits, we do not yet know whether the signal is in high-low or
// low-high order, and thus do not know whether an edge is a boundary
// between bits, or between a single bit's high and low parts.
//
// To synchronize we need to look for a point at which the period length
// changes between that of a one-bit and a zero-bit:
//
//                   :
//   _   _   _   _    __    __   _   _
// _| |_| |_| |_| |__|  |__|  |_| |_| |
//                   :
//         length change means we
//         must be now in Phase A
//
// Since the preamble that marks the start of a packet is a train of
// one-bits followed by a zero-bit, we can combine both phase synchronization
// and preamble detection into one pass. A suitably long sequence of one-bits
// followed by the first period of a zero-bit gives us both the phase of the
// signal and the start of a packet.
//
//
// The second pass is packet and byte extraction. Due to the different byte
// and packet end bits, the packet structure can be followed logically and
// byte and packet boundaries followed provided the input conforms to
// specification. The final byte is always a check byte, which we compare
// against an accumulated xor of the previous bytes in the packet.
//
//    ?    preamble.   byte     byte  check byte
//        +--------+ +------+ +------+ +------+
// 1101000111111111101010101001111000000101101011111...
//                  :        :        :        :
//                  +--byte end bits--+    packet end bit
//

int main()
{
    cli();
    init();
    sei();
    
    uart_puts("Running\r\n");
    
    unsigned long last_length;
    int state = SEEKING_PREAMBLE, preamble_half_bits = 0, last_bit;
    uint8_t bitmask, byte, check_byte;
    for (;;) {
        unsigned long length;
        
        // Wait for an edge from the input ISR, and copy its length.
        while (!edge)
            ;
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
            // On an invalid bit length, attempt to resynchronize.
            preamble_half_bits = 0;
            state = SEEKING_PREAMBLE;
            
            if (!cutout) {
                char line[80];
                sprintf(line, "\aBAD len %luus\r\n", length);
                uart_puts(line);
            }
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
                // If we see anything other than a zero half-bit here it means
                // we misdetected a period as a zero that shouldn't be, so return
                // back to seeking the preamble.
                if (bit) {
                    preamble_half_bits = 0;
                    state = SEEKING_PREAMBLE;
                } else {
                    check_byte = 0;
                    bitmask = 1 << 7;
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
                    
                    if (!cutout) {
                        char line[80];
                        sprintf(line, "\aBAD match %c%c\r\n", last_bit ? 'H' : 'L', bit ? 'H' : 'L');
                        uart_puts(line);
                    }
                } else if (bit && DELTA(length, last_length) > 8) {
                    // Double-check the delta of one-bit phases, if we go out of spec,
                    // treat it the same as if we had non-matching bits and
                    // resynchronize the phase.
                    preamble_half_bits = 0;
                    state = SEEKING_PREAMBLE;
                    
                    if (!cutout) {
                        char line[80];
                        sprintf(line, "\aBAD delta %luus\r\n", DELTA(length, last_length));
                        uart_puts(line);
                    }
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
                    
#if DEBUG
                    uart_putc(bit ? '1' : '0');
#endif
                } else if (!bit) {
                    // Zero-bit goes between bytes, accumulate the check byte
                    // and prepare for the next.
                    check_byte ^= byte;
                    bitmask = 1 << 7;
                    state = PACKET_A;
                    
#if DEBUG
                    uart_putc(' ');
#endif
                } else if (byte != check_byte) {
                    // Check byte doesn't match, but we otherwise kept sychronisation.
                    // Assume we can carry on.
                    
                    preamble_half_bits = 0;
                    state = SEEKING_PREAMBLE;
                    
#if DEBUG
                    uart_puts(" \aERR\r\n");
#else
                    uart_puts("\aBAD check\r\n");
#endif
                } else {
                    // Check byte matches the error check byte in the stream.
                    // Now we've reached the end of a packet, and go back into
                    // dumb preamble seeking mode.
                    
                    state = SEEKING_PREAMBLE;
                    preamble_half_bits = 0;
                    
#if DEBUG
                    uart_puts(" OK\r\n");
#endif
                }
                
                break;
        }
    }
}
