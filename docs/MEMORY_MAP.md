# Project130 memory-map policy

## 1. Separate address spaces

Project130 has distinct address spaces:
- ATM host Z80 address space and ATM physical/banked memory;
- NeoGS Z80 logical windows and NeoGS physical RAM;
- x86 guest physical address space (1 MiB, Intel 8086 Real Mode).

They are not interchangeable. A guest address is never an ATM physical address, NeoGS hardware register address, or NeoGS physical page number.

## 2. NeoGS physical backing

APPROVED BASELINE (2026-11-12): Project130 adopts the Project126 NeoGS physical memory map.

- 4 MiB physical RAM, 256 pages of 16 KiB.
- Resident kernel: pages 00h–0Fh.
- SYSBIOS: pages 10h–1Fh.
- VGA BIOS: pages 20h–2Fh.
- VGA VRAM: pages 30h–3Fh.
- Frame workspace: pages 40h–41h.
- DMA staging: page 42h.
- IPC/control: page 43h.
- Guest RAM backing: pages 44h–83h (1 MiB).
- Reserved: pages 84h–FFh.

The NeoGS logical window selectors and DMA rules are specified in docs/NeoGS/MEMORY_MAP.md.

## 3. x86 guest physical memory

The initial guest profile is Intel 8086 Real Mode with a 20-bit, 1 MiB physical address space (00000h–FFFFFh), wrapping at 1 MiB. The Project126 guest map is adopted as the Project130 baseline:

| Guest range | Size | Region |
|---|---:|---|
| 00000h–9FFFFh | 640 KiB | Low RAM |
| A0000h–BFFFFh | 128 KiB | VGA aperture |
| C0000h–C7FFFh | 32 KiB | VGA BIOS |
| C8000h–FDFFFh | 216 KiB | High RAM |
| FE000h–FFFFFh | 8 KiB | System BIOS |

The physical SYSBIOS slot is 256 KiB (pages 10h–1Fh); the initial 8 KiB BIOS image is mapped into the guest 8 KiB range at FE000h–FFFFFh. BIOS writes are rejected. The reset vector is FFFF:0000, physical FFFF0h, offset 1FF0h within the mapped BIOS image.

The guest map is a software memory model backed by NeoGS RAM. It does not imply direct hardware access by the guest CPU.

## 4. ATM host memory

ATM host allocations remain separate. The existing resident image, UI, stack, TR-DOS catalogue and physical W3 mapper keep their own ATM-side ownership. The NeoGS DMA staging page is not an ATM physical page. ATM staging buffers must be allocated and mapped only through the established ATM mapper procedure.

## 5. BIOS execution gate

The 8086 must not be released from reset until:
1. selected BIOS file is validated as exactly 8192 bytes;
2. IMAGE_BEGIN / IMAGE_FRAGMENT / IMAGE_FINISH complete over Project130 DMA/IPC;
3. NeoGS verifies installed bytes in the SYSBIOS physical slot;
4. guest FE000h–FFFFFh reads back the same 8192 bytes;
5. reset-vector bytes at FFFF0h are readable and valid;
6. CPU state is initialized to CS:IP=FFFF:0000 and FLAGS=0002h.

A TR-DOS read or a sent DMA frame alone is not BIOS execution success.
