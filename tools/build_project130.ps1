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
$SymFile = Join-Path $BuildDir "P130BOOT.sym"
$Out = [System.IO.Path]::GetFullPath($Output)
if ([System.IO.Path]::GetFileName($Out) -ne "disk_A.trd") {
    throw "The packaging source writes disk_A.trd; use -Output disk_A.trd"
}

Remove-Item -Force -ErrorAction SilentlyContinue $Resident, $MapFile, $SymFile, $Out

Write-Host "[P130 BUILD] VERSION=BOOTSTRAP-0.1.0-SKELETON"
foreach ($Source in @("src/main.c", "src/entry.asm", "src/boot/main.asm")) {
    $Hash = (Get-FileHash $Source -Algorithm SHA256).Hash.Substring(0, 8)
    Write-Host "[P130 BUILD] $Source=$Hash"
}
Write-Host "[P130 BUILD] ZCC=$Zcc"
Write-Host "[P130 BUILD] Z88DK_BIN=$Z88dkBin"
Write-Host "[P130 BUILD] SJASMPLUS=$SjAsmPlus"

# Match the known Project129 Z88DK no-CRT link model and TR-DOS load address.
& $Zcc +zx -v -O2 -compiler=sdcc --no-crt -Cl-r24576 -m -s -bn $Resident src/entry.asm src/main.c
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
    throw "Resident entry _p130_entry must be linked at #6000"
}
if (-not $CEntryMatch.Success) { throw "C entry _p130_c_entry missing from link map" }

$ResidentEnd = 0x6000 + $ResidentSize
if ($ResidentEnd -gt 0xB000) { throw "Resident image overlaps BASIC loader at #B000" }
Write-Host ("[P130 BUILD] IMAGE_SIZE={0} ENTRY=#6000 C_ENTRY=#{1:X4} END=#{2:X4}" -f $ResidentSize, [Convert]::ToInt32($CEntryMatch.Groups[1].Value,16), $ResidentEnd)

& $SjAsmPlus -zx -q src/boot/main.asm
if ($LASTEXITCODE -ne 0) { throw "SjASMPlus TR-DOS packaging failed: $LASTEXITCODE" }
if (-not (Test-Path $Out)) { throw "SjASMPlus returned success but disk image is missing: $Out" }
Write-Host "[P130 BUILD] DISK=$Out"
Write-Host "[P130 BUILD] BUILD COMPLETE (runtime boot not yet validated)"
