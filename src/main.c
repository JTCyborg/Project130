#include <stdint.h>

#define P130_BUILD_ID "BOOTSTRAP-0.1.0-SKELETON"

volatile uint8_t p130_debug_value;

static void p130_debug_putc(uint8_t value)
{
    p130_debug_value = value;
    __asm
        ld a,(_p130_debug_value)
        ld bc,00EFh
        out (c),a
    __endasm;
}

static void debug_puts(const char *text)
{
    while (*text) p130_debug_putc((uint8_t)*text++);
}

void p130_c_entry(void)
{
    debug_puts("\r\n[P130] C IMAGE EXECUTED\r\n");
    debug_puts("[P130] Z88DK C ENTRY\r\n");
    debug_puts("[P130] BUILD: " P130_BUILD_ID "\r\n");
    debug_puts("[P130] DEBUG PORT EF READY\r\n");
    debug_puts("[P130] ATM HOST BOOTSTRAP READY\r\n");
    debug_puts("[P130] NEO GS / DMA NOT INITIALIZED\r\n");

    for (;;) {
        /* Stage 0 deliberately remains in a safe, interrupt-disabled idle. */
    }
}
