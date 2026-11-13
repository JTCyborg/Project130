#ifndef P130_MAP_H
#define P130_MAP_H

#include <stdint.h>

/* ATM Turbo 2+ W3 physical mapper. W0/W1/W2 are never changed. */
#define P130_MAP_PAGE_COUNT 64u
#define P130_MAP_PAGE_NONE  0xFFu
#define P130_MAP_BANK_DEPTH_MAX 8u

uint8_t p130_map_init(void);
uint8_t p130_map_w3_current(void);
uint8_t p130_map_w3_bank_enter(uint8_t page);
uint8_t p130_map_w3_bank_leave(void);
uint8_t p130_map_w3_bank_depth(void);
uint8_t p130_map_w3_hw_selftest(void);

#endif
