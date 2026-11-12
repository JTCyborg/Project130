# Project126 source import into Project130

Imported from Project126/main as an intact source baseline.

## Copied content

- Complete `neogs_sub/` resident source set: bootstrap, IPC, overlay gate, CPU state, instruction execution, ALU, ModR/M, virtual I/O, virtual devices, VGA, and video conversion.
- Complete `shared/` definitions: DMA/IPC ABI, Project126 NeoGS physical map, and Project126 guest x86 machine map.
- Complete `atm_host/` source set: GS105a loader, ATM IPC driver, BIOS/disk loaders, catalogue, RTC, console, and Project126 host entry/build sources.
- Project126 build entry points and implementation/protocol/memory-map/overlay/video documentation.

## Integration constraints for Project130

The imported files are preserved at their original paths and are not yet wired into the Project130 build.

1. Project126's `p126_bootstrap.asm` sends A1 and then receives a resident image over the legacy DBIT/GSDAT byte channel. Project130 must retain its own small-bootstrap-only handoff: after bootstrap startup, all resident/module/application traffic must use DMA/IPC. Do not replace `src/neogs/bootstrap.asm` or `src/neogs/loader.asm` with the Project126 versions unchanged.
2. `shared/p126_neogs_memory_map.inc` describes Project126's 4 MiB / 16 KiB-page allocation. It is imported as reference, not adopted as Project130's physical RAM map. Project130's NeoGS RAM capacity, page semantics, and DMA buffer addresses remain separately specified in `docs/NeoGS/MEMORY_MAP.md`.
3. The Project126 x86 guest map is a reference implementation only; Project130's custom 1 MiB guest memory map remains authoritative.
4. No build or runtime validation is claimed by this source import.

Next integration step: adapt the imported resident/IPC stack to Project130's approved physical map and small-bootstrap-to-DMA handoff, then add it to the Project130 build/package pipeline.
