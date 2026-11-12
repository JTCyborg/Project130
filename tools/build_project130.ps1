[CmdletBinding()]
param([string]$Zcc="zcc",[string]$SjAsmPlus="sjasmplus",[string]$Output=".\disk_A.trd")
$ErrorActionPreference="Stop"
$Root=Split-Path -Parent $PSScriptRoot
Set-Location $Root
$cmd=Get-Command $SjAsmPlus -ErrorAction SilentlyContinue
if (-not $cmd){throw "SjASMPlus not found: $SjAsmPlus"}
$SjAsmPlus=$cmd.Source
$Build=Join-Path $Root "build"
New-Item -ItemType Directory -Force -Path $Build|Out-Null
$Out=[System.IO.Path]::GetFullPath($Output)
if ([System.IO.Path]::GetFileName($Out) -ne "disk_A.trd"){throw "Output must be disk_A.trd"}
Remove-Item -Force -ErrorAction SilentlyContinue $Out,(Join-Path $Build "disk_A.trd")
Write-Host "[P130 BUILD] VERSION=P130-P125-INT10-FULL-TEXT-P126-VGA"
Write-Host "[P130 BUILD] ACTIVE ATM HOST=src/project126/atm_host/project126_main.asm"
Write-Host "[P130 BUILD] FLOW=BOOT.B -> P130BOOT.C -> P126BOOT.C -> X86CORE/OVERLAYS -> CATALOGUE -> BIOS ENTER -> SYSBIOS PAGE10"

