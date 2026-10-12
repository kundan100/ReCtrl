@echo off
REM ============================================================
REM How to run this script from different terminals:
REM 
REM CMD:        ReCtrl_installation_activation.bat
REM PowerShell: .\ReCtrl_installation_activation.bat
REM Git Bash:   ./ReCtrl_installation_activation.bat
REM             or cmd.exe //c ReCtrl_installation_activation.bat
REM ============================================================

REM Enable delayed expansion to properly read variables set by called scripts
setlocal enabledelayedexpansion

REM ---------- ---------- Define colors for sucess/error msg
REM ANSI escape for colored text (Windows 10+ consoles).
REM Do NOT use these chars in msg while using colors: !, (, )
for /F %%A in ('echo prompt $E^| cmd') do set "ESC=%%A"
set "colorSuccess=!ESC![92m"
set "colorError=!ESC![91m"
set "colorDefault=!ESC![0m"

REM Seconds to wait before this window closes automatically (change as needed).
set CLOSE_DELAY_SECONDS__FOR_PAUSE=5

REM ---------- ---------- start
echo Activating/Installing/Starting ReCtrl...
echo.

REM Set script path (relative to this BAT file location)
set AHK_SCRIPT=%~dp0index.ahk

REM Try to load from .env file if it exists
set AHK_EXE_MyCustomPath=
if exist "%~dp0.env" (
    echo Loading configuration from .env file...
    call "%~dp0scripts\envParser.bat"
    if not "!AHK_EXE!"=="" (
        set AHK_EXE_MyCustomPath=!AHK_EXE!
        echo !colorSuccess!Loaded AutoHotkey path from .env:!colorDefault! !AHK_EXE!
        echo.
    )
)

REM Auto-detect AutoHotkey installation
set AHK_EXE=

echo checking if AutoHotkey64.exe exists on your machine (standard paths) or not...
REM Check-1: Default Program Files installation (AHK v2)
if exist "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" (
    set AHK_EXE=C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe
    echo !colorSuccess!success Check-1!colorDefault!
    goto :found
)

REM Check-2: Default Program Files installation (root)
if exist "C:\Program Files\AutoHotkey\AutoHotkey64.exe" (
    set AHK_EXE=C:\Program Files\AutoHotkey\AutoHotkey64.exe
    echo !colorSuccess!success Check-2!colorDefault!
    goto :found
)

REM Check-3a: User local installation
if exist "%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe" (
    set AHK_EXE=%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe
    echo !colorSuccess!success Check-3a!colorDefault!
    goto :found
)
REM Check-3b: User local installation
if exist "%LocalAppData%\Programs\AutoHotkey_2.0.19\AutoHotkey64.exe" (
    set AHK_EXE=%LocalAppData%\Programs\AutoHotkey_2.0.19\AutoHotkey64.exe
    echo !colorSuccess!success Check-3b!colorDefault!
    goto :found
)

REM Check-4: Scoop installation
if exist "%USERPROFILE%\scoop\apps\autohotkey\current\AutoHotkey64.exe" (
    set AHK_EXE=%USERPROFILE%\scoop\apps\autohotkey\current\AutoHotkey64.exe
    echo !colorSuccess!success Check-4!colorDefault!
    goto :found
)

REM Check-5: Search in PATH
where AutoHotkey64.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    for /f "delims=" %%i in ('where AutoHotkey64.exe') do set AHK_EXE=%%i
    echo !colorSuccess!success Check-5!colorDefault!
    goto :found
)

REM Check-6: Use path from .env if it was loaded (developer preference)
if not "%AHK_EXE_MyCustomPath%"=="" (
    if exist "%AHK_EXE_MyCustomPath%" (
        set AHK_EXE=%AHK_EXE_MyCustomPath%
        echo !colorSuccess!success Check-6 - from .env!colorDefault!
        goto :found
    )
)

REM Check-7: Ask user for custom path
echo.
echo !colorError!AutoHotkey not found in standard locations.!colorDefault!
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
    echo !colorSuccess!success Check-7 - User provided!colorDefault!
    goto :found
) else (
    echo [ERROR] Invalid path: %USER_AHK_PATH%
    goto :notfound
)

:notfound
echo.
echo !colorError![ERROR] AutoHotkey v2 not found.!colorDefault!
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

REM Launch ReCtrl
start "" "%AHK_EXE%" "%AHK_SCRIPT%"

REM Escape "!" as ^^! so delayed expansion does not eat the reset code / rest of the line.
echo !colorSuccess!ReCtrl activated. Check system tray for the icon.!colorDefault!
call :countdown
exit /b 0

REM ---------- ---------- Generic functions ---------- ---------- ---------- ----------
REM Print a decreasing counter each second, then return (window closes via exit above).
:countdown
echo.
echo Closing in !CLOSE_DELAY_SECONDS__FOR_PAUSE! second^(s^)...
for /l %%i in (!CLOSE_DELAY_SECONDS__FOR_PAUSE!,-1,1) do (
    echo %%i
    timeout /t 1 /nobreak >nul
)
goto :eof

