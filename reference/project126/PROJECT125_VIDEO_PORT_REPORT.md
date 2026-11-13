# Project125 -> Project130 BIOS/VGA video port report

Date: 2026-11-13

## Scope and acceptance contract

The required port is the Project125 BIOS INT 10h + VGA text pipeline, preserving only the Project130 architecture boundary: resident overlay gates, the Project126 guest-memory mapper, IPC/DMA transport, and the ATM host presenter. The functional rules (BIOS text operations, VGA register semantics, planar addressing, character/attribute capture, and frame interpretation) must remain Project125-derived.

This report records source-level comparisons against:
- Project125 `0/neogs_sub/bios/bios_video.asm` (blob `467dd5fe7d9c95b28c944d0729389227d688775a`)
- Project125 `0/neogs_sub/x86_vga.asm` (blob `aa9be1c5343beb55d7a7dba6a760f764e027ff0e`)
- Project125 `0/shared/vga_memory.inc` (blob `b6848662e6a1bfd25ad11d122c326b0386dfc9f1`)
- Project130 `reference/project126/neogs_sub/x86_bios_video.asm` (blob `444a1843607e892830ac194356ac9e692c086cbc`)
- Project130 `reference/project126/neogs_sub/x86_vga.asm` (blob `08285b30d983973f37be8f87db5183fa4460c5ab`)
- Project130 `reference/project126/neogs_sub/x86_video_convert.asm` (blob `0db5e98168f1aed50b7a57a8b2cd1ceb6258bd54`)

## Stage 1 — BIOS INT 10h service logic

The Project130 BIOS module is not a byte-for-byte copy of Project125. The following functional routines were compared:

| Routine | Source comparison | Project130 adaptation |
|---|---|---|
| INT 10h dispatch | same dispatch decisions | bounded #EF trace added |
| AH=00 mode set | adapted | VGA indexed-register writes go through resident X86VGA API; BDA writes go through guest-memory mapper |
| clear page | same 80x25 cell iteration | per-cell writes use the mapped guest-memory API |
| AH=06/07 scroll entry | same | none |
| scroll common/copy/clear | adapted | P125's direct x86_mem_read8/write8 calls replaced with physical-address calculation plus x86_guest_mem_read8/write8 |
| AH=0F get mode | same result | none |
| AH=02 set cursor | same validation and state update | BDA cursor store uses mapped guest-memory API |
| AH=03 get cursor | adapted | BDA read uses mapped guest-memory API |
| AH=0E teletype | adapted | P125 cursor/CR/LF/backspace/write behavior retained, with lazy VGA state setup and diagnostics |
| cell writer | adapted | P125 row*160 + column*2 calculation retained; actual writes go through x86_cpu_calc_phys + x86_guest_mem_write8 |

The Project130 implementation has additional code absent in Project125: explicit VGA I/O adapters, guest physical-address adapters, BDA byte/word helpers, a teletype byte trace, and a one-shot VGA readback trace.

Project125-only items not present in the Project130 module:
- `bios_int10_install_vector_impl`: not copied because Project130 interrupt dispatch/IVT ownership is handled by its X86EXEC/BIOS integration, not by the video overlay.
- `bios_int10_video_test_impl` and its embedded real-mode test image: not yet ported. This is a missing automated regression test, not evidence that the production service logic is equivalent.
- P125's generic `bios_video_write_byte/word` helpers: replaced by Project130's guest physical mapper adapters.

**Stage 1 status: partially ported, not complete.** The core text-service behavior is recognizable and mostly retained, but several routines are architecture-adapted rather than source-identical, and the P125 executable regression test is still missing.

## Stage 2 — VGA register model and port access

Project125's VGA core is resident and reads the shared `x86_io_port` / `x86_io_value` state established by the common I/O dispatcher.

Project130 moves the core into dynamic overlay X86VGA (module ID 05, overlay page 08). Its public entry points stage the port/value in overlay-local state and then enter implementation routines. This is a necessary architecture adaptation, but the decoder must consume the staged values rather than stale dispatcher globals.

