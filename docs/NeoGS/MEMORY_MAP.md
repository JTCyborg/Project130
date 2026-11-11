# Project130 NeoGS physical memory and DMA buffer map

Status: allocation worksheet, **not yet approved**. All physical addresses remain unassigned until the target NeoGS RAM capacity, paging behavior and DMA address semantics are confirmed.

This document is deliberately separate from the x86 guest memory map in `docs/MEMORY_MAP.md`.

## 1. Address spaces

| Space | Owner | Purpose | Addressing |
|---|---|---|---|
| ATM host Z80 | ATM Turbo 2+ | Host code, TR-DOS/HDD, physical memory mapper, DMA staging | Z80 logical windows plus ATM physical pages |
| NeoGS Z80 | NeoGS | Bootstrap, resident runtime, IPC endpoint and DMA backing | NeoGS-local logical windows plus NeoGS physical RAM |
| x86 guest | NeoGS software | 8086 Real Mode guest memory | Custom 1 MiB guest physical address space |
| ZX DMA aperture | ATM/NeoGS transport | Byte window used to generate DMA cycles | ATM-visible `0000–3FFF`; maps to a NeoGS-local DMA address |

An address in one row must never be silently reused as an address in another row.

## 2. NeoGS physical memory inventory

| Property | Project130 value | State |
|---|---:|---|
| Installed/usable NeoGS RAM | TBD | Must be confirmed |
| Physical page size | TBD | Must be confirmed |
| Page count | TBD | Derived only after capacity and page size are known |
| Main page selector semantics | TBD | Must be confirmed |
| Extended page selector semantics | TBD | Must be confirmed |
| DMA address width / valid range | TBD | Must be confirmed |
| ROM disable behavior | `GSCFG0 #0F`, `NOROM bit 0` | Documented; target validation pending |

The Project126 proposal of 4 MiB / 256 pages × 16 KiB is not adopted as a Project130 fact.

## 3. Reserved-region allocation worksheet

The following regions must be allocated without overlap. Their final physical ranges and page IDs are intentionally blank.

| Region | Required capacity | Physical base / pages | CPU window | Notes |
|---|---:|---|---|---|
| Bootstrap execution | Bootstrap image size | TBD | ROM receive address `#4000` before ROM disable | Bootstrap source must fit the GS105a receive contract |
| Resident NeoGS runtime | TBD | TBD | TBD | Code, private state and stack |
| Resident IPC/control | TBD | TBD | TBD | Must remain accessible while DMA window is mapped |
| DMA RX backing | At least one negotiated frame | TBD | Through ZX DMA aperture | NeoGS receives ATM→NeoGS bytes |
| DMA TX backing | At least one negotiated frame | TBD | Through ZX DMA aperture | NeoGS supplies NeoGS→ATM bytes |
| Guest x86 RAM backing | 1 MiB logical | TBD | NeoGS-managed | Independent from DMA buffers |
| x86 BIOS/firmware backing | TBD | TBD | NeoGS-managed | Distinct from guest RAM where required |
| VGA state/VRAM backing | TBD | TBD | NeoGS-managed | Separate from ATM presentation buffers |
| ATM presentation frame | Per agreed frame ABI | TBD | ATM-owned | Converted/presented by ATM host |

RX and TX may share storage only if the protocol explicitly serializes ownership and the DMA direction switch procedure is followed. The initial implementation should prefer distinct buffers.

## 4. ATM staging-buffer worksheet

| Buffer | Direction | ATM physical page | Z80 logical address | Capacity | Owner/lifetime |
|---|---|---|---|---:|---|
| Host→NeoGS staging | ATM→NeoGS | TBD | TBD | TBD | ATM owns until DMA completion |
| NeoGS→Host staging | NeoGS→ATM | TBD | TBD | TBD | ATM owns while receiving |
| Control/header scratch | Bidirectional | TBD | TBD | TBD | Must not overlap resident host stack/code |
| Video frame staging | NeoGS→ATM | TBD | TBD | TBD | ATM owns until presentation completes |

ATM host buffers must be reconciled with the existing Project130 resident image at `#6000`, UI at `#A000`, stack below `#C000`, TR-DOS catalogue at `#C800`, and the physical W3 mapper. These current addresses do not imply that any of them is a valid DMA staging allocation.

## 5. DMA aperture rules

The Project129 NeoGS ZX-DMA reference records the following behavior:

- DMA register block on NeoGS: `MOD=#1B`, `HAD=#1C`, `MAD=#1D`, `LAD=#1E`, `CST=#1F`.
- ZX DMA module selector: `1`.
- ATM-visible transfer aperture: `0000–3FFF`.
- Read direction: enable ROM at the aperture, perform and discard one dummy read, then consume the requested bytes.
- Write direction: first aperture write is the first payload byte; no dummy write.
- Disable DMA between direction changes.
- No interrupts while the aperture can expose DMA data to the interrupt vector.
- Every wait is bounded and every exit leaves DMA disabled/idle.

These are driver requirements, not a finalized physical allocation.

## 6. Approval gate

Concrete addresses may be assigned only after all of the following are recorded:

1. Target NeoGS board/emulator RAM capacity and usable address range.
2. Page size and exact main/extended page selector encoding.
3. DMA address width and whether DMA addresses are linear physical addresses.
4. The mapping that connects the ATM-visible aperture to the selected NeoGS DMA backing address.
5. ATM physical page capacity and W3 ownership/mapper procedure.
6. Non-overlapping allocations for resident code/stack, RX, TX, guest memory, BIOS and video.
7. Maximum frame size and whether RX/TX buffers can be reused.

No code may use a guessed value from this worksheet. No runtime self-test or synthetic DMA traffic is to be embedded in Project130.
