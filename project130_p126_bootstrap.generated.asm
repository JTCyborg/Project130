DEVICE ZXSPECTRUM128
ORG #4000
INCLUDE "reference/project126/neogs_sub/p126_bootstrap.asm"
ASSERT p126_bootstrap_start=#4000
ASSERT p126_bootstrap_end>p126_bootstrap_start
ASSERT p126_bootstrap_end<=#4100
ASSERT p126_bootstrap_end-p126_bootstrap_start<=#0100
SAVEBIN "build/P126_BOOTSTRAP.bin",p126_bootstrap_start,p126_bootstrap_end-p126_bootstrap_start
