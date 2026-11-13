#include <stdint.h>
#include "map.h"
#include "memory.h"

/*
 * Project130 ATM2+ physical W3 mapper.
 *
 * The UI/video bootstrap has already enabled the shadow ports and restored
 * W3=P0. This mapper owns only W3 (#C000-#FFFF); W0/W1/W2 are never written.
 * Page selection follows the Project129 hardware contract:
 *   port #FFF7, data byte #7F-page.
 *
 * Calls are serialized by the resident main loop. No IRQ-driven UI or mapper
 * access is enabled yet; add a critical-section/ownership protocol before
 * introducing concurrent callers.
 */
static uint8_t p130_map_ready;
static uint8_t p130_map_shadow_w3;
static uint8_t p130_map_bank_stack[P130_MAP_BANK_DEPTH_MAX];
static uint8_t p130_map_bank_depth;

volatile uint8_t p130_map_hw_encoded;
extern void p130_map_hw_write(void);

static uint8_t p130_map_hw_apply(uint8_t page)
{
    if (page >= P130_MAP_PAGE_COUNT) return 1u;
    p130_map_hw_encoded = (uint8_t)(0x7Fu - page);
    p130_map_hw_write();
    return 0u;
}

uint8_t p130_map_init(void)
{
    if (!p130_page_is_reserved(0u) ||
        !p130_page_is_reserved(2u) ||
        !p130_page_is_reserved(3u) ||
        !p130_page_is_reserved(5u) ||
        !p130_page_is_reserved(7u)) return 1u;

    p130_map_ready = 0u;
    p130_map_bank_depth = 0u;
    p130_map_shadow_w3 = 0u;

    /* UI init has restored P0; explicitly synchronize the physical latch. */
    if (p130_map_hw_apply(0u) != 0u) return 2u;
    p130_map_ready = 1u;
    return 0u;
}

uint8_t p130_map_w3_current(void)
{
    if (!p130_map_ready) return P130_MAP_PAGE_NONE;
    return p130_map_shadow_w3;
}

uint8_t p130_map_w3_bank_enter(uint8_t page)
{
    uint8_t status;

    if (!p130_map_ready || page >= P130_MAP_PAGE_COUNT) return 1u;
    if (!p130_page_is_allocated(page) || p130_page_is_reserved(page)) return 2u;
    if (p130_map_bank_depth >= P130_MAP_BANK_DEPTH_MAX) return 3u;
    if (p130_map_shadow_w3 == page) return 4u;

    status = p130_page_pin(page);
    if (status != 0u) return 5u;
    status = p130_map_hw_apply(page);
    if (status != 0u) {
        (void)p130_page_unpin(page);
        return 6u;
    }

    p130_map_bank_stack[p130_map_bank_depth++] = page;
    p130_map_shadow_w3 = page;
    return 0u;
}

uint8_t p130_map_w3_bank_leave(void)
{
    uint8_t current_page;
    uint8_t previous_page;
    uint8_t status;

    if (!p130_map_ready || p130_map_bank_depth == 0u) return 1u;

    current_page = p130_map_bank_stack[p130_map_bank_depth - 1u];
    previous_page = (p130_map_bank_depth > 1u)
        ? p130_map_bank_stack[p130_map_bank_depth - 2u]
        : 0u;

    if (p130_map_shadow_w3 != current_page) return 2u;
    status = p130_map_hw_apply(previous_page);
    if (status != 0u) return 3u;

    status = p130_page_unpin(current_page);
    if (status != 0u) {
        (void)p130_map_hw_apply(current_page);
        return 4u;
    }

    --p130_map_bank_depth;
    p130_map_shadow_w3 = previous_page;
    return 0u;
}

uint8_t p130_map_w3_bank_depth(void)
{
    return p130_map_bank_depth;
}

/*
 * Non-destructive physical mapper test. It allocates two real ATM pages,
 * saves the original bytes at two offsets, writes different signatures,
 * switches W3 between pages, verifies isolation, then restores all bytes.
 */