A concrete defect was found and fixed:
- BIOS called the Project130 resident VGA API with port in HL.
- The wrapper stored HL in `x86_vga_io_port`.
- The VGA port decoder still compared `x86_io_port`, which was not updated by this direct overlay call.
- Consequently BIOS register writes did not reliably update Sequencer/Graphics Controller state, including the B800 aperture configuration.

Fix committed:
- `872d4ab12af8229f1e68b4335c9d64011b20021f`
- `Fix VGA overlay port decode for BIOS register writes`
- All 13 stale `ld hl,(x86_io_port)` reads in the X86VGA register decoder were redirected to `x86_vga_io_port`. The public read/write implementations stage HL before decoding.

The fix was source-verified on main: no remaining VGA decoder reads of `x86_io_port` via that pattern, and the public read/write paths stage the port into `x86_vga_io_port`.

## Stage 3 — VGA memory aperture, planes, and addressing

Source comparison found exact normalized instruction-body matches for:
- `x86_vga_decode_aperture`
- `x86_vga_map_plane`
- `x86_vga_offset_even`
- `x86_vga_get_latch`
- `x86_vga_compare_one`
- `x86_vga_mem_read8` vs Project130 `x86_vga_mem_read8_impl`

Project130 renames the four memory/I/O entry points with `_impl` and adds overlay wrappers/gates. The memory-write entry also has an input-staging instruction at entry; after accounting for this adapter and the input variable naming, its main write-mode/plane loop is based on the Project125 routine. A final instruction-by-instruction audit of every write-path staging reference remains required before declaring full equivalence.

Physical plane allocation is deliberately preserved from Project125:
- plane 0: pages #53–#56
- plane 1: pages #57–#5A
- plane 2: pages #5B–#5E
- plane 3: pages #5F–#62

Project130's map additionally allocates frame workspace #40–#41, DMA #42, IPC #43, and guest RAM #63–#A2. These are transport/runtime allocations and do not change the four VGA plane page ranges.

## Stage 4 — BIOS guest-memory adapter

Project125 writes B8000h and BDA addresses through its x86 memory API. Project130 cannot call those resident Project125 memory routines directly because its guest memory is banked and VGA is an overlay.

Project130 therefore translates:
- segment:offset / B800 text offset -> 20-bit physical address using `x86_cpu_calc_phys`
- guest read/write -> `x86_guest_mem_read8` / `x86_guest_mem_write8`
- B800 aperture -> X86VGA public memory gate through the common guest-memory dispatcher

The previous commit `22aa92fe74fcf03ece02242e21db01d4d814cea4` routes BIOS memory writes through the resident guest-memory API. Commit `1c1d89c82296ffcbcadad6ff573350b4c6257985` routes BIOS text readback through the resident X86VGA wrapper rather than calling a non-resident overlay implementation directly.

These are integration adapters, not permission to change the P125 VGA semantics.

## Stage 5 — Character/attribute capture and frame transport

Project130 adds `x86_vga_capture_text_frame_gate_impl` and the X86VID conversion overlay. The current text-frame contract is:
- 2000 character bytes
- followed by 2000 attribute bytes
- total payload: 4000 bytes (0x0FA0)
- DMA frame is staged in physical page #42 after the IPC header.

The ATM presenter converts IBM VGA attribute bits to ATM RG6 attributes and writes the received 80x25 cells. Its attribute mapping was previously compared against the Project125 `video_transfer.asm` mapping and found equivalent; the ATM cell writer was also found equivalent at the algorithm level.

**Stage 5 status: not yet proven end-to-end equivalent.** The exact Project125 reverse-DMA capture/command handler still needs a complete side-by-side comparison with Project130's plane capture and IPC payload assembly. The staging workspace safety and exact DMA payload offsets also need a final audit.


### Stage 5A — Exact Project125 reverse-DMA contract

The Project125 host implementation was fetched and compared directly from
`0/zx_main/video_transfer.asm` (blob
`82682ed6f664e6ce43629259f2a4e4f03f6c16c0`).

