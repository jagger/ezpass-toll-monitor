@echo off
REM Quick launcher for EZPass Toll Monitor
REM Double-click this file to check your toll count with estimation

cd /d "%~dp0"
powershell.exe -ExecutionPolicy Bypass -File ".\check-tolls.ps1" -Estimate
pause
