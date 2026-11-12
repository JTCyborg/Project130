# Project130 boot trace and acceptance test

## Expected #EF startup order

| Order | Marker | Origin | Meaning |
|---:|---|---|---|
| 1 | `P130]` | BASIC line 11 | BASIC loader starts and debug channel 1 is active |
| 2 | `LOAD` | BASIC line 21 | TR-DOS CODE load returned to BASIC |
| 3 | `>` | `_p130_entry` | Resident image entered at #6000 |
| 4 | `130` | `_p130_entry` | Initial stack and ATM/TR-DOS paging established; C handoff follows |
| 5 | `[P130] C IMAGE EXECUTED` | C entry | C function entered |
| 6 | `[P130] BUILD: P130-0.5.9-P126-STARTUP-ORDER` | C entry | Exact build identity |
| 7 | `[NEOGS] GS105a BOOTSTRAP LAUNCH BEGIN` | C entry | NeoGS startup is the first subsystem after host entry |
| 8 | `Rr...` | NeoGS loader | NEOBOOT open/validation, GS105a reset, #14 transfer, X86CORE preflight, #13/A1 handshake |
| 9 | `[NEOGS] STAGE0 A1 ACK RECEIVED; BOOTSTRAP IDLE` | C entry | Only stage-0 A1 passed; resident firmware and DMA/IPC are not running |
| 10 | `[TR-DOS] CATALOGUE PRELOAD BEGIN` | C entry | Full 8-sector catalogue preload, after NeoGS launch |
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
