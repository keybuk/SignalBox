// PowerStation.
//
// Connect INT0 (D2) to the logical DCC signal, B0 to the H-Bridge Brake (with
// pull-up), and ADC0 to the H-Bridge Current Sense.
//
// Brake will start Set, be cleared when there is a signal, and set on signal
// loss, or on current overload. Current overload can only be cleared by Reset.

#include <avr/io.h>
#include <avr/interrupt.h>

#include <util/delay.h>

#include <stdio.h>

#include "uart.h"


// Reason for engaging the brake pin.
#define NO_SIGNAL 1
#define OVERLOAD  2
volatile int brake;

// Overload threshold.
#define THRESHOLD 1000

// Store more than one recent analog value so we can display an average.
// v is the next value to be written, v_fill is true once values is filled.
#define VALUES 8
volatile int values[VALUES], v, v_fill;


// INT0 Interrupt.
// Fires when the input signal on INT0 (D2) changes.
//
// Resets the timer counter, and clears the output (B0).
//
// Thus any change to the input signal results in an immediate resumption of
// output power, and a new 250ms timeout is begun; as long as the signal changes
// again before the timeout, power is maintained.
ISR(INT0_vect)
{
  TCNT1 = 0;
  brake &= ~_BV(NO_SIGNAL);
  if (!brake)
    PORTB &= ~_BV(PORTB0);
}

// TIMER1 Comparison Interrupt.
// Fires when Timer1 reaches TOP (set in OCR1A).
//
// Sets the output (B0).
ISR(TIMER1_COMPA_vect)
{
  brake |= _BV(NO_SIGNAL);
  PORTB |= _BV(PORTB0);
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

  if (value > THRESHOLD) {
    brake |= _BV(OVERLOAD);
    PORTB |= _BV(PORTB0);
  }

  values[v++] = value;
  v %= VALUES;
  if (!v) v_fill = 1;
}


int main()
{
  cli();

  // Configure B0 for output, and set.
  DDRB |= _BV(DDB0);
  PORTB |= _BV(PORTB0);

  // Configure timer for 250ms (16Mhz clock; 64 prescale, TOP of 12500) in CTC
  // mode and enable. CTC mode means TCNT1 is cleared to 0 each time the timer
  // reaches TOP, and also means we can clear it ourselves.
  TCCR1B |= _BV(CS12);
  OCR1A = 12500;
  TCCR1B |= _BV(WGM12);
  TIMSK1 |= _BV(OCIE1A);

  // Configure D2 (INT0) for input, disable the pull-up.
  DDRD &= ~_BV(DDD2);
  PORTD &= ~_BV(PORTD2);

  // Configure INT0 to generate an interrupt for any logical change.
  EICRA |= _BV(ISC00);
  EIMSK |= _BV(INT0);

  // Configure the ADC in free-running mode, reading from ADC0, generating
  // interrupts on new data, and with a clock pre-scalar of 128.
  ADCSRA = _BV(ADEN) | _BV(ADSC) | _BV(ADATE) | _BV(ADIE) |
           _BV(ADPS2) | _BV(ADPS1) | _BV(ADPS0);

  // Ready to roll; re-enable interrupts.
  sei();

  uart_init(UART_BAUD_SELECT(9600, F_CPU));
  uart_puts("DCC PowerStation\r\n");

  for (;;) {
    char buffer[80];
    int value = 0;
    float amps;

    for (int i = 0; i < v_fill ? VALUES : v; ++i)
      value += values[i];
    if (v_fill || v)
      value /= v_fill ? VALUES : v;

    // value is 0=0, 1024=5.0

    // Vmax = 4.9764
    // Imax = 6 * 0.000377 = 0.002262
    // R = 2200

    // V = IR
    
    //          va
    // V = 5 * ----
    //         1024

    //      va
    // 5 * ---- = IR
    //     1024

    //      va
    // 5 * ---- = I * 2200
    //     1024

    //      va.     1
    // 5 * ---- * ---- = I
    //     1024   2200

    //        1
    // I * -------- = Iout
    //     0.000377

    amps = 5.0 * value / 1024.0 * 1.0 / 2200.0 * 1.0 / 0.000377;

    if (brake & _BV(NO_SIGNAL))
      uart_puts("No signal - ");
    if (brake & _BV(OVERLOAD))
      uart_puts("Overload - ");

    sprintf(buffer, "value = %d  %.2fA\r\n", value, amps);
    uart_puts(buffer);
    _delay_ms(500);
  }
}
