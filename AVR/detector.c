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


#if BOOSTER && DETECTOR
# error "Not enough timers to be both BOOSTER and DETECTOR"
#endif

#define DCC       PD2

// Input parser states.
#define SEEKING_PREAMBLE 0
#define PACKET_START     1
#define PACKET_A         2
#define PACKET_B         3
#define BYTE_END         4

#define DELTA(_a, _b) ((_a) > (_b) ? (_a) - (_b) : (_b) - (_a))

volatile uint8_t cutout;

#if BOOSTER
// Overload threshold of 3A, where we pull the power.
#define HARD_OVERLOAD 512

#define THERMAL   PD3

#define DIRENABLE PORTC1
#define BRAKE     PORTC2
#define PWM       PORTC3

// Brake condition bit numbers.
#define NO_SIGNAL 0
#define OVERLOAD  1
#define OVERHEAT  2

volatile uint8_t brake;
#endif // BOOSTER

#if DETECTOR
#define CUTOUT    PD3
#endif // DETECTOR


#define TIMER0_PRESCALE (_BV(CS01) | _BV(CS00))
#define TIMER1_PRESCALE (_BV(CS11))
#define TIMER2_PRESCALE (_BV(CS22) | _BV(CS21) | _BV(CS20))

// MARK: -
// MARK: Initialization.

