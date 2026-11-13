@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo PROJECT130 - PROJECT126 ATM HOST + SJASMPLUS TR-DOS BUILD
echo ============================================================
echo [BUILD] Active host chain: Project126 exact ATM implementation
echo [BUILD] Output: disk_A.trd
echo.

if exist "tools\sjasmplus.exe" (
    set "SJASMPLUS=.\tools\sjasmplus.exe"
) else (
    where sjasmplus >nul 2>nul
    if errorlevel 1 (
        echo [ERROR] SjASMPlus was not found.
        echo [ERROR] Put sjasmplus.exe in tools\ or add it to PATH.
        goto :failed
    )
    set "SJASMPLUS=sjasmplus"
)

if not exist "tools\build_project130.ps1" (
    echo [ERROR] tools\build_project130.ps1 was not found.
    goto :failed
)

if not exist "build" mkdir "build"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "tools\build_project130.ps1" -SjAsmPlus "%SJASMPLUS%"
if errorlevel 1 goto :failed

if not exist "disk_A.trd" (
    echo [ERROR] Build script returned success but disk_A.trd is missing.
    goto :failed
)

copy /y "disk_A.trd" "build\disk_A.trd" >nul
if errorlevel 1 goto :failed

echo.
echo [BUILD] SUCCESS
echo [BUILD] IMAGE=disk_A.trd
echo [BUILD] HOST=PROJECT126 EXACT, LOAD=#6000
echo [BUILD] BIOS=SELECT FROM ATM CATALOGUE, TRANSFER TO NEOGS SYSBIOS PAGE10
echo [BUILD] Open disk_A.trd in Unreal Speccy.
echo [BUILD] Run the TR-DOS disk and capture the complete #EF trace.
echo.
pause
exit /b 0

:failed
echo.
echo [BUILD] FAILED. Do NOT run an older disk_A.trd.
echo [BUILD] Check the SjASMPlus output above.
echo.
pause
exit /b 1
