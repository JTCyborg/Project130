; Project130 ATM Turbo 2+ physical W3 mapper backend.
; ATM2+ page dispatcher: W3=#FFF7, data=#7F-page.
; W0/W1/W2 are deliberately untouched. The UI bootstrap enables shadow ports
; and leaves W3 on physical page 0 before this backend is initialized.

SECTION CODE
PUBLIC _p130_map_hw_write
EXTERN _p130_map_hw_encoded

_p130_map_hw_write:
        push    af
        push    bc
        ld      a,(_p130_map_hw_encoded)
        ld      bc,0FFF7h
        out     (c),a
        pop     bc
        pop     af
        ret
