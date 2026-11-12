; Project130 SYSBIOS file loader, ported from Project126 working path.
SECTION CODE
; Private names avoid collisions with the shared Project126 transport module.
P130_BIOS_FRAME EQU 0C000h
P130_BIOS_FLAG_FRAGMENT EQU 002h
P130_BIOS_FILE_SIZE EQU 02000h
P130_BIOS_SECTOR_COUNT EQU 32
P130_BIOS_SECTOR_SIZE EQU 00100h
P130_BIOS_FRAGMENT_DATA EQU 0C01Ch
P130_BIOS_OP_IMAGE_FRAGMENT EQU 001h
P130_BIOS_OP_IMAGE_FINISH EQU 002h
P130_BIOS_SERVICE_IMAGE EQU 007h
EXTERN p130_cat_debug_string
EXTERN p130_cat_find_index
EXTERN p130_cat_get_selected_index
EXTERN p130_trdos_rom_call
EXTERN p126_bios_send_frame
EXTERN p126_bios_frame_flags
EXTERN p126_ipc_debug_hex_byte
EXTERN p126_host_log_prefix
PUBLIC p130_bios_load_selected
; =========================================================================
; PROJECT126 — selected SYSBIOS loader
;
; Selection is made in the ATM catalogue. TR-DOS access is restored using
; the same pre-video mapping as initial startup; the chosen 8 KiB .C file is
; staged in page 0, then sent as ABI 1.1 IMAGE BEGIN/FRAGMENT/FINISH frames.
; NeoGS installs the fragment into physical SYSBIOS page 10h.
; =========================================================================

; Called by the catalogue after Enter has been pressed and released.
; OUT: carry clear after NeoGS has acknowledged all three IMAGE operations.
p130_bios_load_selected:
        ; Match the Project125 BIOS loader entry contract explicitly.
        di
        ld      (p130_bios_saved_sp),sp
        ld      sp,0BFFFh
        ld      hl,p130_bios_log_load_begin
        call    p130_cat_debug_string
        xor     a
        ld      (p130_bios_error),a
        ld      (p130_bios_disk_mode_active),a

        ; Resolve the selected visible catalogue index to its TR-DOS entry.
        call    p130_cat_get_selected_index
        call    p130_cat_find_index
        jp      c,p130_bios_bad_selection
        ; Preserve the selected directory-entry pointer across logging.
        ; p130_cat_debug_string uses HL for its message pointer.
        push    hl
        ld      hl,p130_bios_log_selection_resolved
        call    p130_cat_debug_string
        pop     hl
        push    hl
        ld      de,05CDDh
        ld      bc,8
        ldir
        pop     hl
        ld      de,8
        add     hl,de
        ld      a,(hl)
        cp      'C'
        jp      nz,p130_bios_bad_file_type
        ld      hl,p130_bios_log_file_type_ok
        call    p130_cat_debug_string
        ; Emit the exact selected 8.3 name into the diagnostic stream.
        call    p130_bios_log_selected_filename

        ; Enter the same legacy mapping used before ATM video initialization.
        ; Disk reads must not run with the alternate ATM window mapping active.
        ld      hl,p130_bios_log_trdos_map_begin
        call    p130_cat_debug_string
        call    p130_bios_enter_trdos_mode
        ld      hl,p130_bios_log_trdos_map_done
        call    p130_cat_debug_string
        ld      a,1
        ld      (p130_bios_disk_mode_active),a

        ; Project125 TR-DOS ROM file-open ABI: C=0Ah finds the exact 8.3 name,
        ; C=08h returns the full descriptor in the standard system variables.
        ld      a,'C'
        ld      (05CE5h),a
        ld      a,9
        ld      (05D06h),a
        ld      hl,p130_bios_log_open_call
        call    p130_cat_debug_string
        ; Keep the Project125 ROM-call boundary exact: no helper, logger,
        ; RTC access, or diagnostic I/O between setting C and CALL 03D13h.
        ld      c,10
        call    p130_bios_trdos_call
        ld      hl,p130_bios_log_open_return
        call    p130_cat_debug_string
        ld      a,c
        cp      0FFh
        jp      z,p130_bios_file_not_found
        push    af
        xor     a
        ld      (05D0Fh),a
        ld      (05D10h),a
        pop     af
        ld      hl,p130_bios_log_descriptor_call
        call    p130_cat_debug_string
        ld      c,8
        call    p130_bios_trdos_call
        ld      hl,p130_bios_log_descriptor_return
        call    p130_cat_debug_string
        ld      a,(05D0Fh)
        ld      b,a
        ld      a,(05D10h)
        or      b
        jp      nz,p130_bios_bad_descriptor
        ld      hl,p130_bios_log_file_open
        call    p130_cat_debug_string

        ; All selectable BIOS files must be exactly 8192 bytes / 32 sectors.
        ld      hl,(05CE8h)
        ld      de,P130_BIOS_FILE_SIZE
        or      a
        sbc     hl,de
        jp      nz,p130_bios_bad_size
        ld      a,(05CEAh)
        cp      P130_BIOS_SECTOR_COUNT
        jp      nz,p130_bios_bad_size
        ld      (p130_bios_sectors_left),a
        ld      hl,p130_bios_log_size_ok
        call    p130_cat_debug_string
        ld      hl,p130_bios_log_read_begin
        call    p130_cat_debug_string
        ld      a,(05CEBh)
        cp      16
        jp      nc,p130_bios_bad_descriptor
        ld      (p130_bios_sector),a
        ld      a,(05CECh)
        ld      (p130_bios_track),a
        ld      hl,P130_BIOS_FRAGMENT_DATA
        ld      (p130_bios_buffer_ptr),hl

