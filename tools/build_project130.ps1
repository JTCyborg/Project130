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
$Out = [System.IO.Path]::GetFullPath($Output)
if ([System.IO.Path]::GetFileName($Out) -ne "disk_A.trd") {
    throw "The packaging source writes disk_A.trd; use -Output disk_A.trd"
}

Remove-Item -Force -ErrorAction SilentlyContinue $Resident, $MapFile, (Join-Path $BuildDir "P130BOOT.sym"), $Out

Write-Host "[P130 BUILD] VERSION=BOOTSTRAP-0.2.0-ATM-HOST-BASE"
foreach ($Source in @("src/main.c", "src/memory.c", "src/memory.h", "src/entry.asm", "src/boot/main.asm")) {
    $Hash = (Get-FileHash $Source -Algorithm SHA256).Hash.Substring(0, 8)
    Write-Host "[P130 BUILD] $Source=$Hash"
}
Write-Host "[P130 BUILD] ZCC=$Zcc"
Write-Host "[P130 BUILD] Z88DK_BIN=$Z88dkBin"
Write-Host "[P130 BUILD] Z80ASM=$Z80Asm"
Write-Host "[P130 BUILD] SJASMPLUS=$SjAsmPlus"

# Same no-CRT link model and relocation used by the proven Project129 build.
& $Zcc +zx -v -O2 -compiler=sdcc --no-crt -Cl-r24576 -m -s -bn $Resident src/entry.asm src/main.c src/memory.c
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
Write-Host ("[P130 BUILD] IMAGE_SIZE={0} ENTRY=#6000 C_ENTRY=#{1:X4} END=#{2:X4} CALL=VERIFIED" -f $ResidentSize, $CEntryAddress, $ResidentEnd)

& $SjAsmPlus --dirbol src/boot/main.asm
if ($LASTEXITCODE -ne 0) { throw "SjASMPlus TR-DOS packaging failed: $LASTEXITCODE" }
if (-not (Test-Path $Out)) { throw "SjASMPlus returned success but disk image is missing: $Out" }
$DiskSize = (Get-Item $Out).Length
if ($DiskSize -ne 655360) { throw "TR-DOS image must be 655360 bytes; actual size: $DiskSize" }
Write-Host "[P130 BUILD] DISK=$Out SIZE=$DiskSize"
Write-Host "[P130 BUILD] BUILD COMPLETE (runtime test required)"
