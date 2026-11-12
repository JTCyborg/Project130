# Project130 NeoGS bootstrap and DMA transport architecture

Status: GS105a stage-0 launcher is implemented in source. The Project126 NeoGS physical map is approved for Project130. The resident DMA/IPC payload transport and BIOS execution path remain to be implemented; no target validation is implied.

## 1. Startup and ownership

The stock NeoGS GS105a ROM is retained only as a temporary bootstrap launcher.

1. ATM locates and validates NEOBOOT.C.
2. ATM uses stock GS105a command #14 to place the bootstrap at ROM receive address #4000. Length is a 16-bit two's-complement negative value; low byte is preloaded before command dispatch and high byte follows #14.
3. ATM opens X86CORE.C, reads its first sector and validates the 1..16 KiB length, matching the Project126 pre-#13 TR-DOS transaction. Project130 does not send core bytes through GSDAT.
4. ATM issues #13 to transfer control to #4000.
5. Bootstrap follows Project126 stage-0 order: DI, temporary SP=#3FFF, disable ZX DMA (#1B/#1F), settle, set GSCFG0 NOROM+EXPAG with RAMRO clear, establish temporary WIN0/WIN3 mapping (#20/#00/#10), then move stack to #FFFE.
6. Bootstrap publishes one A1 ready acknowledgement and idles. A1 confirms only stage-0 readiness, not resident runtime, DMA, IPC or x86 CPU operation.

The GS105a #14/#13 exchange is the only legacy byte-channel exception. It transfers the small bootstrap image only. After A1, all resident code, BIOS, modules, control payloads and video data use Project130 DMA/IPC. No further GSDAT payload streaming is permitted.

## 2. Ownership and port boundary

- ATM Turbo 2+ owns physical devices, ATM physical memory mapping and host-side DMA orchestration.
- ATM-side code uses only the documented host-visible NeoGS command/status/data interface for stage-0 bootstrap and IPC control.
- ATM-side code must not write NeoGS-local DMA registers as if they were ATM ports.
- NeoGS code must not perform physical ATM I/O. Guest x86 IN/OUT is implemented by software virtual devices and host-service requests.
- No IRQ is enabled during bootstrap or initial transport bring-up.

NeoGS-local ZX DMA registers are MOD=#1B, HAD=#1C, MAD=#1D, LAD=#1E, CST=#1F. They are programmed by NeoGS-side code, not by direct ATM port writes.

## 3. DMA rules

- Select ZX DMA module 1 on the NeoGS side.
- Program the exact requested start address.
- DMA read: enable the ROM aperture, discard the first dummy read, then consume payload byte zero. Do not decrement the programmed address.
- DMA write: no dummy write; first write is payload byte zero.
- Disable DMA before changing direction.
- Keep interrupts disabled while the ROM aperture exposes DMA data until vector handling is designed.
- All waits are bounded; all exits leave DMA disabled or in documented idle state.

The approved NeoGS physical DMA staging page is #42. The ZX-visible ATM aperture 0000–3FFF is a different address space. See docs/NeoGS/MEMORY_MAP.md.

## 4. Project130 transport ABI

Project130 owns its transport ABI. Project126 framing is a reference, not an automatically accepted wire format. Before payload traffic is enabled, define magic/version, message type, sequence, payload length, CRC coverage, completion and stale-response handling, timeout/resync, DMA direction and ownership, maximum frame and fragmentation.

Control plane may use documented NeoGS command/status handshakes. Application payload bytes use DMA only.

## 5. BIOS load and launch contract

The selected BIOS is one of the three 8 KiB TR-DOS images documented in docs/NeoGS/BIOS_IMAGES.md.

1. ATM opens the selected BIOS .C file and validates type and exact size (8192 bytes / 32 TR-DOS sectors).
2. Read the complete image into ATM staging and calculate CRC-16/CCITT-FALSE over exactly 8192 bytes.
3. Send IMAGE_BEGIN for image kind SYSBIOS, physical page #10 and image length #2000.
4. Send IMAGE_FRAGMENT containing all 8192 bytes.
5. Send IMAGE_FINISH. NeoGS validates the transfer, installs the bytes in the physical SYSBIOS slot (pages #10–#1F), and performs physical readback verification.
6. Guest memory backend maps the 8 KiB image at FE000h–FFFFFh and verifies guest-visible readback, including reset-vector bytes at FFFF0h.
7. Only after successful verification, initialize 8086 state to CS:IP=FFFF:0000, FLAGS=0002h, and begin instruction execution.

The physical SYSBIOS slot is 256 KiB; each initial BIOS image is 8 KiB; the guest-visible ROM window is 8 KiB. These sizes must not be conflated.

## 6. Current implementation status

The current Project130 tree contains the BIOS binaries in the TR-DOS image and the GS105a stage-0 bootstrap/launcher. It does not yet contain the resident DMA/IPC receiver, SYSBIOS image installer, guest-memory backend, or integrated 8086 CPU execution path. Therefore no BIOS can yet be reported as loaded or running.

Implementation order:
1. complete and validate the A1 stage-0 handoff;
2. implement Project130 DMA/IPC receiver and host sender using approved page #42 staging;
3. implement SYSBIOS IMAGE_BEGIN/FRAGMENT/FINISH and physical readback;
4. implement the adopted guest 1 MiB map and BIOS ROM window;
5. implement reset-state initialization and release the 8086 execution loop;
6. verify the first reset-vector instruction, then continue BIOS startup in bounded execution slices.

No GSDAT payload streaming, guessed physical addresses, synthetic self-tests, or test-only behavior may be introduced.
