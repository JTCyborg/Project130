@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo PROJECT130 - Z88DK + SJASMPLUS TR-DOS BUILD
echo ============================================================
echo [BUILD] Script: tools\build_project130.ps1
echo [BUILD] Output: disk_A.trd
echo.

set "ZCC=zcc"
where zcc >nul 2>nul
if errorlevel 1 (
    if exist "C:\z88dk\bin\zcc.exe" (
        set "ZCC=C:\z88dk\bin\zcc.exe"
    ) else (
        echo [ERROR] Z88DK zcc was not found.
        echo [ERROR] Checked PATH and C:\z88dk\bin\zcc.exe.
        echo [ERROR] Set ZCC to the full path of zcc.exe or add Z88DK bin to PATH.
        goto :failed
    )
)
echo [BUILD] ZCC=%ZCC%

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

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "tools\build_project130.ps1" -Zcc "%ZCC%" -SjAsmPlus "%SJASMPLUS%"
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
echo [BUILD] RESIDENT=P130BOOT.C LOAD=#6000
echo [BUILD] Open disk_A.trd in Unreal Speccy.
echo [BUILD] Run the TR-DOS disk and capture the complete #EF trace.
echo.
pause
exit /b 0

:failed
echo.
echo [BUILD] FAILED. Do NOT run an older disk_A.trd.
echo [BUILD] Check the Z88DK and SjASMPlus output above.
echo.
pause
exit /b 1
