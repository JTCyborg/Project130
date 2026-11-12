[CmdletBinding()]
param(
    [string]$Zcc = "zcc",
    [string]$SjAsmPlus = "sjasmplus",
    [string]$Output = ".\disk_A.trd"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$ZccCommand = Get-Command $Zcc -ErrorAction SilentlyContinue
if (-not $ZccCommand) { throw "Z88DK zcc not found: $Zcc" }
$Zcc = $ZccCommand.Source
$Z88dkBin = Split-Path -Parent $Zcc
$env:PATH = "$Z88dkBin;$env:PATH"

$Z80Asm = Join-Path $Z88dkBin "z88dk-z80asm.exe"
if (-not (Test-Path $Z80Asm)) {
    throw "Z88DK assembler not found: $Z80Asm. Check the Z88DK installation."
}

if (-not (Test-Path $SjAsmPlus)) {
    $AssemblerCommand = Get-Command $SjAsmPlus -ErrorAction SilentlyContinue
    if (-not $AssemblerCommand) { throw "SjASMPlus not found: $SjAsmPlus" }
    $SjAsmPlus = $AssemblerCommand.Source
}

$BuildDir = Join-Path $Root "build"
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
$Resident = Join-Path $BuildDir "P130BOOT.bin"
$MapFile = Join-Path $BuildDir "P130BOOT.map"
$UiImage = Join-Path $BuildDir "P130UI.bin"
$NeoGsBootstrap = Join-Path $BuildDir "NEOBOOT.bin"
$Out = [System.IO.Path]::GetFullPath($Output)
if ([System.IO.Path]::GetFileName($Out) -ne "disk_A.trd") {
    throw "The packaging source writes disk_A.trd; use -Output disk_A.trd"
}

Remove-Item -Force -ErrorAction SilentlyContinue $Resident, $MapFile, $UiImage, $NeoGsBootstrap, (Join-Path $BuildDir "P130BOOT.sym"), $Out

Write-Host "[P130 BUILD] VERSION=P130-0.7.1-PHYSICAL-W3-MAPPER"
foreach ($Source in @("src/main.c", "src/diag.c", "src/diag.h", "src/memory.c", "src/memory.h", "src/map.c", "src/map.h", "src/map_hw.asm", "src/rtc.h", "src/rtc.asm", "src/trdos.asm", "src/hdd.asm", "src/hdd_fat16.asm", "src/catalog.asm", "src/neogs/loader.asm", "src/neogs/bootstrap.asm", "src/neogs/bootstrap_assemble.asm", "reference/project126/neogs_sub/x86_cpu_state_assemble.asm", "reference/project126/neogs_sub/p126_ipc.asm", "reference/project126/shared/p126_ipc_protocol.inc", "src/entry.asm", "src/ui.asm", "src/boot/main.asm")) {
    $Hash = (Get-FileHash $Source -Algorithm SHA256).Hash.Substring(0, 8)
    Write-Host "[P130 BUILD] $Source=$Hash"
}
Write-Host "[P130 BUILD] ZCC=$Zcc"
Write-Host "[P130 BUILD] Z88DK_BIN=$Z88dkBin"
Write-Host "[P130 BUILD] Z80ASM=$Z80Asm"
Write-Host "[P130 BUILD] SJASMPLUS=$SjAsmPlus"

# Same no-CRT link model and relocation used by the proven Project129 build.
& $Zcc +zx -v -O2 -compiler=sdcc --no-crt -Cl-r24576 -m -s -bn $Resident src/entry.asm src/main.c src/diag.c src/memory.c src/map.c src/map_hw.asm src/rtc.asm src/trdos.asm src/hdd.asm src/hdd_fat16.asm src/catalog.asm src/neogs/loader.asm
if ($LASTEXITCODE -ne 0) { throw "Z88DK compile/link failed: $LASTEXITCODE" }
if (-not (Test-Path $Resident)) { throw "Z88DK returned success but did not produce $Resident" }
if (-not (Test-Path $MapFile)) { throw "Z88DK did not produce required map file: $MapFile" }

$ResidentSize = (Get-Item $Resident).Length
if ($ResidentSize -le 0 -or $ResidentSize -gt 20480) {
    throw "Resident image must fit #6000-#AFFF (20 KiB); actual size: $ResidentSize bytes"
}
$MapText = Get-Content -Raw $MapFile
$EntryMatch = [regex]::Match($MapText, '(?m)^_p130_entry\s*=\s*\$([0-9A-Fa-f]{4})')
$CEntryMatch = [regex]::Match($MapText, '(?m)^_p130_c_entry\s*=\s*\$([0-9A-Fa-f]{4})')
if (-not $EntryMatch.Success -or [Convert]::ToInt32($EntryMatch.Groups[1].Value, 16) -ne 0x6000) {
    throw "Invalid resident entry origin. Expected _p130_entry=#6000; inspect $MapFile"
}
if (-not $CEntryMatch.Success) { throw "C entry _p130_c_entry is missing from $MapFile" }

$CEntryAddress = [Convert]::ToInt32($CEntryMatch.Groups[1].Value, 16)
if ($CEntryAddress -lt 0x6000 -or $CEntryAddress -ge (0x6000 + $ResidentSize)) {
    throw ("C entry is outside the loaded resident image: #{0:X4}" -f $CEntryAddress)
}

$ResidentBytes = [System.IO.File]::ReadAllBytes($Resident)
$CallFound = $false
for ($i = 0; $i -lt ($ResidentBytes.Length - 2); $i++) {
    if ($ResidentBytes[$i] -eq 0xCD) {
        $Target = [int]$ResidentBytes[$i + 1] + ([int]$ResidentBytes[$i + 2] -shl 8)
        if ($Target -eq $CEntryAddress) { $CallFound = $true; break }
    }
}
if (-not $CallFound) { throw ("No CALL to linked C entry #{0:X4} found in resident binary" -f $CEntryAddress) }

$ResidentEnd = 0x6000 + $ResidentSize
if ($ResidentEnd -gt 0xB000) { throw "Resident image overlaps BASIC loader at #B000" }
Write-Host ("[P130 BUILD] HOST_IMAGE_SIZE={0} ENTRY=#6000 C_ENTRY=#{1:X4} CALL=VERIFIED" -f $ResidentSize, $CEntryAddress)

# Project126-style console executes from ATM window 2 at #A000. Keeping it
# there is required: the renderer remaps window 1 to the character plane.
& $SjAsmPlus "--raw=$UiImage" src/ui.asm
if ($LASTEXITCODE -ne 0) { throw "ATM console assembly failed: $LASTEXITCODE" }
if (-not (Test-Path $UiImage)) { throw "ATM console assembler produced no image: $UiImage" }
$UiBytes = [System.IO.File]::ReadAllBytes($UiImage)
if ($UiBytes.Length -le 0 -or $UiBytes.Length -gt 4096) {
    throw "ATM console must fit #A000-#AFFF (4 KiB); actual size: $($UiBytes.Length) bytes"
}
$HostBytes = [System.IO.File]::ReadAllBytes($Resident)
$UiOffset = 0x4000
if ($HostBytes.Length -gt $UiOffset) {
    throw "ATM host image overlaps the fixed console origin #A000; host size: $($HostBytes.Length) bytes"
}
if ($UiBytes.Length -lt 12 -or $UiBytes[0] -ne 0xC3 -or $UiBytes[3] -ne 0xC3 -or $UiBytes[6] -ne 0xC3 -or $UiBytes[9] -ne 0xC3) {
    throw "ATM console entry table is invalid; expected JP stubs at #A000, #A003, #A006 and #A009"
}
$CombinedLength = $UiOffset + $UiBytes.Length
if ($CombinedLength -gt 20480) { throw "Combined resident/console image exceeds #6000-#AFFF" }
$Combined = New-Object byte[] $CombinedLength
[Array]::Copy($HostBytes, 0, $Combined, 0, $HostBytes.Length)
[Array]::Copy($UiBytes, 0, $Combined, $UiOffset, $UiBytes.Length)
[System.IO.File]::WriteAllBytes($Resident, $Combined)
$ResidentSize = $Combined.Length
$ResidentEnd = 0x6000 + $ResidentSize
Write-Host ("[P130 BUILD] UI=#A000 UI_SIZE={0} HOST_END=#{1:X4} COMBINED_SIZE={2}" -f $UiBytes.Length, (0x6000 + $HostBytes.Length), $ResidentSize)

# Build the <=256-byte NeoGS stage-0 image first; GS105a #14 uploads this
# image only. The resident core and application payloads are never GSDAT-streamed.
& $SjAsmPlus src/neogs/bootstrap_assemble.asm
if ($LASTEXITCODE -ne 0) { throw "NeoGS bootstrap assembly failed: $LASTEXITCODE" }
if (-not (Test-Path $NeoGsBootstrap)) { throw "NeoGS bootstrap image was not produced" }
$NeoGsBootstrapSize = (Get-Item $NeoGsBootstrap).Length
if ($NeoGsBootstrapSize -le 0 -or $NeoGsBootstrapSize -gt 256) {
    throw "NeoGS bootstrap must fit GS105a #14 (1..256 bytes); actual size: $NeoGsBootstrapSize"
}
Write-Host "[P130 BUILD] NEOBOOT_SIZE=$NeoGsBootstrapSize (SAVEBIN #4000..#40FF; GS105a #14/#13 only)"

# Project126 performs this exact disk open/first-sector read between the
# NEOBOOT #14 transfer and the #13 jump. Build its resident image as a TR-DOS
# preflight file so Project130 preserves that timing/sequence. It is not sent
# over GSDAT; Project130's post-A1 payload path remains DMA/IPC.
$CoreListing = Join-Path $BuildDir "P130_X86CORE.lst"
$CoreSymbols = Join-Path $BuildDir "P130_X86CORE.map"
$CoreImage = Join-Path $BuildDir "X86CORE.C"
# Clean stale outputs BEFORE assembly. The Project126 assembler itself emits
# X86CORE.C and all six split overlays via SAVEBIN; never delete them afterward.
Remove-Item -Force -ErrorAction SilentlyContinue $CoreListing, $CoreSymbols
foreach ($Overlay in @("X86CORE.C","X86IO.C","X86ALU.C","X86DEV.C","X86EXEC.C","X86VGA.C","X86VID.C","X86MODS.MF")) {
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $BuildDir $Overlay)
}
& $SjAsmPlus --msg=all "--lst=build/P130_X86CORE.lst" --lstlab=sort "--sym=build/P130_X86CORE.map" "reference/project126/neogs_sub/x86_cpu_state_assemble.asm"
if ($LASTEXITCODE -ne 0) { throw "Project126-compatible resident preflight image assembly failed: $LASTEXITCODE" }
if (-not (Test-Path $CoreImage)) { throw "Resident preflight image was not produced: build/X86CORE.C" }
$CoreSize = (Get-Item $CoreImage).Length
if ($CoreSize -le 0 -or $CoreSize -gt 0x4000) {
    throw "X86CORE.C preflight image must fit 1..16384 bytes; actual size: $CoreSize"
}