uint8_t p130_map_w3_hw_selftest(void)
{
    volatile uint8_t *window = (volatile uint8_t *)0xC000u;
    uint8_t page1 = P130_MEMORY_PAGE_NONE;
    uint8_t page2 = P130_MEMORY_PAGE_NONE;
    uint8_t page1_saved = 0u;
    uint8_t page2_saved = 0u;
    uint8_t result = 0u;
    uint8_t cleanup_status;
    uint8_t p1a = 0u, p1b = 0u, p2a = 0u, p2b = 0u;

    if (!p130_map_ready || p130_map_bank_depth != 0u) return 1u;

    page1 = p130_page_alloc_topdown();
    if (page1 == P130_MEMORY_PAGE_NONE) return 2u;
    page2 = p130_page_alloc_topdown();
    if (page2 == P130_MEMORY_PAGE_NONE) {
        (void)p130_page_free(page1);
        return 3u;
    }

    if (p130_map_w3_bank_enter(page1) != 0u) {
        result = 4u;
        goto cleanup;
    }
    p1a = window[0x0100u];
    p1b = window[0x3F00u];
    page1_saved = 1u;
    window[0x0100u] = 0xA5u;
    window[0x3F00u] = 0x5Au;

    if (p130_map_w3_bank_enter(page2) != 0u) {
        result = 5u;
        goto cleanup;
    }
    p2a = window[0x0100u];
    p2b = window[0x3F00u];
    page2_saved = 1u;
    window[0x0100u] = 0x3Cu;
    window[0x3F00u] = 0xC3u;

    if (p130_map_w3_bank_leave() != 0u) {
        result = 6u;
        goto cleanup;
    }
    if (window[0x0100u] != 0xA5u || window[0x3F00u] != 0x5Au) {
        result = 7u;
        goto cleanup;
    }
    window[0x0100u] = p1a;
    window[0x3F00u] = p1b;
    page1_saved = 0u;

    if (p130_map_w3_bank_leave() != 0u) {
        result = 8u;
        goto cleanup;
    }
    if (p130_map_w3_bank_enter(page2) != 0u) {
        result = 9u;
        goto cleanup;
    }
    if (window[0x0100u] != 0x3Cu || window[0x3F00u] != 0xC3u) {
        result = 10u;
        goto cleanup;
    }
    window[0x0100u] = p2a;
    window[0x3F00u] = p2b;
    page2_saved = 0u;
    if (p130_map_w3_bank_leave() != 0u) {
        result = 11u;
        goto cleanup;
    }

cleanup:
    while (p130_map_bank_depth != 0u) {
        cleanup_status = p130_map_w3_bank_leave();
        if (cleanup_status != 0u) {
            if (result == 0u) result = (uint8_t)(0x20u | cleanup_status);
            break;
        }
    }

    /* Best-effort restoration if a failure interrupted the normal path. */
    if (p130_map_bank_depth == 0u && page1_saved) {
        if (p130_map_w3_bank_enter(page1) == 0u) {
            window[0x0100u] = p1a;
            window[0x3F00u] = p1b;
            if (p130_map_w3_bank_leave() != 0u && result == 0u) result = 0x2Au;
        } else if (result == 0u) result = 0x2Bu;
    }
    if (p130_map_bank_depth == 0u && page2_saved) {
        if (p130_map_w3_bank_enter(page2) == 0u) {
            window[0x0100u] = p2a;
            window[0x3F00u] = p2b;
            if (p130_map_w3_bank_leave() != 0u && result == 0u) result = 0x2Cu;
        } else if (result == 0u) result = 0x2Du;
    }

    if (page1 != P130_MEMORY_PAGE_NONE && p130_page_refcount(page1) == 0u) {
        if (p130_page_free(page1) != 0u && result == 0u) result = 0x2Eu;
    }
    if (page2 != P130_MEMORY_PAGE_NONE && p130_page_refcount(page2) == 0u) {
        if (p130_page_free(page2) != 0u && result == 0u) result = 0x2Fu;
    }
    if (p130_map_w3_current() != 0u && result == 0u) result = 0x30u;
    return result;
}