# Build provenance: record every source/include/binary/tool actually consumed.
$BuildLog=Join-Path $Build "P130_BUILD_FILES.log"
Remove-Item -Force -ErrorAction SilentlyContinue $BuildLog
Set-Content -Path $BuildLog -Value "# Project130 build input/output manifest" -Encoding UTF8
Add-Content -Path $BuildLog -Value "# FORMAT=ROLE|PATH|BYTES|SHA256"
$BuildFileSeen=@{}
function Add-BuildFile([string]$Path,[string]$Role,[bool]$Scan=$true){
 if([IO.Path]::IsPathRooted($Path)){$full=[IO.Path]::GetFullPath($Path)}else{$full=[IO.Path]::GetFullPath((Join-Path $Root $Path))}
 $key=$full.ToLowerInvariant()
 if($BuildFileSeen.ContainsKey($key)){return}
 $BuildFileSeen[$key]=$true
 if(-not (Test-Path -LiteralPath $full -PathType Leaf)){
  $line="MISSING|$Path|0|"
  Add-Content -Path $BuildLog -Value $line
  throw "Build provenance: required input missing: $Path"
 }
 $item=Get-Item -LiteralPath $full
 $hash=(Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
 $rel=$full.Substring($Root.Length).TrimStart('\','/')
 $line="$Role|$rel|$($item.Length)|$hash"
 Add-Content -Path $BuildLog -Value $line
 Write-Host ("[P130 FILE] {0} SIZE={1} SHA256={2} PATH={3}" -f $Role,$item.Length,$hash,$rel)
 if($Scan -and $full -match '\.(asm|inc|s)$'){
  $text=[IO.File]::ReadAllText($full)
  foreach($m in [regex]::Matches($text,'(?im)^\s*(INCLUDE|INCBIN)\s+"([^"]+)"')){
   $dep=$m.Groups[2].Value
   Add-BuildFile $dep ("DEP-"+$m.Groups[1].Value.ToUpperInvariant()) $true
  }
 }
}
function Add-BuildOutput([string]$Path,[string]$Role){
 Add-BuildFile $Path $Role $false
}

$required=@(
 "src/project126/atm_host/project126_main.asm",
 "src/project126/atm_host/boot_loader.asm",
 "src/project126/atm_host/ds12887_rtc.asm",
 "src/project126/atm_host/neogs_ipc.asm",
 "src/project126/atm_host/neogs_ipc.inc",
 "shared/p126_ipc_protocol.inc",
 "src/project126/atm_host/p126_disk_catalog.asm",
 "src/project126/atm_host/p126_neogs_loader.asm",
 "src/project126/atm_host/p126_bios_loader.asm",
 "src/project126/atm_host/p126_screen_console.asm",
 "src/project126/project126_disk.asm",
 "reference/project126/neogs_sub/p126_bootstrap.asm",
 "reference/project126/neogs_sub/x86_cpu_state_assemble.asm",
 "reference/project126/neogs_sub/x86_bios_video.asm"
)
foreach ($f in $required) { if (-not (Test-Path $f)){throw "Missing Project126 source: $f"}}

# Record the complete direct source set and recursively follow assembler INCLUDEs.
foreach($f in $required){Add-BuildFile $f "SOURCE" $true}
Add-BuildFile "src/project126/project126_disk.asm" "SOURCE-DISK" $false
Add-BuildFile "src/project126/atm_host/boot_loader.asm" "SOURCE-BOOTLOADER" $true
Add-BuildFile $SjAsmPlus "TOOL-SJASMPLUS" $false
foreach($bios in @("bios/27c64d.bin","bios/Bios.bin","bios/Compaq Portable Plus 100666-001 Rev C.bin")){
 Add-BuildFile $bios "BIOS-PACKAGED" $false
}

# Assemble the original Project126 GS105a stage-0 at #4000.
$bootAsm=@'
DEVICE ZXSPECTRUM128
ORG #4000
INCLUDE "reference/project126/neogs_sub/p126_bootstrap.asm"
ASSERT p126_bootstrap_start=#4000
ASSERT p126_bootstrap_end>p126_bootstrap_start
ASSERT p126_bootstrap_end<=#4100
ASSERT p126_bootstrap_end-p126_bootstrap_start<=#0100
SAVEBIN "build/P126_BOOTSTRAP.bin",p126_bootstrap_start,p126_bootstrap_end-p126_bootstrap_start
'@
Set-Content -Path (Join-Path $Root "project130_p126_bootstrap.generated.asm") -Value $bootAsm -Encoding ASCII
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $Build "P126_BOOTSTRAP.bin")
& $SjAsmPlus --dirbol --msg=all "--lst=build/P130_P126_BOOTSTRAP.lst" "--sym=build/P130_P126_BOOTSTRAP.map" "--raw=build/P126_BOOTSTRAP_AUDIT.bin" "project130_p126_bootstrap.generated.asm"
if ($LASTEXITCODE -ne 0){throw "Project126 bootstrap assembly failed: $LASTEXITCODE"}
Add-BuildOutput "build/P126_BOOTSTRAP.bin" "OUTPUT-BOOTSTRAP"
$bootBin=Join-Path $Build "P126_BOOTSTRAP.bin"
if (-not (Test-Path $bootBin)){throw "P126_BOOTSTRAP.bin was not generated"}
$bootSize=(Get-Item $bootBin).Length
if ($bootSize -lt 1 -or $bootSize -gt 256){throw "P126BOOT size invalid: $bootSize"}

# Assemble Project126's resident and all six original overlay modules.
$names=@("X86CORE.C","X86IO.C","X86ALU.C","X86DEV.C","X86EXEC.C","X86VGA.C","X86VID.C","x86_cpu_state.bin")
foreach ($n in $names) {Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $Build $n)}
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $Build "P130_X86CORE.lst"),(Join-Path $Build "P130_X86CORE.map")
& $SjAsmPlus --dirbol --msg=all "--lst=build/P130_X86CORE.lst" "--lstlab=sort" "--sym=build/P130_X86CORE.map" "reference/project126/neogs_sub/x86_cpu_state_assemble.asm"
if ($LASTEXITCODE -ne 0){throw "Project126 resident/overlay assembly failed: $LASTEXITCODE"}
foreach($n in $names){Add-BuildOutput ("build/"+$n) "OUTPUT-X86-MODULE"}
foreach ($n in $names) {
 $target=Join-Path $Build $n
 if (-not (Test-Path $target)){
  $found=@(Get-ChildItem -Path $Root -Filter $n -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.FullName -ne $target -and $_.FullName -notmatch '[\\/](\.git|\.vs|obj|bin)[\\/]'})
  if ($found.Count -eq 1){Copy-Item -Force $found[0].FullName $target}
  elseif ($found.Count -gt 1){throw "Ambiguous SAVEBIN output: $n"}
 }
 if (-not (Test-Path $target)){throw "Project126 output missing: $n"}
}
$limits=@{ "X86CORE.C"=0x4000;"X86IO.C"=0x1000;"X86ALU.C"=0x1000;"X86DEV.C"=0x1000;"X86EXEC.C"=0x4000;"X86VGA.C"=0x4000;"X86VID.C"=0x4000 }
foreach ($n in $limits.Keys) {
 $size=(Get-Item (Join-Path $Build $n)).Length
 if ($size -lt 1 -or $size -gt $limits[$n]){throw "$n size $size exceeds Project126 limit"}
 Write-Host "[P130 BUILD] $n SIZE=$size"
}

