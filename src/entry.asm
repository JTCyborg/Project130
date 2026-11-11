; Project130 Z88DK resident entry.
; First executable byte of P130BOOT.C at #6000; no CRT is linked.

SECTION CODE
PUBLIC _p130_entry
EXTERN _p130_c_entry

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

        call    _p130_c_entry

; C entry is expected to remain resident forever.
        ld      a,'R'
        ld      bc,00EFh
        out     (c),a
p130_idle:
        jr      p130_idle
