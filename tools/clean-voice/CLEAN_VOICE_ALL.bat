@echo off
setlocal EnableDelayedExpansion
title Clean Voice - UVR batch (MB-Roformer-Kim, vocals only, WAV)
rem ============================================================================
rem  CLEAN_VOICE_ALL.bat  v2  -  part of Linea (https://github.com/iK4w4/Linea)
rem  Copyright (c) 2026 Kawa (@iK4w4) - MIT License
rem  v2: model hunt upgraded - v1 only checked 5 guessed UVR folders and
rem  missed non-standard installs. v2 falls back to a full-PC PowerShell
rem  search for the Kim model and CACHES the found path, so later runs are
rem  instant.
rem
rem  Drop this file into the ROOT of any extracted pack folder and double-click.
rem  It finds every audio clip in every subfolder, separates the voice with the
rem  SAME model + settings you use in Ultimate Vocal Remover v5.6.1:
rem     Process method : MDX-Net (Roformer)
rem     Model          : MB-Roformer-Kim  (loaded from YOUR UVR models folder)
rem     Segment size   : 3680
rem     Overlap        : 4
rem     GPU Conversion : ON
rem     Vocals Only    : ON     (no background / instrumental file is kept)
rem     Output format  : WAV, in the SAME folder as the source clip
rem  The source MP3 is deleted after a clip converts OK (that is the "replace").
rem  To keep sources instead, change DELETE_SOURCE below to 0.
rem  Requires the one-time SETUP_CLEAN_VOICE.bat (headless UVR runner).
rem ============================================================================

rem ------------------------- settings (edit if needed) ------------------------
set "DELETE_SOURCE=1"
set "USE_GPU=1"
set "SEGMENT_SIZE=3680"
set "OVERLAP_MDXC=4"
set "WAV_TYPE=PCM_16"
set "MODEL_PATH="
rem If auto-find fails, paste your model path on the line above, e.g.
rem set "MODEL_PATH=C:\Path\To\Ultimate Vocal Remover\models\MDX_Net_Models\MelBand_Roformer_Kim.ckpt"
rem ----------------------------------------------------------------------------

set "ROOT=%~dp0"
set "LOG=%ROOT%clean_voice_log.txt"
set "CACHE_DIR=%LOCALAPPDATA%\VideoPipeline\CleanVoice"
set "CACHE_FILE=%CACHE_DIR%\model_path.txt"
set "DONE=0"
set "FAILED=0"
set "SKIPPED=0"

echo ============================================================
echo  Clean Voice batch - vocals only, no background
echo  Pack folder: %ROOT%
echo ============================================================
echo [%date% %time%] batch started >> "%LOG%"

rem --------------------------- find the runner --------------------------------
set "UVR_CMD="
where uvr >nul 2>&1 && set "UVR_CMD=uvr"
if not defined UVR_CMD if exist "%LOCALAPPDATA%\VideoPipeline\CleanVoice\venv\Scripts\uvr.exe" set "UVR_CMD=%LOCALAPPDATA%\VideoPipeline\CleanVoice\venv\Scripts\uvr.exe"
if not defined UVR_CMD (
    echo.
    echo  [!] The headless UVR runner is not installed yet.
    echo      Run SETUP_CLEAN_VOICE.bat ONCE, then run this file again.
    echo.
    pause
    exit /b 1
)
echo Runner: %UVR_CMD%

rem ------------------------ find the Kim model --------------------------------
call :find_model
if not defined MODEL_PATH (
    echo.
    echo  [!] Searched the whole PC - the MB-Roformer-Kim model was not found.
    echo      Set MODEL_PATH at the top of this file to the full path of
    echo      the model file in your UVR models folder, then run again.
    echo.
    pause
    exit /b 1
)
echo Model : %MODEL_PATH%
echo.

rem ------------------------------ process clips -------------------------------
for /r "%ROOT%" %%F in (*.mp3 *.m4a *.flac *.ogg) do (
    call :process "%%F"
)

echo.
echo ============================================================
echo  Finished.  Converted: %DONE%   Failed: %FAILED%   Skipped: %SKIPPED%
echo  Log: %LOG%
echo ============================================================
echo [%date% %time%] batch finished - converted %DONE%, failed %FAILED%, skipped %SKIPPED% >> "%LOG%"
pause
exit /b 0

rem ============================ subroutine: find_model ========================
:find_model
rem 1) manual setting already given
if defined MODEL_PATH exit /b 0

rem 2) cached path from a previous successful hunt
if exist "%CACHE_FILE%" (
    set /p MODEL_PATH=<"%CACHE_FILE%"
    if defined MODEL_PATH if not exist "%MODEL_PATH%" set "MODEL_PATH="
    if defined MODEL_PATH exit /b 0
)