# Exact Project126 split overlay directory consumed by the imported host loader.
$OverlayProfiles = @(
    @{ Id = 1; Page = 4; File = "X86IO.C"; Max = 0x1000 },
    @{ Id = 2; Page = 5; File = "X86ALU.C"; Max = 0x1000 },
    @{ Id = 3; Page = 6; File = "X86DEV.C"; Max = 0x1000 },
    @{ Id = 4; Page = 7; File = "X86EXEC.C"; Max = 0x4000 },
    @{ Id = 5; Page = 8; File = "X86VGA.C"; Max = 0x4000 },
    @{ Id = 6; Page = 9; File = "X86VID.C"; Max = 0x4000 }
)
function Get-P130Crc16([byte[]]$Bytes) {
    [int]$Crc = 0xFFFF
    foreach ($Value in $Bytes) {
        $Crc = $Crc -bxor ([int]$Value -shl 8)
        for ($Bit = 0; $Bit -lt 8; $Bit++) {
            if (($Crc -band 0x8000) -ne 0) {
                $Crc = (($Crc -shl 1) -band 0xFFFF) -bxor 0x1021
            } else {
                $Crc = ($Crc -shl 1) -band 0xFFFF
            }
        }
    }
    return [uint16]$Crc
}
[System.Collections.Generic.List[byte]]$Manifest = [System.Collections.Generic.List[byte]]::new()
$Manifest.AddRange([byte[]](0x50,0x31,0x32,0x36,1,6,8))
foreach ($Profile in $OverlayProfiles) {
    $Path = Join-Path $BuildDir $Profile.File

    # SjASMPlus SAVEBIN output can be rooted relative to the translation unit
    # depending on the caller's working directory. Normalize the generated
    # artifact into the canonical build directory before validating/packaging.
    if (-not (Test-Path $Path)) {
        $Candidates = @(Get-ChildItem -Path $Root -Filter $Profile.File -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -ne $Path -and
                $_.FullName -notmatch '[\\/](\.git|\.vs|obj|bin)[\\/]'
            })
        if ($Candidates.Count -eq 1) {
            Copy-Item -Force $Candidates[0].FullName $Path
            Write-Host ("[P130 BUILD] RECOVERED SAVEBIN OUTPUT {0} FROM {1}" -f $Profile.File,$Candidates[0].FullName)
        } elseif ($Candidates.Count -gt 1) {
            throw "Ambiguous SjASMPlus output for $($Profile.File): $($Candidates.FullName -join '; ')"
        }
    }
    if (-not (Test-Path $Path)) { throw "Required Project126 overlay missing after SAVEBIN path normalization: $Path" }
    [byte[]]$Bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($Bytes.Length -lt 1 -or $Bytes.Length -gt $Profile.Max) {
        throw "$($Profile.File) size $($Bytes.Length) exceeds its Project126 page limit."
    }
    [uint16]$Crc = Get-P130Crc16 $Bytes
    $Manifest.Add([byte]$Profile.Id)
    $Manifest.Add([byte]$Profile.Page)
    $Manifest.Add([byte]1)
    $Manifest.Add([byte]0)
    $Manifest.Add([byte]($Bytes.Length -band 0xFF))
    $Manifest.Add([byte](($Bytes.Length -shr 8) -band 0xFF))
    $Manifest.Add([byte]($Crc -band 0xFF))
    $Manifest.Add([byte](($Crc -shr 8) -band 0xFF))
    Write-Host ("[P130 BUILD] MODULE={0} PAGE={1:X2} SIZE={2} CRC16={3:X4}" -f $Profile.File,$Profile.Page,$Bytes.Length,$Crc)
}
if ($Manifest.Count -ne 55) { throw "X86MODS.MF must be exactly 55 bytes; got $($Manifest.Count)" }
[System.IO.File]::WriteAllBytes((Join-Path $BuildDir "X86MODS.MF"),$Manifest.ToArray())
Write-Host "[P130 BUILD] X86MODS.MF SIZE=55 RECORDS=6"

