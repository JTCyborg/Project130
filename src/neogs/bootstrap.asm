; Project130 NeoGS stage-0 bootstrap.
; Loaded by GS105a command #14 at address #4000 and entered with #13.
; This image is self-contained and <=256 bytes. It disables the stock ROM,
; acknowledges readiness, then idles until the approved DMA/IPC runtime exists.

        di
        ld      a,1
        out     (#1B),a
        xor     a
        out     (#1F),a
        nop
        nop
        nop
        nop

        ; GSCFG0: clear bit 1 and enable NOROM + EXPAG.
        in      a,(#0F)
        and     #FD
        or      #09
        out     (#0F),a

        ; A1 = bootstrap ready, published on the NeoGS ZX data endpoint.
        ld      bc,#FFFF
p130_ngs_boot_tx_wait:
        in      a,(#04)
        bit     7,a
        jr      z,p130_ngs_boot_tx_ready
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_ngs_boot_tx_wait
        jr      p130_ngs_boot_idle
p130_ngs_boot_tx_ready:
        ld      a,#A1
        out     (#03),a
        ld      bc,#FFFF
p130_ngs_boot_tx_done:
        in      a,(#04)
        bit     7,a
        jr      z,p130_ngs_boot_idle
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_ngs_boot_tx_done

p130_ngs_boot_idle:
        di
        jr      p130_ngs_boot_idle

        ASSERT  $ <= 256
