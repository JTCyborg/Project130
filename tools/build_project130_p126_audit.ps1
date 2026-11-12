[CmdletBinding()]
param(
    [string]$Assembler = ".\tools\sjasmplus.exe"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

if (-not (Test-Path $Assembler)) {
    $Command = Get-Command $Assembler -ErrorAction SilentlyContinue
    if (-not $Command) { throw "SjASMPlus not found: $Assembler" }
    $Assembler = $Command.Source
}
$Assembler = (Resolve-Path $Assembler).Path
$Build = Join-Path $Root "build"
New-Item -ItemType Directory -Force -Path $Build | Out-Null

function Invoke-AssemblyAudit {
    param(
        [string]$Name,
        [string]$Source,
        [string]$Binary,
        [string]$Listing,
        [string]$Symbols,
        [int]$MaximumBytes
    )

    foreach ($Path in @($Source, $Binary, $Listing, $Symbols)) {
        if ([System.IO.Path]::IsPathRooted($Path)) {
            throw "Audit paths must be repository-relative: $Path"
        }
    }

    $BinaryPath = Join-Path $Build $Binary
    $ListingPath = Join-Path $Build $Listing
    $SymbolsPath = Join-Path $Build $Symbols
    Remove-Item -Force -ErrorAction SilentlyContinue $BinaryPath, $ListingPath, $SymbolsPath

    Write-Host "[P130 P126 AUDIT] UNIT=$Name SOURCE=$Source"
    & $Assembler --msg=all "--lst=build/$Listing" --lstlab=sort "--sym=build/$Symbols" "--raw=build/$Binary" $Source
    if ($LASTEXITCODE -ne 0) {
        throw "SjASMPlus failed for $Name with exit code $LASTEXITCODE"
    }

    foreach ($Path in @($BinaryPath, $ListingPath, $SymbolsPath)) {
        if (-not (Test-Path $Path)) {
            throw "Required $Name audit output was not produced: $Path"
        }
    }

    $Size = (Get-Item $BinaryPath).Length
    if ($Size -lt 1 -or $Size -gt $MaximumBytes) {
        throw "$Name audit image size $Size is outside 1..$MaximumBytes bytes."
    }
    Write-Host "[P130 P126 AUDIT] $Name BYTES=$Size LISTING=$Listing SYMBOLS=$Symbols"
}

Write-Host "[P130 P126 AUDIT] VERSION=SOURCE-IMPORT-AUDIT-1.0"
Write-Host "[P130 P126 AUDIT] PURPOSE=ASSEMBLY-AND-SIZE-CHECK-ONLY"
Write-Host "[P130 P126 AUDIT] MAP=PROJECT126-REFERENCE-ONLY"

# This unit emits the resident audit image and all six split CPU/device
# overlays through its own SAVEBIN directives.
$CoreListing = Join-Path $Build "P130_P126_NGS.lst"
$CoreSymbols = Join-Path $Build "P130_P126_NGS.map"
$CoreRaw = Join-Path $Build "P130_P126_NGS.raw"
$CoreOutputs = @(
    "X86CORE.C", "X86IO.C", "X86ALU.C", "X86DEV.C",
    "X86EXEC.C", "X86VGA.C", "X86VID.C", "x86_cpu_state.bin"
)
Remove-Item -Force -ErrorAction SilentlyContinue $CoreListing, $CoreSymbols, $CoreRaw
foreach ($Name in $CoreOutputs) {
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $Build $Name)
}

Write-Host "[P130 P126 AUDIT] UNIT=NeoGS resident and split overlays"
& $Assembler --msg=all "--lst=build/P130_P126_NGS.lst" --lstlab=sort "--sym=build/P130_P126_NGS.map" "neogs_sub/x86_cpu_state_assemble.asm"
if ($LASTEXITCODE -ne 0) {
    throw "SjASMPlus failed for Project126 NeoGS resident with exit code $LASTEXITCODE"
}
foreach ($Name in $CoreOutputs) {
    $Path = Join-Path $Build $Name
    if (-not (Test-Path $Path)) {
        throw "Project126 resident assembly did not emit required image: build/$Name"
    }
    $Size = (Get-Item $Path).Length
    if ($Size -lt 1) {
        throw "Project126 resident image is empty: build/$Name"
    }
    Write-Host "[P130 P126 AUDIT] IMAGE=$Name BYTES=$Size"
}
if ((Get-Item (Join-Path $Build "X86CORE.C")).Length -gt 0x4000) {
    throw "X86CORE.C exceeds the legacy Project126 16 KiB resident-image limit."
}
foreach ($Name in @("X86IO.C", "X86ALU.C", "X86DEV.C")) {
    if ((Get-Item (Join-Path $Build $Name)).Length -gt 0x1000) {
        throw "$Name exceeds the legacy Project126 4 KiB overlay limit."
    }
}
foreach ($Name in @("X86EXEC.C", "X86VGA.C", "X86VID.C")) {
    if ((Get-Item (Join-Path $Build $Name)).Length -gt 0x4000) {
        throw "$Name exceeds the legacy Project126 16 KiB overlay limit."
    }
}

Invoke-AssemblyAudit -Name "ATM IPC" -Source "atm_host/neogs_ipc_assemble.asm" -Binary "P130_P126_ATM_IPC.raw" -Listing "P130_P126_ATM_IPC.lst" -Symbols "P130_P126_ATM_IPC.map" -MaximumBytes 65536
Invoke-AssemblyAudit -Name "NeoGS IPC" -Source "neogs_sub/p126_ipc_assemble.asm" -Binary "P130_P126_NGS_IPC.raw" -Listing "P130_P126_NGS_IPC.lst" -Symbols "P130_P126_NGS_IPC.map" -MaximumBytes 65536
Invoke-AssemblyAudit -Name "GS105a bootstrap reference" -Source "neogs_sub/p126_bootstrap_assemble.asm" -Binary "P130_P126_BOOTSTRAP.raw" -Listing "P130_P126_BOOTSTRAP.lst" -Symbols "P130_P126_BOOTSTRAP.map" -MaximumBytes 256

$Bootstrap = Join-Path $Build "P126_BOOTSTRAP.bin"
if (-not (Test-Path $Bootstrap)) {
    throw "Project126 bootstrap SAVEBIN output missing: build/P126_BOOTSTRAP.bin"
}
$BootstrapSize = (Get-Item $Bootstrap).Length
if ($BootstrapSize -lt 1 -or $BootstrapSize -gt 256) {
    throw "Project126 bootstrap size $BootstrapSize is outside the GS105a 1..256 byte limit."
}
Write-Host "[P130 P126 AUDIT] P126_BOOTSTRAP.bin BYTES=$BootstrapSize"
Write-Host "[P130 P126 AUDIT] COMPLETE"
Write-Host "[P130 P126 AUDIT] NOTE=NO-P130-RUNTIME-INTEGRATION-OR-TARGET-VALIDATION"
