//
//  detector.c
//  SignalBox
//
//  Created by Scott James Remnant on 06/05/17.
//
//

#include <avr/interrupt.h>
#include <avr/io.h>

#include <string.h>

#include "uart.h"


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
    // TODO: should indicate overflow?
    edge = TCNT1;
    TCNT1 = 0;
}

// TIMER1 Comparison Interrupt.
// Fires when TIMER1 reaches TOP.
//
// Indicates a timeout waiting for the input signal to change.
ISR(TIMER1_COMPA_vect)
{
    // TODO: should mark overflow?
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

#define CUTOUT  PD3

static inline void
railcom_init()
{
    // Configure INT1 to generate interrupts for any logical change.
    EICRA |= _BV(ISC10);
    EIMSK |= _BV(INT1);

    // Configure USART for 250kbps (0x03) 8n1 operation, enable the
    // interrupt for receiving (but leaving reciving itself disabled until
    // a cutout) and enable transmitting (but again leave it disabled until
    // we have something to transmit).
    UCSR0B = _BV(RXCIE0) | _BV(TXEN0);
    UCSR0C = _BV(UCSZ01) | _BV(UCSZ00);
    UBRR0H = 0;
    UBRR0L = 0x03;
}

volatile int rx;

// INT1 Interrupt.
// Fires when the input signal on INT1 (D3) changes.
//
// Check the value of the pin to determine whether we're in the cutout or
// not. Toggle whether RX is enabled on the USART accordingly.
ISR(INT1_vect)
{
    int cutout = bit_is_set(PIND, CUTOUT);
    
    if (cutout) {
        UCSR0B |= _BV(RXEN0);
    } else {
        UCSR0B &= ~_BV(RXEN0);
        if (rx) {
            uputc('\r');
            uputc('\n');
            rx = 0;
        }
    }
}

// USART RX Complete Interrupt
// Fires when a newly received byte is available in UDR0.
//
// Collate RailCom response bytes.
ISR(USART_RX_vect)
{
    uint8_t status, data;
    
    status = UCSR0A;
    data = UDR0;
    rx = 1;
    
    // TODO: check the error flags.
    // TODO: do something with the bytes.
    uputc(((data >> 4) > 9 ? '7' : '0') + (data >> 4));
    uputc(((data & 0xf) > 9 ? '7' : '0') + (data & 0xf));
    uputc(' ');
}


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
    PORTD = ~(_BV(DCC) | _BV(CUTOUT));

    dcc_init();
    railcom_init();
    uart_init();
    sei();
    
    uputs("Running\r\n");
    
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
