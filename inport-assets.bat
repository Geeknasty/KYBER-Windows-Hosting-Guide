@echo off
setlocal

echo.
echo ==========================================
echo   KYBER Server Asset Importer (v1.2)
echo ==========================================
echo.

:: Check if the PowerShell script exists in the same directory
if not exist "%~dp0import-assets.ps1" (
    echo ERROR: import-assets.ps1 not found!
    echo.
    echo Please make sure both files are in the same folder:
    echo   - import-assets.bat
    echo   - import-assets.ps1
    echo.
    pause
    exit /b 1
)

:: Run the PowerShell script with ExecutionPolicy Bypass
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0import-assets.ps1"

:: Capture the exit code from PowerShell
set SCRIPT_EXIT=%ERRORLEVEL%

:: Exit with the same code
exit /b %SCRIPT_EXIT%

endlocal