p130_bios_local_read_loop:
        ld      a,(p130_bios_sectors_left)
        or      a
        jr      z,p130_bios_local_read_done
        call    p130_bios_read_next_sector
        jp      c,p130_bios_sector_error
        jr      p130_bios_local_read_loop

p130_bios_local_read_done:
        ; Identify the exact 8 KiB image that was read from TR-DOS.
        ; CRC-16/CCITT-FALSE is calculated over the staged BIOS bytes,
        ; before the DMA transaction, so the log identifies the payload sent.
        call    p130_bios_calculate_image_crc
        call    p130_bios_log_image_identity
        ld      hl,p130_bios_log_read_done
        call    p130_cat_debug_string
        ; Return to the ATM video mapping before any DMA/IPC transaction.
        call    p130_bios_restore_atm_video
        xor     a
        ld      (p130_bios_disk_mode_active),a
        ld      hl,p130_bios_log_video_restored
        call    p130_cat_debug_string

        ; IMAGE_BEGIN payload:
        ; message-id=0001h, image-kind=SYSBIOS, physical-page=10h, size=2000h.
        ld      a,1
        ld      (P130_BIOS_FRAME+18),a
        xor     a
        ld      (P130_BIOS_FRAME+19),a
        ld      (P130_BIOS_FRAME+20),a
        ld      a,010h
        ld      (P130_BIOS_FRAME+21),a
        xor     a
        ld      (P130_BIOS_FRAME+22),a
        ld      a,020h
        ld      (P130_BIOS_FRAME+23),a
        xor     a
        ld      (p126_bios_frame_flags),a
        ld      hl,p130_bios_log_image_begin_tx
        call    p130_cat_debug_string
        ld      bc,6
        ld      de,1
        xor     a
        call    p126_bios_send_frame
        jp      c,p130_bios_transport_error
        ld      hl,p130_bios_log_image_begin_ok
        call    p130_cat_debug_string

        ; IMAGE_FRAGMENT payload begins with the ABI 1.0 ten-byte extension:
        ; message-id=1, index=0, count=1, total logical data length=8192.
        ld      a,1
        ld      (P130_BIOS_FRAME+18),a
        xor     a
        ld      (P130_BIOS_FRAME+19),a
        ld      (P130_BIOS_FRAME+20),a
        ld      (P130_BIOS_FRAME+21),a
        ld      a,1
        ld      (P130_BIOS_FRAME+22),a
        xor     a
        ld      (P130_BIOS_FRAME+23),a
        ld      (P130_BIOS_FRAME+24),a
        ld      a,020h
        ld      (P130_BIOS_FRAME+25),a
        xor     a
        ld      (P130_BIOS_FRAME+26),a
        ld      (P130_BIOS_FRAME+27),a
        ld      a,P130_BIOS_FLAG_FRAGMENT
        ld      (p126_bios_frame_flags),a
        ld      hl,p130_bios_log_image_fragment_tx
        call    p130_cat_debug_string
        ld      bc,0200Ah
        ld      de,2
        ld      a,P130_BIOS_OP_IMAGE_FRAGMENT
        call    p126_bios_send_frame
        jp      c,p130_bios_transport_error
        ld      hl,p130_bios_log_image_fragment_ok
        call    p130_cat_debug_string

        ; IMAGE_FINISH payload carries the same message ID.
        ld      a,1
        ld      (P130_BIOS_FRAME+18),a
        xor     a
        ld      (P130_BIOS_FRAME+19),a
        xor     a
        ld      (p126_bios_frame_flags),a
        ld      hl,p130_bios_log_image_finish_tx
        call    p130_cat_debug_string
        ld      bc,2
        ld      de,3
        ld      a,P130_BIOS_OP_IMAGE_FINISH
        call    p126_bios_send_frame
        jp      c,p130_bios_transport_error
        ld      hl,p130_bios_log_image_finish_ok
        call    p130_cat_debug_string

        xor     a
        ld      (p130_bios_error),a
        ld      hl,(p130_bios_saved_sp)
        ld      sp,hl
        or      a
        ret



