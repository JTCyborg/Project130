#include <stdint.h>
#include "diag.h"
#include "memory.h"
#include "rtc.h"

#define P130_BUILD_ID "BOOTSTRAP-0.3.1-DS12887-RTC"

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

static void p130_ui_clock_update(void)
{
    __asm
        call 0A006h
    __endasm;
}

static void p130_rtc_start(void)
{
    p130_debug_puts("[RTC] DS12887 PROBE BEGIN (GLUK/SMUC)\r\n");
    p130_rtc_probe();
    p130_rtc_read_current();
    p130_ui_clock_update();

    if (p130_rtc_available) {
        p130_debug_puts("[RTC] DS12887 ONLINE; BACKEND=");
        p130_debug_puts(p130_rtc_backend ? "SMUC" : "GLUK");
        p130_debug_puts("; TIME=");
        p130_debug_putc((uint8_t)p130_rtc_hour[0]);
        p130_debug_putc((uint8_t)p130_rtc_hour[1]);
        p130_debug_putc(':');
        p130_debug_putc((uint8_t)p130_rtc_minute[0]);
        p130_debug_putc((uint8_t)p130_rtc_minute[1]);
        p130_debug_putc(':');
        p130_debug_putc((uint8_t)p130_rtc_second[0]);
        p130_debug_putc((uint8_t)p130_rtc_second[1]);
        p130_debug_puts("\r\n");
    } else {
        p130_debug_puts("[RTC] DS12887 NOT DETECTED / INVALID STATUS\r\n");
    }
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
    p130_rtc_start();
    p130_debug_puts("[MAP] PHYSICAL W3 MAPPER NOT INITIALIZED\r\n");
    p130_debug_puts("[P130] NEO GS / DMA NOT INITIALIZED\r\n");

    {
        volatile uint16_t rtc_poll_divider = 0u;
        uint8_t rtc_poll_phase = 0u;
        char last_second_tens = p130_rtc_second[0];
        char last_second_ones = p130_rtc_second[1];
        for (;;) {
            if (!p130_rtc_available) continue;
            ++rtc_poll_divider;
            if (rtc_poll_divider == 0u) {
                ++rtc_poll_phase;
                if (rtc_poll_phase >= 10u) {
                    rtc_poll_phase = 0u;
                    p130_rtc_read_current();
                    if (p130_rtc_second[0] != last_second_tens ||
                        p130_rtc_second[1] != last_second_ones) {
                        last_second_tens = p130_rtc_second[0];
                        last_second_ones = p130_rtc_second[1];
                        p130_ui_clock_update();
                    }
                }
            }
        }
    }
}
