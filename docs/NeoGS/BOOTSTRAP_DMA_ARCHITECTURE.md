# Project130 NeoGS bootstrap and DMA transport architecture

Status: stage-0 bootstrap and GS105a launcher implemented in source; DMA/IPC payload transport and physical map remain gated. No target validation is implied.

## 1. Startup decision

The stock NeoGS GS105a ROM is retained only as a temporary bootstrap launcher.

1. ATM host locates and validates the small Project130 bootstrap image.
2. ATM host uses the stock GS105a receive command `#14` to place that image at the ROM-defined receive address (`#4000`).
3. ATM host uses command `#13` to transfer control to the bootstrap at `#4000`.
4. The bootstrap establishes a private stack, disables the ZX DMA channel, and updates `GSCFG0` (`#0F`) using the documented NOROM/EXPAG transition.
5. The bootstrap emits `E0` after the transition as an entry/transition acknowledgement, then emits `A1` only after the ATM host consumes `E0`; it remains in an idle loop. It does not yet start a DMA receiver because the physical backing map and buffer addresses are unapproved.
6. After the handoff, the stock ROM byte-stream protocol is closed. No resident firmware, module, command, response, event, diagnostic or video payload may be transferred through GSDAT.

The GS105a `#14/#13` exchange is the only legacy byte-channel exception. It transfers the bootstrap image itself and nothing else. In particular, the Project126 pattern of sending a resident core over GSDAT after the ROM has been disabled is **not** adopted.

## 1.1 Bootstrap diagnostics

The ATM launcher emits progress characters `1` through `9` on the existing debug channel `#EF` and console output. The corresponding stage codes are:

1. TR-DOS lookup of `NEOBOOT.C`.
2. TR-DOS file metadata lookup.
3. Bootstrap length validation (1..256 bytes).
4. Read the bootstrap sector into ATM scratch at `#C000`.
5. GS105a reset command `#F4`.
6. GS105a receive command `#14` and its header.
7. Transfer the bootstrap bytes through GSDAT.
8. Jump command `#13` and its target address.
9. Wait for and read the bootstrap `E0` transition acknowledgement, then the `A1` ready acknowledgement.

On a returned failure, the host also prints the last stage code as two hexadecimal digits. If execution stops without returning, the last progress character narrows the blocked operation. These markers are diagnostics only; they do not claim that the bootstrap or DMA transport has passed runtime validation.

## 2. Ownership and port boundary

- ATM Turbo 2+ remains the owner of physical devices, ATM physical memory mapping and host-side DMA orchestration.
- ATM-side code uses only the documented host-visible NeoGS command/status/data interface for the bootstrap handoff and IPC control plane.
- ATM-side code must not write NeoGS-local DMA registers as if they were ATM ports.
- NeoGS code must not perform physical ATM I/O. Guest x86 IN/OUT is implemented by software virtual devices and host-service requests.
- No IRQ is enabled during bootstrap or initial transport bring-up. IRQ policy is a later decision after vectors, stack, acknowledgement and ownership are specified.

Project129's NeoGS port reference lists the NeoGS-local ZX DMA registers as `DMA_MOD=#1B`, `DMA_HAD=#1C`, `DMA_MAD=#1D`, `DMA_LAD=#1E`, `DMA_CST=#1F`. They are programmed by NeoGS-side code, not by direct ATM port writes.

## 3. DMA transfer rules

The Project129 `docs/NeoGS/dma_zx_doc.txt` describes these hardware rules; the Project130 implementation must preserve them:

- Select ZX DMA module 1 on the NeoGS side.
- Program the exact requested start address before enabling DMA.
- DMA read: discard the first byte read from the ROM aperture; it is a dummy. The next byte is the requested first payload byte. Do not subtract one from the programmed address.
- DMA write: no dummy write; the first write is payload byte zero.
- Never interleave read and write directions. Disable DMA before changing direction and re-enable it for the next transfer.
- DMA read requires the ATM ROM aperture at `0000–3FFF` to be enabled so the DMA read cycles are generated. DMA write can target the aperture while RAM is mapped there.
- Keep interrupts disabled while the ROM aperture is exposed until the IM1/vector interaction is explicitly designed.
- All polling and completion waits are bounded. Success and failure exits leave DMA disabled or in a documented idle state.

These are documented device constraints, not evidence that Project130 has validated a DMA transfer.

## 4. Project130 transport ABI

Project130 owns its transport ABI. Project126's message format and loader are references for review, not an automatically accepted wire format.

Before enabling payload traffic, the Project130 ABI must define:

- magic and ABI version;
- message type, service and operation;
- sequence number and payload length;
- CRC algorithm, covered bytes and validation order;
- request/response completion and stale-response handling;
- timeout, cancellation and resynchronization;
- DMA direction, buffer ownership and lifetime;
- maximum frame, fragmentation and wrap behavior.

The control plane may use the documented NeoGS command/status handshake. Application payload bytes must use DMA only.

## 5. Memory-map boundary

The NeoGS physical map and DMA buffer addresses are a separate Project130 design artifact. They must not be inferred from the x86 guest address map or copied from Project126.

The separate map specification must identify and keep distinct:

1. NeoGS local physical RAM capacity, page size, page selectors and reserved regions.
2. NeoGS DMA backing range and the ZX-visible `0000–3FFF` aperture mapping.
3. ATM host staging pages, Z80 window addresses, alignment, ownership and buffer lifetime.
4. x86 guest physical memory (custom 1 MiB address space), which is not a DMA address space.

No Project126 4 MiB / 256-page layout, page number or DMA address is accepted by this architecture decision. The actual board/emulator memory capability and mapping semantics must be established before concrete addresses are assigned.

Until that separate map is approved:
- do not hard-code DMA backing addresses or ATM staging addresses;
- do not start resident firmware/module payload transfers;
- do not start the x86 guest;
- keep the transport disabled rather than substituting guessed addresses.

## 6. Implementation order

1. Complete and approve the separate Project130 NeoGS/ATM memory and DMA-buffer map.
2. Add the small Project130 bootstrap image and bounded GS105a `#14/#13` launcher.
3. Implement ROM disable and the resident-runtime handoff.
4. Implement Project130 DMA/IPC control plane and both transfer directions using the approved map.
5. Integrate selected TR-DOS file loading only after the transport is operational.
6. Record build evidence separately from external emulator/runtime validation.

No runtime self-tests, synthetic payloads, benchmark routines or test-only behavior are to be added to Project130.