; Read-only snapshot immediately before TR-DOS C=00Ah.
; Dumps BANKM, extension, file-name length, live SP, ROM signature at 03D13h,
; and the exact eight-byte name. Preserves all Z80 registers.
p130_bios_trace_search_state:
        push    af
        push    bc
        push    de
        push    hl
        call    p126_host_log_prefix
        ld      bc,000EFh
        ld      hl,p130_bios_trace_state_prefix
p130_bios_local_trace_state_text:
        ld      a,(hl)
        inc     hl
        or      a
        jr      z,p130_bios_local_trace_state_values
        out     (c),a
        jr      p130_bios_local_trace_state_text
p130_bios_local_trace_state_values:
        ld      a,(05C3Bh)
        call    p126_ipc_debug_hex_byte
        ld      a,' '
        out     (c),a
        ld      a,(05CE5h)
        call    p126_ipc_debug_hex_byte
        ld      a,' '
        out     (c),a
        ld      a,(05D06h)
        call    p126_ipc_debug_hex_byte
        ld      a,' '
        out     (c),a
        ld      hl,0
        add     hl,sp
        ld      a,h
        call    p126_ipc_debug_hex_byte
        ld      a,l
        call    p126_ipc_debug_hex_byte
        ld      a,' '
        out     (c),a
        ld      hl,03D13h
        ld      b,8
p130_bios_local_trace_rom_loop:
        ld      a,(hl)
        call    p126_ipc_debug_hex_byte
        inc     hl
        ld      a,' '
        out     (c),a
        djnz    p130_bios_local_trace_rom_loop
        ld      a,13
        out     (c),a
        ld      a,10
        out     (c),a

        call    p126_host_log_prefix
        ld      bc,000EFh
        ld      hl,p130_bios_trace_name_prefix
p130_bios_local_trace_name_text:
        ld      a,(hl)
        inc     hl
        or      a
        jr      z,p130_bios_local_trace_name_value
        out     (c),a
        jr      p130_bios_local_trace_name_text
p130_bios_local_trace_name_value:
        ld      hl,05CDDh
        ld      b,8
p130_bios_local_trace_name_loop:
        ld      a,(hl)
        inc     hl
        out     (c),a
        djnz    p130_bios_local_trace_name_loop
        ld      a,13
        out     (c),a
        ld      a,10
        out     (c),a
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; Local CRC-16/CCITT-FALSE byte update. HL=CRC, A=input byte.
; Kept local so the BIOS loader does not depend on cross-object visibility.
p130_bios_crc16_update:
        push    bc
        xor     h
        ld      h,a
        ld      b,8
p130_bios_crc16_update_bit:
        add     hl,hl
        jr      nc,p130_bios_crc16_update_no_xor
        ld      a,h
        xor     010h
        ld      h,a
        ld      a,l
        xor     021h
        ld      l,a
