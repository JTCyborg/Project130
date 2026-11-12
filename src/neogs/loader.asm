; Complete Project126 ATM-side NeoGS loader ported to Project130.
SECTION CODE
PUBLIC _p130_neogs_startup
PUBLIC _p130_neogs_send_video_mode
PUBLIC _p130_neogs_stage
_p130_neogs_startup:
 call p130_neogs_startup_impl
 jr c,p130_c_startup_failed
 ld l,0
 ld h,0
 ret
p130_c_startup_failed:
 ld l,1
 ld h,0
 ret
_p130_neogs_send_video_mode:
 call p130_neogs_send_video_mode_impl
 jr c,p130_c_video_failed
 ld l,0
 ld h,0
 ret
p130_c_video_failed:
 ld l,1
 ld h,0
 ret
; =========================================================================
; PROJECT126 — ATM host NeoGS bootstrap/firmware loader
; Runs before ATM video paging is enabled. TR-DOS sector reads use the same
; C=5/B=1 ABI already validated by p126_catalog_read_disk.
; =========================================================================
P130_NGS_GSCOM EQU 0BBh
P130_NGS_GSSTAT EQU 0BBh
P130_NGS_GSDAT EQU 0B3h
P130_NGS_GSCTR EQU 033h
P130_NGS_CBIT EQU 0
P130_NGS_DBIT EQU 7
P130_NGS_CMD_RAM EQU 020h
P130_NGS_CMD_JUMP EQU 013h
P130_NGS_CMD_RECV EQU 014h
P130_NGS_ACK_READY EQU 0A1h
P130_NGS_ACK_LENGTH EQU 0A3h
P130_NGS_ACK_DONE EQU 0A2h
P130_NGS_TIMEOUT EQU 0FFFFh

; Called after directory preload and before ATM video initialization.
; Carry clear means the resident image sent its A2h ready acknowledgement.
p130_neogs_startup_impl:
        ld      a,'1'
        ld      (p130_neogs_startup_stage),a
        call    p130_neogs_trace_start
        ld      hl,p130_neogs_boot_name
        call    p130_neogs_open_file
        ret     c
        ld      a,'2'
        ld      (p130_neogs_startup_stage),a
        ; The build deliberately permits a full 256-byte ROM 014h block.
        ; Accept lengths 1..255 and exactly 256 (0100h); reject 0 and >256.
        ld      hl,(p130_neogs_file_length)
        ld      a,h
        or      a
        jr      z,p130_neogs_startup_impl__p130_neogs_boot_length_low
        cp      1
        jp      nz,p130_neogs_boot_file_bad
        ld      a,l
        or      a
        jp      nz,p130_neogs_boot_file_bad
        jr      p130_neogs_startup_impl__p130_neogs_boot_length_ok
p130_neogs_startup_impl__p130_neogs_boot_length_low:
        ld      a,l
        or      a
        jp      z,p130_neogs_boot_file_bad
p130_neogs_startup_impl__p130_neogs_boot_length_ok:

        ; Cold-restart the GS105a ROM only to enter its known bootstrap
        ; receive state. Do NOT query 020h: its RAM-size report is not an
        ; authority for Project126 physical memory and must not gate startup.
        ld      a,'A'
        ld      (p130_neogs_startup_stage),a
        ld      a,0F4h
        call    p130_neogs_send_command_long
        jp      c,p130_neogs_ram_bad



        ; GS105a 014h receives P126BOOT at logical 4000h.
        ld      a,'4'
        ld      (p130_neogs_startup_stage),a
        ld      hl,0
        ld      de,(p130_neogs_file_length)
        or      a
        sbc     hl,de
        ld      (p130_neogs_block_length),hl
        ld      a,l
        call    p130_neogs_send_argument
        ret     c
        ld      a,P130_NGS_CMD_RECV
        call    p130_neogs_send_command
        ret     c
        ld      a,(p130_neogs_block_length+1)
        call    p130_neogs_send_byte
        ret     c
        xor     a
        call    p130_neogs_send_byte
        ret     c
        ld      a,040h
        call    p130_neogs_send_byte
        ret     c
        ld      hl,0C000h
        ld      de,(p130_neogs_file_length)
p130_neogs_startup_impl__p130_neogs_boot_stream:
        ld      a,d
        or      e
        jr      z,p130_neogs_startup_impl__p130_neogs_boot_loaded
        ld      a,(hl)
        call    p130_neogs_send_byte
        ret     c
        inc     hl
        dec     de
        jr      p130_neogs_startup_impl__p130_neogs_boot_stream
p130_neogs_startup_impl__p130_neogs_boot_loaded:
        ; Read the first resident-image sector before starting stage-0.
        ld      a,'5'
        ld      (p130_neogs_startup_stage),a
        ld      hl,p130_neogs_core_name
        call    p130_neogs_open_file
        ret     c
        ld      a,'6'
        ld      (p130_neogs_startup_stage),a
        ld      hl,(p130_neogs_file_length)
        ld      a,h
        cp      040h
        jr      c,p130_neogs_startup_impl__p130_neogs_core_size_low
        jp      nz,p130_neogs_core_file_bad
        ld      a,l
        or      a
        jp      nz,p130_neogs_core_file_bad
p130_neogs_startup_impl__p130_neogs_core_size_low:
        ld      a,h
        or      l
        jp      z,p130_neogs_core_file_bad
        ld      hl,(p130_neogs_file_length)
        ld      (p130_neogs_core_length),hl

        ; Enter stage-0 at 4000h; it publishes A1h when ready.
        ; Keep each GS105a handshake independently visible in the runtime
        ; stage byte. This distinguishes DBIT argument timeout, CBIT command
        ; timeout, address-byte timeout and missing A1h response.
        ld      a,'a'                 ; argument byte (00h) / DBIT clear
        ld      (p130_neogs_startup_stage),a
        xor     a
        call    p130_neogs_send_argument
        ret     c
        ld      a,'b'                 ; command 13h / CBIT clear
        ld      (p130_neogs_startup_stage),a
        ld      a,P130_NGS_CMD_JUMP
        call    p130_neogs_send_command
        ret     c
        ld      a,'c'                 ; destination high byte 40h
        ld      (p130_neogs_startup_stage),a
        ld      a,040h
        call    p130_neogs_send_byte
        jr      nc,p130_neogs_startup_impl__p130_neogs_jump_tx_done
        ld      a,'d'                 ; distinguish A1h wait after command TX
        ld      (p130_neogs_startup_stage),a
        in      a,(P130_NGS_GSSTAT)
        bit     P130_NGS_DBIT,a
        jp      z,p130_neogs_transport_error
        call    p130_neogs_receive_byte
        ret     c
        cp      P130_NGS_ACK_READY
        jp      nz,p130_neogs_transport_error
        jr      p130_neogs_startup_impl__p130_neogs_stage0_ready
p130_neogs_startup_impl__p130_neogs_jump_tx_done:
        ld      a,'e'                 ; normal TX path: wait for A1h
        ld      (p130_neogs_startup_stage),a
        call    p130_neogs_receive_byte
        ret     c
        cp      P130_NGS_ACK_READY
        jp      nz,p130_neogs_transport_error

p130_neogs_startup_impl__p130_neogs_stage0_ready:
        ; Length exchange; A3h confirms the resident image size.
        ld      a,'8'
        ld      (p130_neogs_startup_stage),a
        ld      hl,(p130_neogs_core_length)
        ld      a,l
        call    p130_neogs_send_byte
        ret     c
        ld      a,h
        call    p130_neogs_send_byte
        jr      nc,p130_neogs_startup_impl__p130_neogs_length_sent
        in      a,(P130_NGS_GSSTAT)
        bit     P130_NGS_DBIT,a
        jp      z,p130_neogs_transport_error
        call    p130_neogs_receive_byte
        ret     c
        cp      P130_NGS_ACK_LENGTH
        jp      nz,p130_neogs_transport_error
        jr      p130_neogs_startup_impl__p130_neogs_stream_begin
p130_neogs_startup_impl__p130_neogs_length_sent:
        call    p130_neogs_receive_byte
        ret     c
        cp      P130_NGS_ACK_LENGTH
        jp      nz,p130_neogs_transport_error

p130_neogs_startup_impl__p130_neogs_stream_begin:
        ld      a,'9'
        ld      (p130_neogs_startup_stage),a
        ld      hl,0C000h
        ld      (p130_neogs_buffer_ptr),hl
        ld      hl,256
        ld      (p130_neogs_buffer_remaining),hl
        ld      de,(p130_neogs_core_length)
p130_neogs_startup_impl__p130_neogs_core_stream:
        ld      a,d
        or      e
        jr      z,p130_neogs_startup_impl__p130_neogs_core_stream_done

        ; Project125 V1 streaming order: refill only after the current
        ; 256-byte buffer is fully consumed, then send each byte and wait
        ; for DBIT consumption before advancing to the next byte.
        ld      hl,(p130_neogs_buffer_remaining)
        ld      a,h
        or      l
        jr      nz,p130_neogs_startup_impl__p130_neogs_core_buffer_ready
        push    de
        call    p130_neogs_read_next_sector
        pop     de
        jp      c,p130_neogs_transport_error
        ld      hl,0C000h
        ld      (p130_neogs_buffer_ptr),hl
        ld      hl,256
        ld      (p130_neogs_buffer_remaining),hl
p130_neogs_startup_impl__p130_neogs_core_buffer_ready:
        ld      hl,(p130_neogs_buffer_ptr)
        ld      a,(hl)
        call    p130_neogs_send_byte
        jp      c,p130_neogs_transport_error
        inc     hl
        ld      (p130_neogs_buffer_ptr),hl
        ld      hl,(p130_neogs_buffer_remaining)
        dec     hl
        ld      (p130_neogs_buffer_remaining),hl
        dec     de
        jr      p130_neogs_startup_impl__p130_neogs_core_stream