Write-Host "[P130 BUILD] X86CORE_PREFLIGHT_SIZE=$CoreSize (opened/read before GS105a #13; payload remains DMA/IPC)"

# The three BIOS files are independent 8 KiB ROM images. bios.asm/bios.txt
# describe Bios.bin and are intentionally not packaged as separate images.
foreach ($Bios in @("bios/27c64d.bin", "bios/Bios.bin", "bios/Compaq Portable Plus 100666-001 Rev C.bin")) {
    if (-not (Test-Path $Bios)) { throw "Required BIOS image is missing: $Bios" }
    $BiosSize = (Get-Item $Bios).Length
    if ($BiosSize -ne 8192) { throw "BIOS image must be exactly 8192 bytes: $Bios ($BiosSize)" }
    $BiosHash = (Get-FileHash $Bios -Algorithm SHA256).Hash
    Write-Host "[P130 BUILD] BIOS=$Bios SIZE=$BiosSize SHA256=$BiosHash"
}

& $SjAsmPlus --dirbol src/boot/main.asm
if ($LASTEXITCODE -ne 0) { throw "SjASMPlus TR-DOS packaging failed: $LASTEXITCODE" }
if (-not (Test-Path $Out)) { throw "SjASMPlus returned success but disk image is missing: $Out" }
$DiskSize = (Get-Item $Out).Length
if ($DiskSize -ne 655360) { throw "TR-DOS image must be 655360 bytes; actual size: $DiskSize" }
Write-Host "[P130 BUILD] DISK=$Out SIZE=$DiskSize"
Write-Host "[P130 BUILD] TR-DOS FILES=boot.B,p130boot.C,NEOBOOT.C,X86CORE.C,X86IO.C,X86ALU.C,X86DEV.C,X86EXEC.C,X86VGA.C,X86VID.C,X86MODS.C,BIOS1.C,BIOS2.C,BIOS3.C"
Write-Host "[P130 BUILD] BUILD COMPLETE (runtime test required)"
