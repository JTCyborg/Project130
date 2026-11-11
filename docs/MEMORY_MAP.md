# Project130 memory-map policy

## 1. Separate address spaces

Project130 has at least three distinct address spaces:

- ATM host Z80 address space and its physical/banked memory;
- NeoGS Z80 address space and its local memory;
- x86 guest physical address space (1 MiB for the initial 8086 profile).

They are not interchangeable. A guest address is never an ATM physical address or a NeoGS hardware register address.

## 2. x86 guest memory

The guest has a custom 1 MiB memory configuration with a separately defined map for RAM, BIOS and device windows.

Do not assume the conventional IBM PC layout of 640 KiB RAM plus UMA. Do not hard-code a conventional PC memory map as a compatibility shortcut.

The exact guest ranges, BIOS placement, RAM reservations, video apertures and device windows remain **TBD** and require an explicit design decision before implementation.

## 3. NeoGS backing memory

Project126 contains a proposed NeoGS page allocation for guest RAM, firmware overlays, BIOS backing and video storage. Treat it as a design reference only. Confirm the target NeoGS board's usable RAM and the actual page-mapping constraints before adopting any page numbers or capacity assertions.

NeoGS-local memory mapping is separate from ATM's physical W3 mapper.

## 4. ATM host memory

Project129 demonstrated ATM-side physical page management and W3 mapping procedures. Project130 may reuse the design after porting and validating it in this repository.

The ATM host memory layout, reserved pages, resident image span, DMA staging buffers and video buffers must be documented together before those areas are allocated. The initial bootstrap currently reserves the resident image below #B000 and uses a stack below #C000, following the Project129 boot contract; this is a bootstrap placement, not the final system memory map.

## 5. Required map specification before x86 execution

The map specification must define:

- every guest RAM range and reserved range;
- BIOS ROM/overlay visibility and reset-vector mapping;
- VGA memory aperture and backing storage;
- device register windows;
- read/write behavior for unmapped ranges;
- wraparound and 20-bit physical-address behavior;
- initialization/reset values;
- test cases at every boundary.

No CPU execution milestone may silently invent these ranges.
