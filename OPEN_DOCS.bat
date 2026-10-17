@echo off
title Competition Toolkit - Docs Viewer
cd /d "%~dp0"

echo ===================================================
echo   Starting Competition Toolkit Documentation Hub...
echo ===================================================

where python >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    python server.py
) else (
    echo Python not found in PATH, opening static viewer in default browser...
    start "" "%~dp0docs_viewer\index.html"
)
pause