p130_neogs_startup_impl__p130_neogs_core_stream_done:
        ; Separate payload transfer from the final resident-ready handshake.
        ld      a,'B'
        ld      (p130_neogs_startup_stage),a
        ; As in Project125, receive the resident-ready ACK only after every
        ; payload byte has completed its DBIT-consumed handshake.
        call    p130_neogs_receive_byte
        ret     c
        cp      P130_NGS_ACK_DONE
        jp      nz,p130_neogs_transport_error

        ; Separate the final ACK from manifest file I/O/validation.
        ld      a,'M'
        ld      (p130_neogs_startup_stage),a
        ; Load and validate the versioned module directory before installing
        ; any overlay. It is the build-produced source of size/CRC/page metadata.
        call    p130_neogs_load_manifest
        ret     c

        ; The resident now owns GSCOM and is polling the ABI 1.0 DMA endpoint.
        ; Iterate the module descriptors instead of maintaining four separate
        ; startup call sites. Each descriptor is cross-checked with X86MODS.M.
        ld      hl,p130_neogs_module_table
        ld      b,6
p130_neogs_startup_impl__p130_neogs_module_loop:
        ld      a,(hl)                 ; module ID
        ld      (p130_neogs_manifest_module_id),a
        inc     hl
        ld      a,(hl)                 ; IMAGE kind
        ld      (p130_neogs_overlay_kind),a
        inc     hl
        ld      a,(hl)                 ; physical overlay page
        ld      (p130_neogs_overlay_page),a
        inc     hl
        ld      e,(hl)                 ; maximum size
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      (p130_neogs_overlay_max_size),de
        ld      e,(hl)                 ; TR-DOS filename pointer
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)                 ; preserve startup diagnostic stage
        ld      (p130_neogs_startup_stage),a
        inc     hl
        push    hl                     ; next descriptor
        ex      de,hl
        ld      a,(p130_neogs_overlay_kind)
        ld      de,(p130_neogs_overlay_max_size)
        push    bc                     ; loader/IPC routines may use B
        call    p130_neogs_load_fixed_overlay
        pop     bc
        pop     hl
        ret     c
        djnz    p130_neogs_startup_impl__p130_neogs_module_loop

p130_neogs_startup_impl__p130_neogs_startup_done:
        ld      a,'0'
        ld      (p130_neogs_startup_stage),a
        xor     a
        ret

; -------------------------------------------------------------------------
; Version-1 X86MODS.M loader and validator.
; Layout: 7-byte header followed by six 8-byte records:
; id, physical page, flags, reserved, size16, CRC16/CCITT-FALSE.
; -------------------------------------------------------------------------
p130_neogs_load_manifest:
        ; Lowercase sub-stages identify the manifest open and validation path.
        ld      a,'m'
        ld      (p130_neogs_startup_stage),a
        xor     a
        ld      (p130_neogs_manifest_valid),a
        ld      hl,p130_neogs_manifest_name
        ; X86MODS uses the TR-DOS CODE extension (C), like the overlays.
        ld      a,'C'
        ld      (p130_neogs_file_extension),a
        call    p130_neogs_open_file
        ret     c
        ; V remains active only while checking the exact 55-byte file size.
        ld      a,'V'
        ld      (p130_neogs_startup_stage),a
        ld      hl,(p130_neogs_file_length)
        ld      de,55
        or      a
        sbc     hl,de
        jp      nz,p130_neogs_load_manifest__manifest_bad
        ld      hl,0C000h
        ld      de,p130_neogs_manifest
        ld      bc,55
        ldir

        ld      hl,p130_neogs_manifest
        ld      a,'a'
        ld      (p130_neogs_startup_stage),a
        ld      a,(hl)
        cp      'P'
        jp      nz,p130_neogs_load_manifest__manifest_bad
        inc     hl
        ld      a,'b'
        ld      (p130_neogs_startup_stage),a
        ld      a,(hl)
        cp      '1'
        jp      nz,p130_neogs_load_manifest__manifest_bad
        inc     hl
        ld      a,'c'
        ld      (p130_neogs_startup_stage),a
        ld      a,(hl)
        cp      '2'
        jp      nz,p130_neogs_load_manifest__manifest_bad
        inc     hl
        ld      a,'d'
        ld      (p130_neogs_startup_stage),a
        ld      a,(hl)
        cp      '6'
        jp      nz,p130_neogs_load_manifest__manifest_bad
        inc     hl
        ld      a,'e'
        ld      (p130_neogs_startup_stage),a
        ld      a,(hl)
        cp      1
        jp      nz,p130_neogs_load_manifest__manifest_bad
        inc     hl
        ld      a,'f'
        ld      (p130_neogs_startup_stage),a
        ld      a,(hl)
        cp      6
        jp      nz,p130_neogs_load_manifest__manifest_bad
        inc     hl
        ld      a,'g'
        ld      (p130_neogs_startup_stage),a
        ld      a,(hl)
        cp      8
        jp      nz,p130_neogs_load_manifest__manifest_bad

        ld      hl,p130_neogs_manifest+7
        ld      b,6
        ld      c,1
        ld      d,4
p130_neogs_load_manifest__manifest_record_loop:
        ld      a,c
        ld      (p130_neogs_manifest_record_index),a
        ld      a,'h'
        ld      (p130_neogs_startup_stage),a
        ld      a,(hl)
        cp      c
        jp      nz,p130_neogs_load_manifest__manifest_bad
        inc     hl
        ld      a,'i'
        ld      (p130_neogs_startup_stage),a
        ld      a,(hl)
        cp      d
        jp      nz,p130_neogs_load_manifest__manifest_bad
        inc     hl
        ld      a,'j'
        ld      (p130_neogs_startup_stage),a
        ld      a,(hl)
        cp      1
        jp      nz,p130_neogs_load_manifest__manifest_bad
        inc     hl
        ld      a,'k'
        ld      (p130_neogs_startup_stage),a
        ld      a,(hl)
        or      a
        jp      nz,p130_neogs_load_manifest__manifest_bad
        inc     hl
        ld      a,'l'
        ld      (p130_neogs_startup_stage),a
        ld      a,(hl)
        ld      e,a
        ld      (p130_neogs_manifest_record_size),a
        inc     hl
        ld      a,(hl)
        ld      (p130_neogs_manifest_record_size+1),a
        inc     hl
        ; OR is used only for the zero-size test and destroys A. Reload the
        ; original high byte before applying the 16 KiB per-module limit.
        or      e
        jr      z,p130_neogs_load_manifest__manifest_bad
        ld      a,'m'
        ld      (p130_neogs_startup_stage),a
        ld      a,(p130_neogs_manifest_record_size+1)
        cp      040h
        jr      c,p130_neogs_load_manifest__manifest_size_ok
        jp      nz,p130_neogs_load_manifest__manifest_bad
        ld      a,e
        or      a
        jp      nz,p130_neogs_load_manifest__manifest_bad
p130_neogs_load_manifest__manifest_size_ok:
        inc     hl
        inc     hl
        inc     c
        inc     d
        djnz    p130_neogs_load_manifest__manifest_record_loop
        ld      a,1
        ld      (p130_neogs_manifest_valid),a
        or      a
        ret
p130_neogs_load_manifest__manifest_bad:
        ld      a,10
        ld      (p130_neogs_startup_error),a
        scf
        ret

; Verify the just-staged overlay against its catalog record before IMAGE_BEGIN.
; IN: p130_neogs_overlay_kind and p130_neogs_overlay_size.
; OUT: carry clear on exact size+CRC match.
p130_neogs_verify_overlay_manifest:
        ld      a,(p130_neogs_manifest_valid)
        or      a
        jp      z,p130_neogs_verify_overlay_manifest__manifest_verify_bad
        ld      a,(p130_neogs_overlay_kind)
        cp      P126_IMAGE_KIND_X86IO
        jr      nz,p130_neogs_verify_overlay_manifest__manifest_verify_alu
        ld      a,1
        jr      p130_neogs_verify_overlay_manifest__manifest_verify_id
p130_neogs_verify_overlay_manifest__manifest_verify_alu:
        cp      P126_IMAGE_KIND_X86ALU
        jr      nz,p130_neogs_verify_overlay_manifest__manifest_verify_dev
        ld      a,2
        jr      p130_neogs_verify_overlay_manifest__manifest_verify_id
p130_neogs_verify_overlay_manifest__manifest_verify_dev:
        cp      P126_IMAGE_KIND_X86DEV
        jr      nz,p130_neogs_verify_overlay_manifest__manifest_verify_exec
        ld      a,3
        jr      p130_neogs_verify_overlay_manifest__manifest_verify_id
p130_neogs_verify_overlay_manifest__manifest_verify_exec:
        cp      P126_IMAGE_KIND_X86EXEC
        jr      nz,p130_neogs_verify_overlay_manifest__manifest_verify_vga
        ld      a,4
        jr      p130_neogs_verify_overlay_manifest__manifest_verify_id
p130_neogs_verify_overlay_manifest__manifest_verify_vga:
        cp      P126_IMAGE_KIND_X86VGA
        jr      nz,p130_neogs_verify_overlay_manifest__manifest_verify_vid
        ld      a,5
        jr      p130_neogs_verify_overlay_manifest__manifest_verify_id
p130_neogs_verify_overlay_manifest__manifest_verify_vid:
        cp      P126_IMAGE_KIND_X86VID
        jp      nz,p130_neogs_verify_overlay_manifest__manifest_verify_bad
        ld      a,6
p130_neogs_verify_overlay_manifest__manifest_verify_id:
        ; Descriptor ID and IMAGE kind must identify the same module.
        ld      b,a
        ld      a,(p130_neogs_manifest_module_id)
        cp      b
        jp      nz,p130_neogs_verify_overlay_manifest__manifest_verify_bad
        ld      a,b
        dec     a
        add     a,a
        add     a,a
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,p130_neogs_manifest+7
        add     hl,de
        ld      (p130_neogs_manifest_record_ptr),hl

        ; The build descriptor and manifest must agree on physical placement.
        inc     hl
        ld      a,(hl)
        ld      b,a
        ld      a,(p130_neogs_overlay_page)
        cp      b
        jp      nz,p130_neogs_verify_overlay_manifest__manifest_verify_bad

        ; Exact size must agree with the directory record.
        inc     hl
        inc     hl
        inc     hl
        ld      de,(p130_neogs_overlay_size)
        ld      a,(hl)
        cp      e
        jr      nz,p130_neogs_verify_overlay_manifest__manifest_verify_bad
        inc     hl
        ld      a,(hl)
        cp      d
        jr      nz,p130_neogs_verify_overlay_manifest__manifest_verify_bad

        ; CRC the exact logical file bytes in the DMA frame staging area.
        ld      hl,0FFFFh
        ld      de,0C01Ch
        ld      bc,(p130_neogs_overlay_size)