# Generate the exact Project126 manifest from the binaries actually packaged.
function Get-Crc16([byte[]]$data){
 [int]$crc=0xFFFF
 foreach($v in $data){
  $crc = $crc -bxor ([int]$v -shl 8)
  for ($i = 0; $i -lt 8; $i++){
   if ($crc -band 0x8000){$crc=(($crc -shl 1) -band 0xFFFF) -bxor 0x1021}
   else{$crc=($crc -shl 1) -band 0xFFFF}
  }
 }
 return [uint16]$crc
}
$profiles=@(
 @{Id=1;Page=4;File="X86IO.C"},@{Id=2;Page=5;File="X86ALU.C"},
 @{Id=3;Page=6;File="X86DEV.C"},@{Id=4;Page=7;File="X86EXEC.C"},
 @{Id=5;Page=8;File="X86VGA.C"},@{Id=6;Page=9;File="X86VID.C"}
)
[System.Collections.Generic.List[byte]]$mf=[System.Collections.Generic.List[byte]]::new()
$mf.AddRange([byte[]](0x50,0x31,0x32,0x36,1,6,8))
foreach ($p in $profiles) {
 [byte[]]$data=[IO.File]::ReadAllBytes((Join-Path $Build $p.File))
 [uint16]$crc=Get-Crc16 $data
 $mf.Add([byte]$p.Id);$mf.Add([byte]$p.Page);$mf.Add([byte]1);$mf.Add([byte]0)
 $mf.Add([byte]($data.Length -band 255));$mf.Add([byte](($data.Length -shr 8) -band 255))
 $mf.Add([byte]($crc -band 255));$mf.Add([byte](($crc -shr 8) -band 255))
 Write-Host ("[P130 BUILD] MODULE={0} PAGE={1:X2} SIZE={2} CRC16={3:X4}"-f $p.File,$p.Page,$data.Length,$crc)
}
if ($mf.Count -ne 55){throw "X86MODS.MF must be 55 bytes"}
[IO.File]::WriteAllBytes((Join-Path $Build "X86MODS.MF"),$mf.ToArray())

# All three BIOS payloads must be exactly 8 KiB.
foreach ($bios in @("bios/27c64d.bin","bios/Bios.bin","bios/Compaq Portable Plus 100666-001 Rev C.bin")){
 if (-not (Test-Path $bios)){throw "Missing BIOS: $bios"}
 $size=(Get-Item $bios).Length
 if ($size -ne 8192){throw "BIOS must be 8192 bytes: $bios ($size)"}
 Write-Host "[P130 BUILD] BIOS=$bios SIZE=$size"
}

# Reuse Project126's BASIC boot program; only change the host CODE filename.
$bootText=(Get-Content -Raw "src/project126/atm_host/boot_loader.asm").Replace("proj125","p130boot")
Set-Content -Path (Join-Path $Build "P130_P126_boot_loader.generated.asm") -Value $bootText -Encoding ASCII
Add-BuildOutput "build/P130_P126_boot_loader.generated.asm" "GENERATED-ASM"

