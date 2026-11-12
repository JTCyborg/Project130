; =========================================================================
; PROJECT130 — GS105a stage-0 bootstrap.
; Reference sequence: Project126 neogs_sub/p126_bootstrap.asm.
; Loaded at #4000 by ROM command #14, entered by ROM command #13.
;
; Project130 stops after the A1 bootstrap-ready handshake. Unlike the
; Project126 resident loader, it does not receive a resident payload through
; GSDAT: subsequent traffic belongs to the separately defined DMA/IPC layer.
; The WIN0/WIN3 selections below are the temporary bootstrap execution map,
; not a declaration of the final Project130 physical memory allocation.
; =========================================================================
P130_B_ZXSTAT  EQU #04
P130_B_ZXDATRD EQU #02
P130_B_ZXDATWR EQU #03
P130_B_DMA_MOD EQU #1B
P130_B_DMA_CST EQU #1F
P130_B_GSCFG0  EQU #0F
P130_B_MPAGE   EQU #00
P130_B_MPAGEEX EQU #10
P130_B_READY   EQU #A1

p130_ngs_boot_start:
        di
        ; Exact Project126 entry discipline: valid temporary stack before CALL.
        ld      sp,#3FFF

        ; Disable the ZX DMA engine and let the control write settle.
        ld      a,1
        out     (P130_B_DMA_MOD),a
        xor     a
        out     (P130_B_DMA_CST),a
        ld      b,0
p130_ngs_dma_disable_settle:
        djnz    p130_ngs_dma_disable_settle

        ; NOROM + EXPAG, RAMRO clear — same GSCFG0 transition as Project126.
        in      a,(P130_B_GSCFG0)
        and     #FD
        or      #09
        out     (P130_B_GSCFG0),a

        ; Project126 temporary bootstrap window setup.
        xor     a
        out     (#20),a
        ld      a,#80
        out     (P130_B_MPAGE),a
        ld      a,#01
        out     (P130_B_MPAGEEX),a
        ld      sp,#FFFE

        ; Match the GS105a handoff dummy read before publishing READY.
        ld      bc,#FF02
        in      a,(c)

        ; One and only one ready byte. The host consumes A1 and then starts
        ; its own DMA/IPC initialization; no E0 pre-ack or GSDAT payload.
        ld      a,P130_B_READY
        call    p130_ngs_send_byte

p130_ngs_boot_idle:
        di
        jr      p130_ngs_boot_idle

; A=byte. Same bounded DBIT producer handshake as Project126.
p130_ngs_send_byte:
        ld      (p130_ngs_tx),a
        ld      bc,#FFFF
p130_ngs_send_wait_free:
        in      a,(P130_B_ZXSTAT)
        bit     7,a
        jr      z,p130_ngs_send_free
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_ngs_send_wait_free
        jr      p130_ngs_boot_idle
p130_ngs_send_free:
        ld      a,(p130_ngs_tx)
        out     (P130_B_ZXDATWR),a
        ld      bc,#FFFF
p130_ngs_send_wait_read:
        in      a,(P130_B_ZXSTAT)
        bit     7,a
        jr      z,p130_ngs_send_done
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_ngs_send_wait_read
        jr      p130_ngs_boot_idle
p130_ngs_send_done:
        or      a
        ret

p130_ngs_tx: db 0
p130_ngs_boot_end:
        ASSERT  p130_ngs_boot_end-p130_ngs_boot_start <= 256