p130_neogs_verify_overlay_manifest__manifest_crc_loop:
        ld      a,b
        or      c
        jr      z,p130_neogs_verify_overlay_manifest__manifest_crc_done
        ld      a,(de)
        call    p126_ipc_crc16_update
        inc     de
        dec     bc
        jr      p130_neogs_verify_overlay_manifest__manifest_crc_loop
p130_neogs_verify_overlay_manifest__manifest_crc_done:
        ld      (p130_neogs_manifest_crc_work),hl
        ld      hl,(p130_neogs_manifest_record_ptr)
        ld      de,6
        add     hl,de
        ld      de,(p130_neogs_manifest_crc_work)
        ld      a,(hl)
        cp      e
        jr      nz,p130_neogs_verify_overlay_manifest__manifest_verify_bad
        inc     hl
        ld      a,(hl)
        cp      d
        jr      nz,p130_neogs_verify_overlay_manifest__manifest_verify_bad
        or      a
        ret
p130_neogs_verify_overlay_manifest__manifest_verify_bad:
        scf
        ret

; -------------------------------------------------------------------------
; Load fixed-origin X86IO/X86ALU overlays from TR-DOS through the shared
; ABI 1.0 fixed-profile IMAGE service.
;
; p130_neogs_open_file reads sector 0 to C000h and leaves the remaining
; sector cursor in the shared TR-DOS state. Move the first sector backwards
; into the IMAGE fragment data area at C01Ch (overlap-safe LDDR), then read
; subsequent sectors directly into the following 256-byte slots. This avoids
; a second staging buffer and preserves the 18-byte frame header.
; -------------------------------------------------------------------------
; Shared module loader. IN: HL=TR-DOS 8-byte name, A=IMAGE kind,
; DE=maximum accepted size. The manifest verifier binds the descriptor ID,
; exact file length and CRC before the DMA transaction is allowed to start.
p130_neogs_load_fixed_overlay:
        ld      (p130_neogs_overlay_kind),a
        ld      (p130_neogs_overlay_max_size),de
        call    p130_neogs_open_file
        jr      nc,p130_neogs_load_fixed_overlay__fixed_overlay_open
        ld      a,5
        jp      p130_neogs_store_error

p130_neogs_load_fixed_overlay__fixed_overlay_open:
        ld      hl,(p130_neogs_file_length)
        ld      a,h
        or      l
        jr      z,p130_neogs_load_fixed_overlay__fixed_overlay_bad_size
        ld      de,(p130_neogs_overlay_max_size)
        or      a
        sbc     hl,de
        jr      c,p130_neogs_load_fixed_overlay__fixed_overlay_size_ok
        jr      z,p130_neogs_load_fixed_overlay__fixed_overlay_size_ok
p130_neogs_load_fixed_overlay__fixed_overlay_bad_size:
        ld      a,6
        jp      p130_neogs_store_error

p130_neogs_load_fixed_overlay__fixed_overlay_size_ok:
        ld      hl,(p130_neogs_file_length)
        ld      (p130_neogs_overlay_size),hl

        ; The first sector is already in C000h. Copy min(file_size,256)
        ; bytes backwards to C01Ch so source/destination overlap is safe.
        ld      hl,(p130_neogs_file_length)
        ld      de,256
        or      a
        sbc     hl,de
        jr      c,p130_neogs_load_fixed_overlay__fixed_overlay_first_partial
        ld      bc,256
        jr      p130_neogs_load_fixed_overlay__fixed_overlay_first_copy
p130_neogs_load_fixed_overlay__fixed_overlay_first_partial:
        ld      bc,(p130_neogs_file_length)
p130_neogs_load_fixed_overlay__fixed_overlay_first_copy:
        ld      hl,0C000h
        add     hl,bc
        dec     hl
        push    hl
        ld      hl,0C01Ch
        add     hl,bc
        dec     hl
        ex      de,hl
        pop     hl
        lddr

        ; Remaining sectors are read directly after the first 256-byte block.
        ld      hl,0C11Ch
        ld      (p130_neogs_overlay_data_ptr),hl
p130_neogs_load_fixed_overlay__fixed_overlay_sector_loop:
        ld      a,(p130_neogs_file_sectors_left)
        or      a
        jr      z,p130_neogs_load_fixed_overlay__fixed_overlay_data_ready
        call    p130_neogs_overlay_read_sector
        jr      nc,p130_neogs_load_fixed_overlay__fixed_overlay_sector_ok
        ld      a,7
        jp      p130_neogs_store_error
p130_neogs_load_fixed_overlay__fixed_overlay_sector_ok:
        ld      hl,(p130_neogs_overlay_data_ptr)
        ld      de,256
        add     hl,de
        ld      (p130_neogs_overlay_data_ptr),hl
        jr      p130_neogs_load_fixed_overlay__fixed_overlay_sector_loop

p130_neogs_load_fixed_overlay__fixed_overlay_data_ready:
        ; IMAGE_BEGIN: id=1, kind, physical destination page, exact u16 byte length.
        ld      a,1
        ld      (0C012h),a
        xor     a
        ld      (0C013h),a
        ld      a,(p130_neogs_overlay_kind)
        ld      (0C014h),a
        ld      a,(p130_neogs_overlay_page)
        ld      (0C015h),a
        ld      hl,(p130_neogs_overlay_size)
        ld      (0C016h),hl
        xor     a
        ld      (p126_bios_frame_flags),a
        call    p130_neogs_verify_overlay_manifest
        jr      nc,p130_neogs_load_fixed_overlay__fixed_overlay_manifest_ok
        ld      a,9
        jp      p130_neogs_store_error
p130_neogs_load_fixed_overlay__fixed_overlay_manifest_ok:
        ld      a,(p130_neogs_overlay_kind)
        cp      P126_IMAGE_KIND_X86IO
        jr      nz,p130_neogs_load_fixed_overlay__fixed_overlay_log_not_io
        ld      hl,p130_neogs_io_log_begin
        jr      p130_neogs_load_fixed_overlay__fixed_overlay_log_begin
p130_neogs_load_fixed_overlay__fixed_overlay_log_not_io:
        cp      P126_IMAGE_KIND_X86ALU
        jr      nz,p130_neogs_load_fixed_overlay__fixed_overlay_log_dev_begin
        ld      hl,p130_neogs_alu_log_begin
        jr      p130_neogs_load_fixed_overlay__fixed_overlay_log_begin
p130_neogs_load_fixed_overlay__fixed_overlay_log_dev_begin:
        cp      P126_IMAGE_KIND_X86DEV
        jr      nz,p130_neogs_load_fixed_overlay__fixed_overlay_log_exec_begin
        ld      hl,p130_neogs_dev_log_begin
        jr      p130_neogs_load_fixed_overlay__fixed_overlay_log_begin
p130_neogs_load_fixed_overlay__fixed_overlay_log_exec_begin:
        cp      P126_IMAGE_KIND_X86VID
        jr      nz,p130_neogs_load_fixed_overlay__fixed_overlay_log_vid_begin
        ld      hl,p130_neogs_vid_log_begin
        jr      p130_neogs_load_fixed_overlay__fixed_overlay_log_begin
p130_neogs_load_fixed_overlay__fixed_overlay_log_vid_begin:
        cp      P126_IMAGE_KIND_X86VGA
        jr      nz,p130_neogs_load_fixed_overlay__fixed_overlay_log_vga_begin
        ld      hl,p130_neogs_vga_log_begin
        jr      p130_neogs_load_fixed_overlay__fixed_overlay_log_begin
p130_neogs_load_fixed_overlay__fixed_overlay_log_vga_begin:
        ld      hl,p130_neogs_exec_log_begin
p130_neogs_load_fixed_overlay__fixed_overlay_log_begin:
        call    p130_neogs_log_text
        ld      bc,6
        ld      de,1
        xor     a
        call    p126_bios_send_frame
        jp      c,p130_neogs_load_fixed_overlay__fixed_overlay_transport_error

        ; One FRAGMENT: id=1, index=0, count=1, u32 total length.
        ld      a,1
        ld      (0C012h),a
        xor     a
        ld      (0C013h),a
        xor     a
        ld      (0C014h),a
        ld      (0C015h),a
        ld      a,1
        ld      (0C016h),a
        xor     a
        ld      (0C017h),a
        ld      hl,(p130_neogs_overlay_size)
        ld      (0C018h),hl
        xor     a
        ld      (0C01Ah),a
        ld      (0C01Bh),a
        ld      hl,(p130_neogs_overlay_size)
        ld      de,P126_IPC_FRAGMENT_HEADER
        add     hl,de
        ld      b,h
        ld      c,l
        ld      a,P126_FLAG_FRAGMENT
        ld      (p126_bios_frame_flags),a
        ld      de,2
        ld      a,P126_OP_IMAGE_FRAGMENT
        call    p126_bios_send_frame
        jp      c,p130_neogs_load_fixed_overlay__fixed_overlay_transport_error

        ; IMAGE_FINISH is accepted only after target readback and gate checks.
        ld      a,1
        ld      (0C012h),a
        xor     a
        ld      (0C013h),a
        xor     a
        ld      (p126_bios_frame_flags),a
        ld      bc,2
        ld      de,3
        ld      a,P126_OP_IMAGE_FINISH
        call    p126_bios_send_frame
        jr      c,p130_neogs_load_fixed_overlay__fixed_overlay_transport_error

        ld      a,(p130_neogs_overlay_kind)
        cp      P126_IMAGE_KIND_X86IO
        jr      nz,p130_neogs_load_fixed_overlay__fixed_overlay_log_not_io_ready
        ld      hl,p130_neogs_io_log_ready
        jr      p130_neogs_load_fixed_overlay__fixed_overlay_log_ready
p130_neogs_load_fixed_overlay__fixed_overlay_log_not_io_ready:
        cp      P126_IMAGE_KIND_X86ALU
        jr      nz,p130_neogs_load_fixed_overlay__fixed_overlay_log_dev_ready
        ld      hl,p130_neogs_alu_log_ready
        jr      p130_neogs_load_fixed_overlay__fixed_overlay_log_ready
