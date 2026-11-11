# Project130 boot trace and acceptance test

## Expected #EF sequence

The bootstrap emits distinct markers so the first failing boundary can be identified without guessing.

| Order | Marker | Origin | Meaning |
|---:|---|---|---|
| 1 | `P130]` | BASIC line 11 | BASIC loader is executing and debug channel 1 is active |
| 2 | `LOAD` | BASIC line 21 | TR-DOS CODE load returned to BASIC |
| 3 | `>` | `_p130_entry` | CPU entered the resident image at #6000 |
| 4 | `130` | `_p130_entry` | Resident ASM initialized its stack and reached the C handoff |
| 5 | `[P130] C IMAGE EXECUTED` | C entry | C function was entered |
| 6 | `[P130] Z88DK C ENTRY` | C entry | Z88DK C runtime code is executing |
| 7 | `[P130] BUILD: BOOTSTRAP-0.1.0-SKELETON` | C entry | Build identity |
| 8 | `[P130] ATM HOST BOOTSTRAP READY` | C entry | Stage-0 resident idle reached |
| 9 | `[P130] NEO GS / DMA NOT INITIALIZED` | C entry | Explicitly confirms that later subsystems have not been started |

The BASIC loader changes the diagnostic channel to 2 immediately before calling the resident image, matching the Project127/Project129 boot handoff.

## Failure localization

- No `P130]`: boot.B did not begin or the BASIC debug setup did not execute.
- `P130]` but no `LOAD`: TR-DOS interception/CODE loading did not return.
- `LOAD` but no `>`: resident image was not entered at #6000.
- `>` but no `130`: resident ASM failed before its handoff marker.
- `130` but no C-entry strings: inspect the linked CALL target, C symbol and stack.
- All C-entry strings: Stage 0 runtime acceptance candidate; still confirm stable idle and repeat after reset.

## Test procedure

1. Build with `tools/build_project130.ps1`.
2. Confirm the build reports `CALL=VERIFIED` and `DISK=... SIZE=655360`.
3. Boot `disk_A.trd` in Unreal Speccy using the ATM Turbo 2+ configuration.
4. Capture the complete #EF output, including the first BASIC markers.
5. Repeat after a cold reset.
6. Attach the trace to the repository before marking Stage 0 complete.

## Scope

This test does not validate NeoGS startup, DMA, guest memory, x86 execution, VGA or physical device drivers. The C entry intentionally remains in a safe idle loop.