p130_bios_crc16_update_no_xor:
        djnz    p130_bios_crc16_update_bit
        pop     bc
        ret

; CRC-16/CCITT-FALSE over the exact 8192 bytes staged at C01C.
; OUT: p130_bios_image_crc contains the CRC, all caller registers preserved.
p130_bios_calculate_image_crc:
        push    af
        push    bc
        push    de
        push    hl
        ld      hl,0FFFFh
        ld      de,P130_BIOS_FRAGMENT_DATA
        ld      bc,P130_BIOS_FILE_SIZE
p130_bios_local_image_crc_loop:
        ld      a,(de)
        inc     de
        call    p130_bios_crc16_update
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_bios_local_image_crc_loop
        ld      (p130_bios_image_crc),hl
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; Log filename, fixed image length and CRC of the actual staged payload.
p130_bios_log_image_identity:
        push    af
        push    bc
        push    de
        push    hl
        call    p126_host_log_prefix
        ld      bc,000EFh
        ld      hl,p130_bios_log_image_identity_prefix
p130_bios_local_image_identity_text:
        ld      a,(hl)
        inc     hl
        or      a
        jr      z,p130_bios_local_image_identity_name
        out     (c),a
        jr      p130_bios_local_image_identity_text
p130_bios_local_image_identity_name:
        ld      hl,05CDDh
        ld      b,8
p130_bios_local_image_identity_name_loop:
        ld      a,(hl)
        inc     hl
        out     (c),a
        djnz    p130_bios_local_image_identity_name_loop
        ld      a,'.'
        out     (c),a
        ld      a,'C'
        out     (c),a
        ld      a,' '
        out     (c),a
        ld      hl,P130_BIOS_FILE_SIZE
        ld      a,h
        call    p126_ipc_debug_hex_byte
        ld      a,l
        call    p126_ipc_debug_hex_byte
        ld      a,' '
        out     (c),a
        ld      hl,(p130_bios_image_crc)
        ld      a,h
        call    p126_ipc_debug_hex_byte
        ld      a,l
        call    p126_ipc_debug_hex_byte
        ld      a,13
        out     (c),a
        ld      a,10
        out     (c),a
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; Log the selected TR-DOS 8.3 filename as one timestamped line.
; The directory name is already copied to 05CDDh and type C was validated.
p130_bios_log_selected_filename:
        push    af
        push    bc
        push    de
        push    hl
        call    p126_host_log_prefix
        ld      bc,000EFh
        ld      hl,p130_bios_log_filename_prefix
p130_bios_local_log_filename_prefix_loop:
        ld      a,(hl)
        inc     hl
        or      a
        jr      z,p130_bios_local_log_filename_name
        out     (c),a
        jr      p130_bios_local_log_filename_prefix_loop
p130_bios_local_log_filename_name:
        ld      hl,05CDDh
        ld      b,8
p130_bios_local_log_filename_name_loop:
        ld      a,(hl)
        inc     hl
        out     (c),a
        djnz    p130_bios_local_log_filename_name_loop
        ld      a,'.'
        out     (c),a
        ld      a,'C'
        out     (c),a
        ld      a,13
        out     (c),a
        ld      a,10
        out     (c),a
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; Project130 reuses its existing IMAGE frame builder and DMA transport.
; Read one sector using the proven Project125 TR-DOS C=5/B=1 ABI.
; Cursor advances only after the ROM call reports success.
p130_bios_read_next_sector:
        ld      a,(p130_bios_track)
        ld      d,a
        ld      a,(p130_bios_sector)
        ld      e,a
        ld      hl,(p130_bios_buffer_ptr)
        ld      b,1
        ld      c,5
        xor     a
        ld      (05D0Fh),a
        ld      (05D10h),a
        call    p130_bios_trdos_call
        ld      a,(05D0Fh)
        ld      b,a
        ld      a,(05D10h)
        or      b
        jr      nz,p130_bios_local_read_failed

        ld      hl,(p130_bios_buffer_ptr)
        ld      de,P130_BIOS_SECTOR_SIZE
        add     hl,de
        ld      (p130_bios_buffer_ptr),hl
        ld      a,(p130_bios_sector)
        inc     a
        cp      16
        jr      c,p130_bios_local_same_track
        xor     a
        ld      (p130_bios_sector),a
        ld      a,(p130_bios_track)
        inc     a
        ld      (p130_bios_track),a
        jr      p130_bios_local_cursor_done