p130_neogs_load_fixed_overlay__fixed_overlay_log_dev_ready:
        cp      P126_IMAGE_KIND_X86DEV
        jr      nz,p130_neogs_load_fixed_overlay__fixed_overlay_log_exec_ready
        ld      hl,p130_neogs_dev_log_ready
        jr      p130_neogs_load_fixed_overlay__fixed_overlay_log_ready
p130_neogs_load_fixed_overlay__fixed_overlay_log_exec_ready:
        cp      P126_IMAGE_KIND_X86VID
        jr      nz,p130_neogs_load_fixed_overlay__fixed_overlay_log_vid_ready
        ld      hl,p130_neogs_vid_log_ready
        jr      p130_neogs_load_fixed_overlay__fixed_overlay_log_ready
p130_neogs_load_fixed_overlay__fixed_overlay_log_vid_ready:
        cp      P126_IMAGE_KIND_X86VGA
        jr      nz,p130_neogs_load_fixed_overlay__fixed_overlay_log_vga_ready
        ld      hl,p130_neogs_vga_log_ready
        jr      p130_neogs_load_fixed_overlay__fixed_overlay_log_ready
p130_neogs_load_fixed_overlay__fixed_overlay_log_vga_ready:
        ld      hl,p130_neogs_exec_log_ready
p130_neogs_load_fixed_overlay__fixed_overlay_log_ready:
        call    p130_neogs_log_text
        or      a
        ret

p130_neogs_load_fixed_overlay__fixed_overlay_transport_error:
        ld      a,8
        jp      p130_neogs_store_error

p130_neogs_overlay_read_sector:
        ld      a,(p130_neogs_file_sectors_left)
        or      a
        jr      nz,p130_neogs_overlay_read_sector__overlay_sector_available
        scf
        ret
p130_neogs_overlay_read_sector__overlay_sector_available:
        ld      a,(p130_neogs_file_track)
        ld      d,a
        ld      a,(p130_neogs_file_sector)
        ld      e,a
        ld      hl,(p130_neogs_overlay_data_ptr)
        ld      b,1
        ld      c,5
        xor     a
        ld      (05D0Fh),a
        ld      (05D10h),a
        push    af
        ld      a,'r'
        call    p130_neogs_trace_char
        pop     af
        call 03D13h
        push    af
        ld      a,'R'
        call    p130_neogs_trace_char
        pop     af
        ld      a,(05D0Fh)
        ld      b,a
        ld      a,(05D10h)
        or      b
        jr      nz,p130_neogs_overlay_read_sector__overlay_sector_failed

        ld      a,(p130_neogs_file_sector)
        inc     a
        cp      16
        jr      c,p130_neogs_overlay_read_sector__overlay_sector_same_track
        xor     a
        ld      (p130_neogs_file_sector),a
        ld      a,(p130_neogs_file_track)
        inc     a
        ld      (p130_neogs_file_track),a
        jr      p130_neogs_overlay_read_sector__overlay_sector_advance_done
p130_neogs_overlay_read_sector__overlay_sector_same_track:
        ld      (p130_neogs_file_sector),a
p130_neogs_overlay_read_sector__overlay_sector_advance_done:
        ld      a,(p130_neogs_file_sectors_left)
        dec     a
        ld      (p130_neogs_file_sectors_left),a
        or      a
        ret
p130_neogs_overlay_read_sector__overlay_sector_failed:
        scf
        ret

p130_neogs_boot_file_bad:
        ld      a,1
        jr      p130_neogs_store_error
p130_neogs_core_file_bad:
        ld      a,2
        jr      p130_neogs_store_error
p130_neogs_ram_bad:
        ld      a,3
        jr      p130_neogs_store_error
p130_neogs_transport_error:
        ld      a,4
p130_neogs_store_error:
        ld      (p130_neogs_startup_error),a
        scf
        ret

; IN HL=exact 8-character filename. Directory was preloaded at C800h.
; OUT: carry clear, first sector at C000h, metadata initialized.
p130_neogs_open_file:
        ; Exact Project125 TR-DOS ROM file-open ABI:
        ; C=00Ah searches the 8-character name + extension C at 05CDDh,
        ; then C=008h returns the full descriptor in 05CE8h..05CECh.
        ; Do not parse the preloaded catalogue entries ourselves.
        ld      (p130_neogs_name_ptr),hl
        ld      hl,(p130_neogs_name_ptr)
        ld      de,05CDDh
        ld      bc,8
        ldir
        ld      a,(p130_neogs_file_extension)
        ld      (05CE5h),a
        ld      a,9
        ld      (05D06h),a
        ld      c,10
        push    af
        ld      a,'o'
        call    p130_neogs_trace_char
        pop     af
        call 03D13h
        push    af
        ld      a,'O'
        call    p130_neogs_trace_char
        pop     af
        ld      a,c
        cp      0FFh
        jp      z,p130_neogs_open_file__p130_neogs_file_not_found

        ; C=00Ah returns the directory slot in A; C=008h fetches its descriptor.
        push    af
        xor     a
        ld      (05D0Fh),a
        ld      (05D10h),a
        pop     af
        ld      c,8
        push    af
        ld      a,'d'
        call    p130_neogs_trace_char
        pop     af
        call 03D13h
        push    af
        ld      a,'D'
        call    p130_neogs_trace_char
        pop     af
        ld      a,(05D0Fh)
        ld      b,a
        ld      a,(05D10h)
        or      b
        jp      nz,p130_neogs_open_file__p130_neogs_bad_descriptor

        ; Match Project125: use exact file length and derive sector count
        ; from it, rather than trusting a potentially stale directory count.
        ld      hl,(05CE8h)
        ld      (p130_neogs_file_length),hl
        ld      a,h
        or      l
        jp      z,p130_neogs_open_file__p130_neogs_bad_length
        ld      de,0C010h
        or      a
        sbc     hl,de
        jr      c,p130_neogs_open_file__p130_neogs_file_length_ok
        jp      nz,p130_neogs_open_file__p130_neogs_bad_length
p130_neogs_open_file__p130_neogs_file_length_ok:
        ld      hl,(p130_neogs_file_length)
        ld      de,255
        add     hl,de
        ld      a,h
        or      a
        jp      z,p130_neogs_open_file__p130_neogs_bad_descriptor
        ld      (p130_neogs_file_sectors_left),a

        ld      a,(05CEBh)
        cp      16
        jp      nc,p130_neogs_open_file__p130_neogs_bad_descriptor
        ld      (p130_neogs_file_sector),a
        ld      a,(05CECh)
        ld      (p130_neogs_file_track),a

        ; Acquire only the first sector now; subsequent sectors are read
        ; on demand after the current 256-byte buffer has been consumed.
        ld      a,'s'
        call    p130_neogs_trace_char
        call    p130_neogs_read_next_sector
        ret     c
        ld      hl,0C000h
        ld      (p130_neogs_buffer_ptr),hl
        ld      hl,256
        ld      (p130_neogs_buffer_remaining),hl
        xor     a
        ret

p130_neogs_open_file__p130_neogs_file_not_found:
        ld      a,1
        jr      p130_neogs_open_file__p130_neogs_open_failed
p130_neogs_open_file__p130_neogs_bad_descriptor:
        ld      a,2
        jr      p130_neogs_open_file__p130_neogs_open_failed
p130_neogs_open_file__p130_neogs_bad_length:
        ld      a,3
        jr      p130_neogs_open_file__p130_neogs_open_failed
p130_neogs_open_file__p130_neogs_open_failed:
        ld      (p130_neogs_io_error),a
        scf
        ret

p130_neogs_read_next_sector:
        ; Direct Project125 sector reader: C=5, B=1, HL=0C000h,
        ; DE=track/sector. Advance cursor only after successful ROM return.
        ld      a,(p130_neogs_file_sectors_left)
        or      a
        jr      nz,p130_neogs_read_next_sector__p130_neogs_sector_available
        scf
        ret
p130_neogs_read_next_sector__p130_neogs_sector_available:
        ld      a,(p130_neogs_file_track)
        ld      d,a
        ld      a,(p130_neogs_file_sector)
        ld      e,a
        ld      hl,0C000h
        ld      b,1
        ld      c,5
        xor     a
        ld      (05D0Fh),a
        ld      (05D10h),a
        call 03D13h
        ld      a,(05D0Fh)
        ld      b,a
        ld      a,(05D10h)
        or      b
        jr      nz,p130_neogs_read_next_sector__p130_neogs_sector_io_error

        ld      a,(p130_neogs_file_sector)
        inc     a
        cp      16
        jr      c,p130_neogs_read_next_sector__p130_neogs_sector_same_track
        xor     a
        ld      (p130_neogs_file_sector),a
        ld      a,(p130_neogs_file_track)
        inc     a
        ld      (p130_neogs_file_track),a
        jr      p130_neogs_read_next_sector__p130_neogs_sector_cursor_advanced
p130_neogs_read_next_sector__p130_neogs_sector_same_track:
        ld      (p130_neogs_file_sector),a
p130_neogs_read_next_sector__p130_neogs_sector_cursor_advanced:
        ld      a,(p130_neogs_file_sectors_left)
        dec     a
        ld      (p130_neogs_file_sectors_left),a
        or      a
        ret
p130_neogs_read_next_sector__p130_neogs_sector_io_error:
        ld      a,4
        ld      (p130_neogs_io_error),a
        scf
        ret

; ATM-side diagnostic for the three bytes returned by GS105a 020h.
; Format: [time][ATM] [NGS ROM] RAM24=HH:MM:LL
; This is intentionally emitted by ATM: Project126's NeoGS bootstrap is not
; executing yet while the stock ROM handles the 020h probe.
p130_neogs_log_ram_size:
        push    af
        push    bc
        push    de
        push    hl
        call    p126_host_log_prefix
        ld      hl,p130_neogs_ram_log_text
        call    p130_neogs_log_text
        ld      a,(p130_neogs_ram_size+2)
        call    p130_neogs_log_hex_byte
        ld      a,':'
        ld      bc,000EFh
        out     (c),a
        ld      a,(p130_neogs_ram_size+1)
        call    p130_neogs_log_hex_byte
        ld      a,':'
        ld      bc,000EFh
        out     (c),a
        ld      a,(p130_neogs_ram_size)
        call    p130_neogs_log_hex_byte
        ld      a,13
        ld      bc,000EFh
        out     (c),a
        ld      a,10
        out     (c),a
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

