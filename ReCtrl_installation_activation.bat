@echo off
REM ============================================================
REM How to run this script from different terminals:
REM 
REM CMD:        ReCtrl_installation_activation.bat
REM PowerShell: .\ReCtrl_installation_activation.bat
REM Git Bash:   ./ReCtrl_installation_activation.bat
REM             or cmd.exe //c ReCtrl_installation_activation.bat
REM ============================================================

echo Activating/Installing/Starting ReCtrl...
echo.

REM Set script path (relative to this BAT file location)
set AHK_SCRIPT=%~dp0index.ahk

REM AHK_EXE_MyCustomPath="D:\path-to\AutoHotkey64.exe"
set AHK_EXE_MyCustomPath=""
REM Auto-detect AutoHotkey installation
set AHK_EXE=

echo checking if AutoHotkey64.exe exists on your machine or not...
REM Check-1: Default Program Files installation (AHK v2)
if exist "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" (
    set AHK_EXE=C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe
    echo success Check-1
    goto :found
)

REM Check-2: Default Program Files installation (root)
if exist "C:\Program Files\AutoHotkey\AutoHotkey64.exe" (
    set AHK_EXE=C:\Program Files\AutoHotkey\AutoHotkey64.exe
    echo success Check-2
    goto :found
)

REM Check-3: User local installation
if exist "%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe" (
    set AHK_EXE=%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe
    echo success Check-3
    goto :found
)

REM Check-4: Scoop installation
if exist "%USERPROFILE%\scoop\apps\autohotkey\current\AutoHotkey64.exe" (
    set AHK_EXE=%USERPROFILE%\scoop\apps\autohotkey\current\AutoHotkey64.exe
    echo success Check-4
    goto :found
)

REM Check-5: Search in PATH
where AutoHotkey64.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    for /f "delims=" %%i in ('where AutoHotkey64.exe') do set AHK_EXE=%%i
    echo success Check-5
    goto :found
)

REM Check-6: Custom path (fallback for developer)
if exist %AHK_EXE_MyCustomPath% (
    set AHK_EXE=%AHK_EXE_MyCustomPath%
    echo success Check-6
    goto :found
)

REM Check-7: Ask user for custom path
echo.
echo AutoHotkey not found in standard locations.
echo Note: if you have custom path for AutoHotkey64.exe, update this bat file or provide here when asked.
echo.
set /p USER_AHK_PATH="Enter full path to AutoHotkey64.exe (or press Enter to exit): "

if "%USER_AHK_PATH%"=="" (
    echo Installation cancelled.
    goto :notfound
)

REM Remove quotes if user added them
set USER_AHK_PATH=%USER_AHK_PATH:"=%

if exist "%USER_AHK_PATH%" (
    set AHK_EXE=%USER_AHK_PATH%
    echo success Check-7 (User provided)
    goto :found
) else (
    echo [ERROR] Invalid path: %USER_AHK_PATH%
    goto :notfound
)

:notfound
echo.
echo [ERROR] AutoHotkey v2 not found!
echo.
echo Please install AutoHotkey v2 from one of these sources:
echo   1. Official: https://www.autohotkey.com/v2/
echo   Note: you can download AHK-V2 ZIP, if don't want to install.
echo   2. Scoop:    scoop install autohotkey
echo   3. Winget:   winget install AutoHotkey.AutoHotkey
echo.
pause
exit /b 1

:found
echo Found AutoHotkey: %AHK_EXE%
echo Running script: %AHK_SCRIPT%
echo.
exit /b 0

REM Launch ReCtrl
start "" "%AHK_EXE%" "%AHK_SCRIPT%"

echo ReCtrl activated! Check system tray for the icon.
exit /b 0
