; Project130 Z88DK resident entry.
; First executable byte of P130BOOT.C at #6000; no CRT is linked.

SECTION CODE
PUBLIC _p130_entry
EXTERN _p130_c_entry
EXTERN _p130_neogs_startup
EXTERN _p130_neogs_entry_status

_p130_entry:
        ld      a,'>'
        ld      bc,00EFh
        out     (c),a
        di
        ld      sp,0AFFFh

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

        ; Run the NeoGS loader directly from the assembly entry, before C.
        ; Project126 invokes the same loader from its native Z80 host context;
        ; do not add a Z88DK C frame to the TR-DOS ROM-call path.
        ld      hl,p130_entry_ngs_begin
        call    p130_entry_debug_string
        call    _p130_neogs_startup
        ld      a,l
        ld      (_p130_neogs_entry_status),a

        ; C entry follows only after the complete NeoGS attempt has returned.
        call    _p130_c_entry

; C entry is expected to remain resident forever.
        ld      a,'R'
        ld      bc,00EFh
        out     (c),a
p130_idle:
        jr      p130_idle

; Port-#EF string output, used before the C runtime is entered.
p130_entry_debug_string:
        push    af
        push    bc
        ld      bc,00EFh
.p130_entry_debug_loop:
        ld      a,(hl)
        inc     hl
        or      a
        jr      z,.p130_entry_debug_done
        out     (c),a
        jr      .p130_entry_debug_loop
.p130_entry_debug_done:
        pop     bc
        pop     af
        ret

p130_entry_ngs_begin: db "[NEOGS] GS105a BOOTSTRAP LAUNCH BEGIN",13,10,0