p130_neogs_log_text:
        push    bc
        ld      bc,000EFh
p130_neogs_log_text__p130_neogs_log_text_loop:
        ld      a,(hl)
        inc     hl
        or      a
        jr      z,p130_neogs_log_text__p130_neogs_log_text_done
        out     (c),a
        jr      p130_neogs_log_text__p130_neogs_log_text_loop
p130_neogs_log_text__p130_neogs_log_text_done:
        pop     bc
        ret

; IN A=byte; writes two uppercase hexadecimal digits to ATM 0EFh.
p130_neogs_log_hex_byte:
        push    bc
        ld      c,0EFh
        ld      b,a
        rrca
        rrca
        rrca
        rrca
        and     00Fh
        call    p130_neogs_log_hex_nibble
        ld      a,b
        and     00Fh
        call    p130_neogs_log_hex_nibble
        pop     bc
        ret

p130_neogs_log_hex_nibble:
        cp      10
        jr      c,p130_neogs_log_hex_nibble__p130_neogs_log_hex_digit
        add     'A'-10
        jr      p130_neogs_log_hex_nibble__p130_neogs_log_hex_out
p130_neogs_log_hex_nibble__p130_neogs_log_hex_digit:
        add     '0'
p130_neogs_log_hex_nibble__p130_neogs_log_hex_out:
        out     (c),a
        ret

 ; Query the stock ROM for its 24-bit RAM size. Project126 requires 4 MiB.
p130_neogs_probe_rom_ram:
        ld      a,'C'                 ; C: send 020h and wait for CBIT
        ld      (p130_neogs_startup_stage),a
        ld      a,P130_NGS_CMD_RAM
        call    p130_neogs_send_command_long
        ret     c
        ld      a,'D'                 ; D: wait for/read RAM byte 0
        ld      (p130_neogs_startup_stage),a
        call    p130_neogs_receive_byte
        ret     c
        ld      (p130_neogs_ram_size),a
        ld      a,'E'                 ; E: wait for/read RAM byte 1
        ld      (p130_neogs_startup_stage),a
        call    p130_neogs_receive_byte
        ret     c
        ld      (p130_neogs_ram_size+1),a
        ld      a,'F'                 ; F: wait for/read RAM byte 2
        ld      (p130_neogs_startup_stage),a
        call    p130_neogs_receive_byte
        ret     c
        ld      (p130_neogs_ram_size+2),a
        ld      a,'G'                 ; G: validate reported 24-bit RAM size
        ld      (p130_neogs_startup_stage),a
        ; At this point the stock GS105a ROM still owns the NeoGS CPU.
        ; Capture the exact response on the ATM's independent 0EFh channel.
        call    p130_neogs_log_ram_size
        ld      a,(p130_neogs_ram_size+2)
        cp      040h
        jr      c,p130_neogs_probe_rom_ram__p130_neogs_ram_probe_bad
        or      a
        ret
p130_neogs_probe_rom_ram__p130_neogs_ram_probe_bad:
        scf
        ret

; Extended CBIT wait based on the known-working Project125 GS105a driver.
p130_neogs_send_command_long:
        ld      (p130_neogs_tx_byte),a
        ld      a,(p130_neogs_tx_byte)
        out     (P130_NGS_GSCOM),a
        push    de
        ld      d,16
p130_neogs_send_command_long__p130_neogs_command_long_outer:
        ld      bc,0FFFFh
p130_neogs_send_command_long__p130_neogs_command_long_inner:
        in      a,(P130_NGS_GSSTAT)
        bit     P130_NGS_CBIT,a
        jr      z,p130_neogs_send_command_long__p130_neogs_command_long_done
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_neogs_send_command_long__p130_neogs_command_long_inner
        dec     d
        jr      nz,p130_neogs_send_command_long__p130_neogs_command_long_outer
        pop     de
        scf
        ret
p130_neogs_send_command_long__p130_neogs_command_long_done:
        pop     de
        or      a
        ret

; Stock GS105a command/data primitives. Application payloads do not use these.
p130_neogs_send_command:
        ld      (p130_neogs_tx_byte),a
        ld      a,(p130_neogs_tx_byte)
        out     (P130_NGS_GSCOM),a
        ld      bc,P130_NGS_TIMEOUT
p130_neogs_send_command__p130_neogs_command_wait:
        in      a,(P130_NGS_GSSTAT)
        bit     P130_NGS_CBIT,a
        jr      z,p130_neogs_send_command__p130_neogs_command_ok
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_neogs_send_command__p130_neogs_command_wait
        scf
        ret
p130_neogs_send_command__p130_neogs_command_ok:
        or      a
        ret

p130_neogs_send_argument:
        ; GS105a 013h/014h consume their first argument byte before command
        ; dispatch. The DBIT wait clobbers A with GSSTAT, so preserve the
        ; argument exactly as Project125's gs_boot_write_command_argument does.
        ld      (p130_neogs_tx_byte),a
        call    p130_neogs_wait_dbit_clear
        ret     c
        ld      a,(p130_neogs_tx_byte)
        out     (P130_NGS_GSDAT),a
        or      a
        ret

p130_neogs_send_byte:
        ld      (p130_neogs_tx_byte),a
        call    p130_neogs_wait_dbit_clear
        ret     c
        ld      a,(p130_neogs_tx_byte)
        out     (P130_NGS_GSDAT),a
        jp      p130_neogs_wait_dbit_clear

p130_neogs_receive_byte:
        call    p130_neogs_wait_dbit_set
        ret     c
        in      a,(P130_NGS_GSDAT)
        ; Give the GS105a sender time to observe DBIT being cleared.
        push    af
        push    bc
        ld      bc,00400h
p130_neogs_receive_byte__p130_neogs_receive_turnaround:
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_neogs_receive_byte__p130_neogs_receive_turnaround
        pop     bc
        pop     af
        or      a
        ret

p130_neogs_wait_dbit_clear:
        ld      bc,P130_NGS_TIMEOUT
p130_neogs_wait_dbit_clear__p130_neogs_dbit_clear_loop:
        in      a,(P130_NGS_GSSTAT)
        bit     P130_NGS_DBIT,a
        jr      z,p130_neogs_wait_dbit_clear__p130_neogs_dbit_clear_ok
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_neogs_wait_dbit_clear__p130_neogs_dbit_clear_loop
        scf
        ret
p130_neogs_wait_dbit_clear__p130_neogs_dbit_clear_ok:
        or      a
        ret

p130_neogs_wait_dbit_set:
        ld      bc,P130_NGS_TIMEOUT
p130_neogs_wait_dbit_set__p130_neogs_dbit_set_loop:
        in      a,(P130_NGS_GSSTAT)
        bit     P130_NGS_DBIT,a
        jr      nz,p130_neogs_wait_dbit_set__p130_neogs_dbit_set_ok
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_neogs_wait_dbit_set__p130_neogs_dbit_set_loop
        scf
        ret
p130_neogs_wait_dbit_set__p130_neogs_dbit_set_ok:
        or      a
        ret

; Send the current ATM video mode to NeoGS after the host has finished
; shadow-port setup. Descriptor v1 is: version, RG mode, width, height,
; pixel/layout format, flags, logical frame size (u16).
p130_neogs_send_video_mode_impl:
        push    bc
        push    de
        push    hl
        ; RTC probe may have changed the ATM paging/DOSEN state. Restore the
        ; canonical host/video mapping before touching the 0C000h IPC frame.
        call    p126_bios_restore_atm_video
        ld      hl,0C000h+P126_IPC_HEADER_SIZE
        ld      a,P126_VIDEO_DESC_VERSION
        ld      (hl),a
        inc     hl
        ld      a,(p126_atm_video_mode)
        ld      (hl),a
        inc     hl
        ld      a,P126_VIDEO_TEXT80_WIDTH
        ld      (hl),a
        inc     hl
        ld      a,P126_VIDEO_TEXT80_HEIGHT
        ld      (hl),a
        inc     hl
        ld      a,P126_VIDEO_FORMAT_TEXT80X25
        ld      (hl),a
        inc     hl
        xor     a
        ld      (hl),a
        inc     hl
        ld      hl,P126_VIDEO_TEXT80_FRAME_SIZE
        ld      (0C000h+P126_IPC_HEADER_SIZE+6),hl
        xor     a
        ld      (p126_bios_frame_flags),a
        ld      a,P126_OP_VIDEO_MODE
        ld      bc,P126_VIDEO_MODE_DESC_SIZE
        ld      de,1
        call    p126_bios_send_video_frame
        pop     hl
        pop     de
        pop     bc
        ret


; Runtime trace for the first TR-DOS transaction. This writes single markers
; to the independent ATM debug port and preserves caller registers/flags.
p130_neogs_trace_start:
        ld      a,'1'
p130_neogs_trace_char:
        push    af
        push    bc
        ld      bc,00EFh
        out     (c),a
        pop     bc
        pop     af
        ret

p130_neogs_boot_name: db "NEOBOOT "
p130_neogs_core_name: db "X86CORE "
p130_neogs_io_name:   db "X86IO   "
p130_neogs_alu_name:  db "X86ALU  "
p130_neogs_dev_name:  db "X86DEV  "
p130_neogs_exec_name: db "X86EXEC "
p130_neogs_vga_name:  db "X86VGA  "
p130_neogs_vid_name:  db "X86VID  "
; Descriptor: module ID, IMAGE kind, physical page, max size (u16),
; filename pointer and diagnostic stage character.
p130_neogs_module_table:
        db      1,P126_IMAGE_KIND_X86IO,004h
        dw      P126_IMAGE_X86IO_MAX_SIZE,p130_neogs_io_name
        db      'I'
        db      2,P126_IMAGE_KIND_X86ALU,005h
        dw      P126_IMAGE_X86ALU_MAX_SIZE,p130_neogs_alu_name
        db      'A'
        db      3,P126_IMAGE_KIND_X86DEV,006h
        dw      P126_IMAGE_X86DEV_MAX_SIZE,p130_neogs_dev_name
        db      'D'
        db      4,P126_IMAGE_KIND_X86EXEC,007h
        dw      P126_IMAGE_X86EXEC_MAX_SIZE,p130_neogs_exec_name
        db      'X'
        db      5,P126_IMAGE_KIND_X86VGA,008h
        dw      P126_IMAGE_X86VGA_MAX_SIZE,p130_neogs_vga_name
        db      'V'
        db      6,P126_IMAGE_KIND_X86VID,009h
        dw      P126_IMAGE_X86VID_MAX_SIZE,p130_neogs_vid_name
        db      'C'
