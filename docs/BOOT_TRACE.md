# Project130 boot trace and acceptance test

## Expected #EF startup order

| Order | Marker | Origin | Meaning |
|---:|---|---|---|
| 1 | `P130]` | BASIC line 11 | BASIC loader starts and debug channel 1 is active |
| 2 | `LOAD` | BASIC line 21 | TR-DOS CODE load returned to BASIC |
| 3 | `>` | `_p130_entry` | Resident image entered at #6000 |
| 4 | `130` | `_p130_entry` | Initial stack and ATM/TR-DOS paging established; C handoff follows |
| 5 | `[P130] C IMAGE EXECUTED` | C entry | C function entered |
| 6 | `[P130] BUILD: P130-0.6.0-P126-TRDOS-PRELOAD-FIRST` | C entry | Exact build identity |
| 7 | `[NEOGS] GS105a BOOTSTRAP LAUNCH BEGIN` | C entry | NeoGS startup is the first subsystem after host entry |
| 8 | `Rr...` | NeoGS loader | NEOBOOT open/validation, GS105a reset, #14 transfer, X86CORE preflight, #13/A1 handshake |
| 9 | `[NEOGS] STAGE0 A1 ACK RECEIVED; BOOTSTRAP IDLE` | C entry | Only stage-0 A1 passed; resident firmware and DMA/IPC are not running |
| 10 | `[TR-DOS] CATALOGUE PRELOAD BEGIN` | C entry | Full 8-sector catalogue preload, before NeoGS launch, matching Project126 |
| 11 | `[ATM] VIDEO MODE INIT DONE` | C entry | ATM shadow/video mode initialized before RTC, matching Project126 |
| 12 | `[RTC]` | C entry | RTC probed after video mode initialization |
| 13 | `[ATM] CONSOLE INIT DONE` | C entry | Visible console drawn after RTC, matching Project126 |
| 14 | `[MEM]`, `[HDD]` | C entry | Project130-specific host services initialized after the shared startup stages |

The NeoGS loader trace uses R/r for NEOBOOT lookup and validation, 5 for GS105a reset, 6 for the #14 header, 7 for bootstrap bytes, 8 for X86CORE preflight, 9 for #13, and a1 for the accepted A1 acknowledgement. A failure line includes the stage number.

The BASIC loader changes the diagnostic channel to 2 immediately before calling the resident image.

## Failure localization

- No P130]: BASIC boot did not start or debug channel 1 was not enabled.
- P130] but no LOAD: TR-DOS interception/CODE loading did not return.
- LOAD but no >: resident image was not entered at #6000.
- > but no 130: resident ASM failed before the C handoff.
- 130 but no C-entry strings: inspect the linked CALL target, C symbol and stack.
- NeoGS launch begins but no final A1 marker: inspect the last loader trace marker and GSSTAT/DBIT handshake.
- A1 accepted but no later resident/IPC traffic: expected with the current incomplete stage-0; A1 is not full NeoGS readiness.

## Test procedure

1. Build with tools/build_project130.ps1.
2. Confirm the build reports CALL=VERIFIED and DISK size 655360 bytes.
3. Boot disk_A.trd in Unreal Speccy using the ATM Turbo 2+ configuration.
4. Capture the complete #EF output from the BASIC marker through host initialization.
5. Repeat after a cold reset.
6. Attach the trace to the repository before marking the startup stages as runtime-validated.

## Scope

This trace can validate the host entry, GS105a #14/#13 transaction and A1 acknowledgement. It does not validate the Project126 post-A1 resident transfer, Project130 DMA/IPC initialization, guest memory, x86 execution, VGA or physical device drivers. Those stages remain incomplete and require the separately approved Project130 NeoGS/ATM physical memory and DMA-buffer map.


## 2026-11-12 — restore Project126 pre-bootstrap TR-DOS ordering

Project130 previously called `p130_neogs_startup()` before `p130_trdos_preload()`. This is the reverse of the working Project126 host sequence: Project126 preloads the TR-DOS directory before opening the bootstrap and resident files through the TR-DOS ROM API. Project130 now preloads the directory first, then launches GS105a. Build ID: `P130-0.6.0-P126-TRDOS-PRELOAD-FIRST`.

This is a startup-order correction only. It does not claim that the resident core, X86MODS manifest, overlays, or DMA/IPC endpoint are implemented in Project130. Target build and Unreal Speccy runtime verification are still required.


## 2026-11-12 — TR-DOS ROM-call trampoline

Build `P130-0.6.1-P127-TRDOS-ROM-TRAMPOLINE` fixes the catalogue read path. A direct `CALL #3D13` did not follow the working Project127 TR-DOS return contract. Sector reads now use the Project127 shadow-off transition, install the return trampoline through system variable 23613, enter `#3D13` by JP, restore shadow/video through `#3D2F`, then restore the Project130 host W2/W3 pages. The sector-read ABI registers are restored after the paging writes.

Startup diagnostics now use actual CR/LF escapes rather than printing the literal characters `\\r\\n`.

Target-side build and runtime verification are pending. The expected next marker after `[TR-DOS] CATALOGUE PRELOAD BEGIN` is `r0`; then `r1` through `r7`. A failure or stop before `r0` still needs a fresh runtime trace.