p130_bios_local_same_track:
        ld      (p130_bios_sector),a
p130_bios_local_cursor_done:
        ld      a,(p130_bios_sectors_left)
        dec     a
        ld      (p130_bios_sectors_left),a
        or      a
        ret
p130_bios_local_read_failed:
        scf
        ret

; Keep ROM2 active for the ATM2+ automatic TR-DOS overlay.
; Preserve BANKM D3: it selects the alternate video pages 7/3.
p130_bios_enter_trdos_mode:
        ld      a,(05C3Bh)
        or      010h
        ld      bc,07FFDh
        out     (c),a
        ld      (05C3Bh),a
        ret

; NedoOS ATM2+ sys_SHADOFF / dos3d13_resident call boundary.
; The active high-resolution display keeps shadow ports open through 00177h.
; Before each TR-DOS ROM call, select the documented switchable BASIC-48
; ROM page (083h in WIN0), then write the current Project126 RG=6 mode via
; 0FF77h (A9=1) to close shadow ports. Entering 03D13h with ROM2 set causes
; the hardware TR-DOS overlay/DOSEN transition.
;
; The TR-DOS routine's primary and alternate register results are preserved
; across the video restoration. This wrapper is used for C=0Ah, C=08h and
; each C=05h sector read, matching NedoOS' per-call SHADOFF discipline.
p130_bios_trdos_call:
        call    p130_trdos_rom_call
        push    af
        push    bc
        push    de
        push    hl
        push    ix
        push    iy
        exx
        push    bc
        push    de
        push    hl
        exx
        ex      af,af'
        push    af
        ex      af,af'
        call    0A00Ch
        ex      af,af'
        pop     af
        ex      af,af'
        exx
        pop     hl
        pop     de
        pop     bc
        exx
        pop     iy
        pop     ix
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; Rebuild the ATM 80x25 display mapping after TR-DOS I/O is complete.
p130_bios_restore_atm_video:
        call    0A00Ch
        ret

p130_bios_bad_selection:
        ld      a,1
        jp      p130_bios_fail
p130_bios_bad_file_type:
        ld      a,2
        jp      p130_bios_fail
p130_bios_file_not_found:
        ld      a,3
        jp      p130_bios_fail
p130_bios_bad_descriptor:
        ld      a,4
        jp      p130_bios_fail
p130_bios_bad_size:
        ld      a,5
        jp      p130_bios_fail
p130_bios_sector_error:
        ld      a,6
        jp      p130_bios_fail
p130_bios_transport_error:
        ld      a,7
p130_bios_fail:
        ld      (p130_bios_error),a
        ld      a,(p130_bios_disk_mode_active)
        or      a
        jr      z,p130_bios_local_fail_restore_stack
        call    p130_bios_restore_atm_video
        xor     a
        ld      (p130_bios_disk_mode_active),a
p130_bios_local_fail_restore_stack:
        ld      hl,(p130_bios_saved_sp)
        ld      sp,hl
        ld      a,(p130_bios_error)
        cp      1
        ld      hl,p130_bios_log_bad_selection
        jr      z,p130_bios_local_log_failure
        cp      2
        ld      hl,p130_bios_log_bad_type
        jr      z,p130_bios_local_log_failure
        cp      3
        ld      hl,p130_bios_log_not_found
        jr      z,p130_bios_local_log_failure
        cp      4
        ld      hl,p130_bios_log_bad_descriptor
        jr      z,p130_bios_local_log_failure
        cp      5
        ld      hl,p130_bios_log_bad_size
        jr      z,p130_bios_local_log_failure
        cp      6
        ld      hl,p130_bios_log_sector_error
        jr      z,p130_bios_local_log_failure
        ld      hl,p130_bios_log_transport_error
p130_bios_local_log_failure:
        call    p130_cat_debug_string
        ld      a,(p130_bios_error)
        scf
        ret

