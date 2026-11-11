; Project130 resident Z80 entry.
; TR-DOS loads this image at #6000. Keep this as the first executable section.

SECTION CODE
PUBLIC _p130_entry
EXTERN _p130_c_entry

_p130_entry:
        di
        ld      sp,0BFFFh
        ld      bc,00EFh
        ld      a,'>'
        out     (c),a
        ld      a,'1'
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

p130_idle:
        jr      p130_idle
