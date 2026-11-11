#ifndef P130_MEMORY_H
#define P130_MEMORY_H

#include <stdint.h>

/* ATM Turbo 2+ capacity model: 1 MiB, 64 independently mapped 16 KiB pages.
 * This is accounting metadata only; it does not probe or touch physical RAM.
 */
#define P130_MEMORY_PAGE_COUNT 64u
#define P130_MEMORY_PAGE_SIZE  16384UL
#define P130_MEMORY_LIMIT      0x00100000UL
#define P130_MEMORY_PAGE_NONE  0xFFu

#define P130_PAGE_OWNER_BOOT_W3       0u
#define P130_PAGE_OWNER_STACK_W2      2u
#define P130_PAGE_OWNER_VIDEO_ATTR    3u
#define P130_PAGE_OWNER_RESIDENT_W1   5u
#define P130_PAGE_OWNER_VIDEO_CHARS   7u

uint8_t p130_memory_init(void);
uint8_t p130_page_alloc_topdown(void);
uint8_t p130_page_free(uint8_t page);
uint8_t p130_page_pin(uint8_t page);
uint8_t p130_page_unpin(uint8_t page);
uint8_t p130_page_refcount(uint8_t page);
uint8_t p130_page_is_allocated(uint8_t page);
uint8_t p130_page_is_reserved(uint8_t page);
uint8_t p130_memory_free_count(void);

#endif
