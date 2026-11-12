# Project130

ATM Turbo 2+ 1024 — Z88DK-based system project.

Project130 combines the system architecture and x86 subsystem concept developed in Project126 with the ATM host-hardware procedures proven in Project129. It is a separate implementation: Project126 and Project129 remain unchanged.

## Current baseline

- Host: ATM Turbo 2+ (Z80), started from a TR-DOS boot disk.
- Toolchain: Z88DK (C/SDCC + Z80 assembly); SjASMPlus packages the TR-DOS image.
- Companion x86 subsystem: NeoGS executes the initial Intel 8086 Real Mode profile.
- Host owns physical ATM devices and all external I/O.
- NeoGS exchanges data with the host only through the agreed DMA transport. It does not directly access physical ATM ports or devices.
- Guest x86 memory, I/O ports, interrupts and devices are software models, not aliases for physical ATM resources.

The initial guest memory map, device windows, DMA message ABI and video ABI are design items. Do not infer a conventional IBM PC 640 KiB/UMA map or treat proposed Project126 page allocations as validated Project130 hardware facts.

## Build

On Windows with Z88DK and SjASMPlus available in PATH:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_project130.ps1
```

The build creates `build/P130BOOT.bin` and packages `disk_A.trd`. The first milestone is only a resident C/ASM entry and #EF diagnostics; it does not yet initialize NeoGS or implement DMA.

Only the `src/` tree is the active Project130 implementation. Project126 reference sources are isolated under `reference/project126/` and are not runtime build inputs. The standalone `PCem/` tree is a read-only CPU/VGA reference.\n\nSee [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) for milestones and acceptance criteria, and [docs/PROJECT126_IMPORT.md](docs/PROJECT126_IMPORT.md) for the reference boundary.
