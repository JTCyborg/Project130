; =========================================================================
; PROJECT130 — GS105a stage-0 bootstrap.
; Protocol and execution sequence copied from working Project126. Only
; symbol prefix and diagnostic strings differ. Loaded at #4000 by #14/#13.
; =========================================================================
        DEVICE ZXSPECTRUM128
        ORG #4000

; =========================================================================
; PROJECT126 — GS105a stage-0 bootstrap
; Loaded at 4000h by ROM command #14, entered by ROM command #13.
; Receives one bounded resident image over the legacy DBIT byte channel.
; DBIT/GSDAT are used here only for ROM/bootstrap compatibility; ABI 1.0
; application payloads use DMA after the resident image has started.
; =========================================================================
P130_B_ZXSTAT EQU #04
P130_B_ZXDATRD EQU #02
P130_B_ZXDATWR EQU #03
P130_B_DMA_MOD EQU #1B
P130_B_DMA_CST EQU #1F
P130_B_GSCFG0 EQU #0F
P130_B_MPAGE EQU #00
P130_B_MPAGEEX EQU #10
P130_B_READY EQU #A1
P130_B_LENGTH_ACK EQU #A3
P130_B_ERROR EQU #E1

p130_ngs_boot_start:
        di
        ; Match the proven Project125 bootstrap entry sequence: establish a
        ; temporary stack before any CALL, stop ZX DMA, and allow the DMA
        ; control write to settle before switching to the DBIT byte channel.
        ld      sp,#3FFF
        ld      hl,p130_boot_msg_enter
        call    p130_boot_log
        ld      a,1
        out     (P130_B_DMA_MOD),a
        xor     a
        out     (P130_B_DMA_CST),a
        ld      b,0
.p130_boot_dma_disable_settle:
        djnz    .p130_boot_dma_disable_settle
        in      a,(P130_B_GSCFG0)
        and     #FD
        or      #09
        out     (P130_B_GSCFG0),a
        ld      hl,p130_boot_msg_norom
        call    p130_boot_log
        xor     a
        out     (#20),a                ; WIN0 -> physical page 00
        ld      a,#80
        out     (P130_B_MPAGE),a
        ld      a,#01
        out     (P130_B_MPAGEEX),a
        ; Install the operational temporary stack only after WIN3 is mapped.
        ld      sp,#FFFE
        ld      bc,#FF02
        in      a,(c)
        ld      a,P130_B_READY
        call    p130_boot_send_byte
        call    p130_boot_receive_byte
        ld      e,a
        call    p130_boot_receive_byte
        ld      d,a
        ld      a,d
        or      e
        jp      z,p130_bootstrap_error
        ld      a,d
        cp      #40
        jr      c,p130_bootstrap_length_ok
        jp      nz,p130_bootstrap_error
        ld      a,e
        or      a
        jp      nz,p130_bootstrap_error
p130_bootstrap_length_ok:
        push    bc
        ld      bc,#0400
p130_bootstrap_turnaround:
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_bootstrap_turnaround
        pop     bc
        ld      a,P130_B_LENGTH_ACK
        call    p130_boot_send_byte
        ld      hl,0
p130_bootstrap_copy:
        ld      a,d
        or      e
        jr      z,p130_bootstrap_enter
        call    p130_boot_receive_byte
        ld      (hl),a
        inc     hl
        dec     de
        jr      p130_bootstrap_copy
p130_bootstrap_enter:
        jp      0
p130_bootstrap_error:
        ld      a,P130_B_ERROR
        call    p130_boot_send_byte
p130_bootstrap_halt:
        di
        halt
        jr      p130_bootstrap_halt

p130_boot_send_byte:
        ld      (p130_boot_tx),a
        ld      bc,#FFFF
p130_boot_send_wait_free:
        in      a,(P130_B_ZXSTAT)
        bit     7,a
        jr      z,p130_boot_send_free
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_boot_send_wait_free
        jp      p130_bootstrap_halt
p130_boot_send_free:
        ld      a,(p130_boot_tx)
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
        jp      p130_bootstrap_halt
p130_boot_send_done:
        or      a
        ret

p130_boot_receive_byte:
        ld      bc,#FFFF
p130_boot_receive_wait:
        in      a,(P130_B_ZXSTAT)
        bit     7,a
        jr      nz,p130_boot_receive_ready
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_boot_receive_wait
        jp      p130_bootstrap_halt
p130_boot_receive_ready:
        in      a,(P130_B_ZXDATRD)
        or      a
        ret

; Independent NeoGS diagnostic output. This routine writes directly to the
; NeoGS CPU's own physical #EF debug port; ATM does not proxy these bytes.
p130_boot_log:
        push    af
        push    bc
        ld      bc,#00EF
.p130_boot_log_loop:
        ld      a,(hl)
        inc     hl
        or      a
        jr      z,.p130_boot_log_done
        out     (c),a
        jr      .p130_boot_log_loop
.p130_boot_log_done:
        pop     bc
        pop     af
        ret

p130_boot_msg_enter: db "[130] BOOT ENTER",13,10,0
p130_boot_msg_norom: db "[130] NOROM",13,10,0
p130_boot_tx: db 0
p130_ngs_boot_end:
