; Project130 Z88DK resident entry.
; First executable byte of P130BOOT.C at #6000; no CRT is linked.

SECTION CODE
PUBLIC _p130_entry
EXTERN _p130_c_entry
EXTERN _p130_trdos_preload

_p130_entry:
        ld      a,'>'
        ld      bc,00EFh
        out     (c),a
        di
        ld      sp,0BFFFh

; Mark that control reached the resident entry before calling C.
        ld      a,'1'
        ld      bc,00EFh
        out     (c),a
        ld      a,'3'
        out     (c),a
        ld      a,'0'
        out     (c),a
        ld      a,13
        out     (c),a
        ld      a,10
        out     (c),a

        ; Match the proven ATM/Project127 TR-DOS ROM-call setup.
        ld      a,010h
        ld      bc,07FFDh
        out     (c),a
        ld      (05C3Bh),a
        xor     a
        ld      bc,0EFF7h
        out     (c),a

        ; Read track 0 sectors 1..8 into the host W3 buffer at #C800.
        call    _p130_trdos_preload

        ; Project127 startup contract: initialize the ATM/W3 console before
        ; entering the resident application services.
        call    0A000h

        call    _p130_c_entry

; C entry is expected to remain resident forever.
        ld      a,'R'
        ld      bc,00EFh
        out     (c),a
p130_idle:
        jr      p130_idle