static inline void init() {
    // To analyze the DCC signal we need a timer on which we can count,
    // with reasonable precision, microseconds. Set up TIMER0 for 4µs
    // ticks (64 prescale) which is reasonable enough.
    TCCR0A = _BV(WGM01) | _BV(WGM00);
    TCCR0B = TIMER0_PRESCALE;
    TIMSK0 = _BV(TOIE0);
    
    // Configure INT0 and INT1 to generate interrupts for any logical change.
    // For the booster INT1 is the Thermal Sense Flag from the H-Bridge, for
    // the detector it's the RailCom cutout flag.
    EICRA |= _BV(ISC00);// | _BV(ISC10);
    EIMSK |= _BV(INT0);// | _BV(INT1);
    
    DDRC |= _BV(DDC4);
    
#if BOOSTER
    // The maximum value allowed for a "long zero" is 10,000µs (10ms), use
    // this as a timeout for detecting a loss of DCC signal by configuring
    // a timer in CTC mode, and an appropriate value of TOP (1024 prescale,
    // TOP of 157, it's a smidge over but that's perfect). Timer reaching
    // this indicates a timeout, and the timer can be reset by clearing TCNT2.
    TCCR2A = _BV(WGM21);
    OCR2A = 157;
    TIMSK2 = _BV(OCIE2A);
    
    // The RailCom cutout has an initial delay of 26-32µs before the cutout
    // begins, which then lasts 428-456µs. Use TIMER1 for this in CTC mode
    // and a prescale of 8 so we get ample resolution to produce an accurate
    // result. TOP is set for the length of the RailCom cutout itself, but the
    // timer is not enabled; when it is enabled, TCNT1 is first set to the
    // subtracted value for the initial delay, so that the first comparison
    // event occurs earlier.
    TCCR1B = _BV(WGM12);
    OCR1A = 428 << 1;
    TIMSK1 |= _BV(OCIE1A);
    
    // Use C1-3 as outputs for Direction, Brake and PWM respectively. Set
    // the initial pattern to "No Signal" mode with the direction pin high.
    DDRC |= _BV(DDC1) | _BV(DDC2) | _BV(DDC3);
    PORTC |= _BV(DIRENABLE) | _BV(BRAKE);
    PORTC &= ~_BV(PWM);
    
    // Configure the ADC in free-running mode, reading from ADC0, generating
    // interrupts on new data, and with a clock pre-scalar of 128 (125kHz)
    // for maximum resolution at the fastest possible speed.
//    ADMUX = _BV(REFS0);
//    ADCSRA = _BV(ADEN) | _BV(ADSC) | _BV(ADATE) | _BV(ADIE) | _BV(ADPS2) | _BV(ADPS1) | _BV(ADPS0);
#endif // BOOSTER
    
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
//
// When operating as a Booster, we also use TIMER2 to detect a loss of input
// signal. TCNT2 is reset on each fire of INT0, so that should TIMER2 reach
// TOP, it means the input signal has stopped changing and we can assume its
// loss.

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

static inline unsigned long micros() {
    unsigned long ovf;
    uint8_t tcnt;
    
    ovf = timer0_ovf_count;
    tcnt = TCNT0;
    
    // Check if the timer has overflowed without ticking.
    if (bit_is_set(TIFR0, TOV0) && (tcnt != 0xff))
        ++ovf;
    
    return (ovf << 10) | (tcnt << 2);
}

#if BOOSTER
static inline void set_pins()
{
#if DEBUG
    static uint8_t old_brake = 0, old_cutout = 0;
    if (brake == old_brake && cutout == old_cutout)
        return;
    
    uprintf("B %hx:%hx  C %hd:%hd\r\n", old_brake, brake, old_cutout, cutout);
    
    old_brake = brake;
    old_cutout = cutout;
#endif
    if (brake) {
        // Direction has no effect during a full-off brake, so leave it alone.
        PORTC &= ~_BV(PWM);
        PORTC |= _BV(BRAKE);
    } else if (cutout) {
        // For a short-via-ground cutout we want direction low, with PWM and Brake high.
        PORTC &= ~_BV(DIRENABLE);
        PORTC |= _BV(PWM) | _BV(BRAKE);
    } else {
        // Normal operation..
        PORTC |= _BV(PWM) | _BV(DIRENABLE);
        PORTC &= ~_BV(BRAKE);
    }
}
#endif // BOOSTER

// INT0 Interrupt.
// Fires when the input signal on INT0 (D2) changes.
//
// Tracks the deltas between edges using TIMER0.
ISR(INT0_vect)
{
    unsigned long this_micros;
    
    this_micros = micros();
    delta = this_micros - last_micros;
    edge = 1;
    last_micros = this_micros;
    
#if BOOSTER
    TCNT2 = 0;
    TCCR2B |= TIMER2_PRESCALE;
    
    brake &= ~_BV(NO_SIGNAL);
    set_pins();
#endif // BOOSTER
}

#if BOOSTER
// TIMER2 Comparison Interrupt.
// Fires when TIMER2 reaches TOP.
//
// Indicates a timeout waiting for the input signal to change.
ISR(TIMER2_COMPA_vect)
{
    brake |= _BV(NO_SIGNAL);
    set_pins();
    
    TCCR2B &= ~TIMER2_PRESCALE;
}
#endif // BOOSTER


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
ISR(USART_RX_vect) {
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
#endif // DETECTOR


// MARK: RailCom cutout

// RailCom cutout
// --------------

#if BOOSTER
static inline void end_of_packet()
{
    // Begin the RailCom cutout in ~28-32µs time by setting the timer to just below
    // the comparator. This is based purely on experimentation and external measurement
    // since there's an inherent delay in the AVR's interrupts.
    TCNT1 = 425 << 1;
    TCCR1B |= TIMER1_PRESCALE;
}

// TIMER1 Comparison Interrupt.
// Fires when TIMER1 reaches TOP.
//
// Indicates either the start of end of the RailCom cutout.
ISR(TIMER1_COMPA_vect)
{
    cutout = !cutout;
    set_pins();
    
    // Stop the timer if we're no longer in the cutout.
    if (!cutout)
        TCCR1B &= ~TIMER1_PRESCALE;
}
#else // BOOSTER
static inline void end_of_packet() {}
#endif // BOOSTER


// MARK: Booster Safety

// Booster Safety
// --------------
// To avoid situations of overload or overheat, we monitor both the
// Current Sense and Thermal Sense outputs of the H-Bridge using the
// ADC and INT1 respectively.

#if BOOSTER
// Store more than one recent analog value so our display has some history
// to it. `v` is the next value to be written.
#define VALUES 64
volatile int values[VALUES], v;

// Magic constant multiplier to convert ADC values into Output Amps.
// Derived from:
//   Vmin = 0.0 (at v = 0)
//   Vmax = 5.0 (at v = 1024)
//
//                     v - Vmin
//   V = Vmin + Vmax * --------
//                       1024
//
//                377
//   I = Iout * -------
//              1000000
//
//   R = 2200
//
//   V = IR
//
//        v              377
//   5 * ---- = Iout * ------- * 2200
//       1024          1000000
//
const float value_mult = 5.0 * 1 / 1024.0 * 1000000.0 / 377.0 * 1.0 / 2200.0;

static inline float amps()
{
    int vmax = 0;
    for (int i = 0; i < v; ++i)
        vmax = values[i] > vmax ? values[i] : vmax;
    return vmax * value_mult;
}

// ADC Interrupt.
// Fires when a new analog value is ready to be read.
//
// Reads the value, and checks it for overload before saving it for display
// in the main loop.
ISR(ADC_vect)
{
    int value = ADCL;
    value |= (ADCH << 8);
    
    if (value > HARD_OVERLOAD) {
        brake |= _BV(OVERLOAD);
        set_pins();
        
        // TODO: timer.
    } else if (brake & _BV(OVERLOAD)) {
        // Overload cleared.
        // TODO: count-down timer to re-enable.
    }
    
    values[v++] = value;
    v &= (VALUES - 1);
}

// INT1 Interrupt.
// Fires when the input signal on INT1 (D3) changes.
//
// Check the value of the pin to determine whether the thermal sense pin has
// been set to drain (overheat).
ISR(INT1_vect)
{
    if (bit_is_set(PIND, THERMAL)) {
        brake |= _BV(OVERHEAT);
        set_pins();
        
        // TODO: timer.
    } else if (brake & _BV(OVERHEAT)) {
        // Thermal flag cleared.
        // TODO: count-down tiemr to re-enable.
    }
}
#endif // BOOSTER


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
    
    uputs("Running\r\n");
    
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
            
            if (!cutout)
                uprintf("\aBAD len %luus\r\n", length);
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
                    
                    if (!cutout)
                        uprintf("\aBAD match %c%c\r\n", last_bit ? 'H' : 'L', bit ? 'H' : 'L');
                } else if (bit && DELTA(length, last_length) > 12) {
                    // Double-check the delta of one-bit phases, if we go out of spec,
                    // treat it the same as if we had non-matching bits and
                    // resynchronize the phase.
                    preamble_half_bits = 0;
                    state = SEEKING_PREAMBLE;
                    
                    if (!cutout)
                        uprintf("\aBAD delta %luus\r\n", DELTA(length, last_length));
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
                    uputc(bit ? '1' : '0');
#endif
                } else if (!bit) {
                    // Zero-bit goes between bytes, accumulate the check byte
                    // and prepare for the next.
                    check_byte ^= byte;
                    bitmask = 1 << 7;
                    state = PACKET_A;
                    
#if DEBUG
                    uputc(' ');
#endif
                } else if (byte != check_byte) {
                    // Check byte doesn't match, but we otherwise kept sychronisation.
                    // Assume we can carry on.
                    end_of_packet();
                    
                    preamble_half_bits = 0;
                    state = SEEKING_PREAMBLE;
                    
#if DEBUG
                    uputs(" \aERR\r\n");
#else
                    uputs("\aBAD check\r\n");
#endif
                } else {
                    // Check byte matches the error check byte in the stream.
                    // Now we've reached the end of a packet, and go back into
                    // dumb preamble seeking mode.
                    end_of_packet();
                    
                    state = SEEKING_PREAMBLE;
                    preamble_half_bits = 0;
                    
#if DEBUG
                    uputs(" OK\r\n");
#endif
                }
                
                break;
        }
        
        PINC |= _BV(PC4);
    }
}
