#include <stdint.h>
#include "memory.h"

#define P130_BUILD_ID "BOOTSTRAP-0.2.0-ATM-HOST-BASE"

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

static void p130_debug_puts(const char *text)
{
    while (*text) p130_debug_putc((uint8_t)*text++);
}

static void p130_debug_hex8(uint8_t value)
{
    uint8_t digit = (uint8_t)(value >> 4);
    p130_debug_putc((uint8_t)(digit < 10u ? '0' + digit : 'A' + digit - 10u));
    digit = (uint8_t)(value & 0x0Fu);
    p130_debug_putc((uint8_t)(digit < 10u ? '0' + digit : 'A' + digit - 10u));
}

static void p130_report_memory(void)
{
    uint8_t result;

    p130_debug_puts("[MEM] ATM2+ CAPACITY MODEL=1M PAGES=64 PAGE_SIZE=16K\r\n");
    p130_debug_puts("[MEM] PHYSICAL PROBE NOT IMPLEMENTED; NO RAM TEST WRITES\r\n");

    result = p130_memory_init();
    if (result != 0u) {
        p130_debug_puts("[MEM] PAGE MANAGER INIT FAILED; ERROR=");
        p130_debug_hex8(result);
        p130_debug_puts("\r\n");
        return;
    }

    p130_debug_puts("[MEM] RESERVED=P0:BOOT-W3 P2:STACK P3:VIDEO-ATTR P5:RESIDENT P7:VIDEO-CHARS\r\n");
    p130_debug_puts("[MEM] ALLOCATOR/PIN SELFTEST BEGIN\r\n");
    result = p130_memory_selftest();
    if (result == 0u) {
        p130_debug_puts("[MEM] ALLOCATOR/PIN SELFTEST PASS; FREE=");
        p130_debug_hex8(p130_memory_free_count());
        p130_debug_puts("\r\n");
    } else {
        p130_debug_puts("[MEM] ALLOCATOR/PIN SELFTEST FAILED; TEST=");
        p130_debug_hex8(result);
        p130_debug_puts("\r\n");
    }
}

void p130_c_entry(void)
{
    p130_debug_puts("\r\n[P130] C IMAGE EXECUTED\r\n");
    p130_debug_puts("[P130] Z88DK C ENTRY\r\n");
    p130_debug_puts("[P130] BUILD: " P130_BUILD_ID "\r\n");
    p130_debug_puts("[P130] DEBUG PORT EF READY\r\n");
    p130_debug_puts("[P130] ATM HOST BOOTSTRAP READY\r\n");
    p130_report_memory();
    p130_debug_puts("[MAP] PHYSICAL W3 MAPPER NOT INITIALIZED\r\n");
    p130_debug_puts("[P130] NEO GS / DMA NOT INITIALIZED\r\n");

    for (;;) {
        /* Stage 1 keeps IRQ disabled and performs metadata-only checks. */
    }
}
