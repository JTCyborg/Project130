; Project130 NeoGS stage-0 bootstrap.
; Loaded by GS105a command #14 at address #4000 and entered with #13.
; The image is self-contained and <=256 bytes. It performs only the approved
; local bootstrap transition; it does not assume a physical DMA backing map.

P130_B_ZXSTAT  EQU #04
P130_B_ZXDATWR EQU #03
P130_B_DMA_MOD EQU #1B
P130_B_DMA_CST EQU #1F
P130_B_GSCFG0  EQU #0F
P130_B_ENTRY   EQU #E0
P130_B_READY   EQU #A1

p130_ngs_boot_start:
        di
        ; Establish a valid private stack before any future CALL/interrupt use.
        ld      sp,#3FFF

        ; Stop the ZX DMA engine before changing the ROM/memory configuration.
        ld      a,1
        out     (P130_B_DMA_MOD),a
        xor     a
        out     (P130_B_DMA_CST),a
        ; Allow the DMA control write to settle.
        ld      b,0
p130_ngs_dma_settle:
        djnz    p130_ngs_dma_settle

        ; GSCFG0: clear RAMRO, enable NOROM + EXPAG.
        in      a,(P130_B_GSCFG0)
        and     #FD
        or      #09
        out     (P130_B_GSCFG0),a

        ; E0 confirms execution reached the bootstrap and completed the
        ; ROM/DMA transition. ATM must consume it before A1 is published.
        ld      a,P130_B_ENTRY
        call    p130_ngs_send_ack

        ; A1 is the stable bootstrap-ready acknowledgement.
        ld      a,P130_B_READY
        call    p130_ngs_send_ack

p130_ngs_boot_idle:
        di
        jr      p130_ngs_boot_idle

; A=ack byte. Bounded wait for the host data slot to become free and
; for the host to consume the byte (DBIT clear).
p130_ngs_send_ack:
        ld      (p130_ngs_ack),a
        ld      bc,#FFFF
p130_ngs_ack_wait_free:
        in      a,(P130_B_ZXSTAT)
        bit     7,a
        jr      z,p130_ngs_ack_slot_free
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_ngs_ack_wait_free
        jr      p130_ngs_boot_idle
p130_ngs_ack_slot_free:
        ld      a,(p130_ngs_ack)
        out     (P130_B_ZXDATWR),a
        ld      bc,#FFFF
p130_ngs_ack_wait_consumed:
        in      a,(P130_B_ZXSTAT)
        bit     7,a
        jr      z,p130_ngs_ack_done
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_ngs_ack_wait_consumed
        jr      p130_ngs_boot_idle
p130_ngs_ack_done:
        ret

p130_ngs_ack: db 0

p130_ngs_boot_end:
        ASSERT  p130_ngs_boot_end-p130_ngs_boot_start <= 256
