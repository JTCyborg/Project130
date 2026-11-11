# Project130 BIOS images

The TR-DOS image contains three separate 8 KiB BIOS binaries:

| TR-DOS file | Repository image | Identification |
|---|---|---|
| `BIOS1.C` | `bios/27c64d.bin` | BIOS V1.11, Central Point Software, Inc. (1986/87) |
| `BIOS2.C` | `bios/Bios.bin` | Generic Turbo XT BIOS 1987, for 8088/V20 |
| `BIOS3.C` | `bios/Compaq Portable Plus 100666-001 Rev C.bin` | Compaq Portable Plus BIOS, revision C |

`bios/bios.asm` and `bios/bios.txt` are the source/listing and historical notes for the Generic Turbo XT BIOS in `bios/Bios.bin`. They are not additional BIOS images and are not added to the disk as separate files.

The packaging source includes each binary directly with `INCBIN`; it does not patch, concatenate, pad or rewrite the source bytes. The build checks that each source file is exactly 8192 bytes and prints its SHA-256. The BIOS files are stored as TR-DOS type C files and are visible in the existing file selector.

The current guest BIOS loader/ROM mapping is not yet implemented. Inclusion in the TR-DOS disk makes the images available for the later DMA/IPC-backed load stage; it does not claim that any BIOS currently boots.
