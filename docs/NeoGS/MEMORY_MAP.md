# Project130 NeoGS physical memory and DMA buffer map

Status: APPROVED BASELINE — Project126 NeoGS physical map adopted by explicit project decision on 2026-11-12.

Project130 uses the Project126 NeoGS physical RAM allocation as its baseline. This supersedes the earlier TBD worksheet and the prohibition on adopting Project126 page numbers. Project130 transport ownership rules remain unchanged: ATM owns physical devices and DMA orchestration; NeoGS performs no physical ATM I/O.

## 1. NeoGS physical RAM

| Property | Value |
|---|---:|
| Usable physical RAM | 4 MiB |
| Page size | 16 KiB (0x4000) |
| Physical pages | 256 (0x00–0xFF) |
| Physical address range | 0x000000–0x3FFFFF |
| SYSBIOS slot | pages 0x10–0x1F (256 KiB) |
| BIOS guest-visible image | 8 KiB at guest 0xFE000–0xFFFFF |

This physical map is distinct from the NeoGS Z80 logical 64 KiB window map, ATM physical pages, the ZX DMA aperture, and the x86 guest physical address space.

## 2. Fixed physical allocation

Half-open page ranges are used: [base, base + count).

| Region | First page | Pages | Physical range |
|---|---:|---:|---:|
| Resident kernel/runtime | 0x00 | 0x10 | 0x000000–0x03FFFF |
| SYSBIOS storage | 0x10 | 0x10 | 0x040000–0x07FFFF |
| VGA BIOS storage | 0x20 | 0x10 | 0x080000–0x0BFFFF |
| VGA VRAM | 0x30 | 0x10 | 0x0C0000–0x0FFFFF |
| ATM frame workspace | 0x40 | 0x02 | 0x100000–0x107FFF |
| DMA staging | 0x42 | 0x01 | 0x108000–0x10BFFF |
| IPC/control | 0x43 | 0x01 | 0x10C000–0x10FFFF |
| x86 guest RAM backing | 0x44 | 0x40 | 0x110000–0x14FFFF |
| Reserved | 0x84 | 0x7C | 0x210000–0x3FFFFF |

## 3. Resident Z80 windows

- WIN0 / 0x0000–0x3FFF: fixed resident kernel and data, physical page 0x00.
- WIN1 / 0x4000–0x7FFF: operational stack and fixed runtime data, physical page 0x03.
- WIN2 / 0x8000–0xBFFF: overlay aperture, selected through MPAG port 0x00.
- WIN3 / 0xC000–0xFFFF: banked guest-memory aperture, selected through MPAGEX port 0x10. Resident code, data and stack must never execute from or be stored in WIN3.

MPAG selectors encode ROR8(physical_page), i.e. one RRCA before OUT. Fixed overlays: X86IO page 0x04/selector 0x02; X86ALU page 0x05/selector 0x82; X86DEV page 0x06/selector 0x03; X86EXEC page 0x07/selector 0x83; X86VGA page 0x08; X86VID page 0x09.

## 4. DMA and host staging

The physical DMA staging page is 0x42. The ZX-visible ATM aperture remains 0x0000–0x3FFF; it is not itself the NeoGS physical address. DMA registers are NeoGS-local (MOD=#1B, HAD=#1C, MAD=#1D, LAD=#1E, CST=#1F), and must only be accessed by NeoGS-side code.

Preserve the established DMA rules:
- Select ZX DMA module 1.
- DMA read: enable the ROM aperture, perform and discard one dummy read, then consume payload; do not decrement the programmed address.
- DMA write: no dummy write; the first write is payload byte zero.
- Disable DMA before changing direction.
- Keep interrupts disabled while the ROM aperture exposes DMA data until vector handling is specified.
- All waits are bounded; all exits leave DMA disabled/idle.

ATM-side staging remains owned and mapped by the ATM host. It must not overlap resident host code, stack, catalogue, or video allocations.

## 5. Guest BIOS relationship

The 256 KiB physical SYSBIOS slot (pages 0x10–0x1F) backs the guest system BIOS. Initial BIOS images are 8 KiB and are exposed to the 8086 at guest physical 0xFE000–0xFFFFF. This is not an identity mapping between guest addresses and NeoGS physical pages.

## 6. Integrity checks

The allocation is contiguous and non-overlapping: kernel ends at page 0x10; SYSBIOS at 0x20; VGA BIOS at 0x30; VRAM at 0x40; frame workspace at 0x42; DMA staging at 0x43; IPC at 0x44; guest RAM at 0x84; reserved memory at page 0x100.

Do not change these allocations without an explicit architecture decision and corresponding updates to shared constants and the guest-memory backend.
