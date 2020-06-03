//
//  uart.c
//  SignalBox
//
//  Created by Scott James Remnant on 6/2/20.
//

#include "uart.h"

#include <avr/interrupt.h>
#include <avr/io.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>


#if DEBUG
#define UBUFFER_SIZE 256
volatile char ubuffer[UBUFFER_SIZE];
volatile uint8_t uput, usend;

void uart_init() {
    // Configure USART for 250kbps (0x03) 8n1 operation, enable the
    // interrupt for receiving (but leaving reciving itself disabled until
    // a cutout) and enable transmitting (but again leave it disabled until
    // we have something to transmit).
    UCSR0B = _BV(RXCIE0) | _BV(TXEN0);
    UCSR0C = _BV(UCSZ01) | _BV(UCSZ00);
    UBRR0H = 0;
    UBRR0L = 0x03;
}

void uputc(char ch) {
    ubuffer[uput++] = ch;
    UCSR0B |= _BV(UDRIE0);
}

void uputs(const char *str) {
    while (*str)
        uputc(*str++);
}

void uprintf(const char *format, ...) {
    char data[UBUFFER_SIZE];
    va_list args;

    va_start(args, format);
    vsnprintf(data, UBUFFER_SIZE, format, args);
    va_end(args);

    data[UBUFFER_SIZE - 1] = '\0';
    uputs(data);
}

// USART Data Register Empty Interrupt
// Fires when the USART is ready to transmit a byte.
ISR(USART_UDRE_vect) {
    if (uput != usend) {
        UDR0 = ubuffer[usend++];
    } else {
        UCSR0B &= ~_BV(UDRIE0);
    }
}
#endif  // DEBUG