p130_neogs_manifest_name: db "X86MODS "
p130_neogs_file_extension: db 'C'
p130_neogs_manifest_valid: db 0
p130_neogs_manifest_module_id: db 0
p130_neogs_manifest_record_index: db 0
p130_neogs_manifest_record_size: dw 0
p130_neogs_manifest_record_ptr: dw 0
p130_neogs_manifest_crc_work: dw 0
p130_neogs_manifest: defs 55,0
p130_neogs_overlay_size: dw 0
p130_neogs_overlay_max_size: dw 0
p130_neogs_overlay_kind: db 0
p130_neogs_overlay_page: db 0
p130_neogs_overlay_data_ptr: dw 0C11Ch
p130_neogs_io_log_begin: db "[NGS HOST] X86IO IMAGE BEGIN",13,10,0
p130_neogs_io_log_ready: db "[NGS HOST] X86IO IMAGE TX COMPLETE",13,10,0
p130_neogs_alu_log_begin: db "[NGS HOST] X86ALU IMAGE BEGIN",13,10,0
p130_neogs_alu_log_ready: db "[NGS HOST] X86ALU IMAGE TX COMPLETE",13,10,0
p130_neogs_dev_log_begin: db "[NGS HOST] X86DEV IMAGE BEGIN",13,10,0
p130_neogs_dev_log_ready: db "[NGS HOST] X86DEV IMAGE TX COMPLETE",13,10,0
p130_neogs_exec_log_begin: db "[NGS HOST] X86EXEC IMAGE BEGIN",13,10,0
p130_neogs_exec_log_ready: db "[NGS HOST] X86EXEC IMAGE TX COMPLETE",13,10,0
p130_neogs_vga_log_begin: db "[NGS HOST] X86VGA IMAGE BEGIN",13,10,0
p130_neogs_vga_log_ready: db "[NGS HOST] X86VGA IMAGE TX COMPLETE",13,10,0
p130_neogs_vid_log_begin: db "[NGS HOST] X86VID IMAGE BEGIN",13,10,0
p130_neogs_vid_log_ready: db "[NGS HOST] X86VID IMAGE TX COMPLETE",13,10,0
p130_neogs_name_ptr: dw 0
p130_neogs_file_length: dw 0
p130_neogs_core_length: dw 0
p130_neogs_block_length: dw 0
p130_neogs_buffer_ptr: dw 0C000h
p130_neogs_buffer_remaining: dw 0
p130_neogs_saved_sp: dw 0
p130_neogs_ram_size: db 0,0,0
p130_neogs_ram_log_text: db "[NGS ROM] RAM24=",0
p130_neogs_file_sectors_left: db 0
p130_neogs_file_sector: db 0
p130_neogs_file_track: db 0
p130_neogs_io_error: db 0
p130_neogs_tx_byte: db 0
p130_neogs_startup_error: db 0
_p130_neogs_stage:
p130_neogs_startup_stage: db '0'


; Build and send one maximum-size ABI 1.0 diagnostics request.
; The complete 16 KiB host buffer occupies ATM RAM page 0 at C000-FFFF.
; Page 0 is restored by p126_atm_video_init and is otherwise the TR-DOS
; staging window. The reverse-DMA test reuses this same buffer after TX.
p130_neogs_dma_smoke_test:
        ; The ATM host TR-DOS file is packaged only through A800h. The
        ; C000h staging buffer is runtime RAM, not part of that file, so
        ; initialize every header byte explicitly on each test invocation.
        ld      hl,p130_neogs_dma_test_frame
        ld      a,'P'
        ld      (hl),a
        inc     hl
        ld      a,'1'
        ld      (hl),a
        inc     hl
        ld      a,'2'
        ld      (hl),a
        inc     hl
        ld      a,'6'
        ld      (hl),a
        inc     hl
        ld      a,P126_IPC_MAJOR
        ld      (hl),a
        inc     hl
        ld      a,P126_IPC_MINOR
        ld      (hl),a
        inc     hl
        ld      a,P126_MSG_REQUEST
        ld      (hl),a
        inc     hl
        ld      a,P126_SERVICE_DIAGNOSTICS
        ld      (hl),a
        inc     hl
        ld      a,P126_OP_DIAGNOSTIC
        ld      (hl),a
        inc     hl
        xor     a
        ld      (hl),a                 ; flags
        inc     hl
        ld      a,002h
        ld      (hl),a                 ; sequence low
        inc     hl
        xor     a
        ld      (hl),a                 ; sequence high
        inc     hl
        ld      a,0EEh
        ld      (hl),a                 ; payload length low
        inc     hl
        ld      a,03Fh
        ld      (hl),a                 ; payload length high
        inc     hl
        xor     a
        ld      (hl),a                 ; status low
        inc     hl
        ld      (hl),a                 ; status high
        inc     hl
        ld      (hl),a                 ; CRC low (filled below)
        inc     hl
        ld      (hl),a                 ; CRC high (filled below)

        ld      hl,p130_neogs_dma_test_frame+P126_IPC_HEADER_SIZE
        ld      bc,P126_IPC_MAX_PAYLOAD
        ld      e,0
p130_neogs_dma_smoke_test__p130_neogs_dma_fill:
        ld      a,e
        ld      (hl),a
        inc     hl
        inc     e
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_neogs_dma_smoke_test__p130_neogs_dma_fill

        ; CRC-16/CCITT-FALSE over header[0..15] and all 16366 payload bytes.
        ld      hl,0FFFFh
        ld      de,p130_neogs_dma_test_frame
        ld      b,16
p130_neogs_dma_smoke_test__p130_neogs_dma_crc_header:
        ld      a,(de)
        inc     de
        call    p126_ipc_crc16_update
        djnz    p130_neogs_dma_smoke_test__p130_neogs_dma_crc_header
        inc     de
        inc     de
        ld      bc,P126_IPC_MAX_PAYLOAD
p130_neogs_dma_smoke_test__p130_neogs_dma_crc_payload:
        ld      a,(de)
        inc     de
        call    p126_ipc_crc16_update
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_neogs_dma_smoke_test__p130_neogs_dma_crc_payload
        ld      (p130_neogs_dma_test_frame+P126_IPC_OFF_CRC),hl
        ld      hl,p130_neogs_dma_test_frame
        ld      bc,P126_IPC_MAX_FRAME_SIZE
        jp      p126_ipc_dma_send_frame

p130_neogs_dma_test_frame EQU 0C000h

; Project126 IPC/IMAGE DMA implementation and ABI constants.
; Project126 ATM-side IMAGE/DMA transport used by the full Project130 loader.
; =========================================================================
; PROJECT126 — shared DMA/IPC ABI constants
; Version: P126 DMA/IPC ABI 1.1
; This file contains protocol constants only; no host or NeoGS port I/O.
; =========================================================================

P126_IPC_MAJOR             EQU 1
P126_IPC_MINOR             EQU 1
P126_IPC_HEADER_SIZE       EQU 18
P126_IPC_MAX_FRAME_SIZE    EQU 04000h
P126_IPC_MAX_PAYLOAD       EQU P126_IPC_MAX_FRAME_SIZE-P126_IPC_HEADER_SIZE
P126_IPC_FRAGMENT_HEADER   EQU 10
P126_IPC_MAX_FRAGMENT_DATA EQU P126_IPC_MAX_PAYLOAD-P126_IPC_FRAGMENT_HEADER

; The 16 KiB DMA test frame occupies C000h..FFFFh exactly.
        ASSERT  p130_neogs_dma_test_frame + P126_IPC_MAX_FRAME_SIZE = 10000h

; Fixed header offsets.
P126_IPC_OFF_MAGIC        EQU 0
P126_IPC_OFF_MAJOR        EQU 4
P126_IPC_OFF_MINOR        EQU 5
P126_IPC_OFF_TYPE         EQU 6
P126_IPC_OFF_SERVICE      EQU 7
P126_IPC_OFF_OPERATION    EQU 8
P126_IPC_OFF_FLAGS        EQU 9
P126_IPC_OFF_SEQUENCE     EQU 10
P126_IPC_OFF_LENGTH       EQU 12
P126_IPC_OFF_STATUS       EQU 14
P126_IPC_OFF_CRC          EQU 16

; Message types.
P126_MSG_REQUEST          EQU 001h
P126_MSG_RESPONSE         EQU 002h
P126_MSG_EVENT            EQU 003h
P126_MSG_CANCEL           EQU 004h

; Header flags.
P126_FLAG_ACK_REQUIRED    EQU 001h
P126_FLAG_FRAGMENT        EQU 002h
P126_FLAG_IDEMPOTENT      EQU 004h
P126_FLAG_VALID_MASK      EQU 007h

; GSCOM control-plane commands. Valid only under Project126 resident firmware.
P126_CMD_HOST_FRAME       EQU 0E0h
P126_CMD_NGS_FRAME        EQU 0E1h
P126_CMD_NGS_VIDEO_FRAME  EQU 0E4h
P126_CMD_RESYNC           EQU 0E2h
P126_CMD_CAPABILITIES     EQU 0E3h
P126_CMD_DMA_END          EQU 0FFh

; Service IDs.
P126_SERVICE_SESSION      EQU 000h
P126_SERVICE_INPUT        EQU 001h
P126_SERVICE_VIDEO        EQU 002h
P126_SERVICE_STORAGE      EQU 003h
P126_SERVICE_CLOCK        EQU 004h
P126_SERVICE_DIAGNOSTICS  EQU 005h
P126_SERVICE_CONFIG       EQU 006h
P126_SERVICE_IMAGE        EQU 007h