# Use the original Project126 TR-DOS packaging source and directory names.
$diskText=(Get-Content -Raw "src/project126/project126_disk.asm").Replace("@@HOST_NAME@@","p130boot").Replace("@@BOOT_NAME@@","boot")
Set-Content -Path (Join-Path $Root "project130_disk.generated.asm") -Value $diskText -Encoding ASCII
Add-BuildFile "project130_disk.generated.asm" "GENERATED-DISK-ASM" $true
& $SjAsmPlus --dirbol --msg=all "--lst=build/P130_DISK.lst" "--lstlab=sort" "--sym=build/P130_DISK.map" "project130_disk.generated.asm"
if ($LASTEXITCODE -ne 0){throw "Project126 TR-DOS packaging failed: $LASTEXITCODE"}
if (-not (Test-Path $Out)){throw "disk_A.trd was not produced"}
$diskSize=(Get-Item $Out).Length
if ($diskSize -ne 655360){throw "TR-DOS image size invalid: $diskSize"}

# Verify the directory entries and fixed BIOS lengths before publishing output.
[byte[]]$disk=[IO.File]::ReadAllBytes($Out)
$entries=@(
 @{Name="boot    B";Length=0},@{Name="p130bootC";Length=0},@{Name="P126BOOTC";Length=0},
 @{Name="X86CORE C";Length=0},@{Name="X86IO   C";Length=0},@{Name="X86ALU  C";Length=0},
 @{Name="X86DEV  C";Length=0},@{Name="X86EXEC C";Length=0},@{Name="X86VGA  C";Length=0},
 @{Name="X86VID  C";Length=0},@{Name="X86MODS C";Length=55},
 @{Name="BIOS1   C";Length=8192;Sectors=32},@{Name="BIOS2   C";Length=8192;Sectors=32},@{Name="COMPAQ  C";Length=8192;Sectors=32}
)
foreach ($e in $entries) {
 [byte[]]$key=[Text.Encoding]::ASCII.GetBytes($e.Name);$found=$false
 for ($off = 0; $off -lt 2048; $off += 16){
  $match=$true
  for ($i = 0; $i -lt $key.Length; $i++){if ($disk[$off + $i] -ne $key[$i]){$match=$false;break}}
  if ($match) {
   $found=$true;$length=[int]$disk[$off+11]+([int]$disk[$off+12]-shl 8)
   if ($e.Length -ne 0 -and $length -ne $e.Length){throw "$($e.Name) length $length; expected $($e.Length)"}
   $sectors=[int]$disk[$off+13]
   if ($e.ContainsKey("Sectors") -and $sectors -ne $e.Sectors){throw "$($e.Name) sectors $sectors; expected $($e.Sectors)"}
   Write-Host "[P130 BUILD] TRD=$($e.Name) LENGTH=$length";break
  }
 }
 if (-not $found){throw "Required TR-DOS entry missing: $($e.Name)"}
}
Copy-Item -Force $Out (Join-Path $Build "disk_A.trd")
Add-BuildOutput $Out "OUTPUT-TRD"
Add-BuildOutput "build/disk_A.trd" "OUTPUT-TRD-COPY"
Write-Host "[P130 BUILD] FILE MANIFEST=build/P130_BUILD_FILES.log"
Write-Host "[P130 BUILD] DISK=$Out SIZE=$diskSize"
Write-Host "[P130 BUILD] ACTIVE HOST=PROJECT126 EXACT"
Write-Host "[P130 BUILD] BIOS FLOW=CATALOGUE ENTER -> 32 SECTORS -> DMA/IPC ABI 1.1 -> SYSBIOS PAGE10"
Write-Host "[P130 BUILD] BUILD COMPLETE (runtime test required)"){
  $text=[IO.File]::ReadAllText($full)
  foreach($m in [regex]::Matches($text,'(?im)^\\s*(INCLUDE|INCBIN)\\s+"([^"]+)"')){
   $dep=$m.Groups[2].Value
   Add-BuildFile $dep ("DEP-"+$m.Groups[1].Value.ToUpperInvariant()) $true
  }
 }
}
function Add-BuildOutput([string]$Path,[string]$Role){
 Add-BuildFile $Path $Role $false
}
