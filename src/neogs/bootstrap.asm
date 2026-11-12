; =========================================================================
; PROJECT130 — GS105a stage-0 bootstrap.
; Entry and first-byte handshake are deliberately identical to the proven
; Project126 bootstrap. Loaded at #4000 by ROM command #14, entered by #13.
; Project130 stops after the common A1 handshake; DMA/IPC follows later.
; =========================================================================
        DEVICE ZXSPECTRUM128
        ORG #4000

P130_B_ZXSTAT  EQU #04
P130_B_ZXDATWR EQU #03
P130_B_DMA_MOD EQU #1B
P130_B_DMA_CST EQU #1F
P130_B_GSCFG0  EQU #0F
P130_B_MPAGE   EQU #00
P130_B_MPAGEEX EQU #10
P130_B_READY   EQU #A1

p130_ngs_boot_start:
        di
        ; Exact Project126 entry discipline: establish stack before CALL.
        ld      sp,#3FFF
        ld      hl,p130_boot_msg_enter
        call    p130_boot_log
        ; Stop ZX DMA and allow the control write to settle.
        ld      a,1
        out     (P130_B_DMA_MOD),a
        xor     a
        out     (P130_B_DMA_CST),a
        ld      b,0
p130_ngs_dma_disable_settle:
        djnz    p130_ngs_dma_disable_settle
        ; Exact Project126 NOROM + EXPAG transition.
        in      a,(P130_B_GSCFG0)
        and     #FD
        or      #09
        out     (P130_B_GSCFG0),a
        ld      hl,p130_boot_msg_norom
        call    p130_boot_log
        ; Exact Project126 temporary bootstrap window setup.
        xor     a
        out     (#20),a
        ld      a,#80
        out     (P130_B_MPAGE),a
        ld      a,#01
        out     (P130_B_MPAGEEX),a
        ld      sp,#FFFE
        ld      bc,#FF02
        in      a,(c)
        ; A1 is the FIRST DBIT byte, exactly as in Project126.
        ld      a,P130_B_READY
        call    p130_boot_send_byte
p130_ngs_boot_idle:
        di
        jr      p130_ngs_boot_idle

; A=byte. Same bounded DBIT producer handshake as Project126.
p130_boot_send_byte:
        ld      (p130_ngs_tx),a
        ld      bc,#FFFF
p130_boot_send_wait_free:
        in      a,(P130_B_ZXSTAT)
        bit     7,a
        jr      z,p130_boot_send_free
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_boot_send_wait_free
        jp      p130_ngs_boot_idle
p130_boot_send_free:
        ld      a,(p130_ngs_tx)
        out     (P130_B_ZXDATWR),a
        ld      bc,#FFFF
p130_boot_send_wait_read:
        in      a,(P130_B_ZXSTAT)
        bit     7,a
        jr      z,p130_boot_send_done
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_boot_send_wait_read
        jp      p130_ngs_boot_idle
p130_boot_send_done:
        or      a
        ret

; Independent NeoGS-side diagnostics, as in Project126.
p130_boot_log:
        push    af
        push    bc
        ld      bc,#00EF
p130_boot_log_loop:
        ld      a,(hl)
        inc     hl
        or      a
        jr      z,p130_boot_log_done
        out     (c),a
        jr      p130_boot_log_loop
p130_boot_log_done:
        pop     bc
        pop     af
        ret

p130_boot_msg_enter: db "[P130 NGS] BOOTSTRAP ENTER",13,10,0
p130_boot_msg_norom: db "[P130 NGS] NOROM ENABLED",13,10,0
p130_ngs_tx: db 0
p130_ngs_boot_end:
        ASSERT p130_ngs_boot_start = #4000
        ASSERT p130_ngs_boot_end <= #4100
        ASSERT p130_ngs_boot_end-p130_ngs_boot_start <= 256
