; =========================================================================
; PROJECT130 — explicit GS105a bootstrap image extraction.
; This follows the proven Project126 assembly method: assemble the module
; at its execution address, then SAVEBIN exactly [#4000, end).
; Never rely on a generic raw-image origin when packaging a ROM #14 payload.
; =========================================================================
        INCLUDE "src/neogs/bootstrap.asm"

        ASSERT p130_ngs_boot_start = #4000
        ASSERT p130_ngs_boot_end > p130_ngs_boot_start
        ASSERT p130_ngs_boot_end <= #4100
        ASSERT p130_ngs_boot_end-p130_ngs_boot_start <= #0100

        DISPLAY "P130_BOOTSTRAP_START=",/H,p130_ngs_boot_start
        DISPLAY "P130_BOOTSTRAP_END=",/H,p130_ngs_boot_end
        DISPLAY "P130_BOOTSTRAP_SIZE=",/D,p130_ngs_boot_end-p130_ngs_boot_start

        SAVEBIN "build/NEOBOOT.bin",p130_ngs_boot_start,p130_ngs_boot_end-p130_ngs_boot_start
