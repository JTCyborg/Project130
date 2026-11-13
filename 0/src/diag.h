#ifndef P130_DIAG_H
#define P130_DIAG_H

#include <stdint.h>

/* ATM host diagnostic channel. This API is ATM-side only. */
void p130_debug_putc(uint8_t value);
void p130_debug_puts(const char *text);
void p130_debug_hex8(uint8_t value);
void p130_debug_hex16(uint16_t value);

#endif