; Initial operation IDs.
P126_OP_HELLO             EQU 000h
P126_OP_CAPABILITIES      EQU 001h
P126_OP_RESYNC            EQU 002h
P126_OP_DIAGNOSTIC        EQU 000h
P126_OP_IMAGE_BEGIN       EQU 000h
P126_OP_IMAGE_FRAGMENT    EQU 001h
P126_OP_IMAGE_FINISH      EQU 002h
P126_OP_IMAGE_RESULT      EQU 003h
P126_OP_INPUT_KEYBOARD     EQU 000h

; Video service operations and mode descriptor ABI.
P126_OP_VIDEO_MODE         EQU 000h
P126_OP_VIDEO_FRAME_REQUEST EQU 001h
P126_OP_VIDEO_FRAME          EQU 002h
P126_OP_VIDEO_FRAME_FRAGMENT EQU 003h
P126_OP_VIDEO_FRAME_FINISH   EQU 004h
P126_VIDEO_MODE_DESC_SIZE  EQU 8
P126_VIDEO_DESC_VERSION    EQU 1
P126_VIDEO_FORMAT_TEXT80X25 EQU 1
P126_ATM_MODE_RG6_TEXT80X25 EQU 6
; Public ATM-side renderer mode name used by the screen-console and IPC modules.
P126_ATM_VIDEO_MODE_RG6_TEXT80X25 EQU P126_ATM_MODE_RG6_TEXT80X25
P126_VIDEO_TEXT80_WIDTH    EQU 80
P126_VIDEO_TEXT80_HEIGHT   EQU 25
P126_VIDEO_TEXT80_CELLS    EQU 2000
P126_VIDEO_TEXT80_FRAME_SIZE EQU 4000

; Response status codes (16-bit values).
P126_STATUS_OK            EQU 00000h
P126_STATUS_BAD_MAGIC     EQU 00001h
P126_STATUS_BAD_VERSION   EQU 00002h
P126_STATUS_BAD_FRAME     EQU 00003h
P126_STATUS_CRC_ERROR     EQU 00004h
P126_STATUS_SEQUENCE      EQU 00005h
P126_STATUS_NO_SERVICE    EQU 00006h
P126_STATUS_NO_OPERATION  EQU 00007h
P126_STATUS_NO_BUFFER     EQU 00008h
P126_STATUS_HOST_IO       EQU 00009h
P126_STATUS_TIMEOUT       EQU 0000Ah
P126_STATUS_CANCELLED     EQU 0000Bh
P126_STATUS_ADDRESS_RANGE EQU 0000Ch
P126_STATUS_BUSY          EQU 0000Dh
P126_STATUS_RESET_REQUIRED EQU 0000Eh
P126_STATUS_BAD_FRAGMENT  EQU 0000Fh

; CRC-16/CCITT-FALSE.
P126_CRC16_POLY           EQU 01021h
P126_CRC16_INITIAL_H      EQU 0FFh
P126_CRC16_INITIAL_L      EQU 0FFh
P126_CRC16_CHECK_H        EQU 029h
P126_CRC16_CHECK_L        EQU 0B1h


; IMAGE service v1.1 image profiles.
; IMAGE_BEGIN payload: message-id u16, image-kind u8, physical-page u8,
; exact image-size u16. The receiver validates kind/page policy and derives
; the WIN3/MPAGEX selector from ROR8(physical-page).
; SYSBIOS: 8 KiB image to physical page 10h. X86 overlays retain their
; pinned page assignments 04h..07h until the resident module manager owns
; allocation of the dynamic page range.
P126_IMAGE_KIND_SYSBIOS      EQU 000h
P126_IMAGE_KIND_X86IO        EQU 001h
P126_IMAGE_KIND_X86ALU       EQU 002h
P126_IMAGE_KIND_X86DEV       EQU 003h
P126_IMAGE_KIND_X86EXEC      EQU 004h
P126_IMAGE_KIND_X86VGA       EQU 005h
P126_IMAGE_KIND_X86VID       EQU 006h
P126_IMAGE_X86IO_MAX_SIZE    EQU 01000h
P126_IMAGE_X86ALU_MAX_SIZE   EQU 01000h
P126_IMAGE_X86DEV_MAX_SIZE   EQU 01000h
P126_IMAGE_X86EXEC_MAX_SIZE  EQU 04000h
P126_IMAGE_X86VGA_MAX_SIZE   EQU 04000h
P126_IMAGE_X86VID_MAX_SIZE   EQU 04000h
P126_IMAGE_SYSBIOS_SIZE      EQU 02000h
P126_IMAGE_FRAGMENT_EXT_SIZE EQU 10

P126_GSCOM EQU 0BBh
P126_GSSTAT EQU 0BBh
P126_GSDAT EQU 0B3h
P126_CBIT EQU 0
P126_DBIT EQU 7
P126_IPC_TIMEOUT EQU 0FFFFh
P126_IPC_DMA_WINDOW EQU 0000h
P126_IPC_DMA_END EQU 0FFh
P126_BIOS_FRAME EQU 0C000h
p126_ipc_crc16_update:
        push    bc
        xor     h
        ld      h, a
        ld      b, 8
scope__p126_crc_bit:
        add     hl, hl
        jr      nc, scope__p126_crc_no_xor
        ld      a, h
        xor     010h
        ld      h, a
        ld      a, l
        xor     021h
        ld      l, a
scope__p126_crc_no_xor:
        djnz    scope__p126_crc_bit
        pop     bc
        ret


p126_ipc_validate_tx_frame:
        ld      (p126_ipc_frame_ptr),hl
        ld      (p126_ipc_frame_size),bc
        ld      a,b
        or      a
        jr      nz,scope__p126_tx_min_ok
        ld      a,c
        cp      P126_IPC_HEADER_SIZE
        jp      c,scope__p126_tx_bad
scope__p126_tx_min_ok:
        ld      a,b
        cp      040h
        jr      c,scope__p126_tx_size_ok
        jp      nz,scope__p126_tx_bad
        ld      a,c
        or      a
        jp      nz,scope__p126_tx_bad
scope__p126_tx_size_ok:
        push    hl
        pop     ix
        ld      a,(ix+0)
        cp      'P'
        jp      nz,scope__p126_tx_magic
        ld      a,(ix+1)
        cp      '1'
        jp      nz,scope__p126_tx_magic
        ld      a,(ix+2)
        cp      '2'
        jp      nz,scope__p126_tx_magic
        ld      a,(ix+3)
        cp      '6'
        jp      nz,scope__p126_tx_magic
        ld      a,(ix+4)
        cp      P126_IPC_MAJOR
        jp      nz,scope__p126_tx_version
        ld      a,(ix+5)
        cp      P126_IPC_MINOR
        jp      nz,scope__p126_tx_version
        ld      a,(ix+6)
        cp      P126_MSG_REQUEST
        jp      nz,scope__p126_tx_bad
        ld      a,(ix+9)
        and     0F8h
        jp      nz,scope__p126_tx_bad
        ; actual_size must equal header_size + declared_payload_length.
        ld      l,(ix+12)
        ld      h,(ix+13)
        ld      de,P126_IPC_HEADER_SIZE
        add     hl,de
        ld      de,(p126_ipc_frame_size)
        or      a
        sbc     hl,de
        jp      nz,scope__p126_tx_bad
        xor     a
        ret
scope__p126_tx_magic:
        ld      a,P126_STATUS_BAD_MAGIC
        scf
        ret
scope__p126_tx_version:
        ld      a,P126_STATUS_BAD_VERSION
        scf
        ret
scope__p126_tx_bad:
        ld      a,P126_STATUS_BAD_FRAME
        scf
        ret

; -------------------------------------------------------------------------
; Emit a build/runtime identity to ATM's independent debug port 0EFh.
; Preserves AF, BC and HL.
; -------------------------------------------------------------------------
p126_ipc_wait_cbit_clear_dma:
        ld      d,8
p126_ipc_wait_cbit_clear_dma__p126_dma_cbit_outer:
        ld      bc,0FFFFh
p126_ipc_wait_cbit_clear_dma__p126_dma_cbit_inner:
        call    p126_ipc_read_status
        bit     P126_CBIT,a
        jr      z,p126_ipc_wait_cbit_clear_dma__p126_dma_cbit_ready
        dec     bc
        ld      a,b
        or      c
        jr      nz,p126_ipc_wait_cbit_clear_dma__p126_dma_cbit_inner
        dec     d
        jr      nz,p126_ipc_wait_cbit_clear_dma__p126_dma_cbit_outer
        ld      a,(p126_ipc_last_status)
        scf
        ret
p126_ipc_wait_cbit_clear_dma__p126_dma_cbit_ready:
        ld      a,(p126_ipc_last_status)
        or      a
        ret

p126_ipc_read_status:
 in a,(P126_GSSTAT)
 ld (p126_ipc_last_status),a
 ret
p126_ipc_last_status: db 0
p126_ipc_debug_string:
p126_ipc_debug_hex_byte:
p126_ipc_debug_crlf:
p126_host_log_prefix:
p126_bios_restore_atm_video:
p126_atm_video_init:
        call    0A00Ch
        ret
p126_atm_video_mode: db P126_ATM_VIDEO_MODE_RG6_TEXT80X25
p126_bios_frame_flags: db 0
p126_ipc_dma_send_frame:
        ; Preserve the caller's frame pointer and length before any logger
        ; call, because the string writer advances HL.
        ld      a,1
        ld      (p126_ipc_dma_stage),a
        ld      (p126_ipc_dma_source),hl
        ld      (p126_ipc_dma_size),bc
        ld      hl,p126_ipc_log_dma_tx_begin
        call    p126_ipc_debug_string
        ld      hl,(p126_ipc_dma_source)
        ld      bc,(p126_ipc_dma_size)
        ; Match the proven Project125 host path: validate the frame envelope
        ; here, but do not spend the transfer startup path recalculating the
        ; complete 16 KiB CRC. The frame builder already wrote the CRC; NeoGS
        ; performs the authoritative full CRC check after DMA reception.
        call    p126_ipc_validate_tx_frame
        jr      nc,p126_atm_video_init__p126_dma_frame_valid
        ld      (p126_ipc_dma_error),a
        push    af
        ld      hl,p126_ipc_log_dma_tx_validate_bad
        call    p126_ipc_debug_string
        pop     af
        ; Emit the exact rejected frame envelope so the first failing header
        ; field can be identified without guessing or weakening validation.
        call    p126_ipc_debug_hex_byte
        ld      hl,p126_ipc_log_dma_tx_bad_size
        call    p126_ipc_debug_string
        ld      hl,(p126_ipc_dma_size)
        ld      a,h
        call    p126_ipc_debug_hex_byte
        ld      a,l
        call    p126_ipc_debug_hex_byte
        ld      hl,p126_ipc_log_dma_tx_bad_header
        call    p126_ipc_debug_string
        ld      ix,(p126_ipc_dma_source)
        ld      b,P126_IPC_HEADER_SIZE
