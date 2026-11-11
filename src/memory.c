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