Its `p125_video_pull_and_present` sequence is:
1. Issue `CMD_VIDEO_PULL`.
2. Wait until GSSTAT CBIT clears.
3. Disable host interrupts.
4. Perform the mandatory dummy read from address zero.
5. Copy exactly `0x0FA0` bytes from reverse-DMA address zero to host `#C000`.
6. Send `#FF` to GSCOM and wait for transfer completion.
7. Present chars from `#C000..#C7CF` and attrs from `#C7D0..#CFAF`.

The Project130 capture routine has the same logical byte order and count:
- read 2000 bytes from plane 0 to staging offset 0;
- read 2000 bytes from plane 1 to staging offset `0x07D0`;
- copy `0x0FA0` bytes to the page-42 producer buffer at `#C000 + P126_IPC_HEADER_SIZE`.

This is the correct transport adaptation: Project125's raw reverse-DMA payload begins at host address zero; Project130 wraps the same 4000-byte payload in the 18-byte ABI header and stages it at page42:`#C012`. The host-facing character/attribute offsets therefore remain 0 and 2000 relative to the payload, not relative to the IPC frame start.

### Stage 5B — Presenter contract

Project125's `p125_video_present_text` consumes:
- character pointer starting at `#C000`;
- attribute pointer starting at `#C7D0`;
- 25 rows × 80 columns.

Project130's converter advertises the same 80×25 text payload size (`0x0FA0`) and its ATM presenter consumes the ABI payload after the 18-byte header. This confirms the logical frame layout, but does not by itself prove the complete reverse-DMA sender/receiver handshake or screen contents. The presenter also includes the Project125-compatible attribute conversion and cell mapping previously compared; runtime acceptance remains pending.

### Stage 5C — Remaining transport verification

The source-level checks now establish the byte-layout equivalence. They do not establish runtime correctness. The remaining source/runtime boundary checks are:
- verify the command dispatcher selects the video-frame response path after capture;
- verify the staged IPC header declares exactly `0x0FA0` payload bytes and total frame size `18 + 0x0FA0`;
- verify the sender DMA starts at physical page42 base and transfers the declared complete frame;
- verify the ATM receiver strips the header and presents payload offsets 0 and `0x07D0`;
- verify the host's reverse-DMA dummy-read/interrupt/CBIT sequencing is correctly represented by the Project130 transport implementation;
- run the fresh emulator and confirm nonzero character and attribute data at both ends.


## Runtime evidence and remaining acceptance tests

The last supplied runtime log (SHA `b5e07186ede2b7f6db90f76453a8e84e3def795f`) showed:
- BIOS INT 10h calls and teletype output were reached.
- CPU writes to B800-family addresses occurred.
- the captured character/attribute arrays were still zero.
- the transported frame CRC matched, which only proved that the zero frame was transported intact.

That log predates commit `872d4ab`, so it cannot validate the register-port fix.

Required fresh runtime checks after rebuilding:
1. BIOS VGA Sequencer and GC indexed writes update the expected register model.
2. GC6 aperture selection resolves B8000h to the text aperture.
3. First written character and attribute read back nonzero through the VGA read-text-cell API.
4. Plane 0 and plane 1 capture each contain the expected 2000 bytes.
5. DMA payload length is exactly 0x0FA0, with nonzero character and attribute regions.
6. ATM presenter displays the expected characters and converted attributes.
7. Scroll, cursor, CR/LF, wrap, and backspace behavior match Project125.
8. A P125-derived executable BIOS regression test is added to Project130's native test harness.

No build or runtime test is claimed by this source audit. A fresh `spectrum_out.txt` after the port-decode fix is required for runtime acceptance.

## Overall status

The VGA plane mapping and the bulk of the VGA read/addressing algorithms are carried over from Project125. Project130 has the necessary overlay and guest-memory adapters, and the BIOS VGA port-state bug was corrected. However, this is **not yet a completed full transfer**: the BIOS regression test is absent, some BIOS routines are adapted rather than line-identical, and the capture-to-DMA path still needs exact P125 comparison plus fresh runtime validation.
