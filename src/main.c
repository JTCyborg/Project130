#include <stdint.h>
#include "diag.h"
#include "memory.h"
#include "rtc.h"

#define P130_CATALOGUE_ADDR 0xC800u
#define P130_CATALOGUE_SIZE 2048u

#define P130_BUILD_ID "P130-0.5.7-PRE-A1-CORE-DEFERRED"

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


extern volatile uint8_t p130_trdos_result;
extern uint8_t p130_neogs_startup(void);
extern volatile uint8_t p130_neogs_stage;
extern void p130_catalog_init(void);
extern void p130_catalog_poll(void);
extern void p130_hdd_probe(void);
extern void p130_hdd_list_root(void);
extern volatile uint8_t p130_hdd_present;
extern volatile uint8_t p130_hdd_sector_valid;
extern volatile uint8_t p130_hdd_error;
extern volatile uint8_t p130_hdd_last_status;
extern volatile uint8_t p130_hdd_capacity[4];
extern volatile uint16_t p130_hdd_fat_file_count;

static volatile uint8_t * const p130_trdos_catalogue =
    (volatile uint8_t *)P130_CATALOGUE_ADDR;

static void p130_trdos_list_catalogue(void)
{
    uint16_t offset;
    uint8_t files = 0u;

    p130_debug_puts("[TR-DOS] CATALOGUE FILES\r\n");
    for (offset = 0u; offset < P130_CATALOGUE_SIZE; offset += 16u) {
        uint8_t first = p130_trdos_catalogue[offset];
        uint8_t type = p130_trdos_catalogue[offset + 8u];
        uint8_t end = 8u;
        uint8_t i;

        if (first == 0u || first == 1u) continue;
        if (type != 'B' && type != 'C' && type != 'D' && type != '#') continue;

        while (end != 0u && p130_trdos_catalogue[offset + end - 1u] == ' ') --end;
        p130_debug_puts("  ");
        for (i = 0u; i < end; ++i) {
            uint8_t ch = p130_trdos_catalogue[offset + i];
            if (ch < 32u || ch > 126u) ch = '?';
            p130_debug_putc(ch);
        }
        if (end != 0u) {
            p130_debug_putc('.');
            p130_debug_putc(type);
        }
        p130_debug_puts("\r\n");
        ++files;
    }

    p130_debug_puts("[TR-DOS] DIRECTORY READ OK; FILE COUNT=");
    p130_debug_hex8(files);
    p130_debug_puts("\r\n");
}

static void p130_storage_start(void)
{
    p130_debug_puts("[TR-DOS] CATALOGUE PRELOAD STATUS=");
    p130_debug_hex8(p130_trdos_result);
    p130_debug_puts("\r\n");
    if (p130_trdos_result == 0u) {
        p130_debug_puts("[TR-DOS] DIRECTORY READ OK; 8 SECTORS / 2048 BYTES\r\n");
        p130_trdos_list_catalogue();
    } else {
        p130_debug_puts("[TR-DOS] DIRECTORY READ FAILED\r\n");
    }

    p130_debug_puts("[HDD] NEMO IDE MASTER PROBE BEGIN\r\n");
    p130_hdd_probe();
    if (!p130_hdd_present) {
        p130_debug_puts("[HDD] PROBE FAILED; ERROR=");
        p130_debug_hex8(p130_hdd_error);
        p130_debug_puts(" STATUS=");
        p130_debug_hex8(p130_hdd_last_status);
        p130_debug_puts("\r\n");
        return;
    }

    p130_debug_puts("[HDD] IDENTIFY DEVICE OK; LBA28 SECTORS=");
    p130_debug_hex8(p130_hdd_capacity[3]);
    p130_debug_hex8(p130_hdd_capacity[2]);
    p130_debug_hex8(p130_hdd_capacity[1]);
    p130_debug_hex8(p130_hdd_capacity[0]);
    if (!p130_hdd_sector_valid) {
        p130_debug_puts("\r\n[HDD] LBA 63 READ/BPB VALIDATION FAILED; ERROR=");
        p130_debug_hex8(p130_hdd_error);
        p130_debug_puts(" STATUS=");
        p130_debug_hex8(p130_hdd_last_status);
        p130_debug_puts("\r\n");
        return;
    }

    p130_debug_puts("\r\n[HDD] LBA 63 READ OK; BPB 512B; SIGNATURE 55AA\r\n");
    p130_hdd_list_root();
}

static char p130_rtc_display[8];

static void p130_ui_clock_update(void)
{
    p130_rtc_display[0] = p130_rtc_hour[0];
    p130_rtc_display[1] = p130_rtc_hour[1];
    p130_rtc_display[2] = ':';
    p130_rtc_display[3] = p130_rtc_minute[0];
    p130_rtc_display[4] = p130_rtc_minute[1];
    p130_rtc_display[5] = ':';
    p130_rtc_display[6] = p130_rtc_second[0];
    p130_rtc_display[7] = p130_rtc_second[1];
    __asm
        ld hl,_p130_rtc_display
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

void p130_c_entry(void)
{
    p130_debug_puts("\r\n[P130] C IMAGE EXECUTED\r\n");
    p130_debug_puts("[P130] Z88DK C ENTRY\r\n");
    p130_debug_puts("[P130] BUILD: " P130_BUILD_ID "\r\n");
    p130_debug_puts("[P130] ATM 80X25 CONSOLE READY\r\n");
    p130_debug_puts("[P130] DEBUG PORT EF READY\r\n");
    p130_debug_puts("[P130] ATM HOST BOOTSTRAP READY\r\n");

    /*
     * Keep the Project127 startup order:
     *   entry.asm: DI, stack, ATM paging, TR-DOS catalogue preload
     *   here:      UI/W3, RTC, memory manager, TR-DOS report, HDD
     * NeoGS is started only after the host-side storage stages.
     */
    p130_rtc_start();
    p130_report_memory();
    p130_storage_start();
    p130_debug_puts("[NEOGS] GS105a BOOTSTRAP LAUNCH BEGIN; TRACE=");
    if (p130_neogs_startup() == 0u) {
        p130_debug_puts("[NEOGS] NEOBOOT STARTED; GS105a ROM DISABLED\r\n");
        p130_debug_puts("[NEOGS] DMA/IPC PAYLOAD PATH HELD; MEMORY MAP NOT APPROVED\r\n");
    } else {
        p130_debug_puts("\r\n[NEOGS] BOOTSTRAP LAUNCH FAILED; STAGE=");
        p130_debug_hex8(p130_neogs_stage);
        p130_debug_puts("\r\n");
    }
    p130_catalog_init();
    p130_debug_puts("[MAP] PHYSICAL W3 MAPPER NOT INITIALIZED\r\n");
    p130_debug_puts("[NEOGS] DMA/IPC NOT INITIALIZED; PHYSICAL MAP PENDING\r\n");

    {
        volatile uint16_t rtc_poll_divider = 0u;
        uint8_t rtc_poll_phase = 0u;
        char last_second_tens = p130_rtc_second[0];
        char last_second_ones = p130_rtc_second[1];
        for (;;) {
            p130_catalog_poll();
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
