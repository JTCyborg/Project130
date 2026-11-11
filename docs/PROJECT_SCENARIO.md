# Project130 execution scenario

## Intended boot and runtime flow

1. TR-DOS loads the Project130 BASIC boot file from the boot disk.
2. The BASIC loader reserves memory, emits early diagnostics to ATM port #EF, and loads the resident `P130BOOT.C` image at #6000.
3. The resident Z80 assembly entry establishes a known stack and calls the Z88DK C entry.
4. The ATM host initializes its own diagnostics and then, in later milestones, probes and initializes the physical ATM resources it owns.
5. The host initializes the NeoGS transport using the DMA contract. Control/status handshakes may signal readiness and completion, but payload data is transferred through DMA.
6. NeoGS runtime starts the x86 subsystem and loads/validates the guest BIOS and configuration.
7. The x86 CPU begins in Intel 8086 Real Mode. Guest memory and I/O are software-managed and isolated from physical ATM resources.
8. Guest device requests that need the outside world become host-service messages. The ATM host performs the physical operation and returns a response through DMA.
9. Guest video state is rendered into a frame buffer, transferred to the ATM host through DMA, and converted/presented using the ATM-native video path.

## First executable milestone

The initial image is intentionally smaller than the complete scenario:

- TR-DOS boot file and resident load;
- Z80 ASM entry at #6000;
- Z88DK C entry;
- build/version banner and diagnostic output through ATM port #EF;
- stable idle loop.

No NeoGS startup or DMA is claimed until it has its own implementation and runtime evidence.

## Failure policy

- Every hardware/transport wait must have a finite timeout.
- On initialization failure, print the failing subsystem and error code, disable/leave the affected transfer path in a safe state, and enter a diagnostic idle loop.
- Do not enable live IRQ delivery until vectors, stack ownership and interrupt source acknowledgement are verified.
- Build success is not runtime validation.
