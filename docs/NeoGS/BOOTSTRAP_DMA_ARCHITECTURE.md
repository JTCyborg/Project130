# Project130 NeoGS bootstrap and DMA transport architecture

Status: architecture decision recorded; implementation and target validation pending.

## 1. Startup decision

The stock NeoGS GS105a ROM is retained only as a temporary bootstrap launcher.

1. ATM host locates and validates a small Project130 NeoGS bootstrap image.
2. ATM host uses the stock GS105a receive command `#14` to place that bootstrap at the ROM-defined receive address.
3. ATM host uses command `#13` to transfer control to the bootstrap.
4. The bootstrap establishes its private runtime state and disables the stock ROM through the NeoGS configuration mechanism (`GSCFG0`, port `#0F`, `NOROM` bit).
5. The bootstrap starts the Project130 resident runtime and establishes the Project130 DMA/IPC endpoint.
6. After the transition, the stock ROM byte-stream interface is not used for application payloads. Resident firmware, modules, requests, responses, events, diagnostics and video data use the Project130 DMA/IPC transport.

The GS105a `#14/#13` exchange is a narrowly scoped compatibility exception for initial bootstrap only. It is not a general-purpose payload channel.

## 2. Ownership and port boundary

- ATM Turbo 2+ remains the owner of physical devices, physical memory mapping and DMA orchestration.
- ATM-side code may use the documented host-visible NeoGS control/status interface for startup and IPC control.
- ATM-side code must not access NeoGS-local DMA programming ports as though they were ATM ports.
- NeoGS code must not perform physical ATM I/O. Guest x86 IN/OUT is handled by software virtual devices and host-service messages.
- No IRQ is enabled during initial transport bring-up. IRQ policy is a later milestone after vectors, stack, acknowledgement and ownership are specified.

The Project129 reference lists the NeoGS-local DMA register block as `DMA_MOD=#1B`, `DMA_HAD=#1C`, `DMA_MAD=#1D`, `DMA_LAD=#1E`, `DMA_CST=#1F`; these are not direct ATM-side programming ports.

## 3. DMA transfer rules to preserve

The Project129 NeoGS ZX-DMA documentation records the following hardware behavior. The Project130 driver must preserve these rules:

- Select the ZX DMA module (module value 1) on the NeoGS side.
- Program the exact requested DMA address before enabling DMA.
- For DMA reads, discard the first byte read from the ROM window; it is a dummy value. The next read is the requested first payload byte.
- For DMA writes, do not emit a dummy byte; the first write is payload byte zero.
- Do not interleave read and write directions. Disable DMA and re-enable it after changing direction.
- A DMA read requires the ATM ROM window at `0000–3FFF` to be enabled so the DMA read cycles are generated. A DMA write can target the window while RAM is mapped there.
- Keep interrupts disabled while the DMA window is exposed until the interrupt/vector interaction is explicitly designed.
- All polling and completion waits must be bounded. Every exit path must leave DMA disabled or in a documented idle state.

These are documented device rules, not evidence that Project130 has already validated its own driver or buffers.

## 4. Project130 protocol boundary

The Project130 transport ABI is owned by Project130. Project126's message format and loader are references for design review, not automatically accepted interfaces.

Before payload transport is enabled, the Project130 ABI must specify:

- magic and ABI version;
- message type and service/operation;
- sequence number and payload length;
- CRC and validation rules;
- command/response completion semantics;
- timeout, cancellation and resynchronization;
- DMA direction, buffer ownership and lifetime;
- maximum frame and fragmentation behavior.

Legacy GSDAT byte streaming is prohibited for application payloads after bootstrap.

## 5. Memory and DMA buffer map — intentionally unresolved

No Project126 physical page allocation or buffer address is adopted by this decision.

A separate Project130 memory-map specification must define and approve these distinct address spaces:

1. **NeoGS local physical memory:** usable capacity, page size, page selectors, reserved resident/firmware areas, and the actual backing range used by DMA.
2. **NeoGS DMA transfer window:** the ZX-visible `0000–3FFF` aperture and the mapping/ownership rules that make it refer to the selected DMA backing address.
3. **ATM host staging memory:** physical ATM page(s), Z80 window address(es), buffer size/alignment, lifetime and mapper ownership.
4. **x86 guest memory:** the custom 1 MiB guest address space. It is independent of both NeoGS local physical memory and ATM host memory.

The specification must include address tables for both transfer directions, buffer sizes, alignment, reserved ranges, page-switch procedure and collision/ownership rules.

Until that specification is approved:
- do not hard-code Project126's proposed 4 MiB / 256-page NeoGS layout;
- do not assign final ATM staging-buffer addresses;
- do not claim that a guest physical address is a DMA address;
- keep transport initialization gated and do not start the x86 guest.

## 6. Implementation sequence

1. Record and review the separate NeoGS/ATM memory and DMA-buffer map.
2. Add the small Project130 bootstrap image and its bounded GS105a `#14/#13` launcher.
3. Implement the bootstrap-side stock-ROM disable and resident-runtime handoff.
4. Implement the Project130 DMA/IPC control plane and both transfer directions using the approved map.
5. Integrate TR-DOS catalogue selection with actual payload loading only after the transport is operational.
6. Record build evidence separately from external emulator/runtime validation.

No runtime self-tests, synthetic payloads, benchmark routines or test-only behavior are to be added to Project130.
