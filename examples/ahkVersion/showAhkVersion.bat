@echo off
REM how to run (from ReCtrl directory)...
REM cmd terminal: examples\ahkVersion\showAhkVersion.bat

REM Load environment variables from .env
call "%~dp0..\..\scripts\envParser.bat"
if %ERRORLEVEL% NEQ 0 (
    echo Failed to load .env configuration
    pause
    exit /b 1
)

REM Run AHK file
"%AHK_EXE%" "%~dp0showAhkVersion.ahk"
