# Project126 reference archive

Project126 is retained as a read-only reference for algorithms and proven execution order. Its source is not part of the Project130 runtime build.

Archived source layout:
- reference/project126/atm_host/ — Project126 ATM-side reference implementation.
- reference/project126/neogs_sub/ — Project126 NeoGS resident, CPU and IPC reference implementation.
- reference/project126/shared/ — Project126-specific protocol and memory-map definitions.
- reference/project126/docs/ — Project126 architecture, DMA/IPC, memory-map and overlay specifications.
- reference/project126/SCENARIO.md — original Project126 scenario.
- reference/project126/generated/ — generated Project126 disk assembly artifact.

The Project126 NeoGS physical memory allocation and 1 MiB guest 8086 memory map have now been explicitly adopted as Project130 baselines. Project130 owns the corresponding constants in src/neogs/p130_neogs_memory_map.inc and src/neogs/p130_x86_machine_map.inc. This does not mean Project126 runtime source is copied or linked wholesale.

Important remaining incompatibilities:
1. Project126's legacy bootstrap receives its resident payload over GSDAT after A1. Project130 permits GSDAT only for the small stage-0 bootstrap; all subsequent payloads must use Project130 DMA/IPC.
2. Project126's IPC wire protocol is not automatically Project130's ABI. Port only after reviewing framing, ownership, DMA direction and completion semantics.
3. Project126 ATM host allocations and device integrations must be adapted to Project130's host runtime and current ATM mapper.
4. Project126 source files are not compiled by the normal Project130 build unless explicitly added.

Use tools/build_project130_p126_audit.ps1 only for a reference-source assembly audit. It is not a Project130 runtime build or target validation.
