#include "memory.h"

#define P130_PAGE_FREE      0u
#define P130_PAGE_RESERVED  1u
#define P130_PAGE_ALLOCATED 2u

static uint8_t p130_page_state[P130_MEMORY_PAGE_COUNT];
static uint8_t p130_page_refs[P130_MEMORY_PAGE_COUNT];
static uint8_t p130_memory_ready;

static uint8_t p130_page_valid(uint8_t page)
{
    return (uint8_t)(page < P130_MEMORY_PAGE_COUNT);
}

static uint8_t p130_page_reserve(uint8_t page)
{
    if (!p130_page_valid(page)) return 1u;
    if (p130_page_state[page] == P130_PAGE_ALLOCATED) return 2u;
    p130_page_state[page] = P130_PAGE_RESERVED;
    p130_page_refs[page] = 0u;
    return 0u;
}

uint8_t p130_memory_init(void)
{
    uint16_t page;

    p130_memory_ready = 0u;
    for (page = 0u; page < P130_MEMORY_PAGE_COUNT; ++page) {
        p130_page_state[page] = P130_PAGE_FREE;
        p130_page_refs[page] = 0u;
    }

    /* Match the verified ATM2+ bootstrap ownership used by Project129.
     * P3/P7 are reserved for the future ATM video subsystem, not initialized here.
     */
    if (p130_page_reserve(P130_PAGE_OWNER_BOOT_W3) != 0u) return 1u;
    if (p130_page_reserve(P130_PAGE_OWNER_STACK_W2) != 0u) return 2u;
    if (p130_page_reserve(P130_PAGE_OWNER_VIDEO_ATTR) != 0u) return 3u;
    if (p130_page_reserve(P130_PAGE_OWNER_RESIDENT_W1) != 0u) return 4u;
    if (p130_page_reserve(P130_PAGE_OWNER_VIDEO_CHARS) != 0u) return 5u;

    p130_memory_ready = 1u;
    return 0u;
}

uint8_t p130_page_alloc_topdown(void)
{
    uint16_t page;
    if (!p130_memory_ready) return P130_MEMORY_PAGE_NONE;

    page = P130_MEMORY_PAGE_COUNT;
    while (page != 0u) {
        --page;
        if (p130_page_state[page] == P130_PAGE_FREE) {
            p130_page_state[page] = P130_PAGE_ALLOCATED;
            p130_page_refs[page] = 0u;
            return (uint8_t)page;
        }
    }
    return P130_MEMORY_PAGE_NONE;
}

uint8_t p130_page_free(uint8_t page)
{
    if (!p130_memory_ready || !p130_page_valid(page)) return 1u;
    if (p130_page_state[page] != P130_PAGE_ALLOCATED) return 2u;
    if (p130_page_refs[page] != 0u) return 3u;
    p130_page_state[page] = P130_PAGE_FREE;
    return 0u;
}

uint8_t p130_page_pin(uint8_t page)
{
    if (!p130_memory_ready || !p130_page_valid(page)) return 1u;
    if (p130_page_state[page] != P130_PAGE_ALLOCATED) return 2u;
    if (p130_page_refs[page] == 0xFFu) return 3u;
    ++p130_page_refs[page];
    return 0u;
}

uint8_t p130_page_unpin(uint8_t page)
{
    if (!p130_memory_ready || !p130_page_valid(page)) return 1u;
    if (p130_page_state[page] != P130_PAGE_ALLOCATED) return 2u;
    if (p130_page_refs[page] == 0u) return 3u;
    --p130_page_refs[page];
    return 0u;
}

uint8_t p130_page_refcount(uint8_t page)
{
    if (!p130_memory_ready || !p130_page_valid(page)) return 0xFFu;
    return p130_page_refs[page];
}

uint8_t p130_page_is_allocated(uint8_t page)
{
    if (!p130_memory_ready || !p130_page_valid(page)) return 0u;
    return (uint8_t)(p130_page_state[page] == P130_PAGE_ALLOCATED);
}

uint8_t p130_page_is_reserved(uint8_t page)
{
    if (!p130_memory_ready || !p130_page_valid(page)) return 0u;
    return (uint8_t)(p130_page_state[page] == P130_PAGE_RESERVED);
}

uint8_t p130_memory_free_count(void)
{
    uint16_t page;
    uint8_t count = 0u;
    if (!p130_memory_ready) return 0u;
    for (page = 0u; page < P130_MEMORY_PAGE_COUNT; ++page) {
        if (p130_page_state[page] == P130_PAGE_FREE) ++count;
    }
    return count;
}

/* Metadata-only test. It never maps, reads, or writes physical RAM. */
uint8_t p130_memory_selftest(void)
{
    static uint8_t allocated[P130_MEMORY_PAGE_COUNT];
    uint8_t count = 0u;
    uint8_t page;
    uint16_t i;

    if (!p130_memory_ready) return 1u;
    if (!p130_page_is_reserved(P130_PAGE_OWNER_BOOT_W3) ||
        !p130_page_is_reserved(P130_PAGE_OWNER_STACK_W2) ||
        !p130_page_is_reserved(P130_PAGE_OWNER_VIDEO_ATTR) ||
        !p130_page_is_reserved(P130_PAGE_OWNER_RESIDENT_W1) ||
        !p130_page_is_reserved(P130_PAGE_OWNER_VIDEO_CHARS)) return 2u;
    if (p130_page_free(P130_PAGE_OWNER_STACK_W2) == 0u) return 3u;
    if (p130_page_pin(P130_PAGE_OWNER_STACK_W2) == 0u) return 4u;

    while ((page = p130_page_alloc_topdown()) != P130_MEMORY_PAGE_NONE) {
        if (count >= P130_MEMORY_PAGE_COUNT) return 5u;
        allocated[count++] = page;
    }
    if (count != 59u) return 6u;
    if (allocated[0] != 63u || allocated[58] != 1u) return 7u;
    if (p130_memory_free_count() != 0u) return 8u;
    if (p130_page_alloc_topdown() != P130_MEMORY_PAGE_NONE) return 9u;

    page = allocated[0];
    if (p130_page_pin(page) != 0u || p130_page_pin(page) != 0u) return 10u;
    if (p130_page_refcount(page) != 2u) return 11u;
    if (p130_page_free(page) == 0u) return 12u;
    if (p130_page_unpin(page) != 0u || p130_page_unpin(page) != 0u) return 13u;
    if (p130_page_unpin(page) == 0u) return 14u;
    if (p130_page_free(page) != 0u) return 15u;
    if (p130_page_alloc_topdown() != page) return 16u;

    for (i = 0u; i < count; ++i) {
        if (p130_page_free(allocated[i]) != 0u) return 17u;
    }
    if (p130_memory_free_count() != 59u) return 18u;
    return 0u;
}