rem 3) the standard UVR install folders
set "UVRD1=%LOCALAPPDATA%\Programs\Ultimate Vocal Remover\models\MDX_Net_Models"
set "UVRD2=%ProgramFiles%\Ultimate Vocal Remover\models\MDX_Net_Models"
set "UVRD3=%ProgramFiles(x86)%\Ultimate Vocal Remover\models\MDX_Net_Models"
set "UVRD4=C:\Ultimate Vocal Remover\models\MDX_Net_Models"
set "UVRD5=%USERPROFILE%\Ultimate Vocal Remover\models\MDX_Net_Models"
for %%D in ("%UVRD1%" "%UVRD2%" "%UVRD3%" "%UVRD4%" "%UVRD5%") do (
    if not defined MODEL_PATH if exist "%%~D" (
        for %%P in ("MelBandRoformer.ckpt" "*MelBand*Roformer*.ckpt" "*MelBand*Kim*.ckpt" "*Roformer*Kim*.ckpt" "*Kim*.ckpt" "*Kim*.pth") do (
            if not defined MODEL_PATH (
                for /f "delims=" %%X in ('dir /b "%%~D\%%~P" 2^>nul') do if not defined MODEL_PATH set "MODEL_PATH=%%~D\%%X"
            )
        )
    )
)
if defined MODEL_PATH goto :cache_model

rem 4) full-PC PowerShell hunt (first run can take a bit - it remembers)
echo Hunting for the MB-Roformer-Kim model across this PC - one time only...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$roots = @($env:LOCALAPPDATA, $env:APPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:USERPROFILE, 'D:\', 'E:\', 'F:\', 'G:\', 'H:\'); $f = Get-ChildItem -Path $roots -Include 'MelBandRoformer.ckpt', '*MelBand*Roformer*.ckpt', '*Kim*.ckpt', '*Kim*.pth' -File -Recurse -Depth 7 -ErrorAction SilentlyContinue | Select-Object -First 1; if ($f) { $f.FullName }" > "%TEMP%\vp_model_found.txt" 2>nul
if exist "%TEMP%\vp_model_found.txt" (
    set /p MODEL_PATH=<"%TEMP%\vp_model_found.txt"
    if defined MODEL_PATH if not exist "%MODEL_PATH%" set "MODEL_PATH="
)
if not defined MODEL_PATH exit /b 0

:cache_model
if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%" >nul 2>&1
> "%CACHE_FILE%" echo %MODEL_PATH%
exit /b 0

rem =============================== subroutine =================================
:process
set "SRC=%~1"
set "DIR=%~dp1"
set "BASE=%~n1"
set "OUTWAV=%~dp1%~n1.wav"
set "TMPD=%~dp1_uvr_tmp"

if exist "%OUTWAV%" (
    echo [skip] "%BASE%" - WAV already exists
    set /a SKIPPED+=1
    goto :eof
)

echo [work] "%BASE%"
if exist "%TMPD%" rd /s /q "%TMPD%"
mkdir "%TMPD%" >nul 2>&1

set "GPUFLAG=--gpu"
if "%USE_GPU%"=="0" set "GPUFLAG=--cpu"

"%UVR_CMD%" mdx -m "%MODEL_PATH%" -i "%SRC%" -o "%TMPD%" %GPUFLAG% --segment-size %SEGMENT_SIZE% --overlap-mdxc %OVERLAP_MDXC% --vocals-only --wav-type %WAV_TYPE%
set "RC=%ERRORLEVEL%"

set "VOC="
for /f "delims=" %%V in ('dir /b /s "%TMPD%\*Vocals*.wav" 2^>nul') do if not defined VOC set "VOC=%%V"

if not defined VOC (
    echo [FAIL] "%BASE%" - no vocals output produced ^(runner exit %RC%^)
    echo [%date% %time%] FAIL "%SRC%" exit %RC% >> "%LOG%"
    set /a FAILED+=1
    if exist "%TMPD%" rd /s /q "%TMPD%"
    goto :eof
)

move /y "%VOC%" "%OUTWAV%" >nul
if exist "%TMPD%" rd /s /q "%TMPD%"

rem sanity check: a real vocals WAV for a short clip is well over 10 KB
for %%S in ("%OUTWAV%") do set "OUTSIZE=%%~zS"
if %OUTSIZE% LSS 10240 (
    echo [FAIL] "%BASE%" - output WAV looks empty, source kept
    echo [%date% %time%] FAIL "%SRC%" output too small >> "%LOG%"
    del "%OUTWAV%" >nul 2>&1
    set /a FAILED+=1
    goto :eof
)

echo [ ok ] "%BASE%.wav"
echo [%date% %time%] OK "%SRC%" -> "%OUTWAV%" >> "%LOG%"
set /a DONE+=1
if "%DELETE_SOURCE%"=="1" del "%SRC%" >nul 2>&1
goto :eof
