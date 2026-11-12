# Project126 reference archive

Project126 is retained as a read-only reference for algorithms and proven execution order. Its source is not part of the Project130 runtime build.

Archived source layout:

- `reference/project126/atm_host/` — Project126 ATM-side reference implementation.
- `reference/project126/neogs_sub/` — Project126 NeoGS resident, CPU and IPC reference implementation.
- `reference/project126/shared/` — Project126-specific protocol and memory-map definitions.
- `reference/project126/docs/` — Project126 architecture, DMA/IPC, memory-map and overlay specifications.
- `reference/project126/SCENARIO.md` — original Project126 scenario.
- `reference/project126/generated/` — generated Project126 disk assembly artifact.

The archive is not a source of files to copy wholesale into Project130. Extract only an algorithm or an ordered protocol sequence, then implement it against Project130 interfaces and approved Project130 memory allocations.

Important incompatibilities:

1. Project126's legacy bootstrap receives its resident payload over GSDAT after A1. Project130 permits GSDAT only for the small stage-0 bootstrap; all subsequent payloads must use the Project130 DMA/IPC transport.
2. Project126's 4 MiB / 16 KiB-page NeoGS map is not Project130's physical memory map.
3. Project126's x86 memory layout is not Project130's custom 1 MiB guest map.
4. Project126's ATM/NeoGS source files are not compiled by the normal Project130 build.

Use `tools/build_project130_p126_audit.ps1` only for a reference-source assembly audit. It is not a Project130 runtime build or target validation.
