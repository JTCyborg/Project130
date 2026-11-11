# Project130 architecture

## 1. Purpose

Project130 is a new ATM Turbo 2+ 1024 system implementation using Z88DK. It takes the system-level x86/NeoGS concept from Project126 and the ATM host-side hardware techniques from Project129, without merging either repository into this codebase.

The implementation is emulator-first, but hardware-specific operations must retain explicit ownership and bounded failure behavior.

## 2. System roles

### ATM Turbo 2+ host (Z80)

The ATM host is the system controller. It owns:

- reset, startup and configuration;
- TR-DOS bootstrap and physical storage;
- ATM keyboard and other physical input;
- physical RTC access where present;
- ATM-native display and final frame presentation;
- physical memory mapping and DMA orchestration;
- host services, diagnostics and watchdog/timeouts.

Physical device access belongs to ATM-side modules only.

### NeoGS companion subsystem

NeoGS is the execution subsystem for the initial x86 profile. It owns:

- the emulated Intel 8086 Real Mode CPU;
- guest memory translation/backing;
- software x86 I/O-port and device models;
- guest interrupt-controller/timer state;
- VGA-compatible state and rendering;
- request/response processing for host services.

**NeoGS has no direct external-device access.** It must not perform real-device ATM I/O or directly manipulate ATM physical ports. All communication with the outside world is mediated by the ATM host over DMA.

### x86 guest

The guest is an isolated software machine. Guest physical addresses, I/O ports, IRQs and DMA requests are virtual resources. They must never be mapped directly onto ATM or NeoGS physical I/O registers.

The mandatory initial CPU profile is Intel 8086 Real Mode. Do not require 80186/286 instructions, protected mode, or undocumented extensions for the baseline.

## 3. Layering

Keep these layers independent and expose narrow interfaces:

1. **Boot** — TR-DOS bootstrap, resident entry and build identity.
2. **ATM host** — physical memory mapper, input, storage, clock, display and diagnostics.
3. **Transport** — DMA buffers, message validation, sequence/timeout/error handling.
4. **NeoGS runtime** — Z80-side companion runtime and x86 execution loop.
5. **Guest core** — CPU, guest memory, virtual I/O, IRQ and device models.
6. **Video** — guest VGA state/scanout, frame transport, ATM-native presentation.

A guest device must request a host service through the transport API. It must not call an ATM hardware driver directly.

## 4. Source provenance

- Project126 is the reference for architecture, x86 isolation, guest memory/device modeling and the intended video pipeline. Its proposed memory-page allocations and unfinished ABIs are not automatically validated.
- Project129 is the reference for Z88DK build/boot practice and ATM-side procedures such as W3 mapping, page allocation, RTC, Nemo IDE and diagnostics. Reuse only after checking module dependencies and ownership; do not copy its entire application.
- Project130 owns its source, public interfaces, tests and validation evidence. Project126 and Project129 remain unchanged.

## 5. Non-goals for the first milestone

The first commit does not implement an x86 CPU, BIOS, VGA, NeoGS transport, guest memory map, IRQ/PIC/PIT or physical device drivers. It establishes a reproducible project structure and a visible ATM-side resident entry.
