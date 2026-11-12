# Project126 reference integration audit

Status: optional build-time source audit. This is not the Project130 runtime build and does not enable the DMA/IPC transport.

Run from the Project130 repository root:

```powershell
.\tools\build_project130_p126_audit.ps1
```

The script uses the repository-pinned `tools/sjasmplus.exe` by default. It assembles the imported Project126 NeoGS resident/overlay translation unit, ATM IPC unit, NeoGS IPC unit, and GS105a bootstrap reference. It checks that expected split images are emitted and applies the original Project126 image-size limits.

Audit artifacts are written under `build/P130_P126_*` (plus the split images emitted by the resident assembler). They are not packaged into `disk_A.trd`, loaded by the Project130 host, or sent to NeoGS. The regular `tools/build_project130.ps1` build remains unchanged.

## Deliberate integration boundary

The imported sources still encode Project126 assumptions, including its 4 MiB / 16 KiB physical page map, resident page placement, overlay selectors, DMA/IPC buffer addresses, and its legacy bootstrap's post-A1 GSDAT resident-image receive. Those values are not Project130 allocations.

Project130 must not call the imported resident entry or initialize its DMA endpoint until the Project130 NeoGS/ATM memory map is approved and the resident handoff has been adapted to the Project130 small-bootstrap-only GSDAT rule. Guest x86 memory remains a separate custom 1 MiB address space.

A successful run of this audit would prove assembly and image-size consistency only. It would not prove physical address correctness, runtime compatibility, DMA operation, or emulator/hardware behavior.
