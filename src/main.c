#include <stdint.h>
#include "diag.h"
#include "memory.h"

#define P130_BUILD_ID "BOOTSTRAP-0.3.0-P126-ATM-CONSOLE"

static void p130_report_memory(void)
{
    uint8_t result;

    p130_debug_puts("[MEM] ATM2+ CAPACITY MODEL=1M PAGES=64 PAGE_SIZE=16K\r\n");
    p130_debug_puts("[MEM] CAPACITY MODEL ONLY; PHYSICAL RAM DISCOVERY NOT IMPLEMENTED\r\n");

    result = p130_memory_init();
    if (result != 0u) {
        p130_debug_puts("[MEM] PAGE MANAGER INIT FAILED; ERROR=");
        p130_debug_hex8(result);
        p130_debug_puts("\r\n");
        return;
    }

    p130_debug_puts("[MEM] RESERVED=P0:BOOT-W3 P2:STACK+UI P3:VIDEO-ATTR P5:RESIDENT P7:VIDEO-CHARS\r\n");
    p130_debug_puts("[MEM] PAGE MANAGER READY; FREE=");
    p130_debug_hex8(p130_memory_free_count());
    p130_debug_puts("\r\n");
}

static void p130_ui_init(void)
{
    __asm
        call 0A000h
    __endasm;
}

void p130_c_entry(void)
{
    p130_debug_puts("\r\n[P130] C IMAGE EXECUTED\r\n");
    p130_debug_puts("[P130] Z88DK C ENTRY\r\n");
    p130_debug_puts("[P130] BUILD: " P130_BUILD_ID "\r\n");
    p130_ui_init();
    p130_debug_puts("[P130] ATM 80X25 CONSOLE READY\r\n");
    p130_debug_puts("[P130] DEBUG PORT EF READY\r\n");
    p130_debug_puts("[P130] ATM HOST BOOTSTRAP READY\r\n");
    p130_report_memory();
    p130_debug_puts("[MAP] PHYSICAL W3 MAPPER NOT INITIALIZED\r\n");
    p130_debug_puts("[P130] NEO GS / DMA NOT INITIALIZED\r\n");

    for (;;) {
        /* Emulator host idle: no self-tests or memory probing. */
    }
}
