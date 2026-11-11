#include <stdint.h>

#define P130_BUILD_ID "BOOTSTRAP-0.1.0-SKELETON"
#define P130_DEBUG_PORT 0x00EF

static void p130_debug_putc(uint8_t value)
{
    __asm
        ld a,(_p130_debug_value)
        ld bc,0x00EF
        out (c),a
    __endasm;
}

volatile uint8_t p130_debug_value;

static void debug_puts(const char *text)
{
    while (*text) {
        p130_debug_value = (uint8_t)*text++;
        p130_debug_putc(p130_debug_value);
    }
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
