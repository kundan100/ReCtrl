@echo off
REM ============================================================
REM .env file parser utility
REM Usage: call "%~dp0envParser.bat" [path-to-env-file]
REM If no path provided, loads .env from project root
REM ============================================================

REM Determine .env file location
if "%~1"=="" (
    set "ENV_FILE=%~dp0..\.env"
) else (
    set "ENV_FILE=%~1"
)

REM Check if .env file exists
if not exist "%ENV_FILE%" (
    echo [ERROR] .env file not found: %ENV_FILE%
    echo Please copy .env.template to .env and configure your paths.
    exit /b 1
)

REM Parse .env file - simple version
for /f "usebackq tokens=1,* delims==" %%a in ("%ENV_FILE%") do (
    REM Skip lines starting with # (comments)
    echo %%a | findstr /b "#" >nul
    if errorlevel 1 (
        REM Not a comment, set the variable
        set "%%a=%%b"
    )
)

exit /b 0
