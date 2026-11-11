; Project130 TR-DOS disk packaging.
; The resident Z88DK image is linked at #6000 and loaded as P130BOOT.C.

        DEVICE ZXSPECTRUM128
        EMPTYTRD "disk_A.trd"

        ORG     #B000
CLEAR       EQU #FD
RANDOMIZE   EQU #F9
USR         EQU #C0
REM         EQU #EA
VAL         EQU #B0
OUT_CMD     EQU #DF

basic_loader:
        DB      0,10
        DW      l10_end-l10
l10:
        DB      OUT_CMD,"239",#0E,#00,#00,#EF,#00,#00
        DB      ",","1",#0E,#00,#00,#01,#00,#00,":"
        DB      CLEAR,"24000",#0E,#00,#00,#5D,#C0,#00,#0D
l10_end:

        DB      0,20
        DW      l20_end-l20
l20:
        DB      RANDOMIZE,USR,"15619",#0E,#00,#00
        DW      15619
        DB      0,#3A,REM,#3A
        DB      "LOAD ",34,"p130boot",34," CODE 24576",#0D
l20_end:

        DB      0,30
        DW      l30_end-l30
l30:
        DB      OUT_CMD,"239",#0E,#00,#00,#EF,#00,#00,","
        DB      "2",#0E,#00,#00,#02,#00,#00,":"
        DB      RANDOMIZE,USR,VAL,34,"24576",34,#0D
l30_end:
        DB      #80
basic_loader_end:

        SAVETRD "disk_A.trd","boot.B",basic_loader,basic_loader_end-basic_loader,10

        ORG     #6000
p130_boot_image:
        INCBIN  "build/P130BOOT.bin"
p130_boot_image_end:
        ASSERT  p130_boot_image_end > p130_boot_image
        SAVETRD "disk_A.trd","p130boot.C",p130_boot_image,p130_boot_image_end-p130_boot_image
