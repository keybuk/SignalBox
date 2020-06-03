//
//  uart.h
//  
//
//  Created by Scott James Remnant on 6/2/20.
//

#ifndef SIGNALBOX_UART_H
#define SIGNALBOX_UART_H

#if DEBUG
// Initialize the UART.
void uart_init();

// Write a single character to the UART.
void uputc(char ch);

// Write a string to the UART.
void uputs(const char *str);

// Write a formatted string to the UART.
void uprintf(const char *format, ...);
#else  // DEBUG
static inline void uart_init() {}
static inline void uputc(char ch) {}
static inline void uputs(const char *str) {}
static inline void uprintf(const char *format, ...) {}
#endif  // DEBUG

#endif  // SIGNALBOX_UART_H
