# Project130 implementation plan

A milestone is complete when its implementation and stable interfaces are integrated. Emulator runtime contains production code only: no self-tests, benchmark routines, test payloads or test-only device behavior. Validation is performed externally and recorded as development evidence.

## Stage 0 — project skeleton and boot chain

- [x] Establish repository structure and architecture rules.
- [x] Record Project126/Project129 source boundaries.
- [x] Add Z88DK resident entry and TR-DOS disk packaging script.
- [x] Reuse the proven Project129 no-CRT Z88DK relocation model at #6000.
- [x] Add BASIC boot markers before and after the TR-DOS CODE load.
- [x] Validate resident image size, entry symbols, C-entry address and ASM-to-C CALL in the build script.
- [x] Validate the packaged TR-DOS image is exactly 640 KiB.
- [x] Build with the user's local Z88DK + SjASMPlus installation (user-confirmed build output).
- [x] Run boot image in Unreal Speccy / target ATM environment and confirm the full marker sequence on #EF (user-confirmed runtime trace).
- [ ] Save the first runtime trace as a repository artifact.

## Stage 1 — ATM host foundation

- [x] Port Project126 ATM-native 80x25 console layout and host-page-preserving renderer.
- [x] Separate console image at #A000 so video page remapping cannot unmap executing renderer code.
- [x] Mirror ATM #EF host log output into the lower console log area; no test output is generated.

- [x] Add the minimal ATM #EF diagnostic output path and stable byte/hex helpers.
- [x] Add an ATM2+ physical-page accounting model with reserve/allocate/free/pin operations.
- [x] Add production page accounting with reserve/allocate/free/pin operations (no in-emulator self-test).
- [ ] Implement physical RAM discovery for the emulator host; current 64-page value is a configured ATM2+ capacity model, not a runtime probe.
- [ ] Port the physical W3 mapper only after its hidden-port enable sequence and W3 ownership handoff are integrated.
- [ ] Define ownership/lease rules for banked windows.
- [x] Add the ATM-host DS12887 RTC service using the verified Project129 GLUK/SMUC read-only driver.
- [x] Display and refresh host RTC time in the ATM-native 80x25 console.
- [ ] Establish host capability/version structure and bounded hardware waits.
- [x] Add read-only TR-DOS track-0 catalogue preload through the proven ATM ROM call.
- [x] Add ATM-host Nemo IDE ATA IDENTIFY and bounded LBA28 sector reads.
- [x] Add read-only FAT16 root-directory enumeration to the ATM console and #EF log.
- [ ] Confirm TR-DOS and HDD catalogues on the user's local emulator; validation remains external.
- [ ] Confirm RTC detection, backend selection and live clock updates on the user's local emulator; validation remains external.
- [ ] Confirm Stage 1 integration on the user's local toolchain/emulator; keep validation outside the emulator runtime.

## Stage 2 — NeoGS transport

- [ ] Audit the exact Project129 DMA routines and Project126 transport design.
- [ ] Define the Project130 DMA message header, version, sequence, length and CRC.
- [ ] Implement ATM→NeoGS transfer and verify payload integrity.
- [ ] Implement NeoGS→ATM transfer and verify payload integrity.
- [ ] Verify timeouts, cancellation, buffer ownership and safe idle state.
- [ ] Do not use legacy byte streaming for payloads.

## Stage 3 — NeoGS runtime and guest memory

- [ ] Establish NeoGS runtime startup and memory-capacity checks.
- [ ] Finalize the custom 1 MiB x86 guest memory map.
- [ ] Implement guest read/write/fetch paths and boundary tests.
- [ ] Load and validate the BIOS image and reset-vector mapping.

## Stage 4 — 8086 CPU

- [ ] Audit Project126 CPU implementation and dependencies before porting.
- [ ] Implement/port the complete required Intel 8086 instruction set.
- [ ] Add flags, prefixes, segment:offset calculation and 20-bit address behavior.
- [ ] Add instruction-level and BIOS boot tests.
- [ ] Do not require 80186/286 instructions or protected mode.

## Stage 5 — virtual devices

- [ ] Implement software I/O bus and device registration.
- [ ] Implement PIC/PIT/PPI behavior required by the BIOS.
- [ ] Implement keyboard and RTC host-service bridges.
- [ ] Implement storage host-service bridge.
- [ ] Add device reset, error and unsupported-access tests.

## Stage 6 — VGA and ATM presentation

- [ ] Audit Project126 VGA implementation and PCem reference behavior.
- [ ] Finalize guest VGA memory/register model and scanout.
- [ ] Define canonical frame descriptor and pixel format.
- [ ] Transfer frames by DMA and validate CRC/sequence/slot ownership.
- [ ] Implement ATM-native conversion/presentation using Project112/Project129 evidence.
- [ ] Validate each target ATM mode independently.

## Stage 7 — BIOS and software compatibility

- [ ] Boot the selected 8086 BIOS to a stable diagnostic state.
- [ ] Resolve BIOS device dependencies through software models/host services.
- [ ] Add disk boot and real-mode application tests.
- [ ] Perform external stress validation of memory, DMA, interrupts and video; do not embed test routines in the emulator.

## Stage 8 — integration and release

- [ ] End-to-end boot from TR-DOS to x86 BIOS.
- [ ] External long-duration and repeated-reset validation.
- [ ] Confirm no direct physical I/O from NeoGS.
- [ ] Publish build ID, source hashes, test logs and known limitations.

## Deferred / explicitly out of scope

- 80286/protected mode;
- unverified conventional PC memory layout;
- direct physical device access from NeoGS;
- claiming complete VGA/PC compatibility before the corresponding tests pass.
