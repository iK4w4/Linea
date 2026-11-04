@echo off
setlocal EnableDelayedExpansion
title Clean Voice - one-time setup v3 (headless UVR runner)
rem ============================================================================
rem  SETUP_CLEAN_VOICE.bat  v3  -  run this ONCE on this PC.
rem  Part of Linea (https://github.com/iK4w4/Linea)
rem  Copyright (c) 2026 Kawa (@iK4w4) - MIT License
rem
rem  Version history of pain:
rem   v1: found the bare "py" launcher on a PC with no Python -> venv failed.
rem   v2: verified a real Python, but accepted Python 3.14 - and the runner
rem       package refuses it (Requires-Python ^>=3.9,^<3.11).
rem   v3: requires Python 3.9 or 3.10 EXACTLY, installs 3.10 via winget when
rem       missing, and DELETES any old venv built on a wrong Python version.
rem
rem  Why this exists: Ultimate Vocal Remover's UVR.exe is GUI-only - it has no
rem  command line at all, so a .bat cannot drive the window. This setup installs
rem  "uvr-headless-runner": a command-line runner built to replicate UVR's GUI
rem  behavior exactly. CLEAN_VOICE_ALL.bat loads the SAME MB-Roformer-Kim model
rem  file that sits in your UVR models folder, with your exact settings
rem  (MDX-Net / segment 3680 / overlap 4 / GPU / vocals only / WAV).
rem
rem  It installs into:  %LOCALAPPDATA%\VideoPipeline\CleanVoice\venv   (UVR untouched)
rem  The GPU PyTorch download is LARGE (a few GB). On a slow connection let it
rem  run overnight - it is once only, every pack after that is one click.
rem ============================================================================

set "BASE=%LOCALAPPDATA%\VideoPipeline\CleanVoice"
set "VENV=%BASE%\venv"

echo ============================================================
echo  Clean Voice - one-time setup v3
echo  Install folder: %VENV%
echo ============================================================
echo.

rem ---------------- find Python 3.9 or 3.10 EXACTLY ---------------------------
set "PYCMD="
call :try_py "py -3.10" "Python 3.10."
if not defined PYCMD call :try_py "py -3.9" "Python 3.9."

if not defined PYCMD (
    echo Python 3.9/3.10 not found - installing Python 3.10 with winget...
    where winget >nul 2>&1
    if errorlevel 1 (
        echo.
        echo [!] winget is not available on this PC.
        echo     Install Python 3.10 from python.org, tick "Add python.exe to
        echo     PATH" during install, then run this setup again.
        echo.
        pause
        exit /b 1
    )
    winget install -e --id Python.Python.3.10 --accept-source-agreements --accept-package-agreements
    echo.
    echo Re-checking for Python 3.10...
    call :try_py "py -3.10" "Python 3.10."
)
if not defined PYCMD (
    echo.
    echo [!] Python 3.10 still not detected after the install attempt.
    echo     Close this window and run the setup again - a fresh window
    echo     usually sees the new Python. If it still fails, install
    echo     Python 3.10 from python.org with "Add python.exe to PATH".
    echo.
    pause
    exit /b 1
)
echo Python: %PYCMD%
%PYCMD% --version
echo.

rem --------------- venv: rebuild if it is on a wrong Python -------------------
if exist "%VENV%\Scripts\python.exe" (
    set "VENV_OK="
    "%VENV%\Scripts\python.exe" --version > "%TEMP%\vp_venv_check.txt" 2>&1
    findstr /c:"Python 3.10." "%TEMP%\vp_venv_check.txt" >nul 2>&1 && set "VENV_OK=1"
    findstr /c:"Python 3.9." "%TEMP%\vp_venv_check.txt" >nul 2>&1 && set "VENV_OK=1"
    if not defined VENV_OK (
        echo Old venv is on the wrong Python version - deleting it...
        rd /s /q "%VENV%"
    )
)
if not exist "%VENV%\Scripts\python.exe" (
    echo Creating virtual environment...
    %PYCMD% -m venv "%VENV%"
    if errorlevel 1 (
        echo [!] venv creation failed.
        pause
        exit /b 1
    )
)
set "VPY=%VENV%\Scripts\python.exe"

echo Upgrading pip...
"%VPY%" -m pip install --upgrade pip
echo.

rem ------------------------------- GPU or CPU ---------------------------------
echo GPU Conversion is the fast path; CPU works too, just slower.
echo  - GPU PyTorch = big one-time download (a few GB), fast conversions.
echo  - CPU PyTorch = much smaller download, slower conversions (fine for
echo    short dialogue clips, just slower).
echo.
choice /c GC /n /m "Install [G]PU or [C]PU PyTorch? "
if errorlevel 2 goto cpu_torch
if errorlevel 1 goto gpu_torch

:gpu_torch
echo Installing GPU PyTorch (CUDA 12.4) - this is the big download, be patient...
"%VPY%" -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
if errorlevel 1 (
    echo [!] GPU PyTorch install failed - falling back to CPU PyTorch.
    goto cpu_torch
)
goto runner

:cpu_torch
echo Installing CPU PyTorch...
"%VPY%" -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
if errorlevel 1 (
    echo [!] PyTorch install failed. Check your internet and run setup again.
    pause
    exit /b 1
)

:runner
echo.
echo Installing the headless UVR runner...
"%VPY%" -m pip install uvr-headless-runner
if errorlevel 1 (
    echo [!] Runner install failed. Check your internet and run setup again.
    pause
    exit /b 1
)

echo.
echo Verifying...
if exist "%VENV%\Scripts\uvr.exe" (
    "%VENV%\Scripts\uvr.exe" info
    echo.
    echo ============================================================
    echo  SETUP DONE. From now on: extract a pack, double-click
    echo  CLEAN_VOICE_ALL.bat inside it, done.
    echo ============================================================
) else (
    echo [!] uvr.exe not found after install - something went wrong above.
)
echo.
pause
exit /b 0

rem ============================ subroutine: try_py ============================
rem  %~1 = candidate command, e.g. "py -3.10".  %~2 = exact version string
rem  that MUST appear in its --version output, e.g. "Python 3.10.".
rem  Sets PYCMD only on a true match - other Pythons (3.14 etc.) are rejected.
:try_py
set "CAND=%~1"
%CAND% --version > "%TEMP%\vp_py_check.txt" 2>&1
if errorlevel 1 exit /b 1
findstr /c:"%~2" "%TEMP%\vp_py_check.txt" >nul 2>&1
if errorlevel 1 exit /b 1
set "PYCMD=%CAND%"
exit /b 0
