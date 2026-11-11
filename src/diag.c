#include <stdint.h>
#include "diag.h"

volatile uint8_t p130_debug_value;

void p130_debug_putc(uint8_t value)
{
    p130_debug_value = value;
    __asm
        ld a,(_p130_debug_value)
        ld bc,00EFh
        out (c),a
    __endasm;
}

void p130_debug_puts(const char *text)
{
    while (*text) p130_debug_putc((uint8_t)*text++);
}

void p130_debug_hex8(uint8_t value)
{
    uint8_t digit = (uint8_t)(value >> 4);
    p130_debug_putc((uint8_t)(digit < 10u ? '0' + digit : 'A' + digit - 10u));
    digit = (uint8_t)(value & 0x0Fu);
    p130_debug_putc((uint8_t)(digit < 10u ? '0' + digit : 'A' + digit - 10u));
}

void p130_debug_hex16(uint16_t value)
{
    p130_debug_hex8((uint8_t)(value >> 8));
    p130_debug_hex8((uint8_t)value);
}