p126_atm_video_init__p126_dma_bad_header_dump:
        ld      a,(ix+0)
        call    p126_ipc_debug_hex_byte
        inc     ix
        djnz    p126_atm_video_init__p126_dma_bad_header_dump
        call    p126_ipc_debug_crlf
        scf
        ret
p126_atm_video_init__p126_dma_frame_valid:
        ld      hl,p126_ipc_log_dma_tx_validate_ok
        call    p126_ipc_debug_string
        xor     a
        ld      (p126_ipc_dma_error),a

        ld      a,2
        ld      (p126_ipc_dma_stage),a
        ld      bc,(p126_ipc_dma_size)
        ld      a,b
        cp      040h
        jr      c,p126_atm_video_init__p126_dma_size_valid
        jp      nz,p126_atm_video_init__p126_dma_bad_size
        ld      a,c
        or      a
        jr      z,p126_atm_video_init__p126_dma_size_valid
        jp      p126_atm_video_init__p126_dma_bad_size

p126_atm_video_init__p126_dma_size_valid:
        ld      a,3
        ld      (p126_ipc_dma_stage),a
        ; Emit COPY BEGIN before arming the receiver. Once E0 is acknowledged,
        ; do not spend any time in the screen-console logger: the receiver's
        ; DMA watchdog is already running and LDIR must start immediately.
        ld      hl,p126_ipc_log_dma_tx_copy_begin
        call    p126_ipc_debug_string
        ld      hl,p126_ipc_log_dma_tx_e0
        call    p126_ipc_debug_string
        ; DMA setup on NeoGS includes page selection and DMA register writes.
        ; Use the long completion watchdog here as well as for FF: the ordinary
        ; command timeout can expire while the receiver is still arming DMA.
        ld      a,P126_CMD_HOST_FRAME
        out     (P126_GSCOM),a
        call    p126_ipc_wait_cbit_clear_dma
        jr      nc,p126_atm_video_init__p126_dma_e0_ack
        push    af
        ld      hl,p126_ipc_log_dma_tx_e0_timeout
        call    p126_ipc_debug_string
        pop     af
        scf
        ret
p126_atm_video_init__p126_dma_e0_ack:
        ; E0 cleared CBIT: NeoGS is already waiting for the first DMA byte.
        ; No console output or other slow work is allowed before LDIR.
        ld      a,4
        ld      (p126_ipc_dma_stage),a
        di
        ld      hl,(p126_ipc_dma_source)
        ld      bc,(p126_ipc_dma_size)
        ld      de,P126_IPC_DMA_WINDOW
        ldir

        ; Send DMA END immediately after the final byte. Screen-console
        ; mirroring is deliberately deferred: per-character console writes
        ; here can let NeoGS' bounded DMA receiver watchdog expire.
        ld      a,5
        ld      (p126_ipc_dma_stage),a
        ld      a,P126_IPC_DMA_END
        out     (P126_GSCOM),a
        call    p126_ipc_wait_cbit_clear_dma
        jr      nc,p126_atm_video_init__p126_dma_ff_ack
        push    af
        ld      hl,p126_ipc_log_dma_tx_copy_done
        call    p126_ipc_debug_string
        ld      hl,p126_ipc_log_dma_tx_ff
        call    p126_ipc_debug_string
        ld      hl,p126_ipc_log_dma_tx_ff_timeout
        call    p126_ipc_debug_string
        pop     af
        scf
        ret
p126_atm_video_init__p126_dma_ff_ack:
        ; It is safe to update both debug streams after NeoGS has completed
        ; the frame receive and service dispatch.
        ld      hl,p126_ipc_log_dma_tx_copy_done
        call    p126_ipc_debug_string
        ld      hl,p126_ipc_log_dma_tx_ff
        call    p126_ipc_debug_string
        ld      hl,p126_ipc_log_dma_tx_done
        call    p126_ipc_debug_string
        xor     a
        ld      (p126_ipc_dma_stage),a
        ret

p126_atm_video_init__p126_dma_bad_size:
        ld      a,P126_STATUS_BAD_FRAME
        scf
        ret

p126_ipc_dma_source: dw 0
p126_ipc_dma_size:   dw 0
; 0=success/not started, 1=local frame validation, 2=DMA size,
; 3=E0/READY handshake, 4=payload copy, 5=FF/completion acknowledgement.
p126_ipc_dma_stage:  db 0

p126_ipc_dma_error: db 0

PUBLIC p126_bios_send_frame
PUBLIC p126_bios_frame_flags
PUBLIC p126_ipc_debug_hex_byte
PUBLIC p126_ipc_crc16_update
PUBLIC p126_ipc_crc16_update
PUBLIC p126_host_log_prefix
p126_bios_send_frame:
        ld      (p126_bios_operation),a
        ld      a,P126_SERVICE_IMAGE
        ld      (p126_bios_service),a
        jp      p126_bios_send_frame_common

p126_bios_send_video_frame:
        ld      (p126_bios_operation),a
        ld      a,P126_SERVICE_VIDEO
        ld      (p126_bios_service),a
        jp      p126_bios_send_frame_common

p126_bios_send_frame_common:
        ld      (p126_bios_payload_length),bc
        ld      (p126_bios_sequence),de
        ld      hl,P126_BIOS_FRAME
        ld      a,'P'
        ld      (hl),a
        inc     hl
        ld      a,'1'
        ld      (hl),a
        inc     hl
        ld      a,'2'
        ld      (hl),a
        inc     hl
        ld      a,'6'
        ld      (hl),a
        inc     hl
        ld      a,P126_IPC_MAJOR
        ld      (hl),a
        inc     hl
        ld      a,P126_IPC_MINOR
        ld      (hl),a
        inc     hl
        ld      a,P126_MSG_REQUEST
        ld      (hl),a
        inc     hl
        ld      a,(p126_bios_service)
        ld      (hl),a
        inc     hl
        ld      a,(p126_bios_operation)
        ld      (hl),a
        inc     hl
        ld      a,(p126_bios_frame_flags)
        ld      (hl),a
        inc     hl
        ld      hl,(p126_bios_sequence)
        ld      (P126_BIOS_FRAME+10),hl
        ld      hl,(p126_bios_payload_length)
        ld      (P126_BIOS_FRAME+12),hl
        xor     a
        ld      (P126_BIOS_FRAME+14),a
        ld      (P126_BIOS_FRAME+15),a

        ; CRC-16/CCITT-FALSE over header[0..15] and the complete payload.
        ld      hl,0FFFFh
        ld      de,P126_BIOS_FRAME
        ld      b,16
p126_bios_send_frame_common__p126_bios_crc_header:
        ld      a,(de)
        inc     de
        call    p126_ipc_crc16_update
        djnz    p126_bios_send_frame_common__p126_bios_crc_header
        ; CRC field at offsets 16..17 is excluded from the checksum.
        ; Continue with payload at frame+18, matching the NeoGS validator.
        inc     de
        inc     de
        ld      bc,(p126_bios_payload_length)
p126_bios_send_frame_common__p126_bios_crc_payload:
        ld      a,b
        or      c
        jr      z,p126_bios_send_frame_common__p126_bios_crc_done
        ld      a,(de)
        inc     de
        call    p126_ipc_crc16_update
        dec     bc
        jr      p126_bios_send_frame_common__p126_bios_crc_payload
p126_bios_send_frame_common__p126_bios_crc_done:
        ld      (P126_BIOS_FRAME+16),hl
        ; DMA API expects the exact frame byte count, not the absolute
        ; address of the end of the frame. Compute 18-byte header + payload.
        ld      hl,(p126_bios_payload_length)
        ld      de,P126_IPC_HEADER_SIZE
        add     hl,de
        ld      b,h
        ld      c,l
        ld      hl,P126_BIOS_FRAME
        jp      p126_ipc_dma_send_frame

p126_bios_service: db 0
p126_bios_operation: db 0
p126_bios_payload_length: dw 0
p126_bios_sequence: dw 0
p126_ipc_frame_ptr: dw 0
p126_ipc_frame_size: dw 0
p126_ipc_log_dma_tx_begin: db "[ATM IPC] DMA TX BEGIN",13,10,0
p126_ipc_log_dma_tx_validate_bad: db "[ATM IPC] DMA TX VALIDATE FAILED",13,10,0
p126_ipc_log_dma_tx_bad_size: db " SIZE=",0
p126_ipc_log_dma_tx_bad_header: db " HEADER=",0
p126_ipc_log_dma_tx_validate_ok: db "[ATM IPC] FRAME STRUCTURE VALID",13,10,0
p126_ipc_log_dma_tx_copy_begin: db "[ATM IPC] DMA COPY BEGIN",13,10,0
p126_ipc_log_dma_tx_e0: db "[ATM IPC] SEND E0",13,10,0
p126_ipc_log_dma_tx_e0_timeout: db "[ATM IPC] E0 ACK TIMEOUT",13,10,0
p126_ipc_log_dma_tx_copy_done: db "[ATM IPC] DMA COPY DONE",13,10,0
p126_ipc_log_dma_tx_ff: db "[ATM IPC] SEND FF",13,10,0
p126_ipc_log_dma_tx_ff_timeout: db "[ATM IPC] FF ACK TIMEOUT",13,10,0
p126_ipc_log_dma_tx_done: db "[ATM IPC] DMA TX COMPLETE",13,10,0