p130_bios_saved_sp:        dw 0
p130_bios_buffer_ptr:      dw P130_BIOS_FRAGMENT_DATA
p130_bios_sectors_left:    db 0
p130_bios_track:           db 0
p130_bios_sector:          db 0
p130_bios_error:           db 0
p130_bios_disk_mode_active: db 0
p130_bios_service:         db P130_BIOS_SERVICE_IMAGE
p130_bios_operation:       db 0
p130_bios_payload_length:  dw 0
p130_bios_sequence:        dw 0
p130_bios_image_crc:        dw 0

; ATM-side progress markers for the selected BIOS load transaction.
p130_bios_log_load_begin:       db "[CAT] BIOS LOAD BEGIN",13,10,0
p130_bios_log_selection_resolved: db "[CAT] BIOS SELECTION RESOLVED",13,10,0
p130_bios_log_filename_prefix:   db "[CAT] BIOS FILE SELECTED: ",0
p130_bios_log_image_identity_prefix: db "[CAT] BIOS IMAGE NAME/SIZE/CRC16: ",0
p130_bios_trace_state_prefix:   db "[CAT] TRDOS C=0A STATE BANKM/EXT/LEN/SP/ROM=",0
p130_bios_trace_name_prefix:    db "[CAT] TRDOS C=0A NAME=",0
p130_bios_log_file_type_ok:      db "[CAT] BIOS FILE TYPE C OK",13,10,0
p130_bios_log_trdos_map_begin:   db "[CAT] TRDOS MAP SWITCH BEGIN",13,10,0
p130_bios_log_trdos_map_done:    db "[CAT] TRDOS MAP SWITCH DONE",13,10,0
p130_bios_log_open_call:         db "[CAT] TRDOS OPEN C=0A CALL",13,10,0
p130_bios_log_open_return:       db "[CAT] TRDOS OPEN C=0A RETURN",13,10,0
p130_bios_log_descriptor_call:   db "[CAT] TRDOS DESCRIPTOR C=08 CALL",13,10,0
p130_bios_log_descriptor_return: db "[CAT] TRDOS DESCRIPTOR C=08 RETURN",13,10,0
p130_bios_log_file_open:        db "[CAT] BIOS FILE OPEN OK",13,10,0
p130_bios_log_size_ok:          db "[CAT] BIOS FILE SIZE OK",13,10,0
p130_bios_log_read_begin:       db "[CAT] BIOS READ BEGIN",13,10,0
p130_bios_log_read_done:        db "[CAT] BIOS READ COMPLETE",13,10,0
p130_bios_log_video_restored:   db "[CAT] BIOS ATM VIDEO RESTORED",13,10,0
p130_bios_log_image_begin_tx:   db "[CAT] IMAGE BEGIN TX",13,10,0
p130_bios_log_image_begin_ok:   db "[CAT] IMAGE BEGIN HANDLER COMPLETE",13,10,0
p130_bios_log_image_fragment_tx: db "[CAT] IMAGE FRAGMENT TX",13,10,0
p130_bios_log_image_fragment_ok: db "[CAT] IMAGE FRAGMENT HANDLER COMPLETE",13,10,0
p130_bios_log_image_finish_tx:  db "[CAT] IMAGE FINISH TX",13,10,0
p130_bios_log_image_finish_ok:  db "[CAT] IMAGE FINISH HANDLER COMPLETE",13,10,0
p130_bios_log_bad_selection:    db "[CAT] BIOS ERROR: BAD SELECTION",13,10,0
p130_bios_log_bad_type:         db "[CAT] BIOS ERROR: FILE TYPE",13,10,0
p130_bios_log_not_found:        db "[CAT] BIOS ERROR: FILE NOT FOUND",13,10,0
p130_bios_log_bad_descriptor:   db "[CAT] BIOS ERROR: DESCRIPTOR",13,10,0
p130_bios_log_bad_size:         db "[CAT] BIOS ERROR: SIZE/SECTORS",13,10,0
p130_bios_log_sector_error:     db "[CAT] BIOS ERROR: SECTOR READ",13,10,0
p130_bios_log_transport_error:  db "[CAT] BIOS ERROR: IPC/DMA",13,10,0

