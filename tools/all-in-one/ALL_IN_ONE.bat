@echo off
setlocal EnableDelayedExpansion
title ALL IN ONE v2 - folder by folder: Clean Voice (UVR) + Upscale Images (Real-ESRGAN)
rem ============================================================================
rem  ALL_IN_ONE.bat  v2  -  part of Linea (https://github.com/iK4w4/Linea)
rem  Copyright (c) 2026 Kawa (@iK4w4) - MIT License
rem  ONE bat for the whole pack, FOLDER BY FOLDER:
rem  drop it into the ROOT of any extracted pack folder and double-click.
rem
rem  For EACH folder, in order:
rem     1) AUDIO  - every clip -^> vocals-only WAV, same folder/name, MP3
rem        replaced. (UVR, MDX-Net: it uses the vocal model .ckpt it
rem        finds in your UVR models folder - MODEL_PATH below pins
rem        one file. GPU on, Vocals Only on, WAV out, headless runner.)
rem     2) IMAGES - every image -^> Real-ESRGAN 4x, finished as
rem        2560px JPG quality 95 (steps down only to fit YouTube's
rem        2,000,000-byte thumbnail limit), original replaced in place.
rem        Images already 2560px or wider are skipped.
rem     3) NEXT FOLDER.
rem
rem  Why folder order is the best order:
rem   - Only ONE engine ever touches the GPU at a time; each engine fully
rem     exits (VRAM freed) before the next step. Plus a 1s cooldown between
rem     folders. No overlap, no GPU fight, no crash.
rem   - Folders finish COMPLETELY one by one: RANK 01 is 100% upload-ready
rem     while RANK 02 is still cooking. Stop it mid-run and every finished
rem     folder stays finished; re-running skips what is already done.
rem
rem  If one engine is missing on this PC, its half is skipped per folder with
rem  a clear message and the other half still runs.
rem  Requires: SETUP_CLEAN_VOICE.bat run once (audio) + the portable
rem  Real-ESRGAN folder on this PC (images).
rem ============================================================================

rem ------------------------------ settings ------------------------------------
rem  Audio:
rem  A_DELETE_SOURCE: 0 = keep the source clip after a successful clean
rem  (the safe default). Set it to 1 only if you want sources deleted.
set "A_DELETE_SOURCE=0"
set "A_USE_GPU=1"
set "A_SEGMENT_SIZE=3680"
set "A_OVERLAP_MDXC=4"
set "A_WAV_TYPE=PCM_16"
set "MODEL_PATH="
rem  Images: (I_MODEL names any model in your Real-ESRGAN models
rem  folder - the ncnn release ships several, the names say the target)
set "I_MODEL=realesrgan-x4plus"
set "I_SCALE=4"
set "I_TILE=0"
set "I_THREADS=1:2:2"
set "I_TARGET_WIDTH=2560"
set "I_QUALITY=95"
set "I_MAX_BYTES=2000000"
set "ESRGAN_PATH="
rem  GPU cooldown between folders, in seconds:
set "COOLDOWN=1"
rem ----------------------------------------------------------------------------

set "ROOT=%~dp0"
set "LOG=%ROOT%all_in_one_log.txt"
set "A_CACHE_DIR=%LOCALAPPDATA%\VideoPipeline\CleanVoice"
set "A_CACHE_FILE=%A_CACHE_DIR%\model_path.txt"
set "I_CACHE_DIR=%LOCALAPPDATA%\VideoPipeline\Upscale"
set "I_CACHE_FILE=%I_CACHE_DIR%\esrgan_path.txt"
set "I_WORK=%TEMP%\VideoPipeline_work"
set "A_DONE=0"
set "A_FAILED=0"
set "A_SKIPPED=0"
set "I_DONE=0"
set "I_FAILED=0"
set "I_SKIPPED=0"
set "AUDIO_OK="
set "IMAGES_OK="
set "F_IDX=0"
set "F_TOTAL=0"

echo ============================================================
echo  ALL IN ONE v2 - folder by folder: clean voice + upscale
echo  Pack folder: %ROOT%
echo ============================================================
echo [%date% %time%] all-in-one v2 started >> "%LOG%"

rem ============================ locate engines ================================
set "UVR_CMD="
where uvr >nul 2>&1 && set "UVR_CMD=uvr"
if not defined UVR_CMD if exist "%LOCALAPPDATA%\VideoPipeline\CleanVoice\venv\Scripts\uvr.exe" set "UVR_CMD=%LOCALAPPDATA%\VideoPipeline\CleanVoice\venv\Scripts\uvr.exe"
if defined UVR_CMD (
    call :find_model
    if defined MODEL_PATH set "AUDIO_OK=1"
)
if defined AUDIO_OK (
    echo Audio engine : %UVR_CMD%
    echo Audio model  : %MODEL_PATH%
) else (
    echo Audio engine : NOT READY - audio halves will be skipped.
    echo                ^(Run SETUP_CLEAN_VOICE.bat once, and check a vocal
    echo                 model .ckpt exists in your UVR models folder.^)
)

call :find_esrgan
if defined ESRGAN_PATH (
    for %%E in ("%ESRGAN_PATH%") do set "ESRGAN_DIR=%%~dpE"
    if exist "!ESRGAN_DIR!models\%I_MODEL%.param" set "IMAGES_OK=1"
)
if defined IMAGES_OK (
    echo Image engine : %ESRGAN_PATH%
) else (
    echo Image engine : NOT READY - image halves will be skipped.
    echo                ^(Real-ESRGAN portable folder not found, or model
    echo                 "%I_MODEL%" missing in its models folder.^)
)
echo.

if not defined AUDIO_OK if not defined IMAGES_OK (
    echo [!] Neither engine is ready - nothing to do.
    pause
    exit /b 1
)

rem ========================= folder list (snapshot) ===========================
rem Root itself first, then every subfolder (dir /s = RANK order for packs).
set "FLIST=%TEMP%\vp_allinone_folders.txt"
dir /b /s /ad "%ROOT%." > "%FLIST%" 2>nul
for /f %%C in ('type "%FLIST%" ^| find /c /v ""') do set "F_TOTAL=%%C"
set /a F_TOTAL+=1

call :now_cs
set "T0_CS=%NOW_CS%"
call :process_folder "%ROOT%"
for /f "usebackq delims=" %%D in ("%FLIST%") do call :process_folder "%%D"
del "%FLIST%" >nul 2>&1

rem ================================= summary ==================================
call :now_cs
set /a ELAPSED_CS=NOW_CS-T0_CS
if %ELAPSED_CS% LSS 0 set /a ELAPSED_CS+=8640000
set "V=%ELAPSED_CS%"
call :fmt_cs
set "TOTAL_TIME_STR=%FMT%"
echo ============================================================
echo  ALL DONE - %F_IDX% folders processed.
echo  Audio : converted %A_DONE%, failed %A_FAILED%, skipped %A_SKIPPED%
echo  Images: upscaled %I_DONE%, failed %I_FAILED%, skipped %I_SKIPPED%
echo  Time taken: %TOTAL_TIME_STR%
echo  Log: %LOG%
echo ============================================================
echo [%date% %time%] all-in-one v2 finished - audio %A_DONE%/%A_FAILED%/%A_SKIPPED%, images %I_DONE%/%I_FAILED%/%I_SKIPPED% >> "%LOG%"
pause
exit /b 0

rem ====================== subroutines: now_cs / fmt_cs =======================
rem  now_cs: sets NOW_CS = current time in centiseconds.
rem  fmt_cs: formats %V% (centiseconds) as M:SS into FMT.
:now_cs
for /f "tokens=1-4 delims=:.," %%a in ("%TIME%") do set /a NOW_CS=((%%a*60)+%%b)*6000+%%c*100+%%d
goto :eof

:fmt_cs
set /a TM=V/6000, TS=(V/100) %% 60
if %TS% LSS 10 set "TS=0%TS%"
set "FMT=%TM%:%TS%"
goto :eof

rem ========================== subroutine: process_folder ======================
rem  %~1 = one folder. Audio half first, then images half, then cooldown.
:process_folder
set "DIR=%~1"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
for %%N in ("%DIR%") do set "DNAME=%%~nxN"
if "%DNAME%"=="_uvr_tmp" goto :eof
set /a F_IDX+=1
echo ------------------------------------------------------------
echo  FOLDER !F_IDX!/%F_TOTAL% - %DNAME%
echo ------------------------------------------------------------
set "B_A_DONE=%A_DONE%"
set "B_A_FAIL=%A_FAILED%"
set "B_I_DONE=%I_DONE%"
set "B_I_FAIL=%I_FAILED%"

rem ---- audio half: clips directly in this folder ----
if defined AUDIO_OK (
    for %%F in ("%DIR%\*.mp3" "%DIR%\*.m4a" "%DIR%\*.flac" "%DIR%\*.ogg") do call :process_audio "%%F"
    set /a D_A_DONE=A_DONE-B_A_DONE
    set /a D_A_FAIL=A_FAILED-B_A_FAIL
    if !D_A_DONE! GTR 0 echo  audio in this folder: !D_A_DONE! converted
    if !D_A_FAIL! GTR 0 echo  audio in this folder: !D_A_FAIL! FAILED - see log
) else (
    echo  audio: skipped ^(engine not ready^)
)

rem ---- images half: this folder only ----
if defined IMAGES_OK (
    call :process_dir "%DIR%"
    set /a D_I_DONE=I_DONE-B_I_DONE
    set /a D_I_FAIL=I_FAILED-B_I_FAIL
    if !D_I_DONE! GTR 0 echo  images in this folder: !D_I_DONE! upscaled
    if !D_I_FAIL! GTR 0 echo  images in this folder: !D_I_FAIL! FAILED - see log
) else (
    echo  images: skipped ^(engine not ready^)
)

call :now_cs
set /a ELAPSED_CS=NOW_CS-T0_CS
if %ELAPSED_CS% LSS 0 set /a ELAPSED_CS+=8640000
set "V=%ELAPSED_CS%"
call :fmt_cs
set "ELAPSED_STR=%FMT%"
if !F_IDX! LSS %F_TOTAL% (
    set /a AVG_CS=ELAPSED_CS / F_IDX
    set /a REMAIN_CS=AVG_CS * (F_TOTAL - F_IDX)
    set "V=!REMAIN_CS!"
    call :fmt_cs
    echo  time: !ELAPSED_STR! elapsed - about !FMT! left ^(estimate^)
)
if !F_IDX! EQU %F_TOTAL% echo  time: !ELAPSED_STR! total

rem ---- GPU cooldown, then next folder ----
if %COOLDOWN% GTR 0 timeout /t %COOLDOWN% /nobreak >nul 2>&1
goto :eof

rem ============================ subroutine: find_model ========================
:find_model
if defined MODEL_PATH exit /b 0
if exist "%A_CACHE_FILE%" (
    set /p MODEL_PATH=<"%A_CACHE_FILE%"
    if defined MODEL_PATH if not exist "%MODEL_PATH%" set "MODEL_PATH="
    if defined MODEL_PATH exit /b 0
)
set "UVRD1=%LOCALAPPDATA%\Programs\Ultimate Vocal Remover\models\MDX_Net_Models"
set "UVRD2=%ProgramFiles%\Ultimate Vocal Remover\models\MDX_Net_Models"
set "UVRD3=%ProgramFiles(x86)%\Ultimate Vocal Remover\models\MDX_Net_Models"
set "UVRD4=C:\Ultimate Vocal Remover\models\MDX_Net_Models"
set "UVRD5=%USERPROFILE%\Ultimate Vocal Remover\models\MDX_Net_Models"
for %%D in ("%UVRD1%" "%UVRD2%" "%UVRD3%" "%UVRD4%" "%UVRD5%") do (
    if not defined MODEL_PATH if exist "%%~D" (
        for %%P in ("*.ckpt" "*.pth") do (
            if not defined MODEL_PATH (
                for /f "delims=" %%X in ('dir /b "%%~D\%%~P" 2^>nul') do if not defined MODEL_PATH set "MODEL_PATH=%%~D\%%X"
            )
        )
    )
)
if defined MODEL_PATH goto :cache_model
echo Hunting for a vocal model (.ckpt) across this PC - one time only...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$roots = @($env:LOCALAPPDATA, $env:APPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:USERPROFILE, 'D:\', 'E:\', 'F:\', 'G:\', 'H:\'); $f = Get-ChildItem -Path $roots -Directory -Recurse -Depth 6 -Filter 'MDX_Net_Models' -ErrorAction SilentlyContinue | ForEach-Object { Get-ChildItem $_.FullName -Filter '*.ckpt' -File -ErrorAction SilentlyContinue } | Select-Object -First 1; if ($f) { $f.FullName }" > "%TEMP%\vp_model_found.txt" 2>nul
if exist "%TEMP%\vp_model_found.txt" (
    set /p MODEL_PATH=<"%TEMP%\vp_model_found.txt"
    if defined MODEL_PATH if not exist "%MODEL_PATH%" set "MODEL_PATH="
)
if not defined MODEL_PATH exit /b 0
:cache_model
if not exist "%A_CACHE_DIR%" mkdir "%A_CACHE_DIR%" >nul 2>&1
> "%A_CACHE_FILE%" echo %MODEL_PATH%
exit /b 0

rem =========================== subroutine: find_esrgan ========================
:find_esrgan
if defined ESRGAN_PATH if exist "%ESRGAN_PATH%" exit /b 0
set "ESRGAN_PATH="
if exist "%~dp0realesrgan-ncnn-vulkan.exe" set "ESRGAN_PATH=%~dp0realesrgan-ncnn-vulkan.exe"
if defined ESRGAN_PATH goto :cache_esrgan
if exist "%I_CACHE_FILE%" (
    set /p ESRGAN_PATH=<"%I_CACHE_FILE%"
    if defined ESRGAN_PATH if not exist "%ESRGAN_PATH%" set "ESRGAN_PATH="
    if defined ESRGAN_PATH exit /b 0
)
for %%P in ("F:\Real-ESRGAN\realesrgan-ncnn-vulkan.exe" "C:\Real-ESRGAN\realesrgan-ncnn-vulkan.exe" "D:\Real-ESRGAN\realesrgan-ncnn-vulkan.exe" "E:\Real-ESRGAN\realesrgan-ncnn-vulkan.exe" "%USERPROFILE%\Real-ESRGAN\realesrgan-ncnn-vulkan.exe") do (
    if not defined ESRGAN_PATH if exist "%%~P" set "ESRGAN_PATH=%%~P"
)
if defined ESRGAN_PATH goto :cache_esrgan
echo Hunting for realesrgan-ncnn-vulkan.exe across this PC - one time only...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$roots = @('C:\', 'D:\', 'E:\', 'F:\', 'G:\', 'H:\', $env:USERPROFILE); $f = Get-ChildItem -Path $roots -Filter 'realesrgan-ncnn-vulkan.exe' -File -Recurse -Depth 4 -ErrorAction SilentlyContinue | Select-Object -First 1; if ($f) { $f.FullName }" > "%TEMP%\vp_esrgan_found.txt" 2>nul
if exist "%TEMP%\vp_esrgan_found.txt" (
    set /p ESRGAN_PATH=<"%TEMP%\vp_esrgan_found.txt"
    if defined ESRGAN_PATH if not exist "%ESRGAN_PATH%" set "ESRGAN_PATH="
)
if not defined ESRGAN_PATH exit /b 0
:cache_esrgan
if not exist "%I_CACHE_DIR%" mkdir "%I_CACHE_DIR%" >nul 2>&1
> "%I_CACHE_FILE%" echo %ESRGAN_PATH%
exit /b 0

rem ========================== subroutine: process_audio =======================
:process_audio
set "SRC=%~1"
if not exist "%SRC%" goto :eof
set "BASE=%~n1"
set "OUTWAV=%~dp1%~n1.wav"
set "TMPD=%~dp1_uvr_tmp"
if exist "%OUTWAV%" (
    echo [skip] "%BASE%" - WAV already exists
    set /a A_SKIPPED+=1
    goto :eof
)
echo [audio] "%BASE%"
if exist "%TMPD%" rd /s /q "%TMPD%"
mkdir "%TMPD%" >nul 2>&1
set "GPUFLAG=--gpu"
if "%A_USE_GPU%"=="0" set "GPUFLAG=--cpu"
"%UVR_CMD%" mdx -m "%MODEL_PATH%" -i "%SRC%" -o "%TMPD%" %GPUFLAG% --segment-size %A_SEGMENT_SIZE% --overlap-mdxc %A_OVERLAP_MDXC% --vocals-only --wav-type %A_WAV_TYPE%
set "RC=%ERRORLEVEL%"
set "VOC="
for /f "delims=" %%V in ('dir /b /s "%TMPD%\*Vocals*.wav" 2^>nul') do if not defined VOC set "VOC=%%V"
if not defined VOC (
    echo [FAIL] "%BASE%" - no vocals output produced ^(runner exit %RC%^)
    echo [%date% %time%] AUDIO FAIL "%SRC%" exit %RC% >> "%LOG%"
    set /a A_FAILED+=1
    if exist "%TMPD%" rd /s /q "%TMPD%"
    goto :eof
)
move /y "%VOC%" "%OUTWAV%" >nul
if exist "%TMPD%" rd /s /q "%TMPD%"
for %%S in ("%OUTWAV%") do set "OUTSIZE=%%~zS"
if %OUTSIZE% LSS 10240 (
    echo [FAIL] "%BASE%" - output WAV looks empty, source kept
    echo [%date% %time%] AUDIO FAIL "%SRC%" output too small >> "%LOG%"
    del "%OUTWAV%" >nul 2>&1
    set /a A_FAILED+=1
    goto :eof
)
echo [ ok ] "%BASE%.wav"
echo [%date% %time%] AUDIO OK "%SRC%" -> "%OUTWAV%" >> "%LOG%"
set /a A_DONE+=1
if "%A_DELETE_SOURCE%"=="1" del "%SRC%" >nul 2>&1
goto :eof

rem =========================== subroutine: process_dir ========================
rem  Images half for ONE folder (Real-ESRGAN folder mode + PowerShell finish).
:process_dir
set "DIR=%~1"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
set "HASIMG="
for %%X in (jpg jpeg png webp bmp) do if exist "%DIR%\*.%%X" set "HASIMG=1"
if not defined HASIMG goto :eof
if exist "%I_WORK%" rd /s /q "%I_WORK%"
mkdir "%I_WORK%\masters" >nul 2>&1
echo [images] upscaling... (quiet - engine noise goes to the log)
echo [%date% %time%] esrgan run on "%DIR%" >> "%LOG%"
"%ESRGAN_PATH%" -i "%DIR%" -o "%I_WORK%\masters" -n %I_MODEL% -s %I_SCALE% -t %I_TILE% -j %I_THREADS% -f png >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [FAIL] Real-ESRGAN errored on this folder - originals untouched.
    echo [%date% %time%] IMAGE FAIL dir "%DIR%" esrgan error >> "%LOG%"
    set /a I_FAILED+=1
    goto :eof
)
set "VP_SRC_DIR=%DIR%"
set "VP_MASTER_DIR=%I_WORK%\masters"
set "VP_TARGET_W=%I_TARGET_WIDTH%"
set "VP_Q=%I_QUALITY%"
set "VP_MAXB=%I_MAX_BYTES%"
set "VP_SCALE=%I_SCALE%"
set "VP_LOG=%LOG%"
set "VP_COUNTS=%I_WORK%\counts.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText('%~f0'); $i=$s.LastIndexOf('::POWERSHELL_BELOW'); Invoke-Expression $s.Substring($s.IndexOf([char]10, $i)+1)"
if exist "%VP_COUNTS%" (
    for /f "usebackq tokens=1,2 delims==" %%A in ("%VP_COUNTS%") do (
        if "%%A"=="DONE" set /a I_DONE+=%%B
        if "%%A"=="SKIPPED" set /a I_SKIPPED+=%%B
        if "%%A"=="FAILED" set /a I_FAILED+=%%B
    )
)
if exist "%I_WORK%" rd /s /q "%I_WORK%"
goto :eof

::POWERSHELL_BELOW
$srcDir = $env:VP_SRC_DIR
$masters = $env:VP_MASTER_DIR
$targetW = [int]$env:VP_TARGET_W
$startQ = [int]$env:VP_Q
$maxBytes = [int]$env:VP_MAXB
$scaleF = [int]$env:VP_SCALE
$logFile = $env:VP_LOG
$countsFile = $env:VP_COUNTS
$ok = 0; $skip = 0; $fail = 0
Add-Type -AssemblyName System.Drawing
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$srcExts = '.jpg', '.jpeg', '.png', '.webp', '.bmp'
Get-ChildItem $masters -File -Filter '*.png' | ForEach-Object {
    $base = $_.BaseName
    $src = $null
    foreach ($e in $srcExts) {
        $cand = Join-Path $srcDir ($base + $e)
        if (Test-Path $cand) { $src = $cand; break }
    }
    if (-not $src) { $fail++; Add-Content $logFile ("IMAGE FAIL no source match for master " + $_.Name); return }
    try {
        $img = [System.Drawing.Image]::FromFile($_.FullName)
        $srcW = [int]($img.Width / $scaleF)
        if ($srcW -ge $targetW) {
            $img.Dispose()
            $skip++
            Add-Content $logFile ("IMAGE SKIP " + $src + " - already " + $srcW + "px wide")
            Write-Host ("[skip] " + $base + " - already wide enough")
            return
        }
        $sc = $targetW / $img.Width
        if ($sc -gt 1) { $sc = 1 }
        $w = [int]($img.Width * $sc)
        $h = [int]($img.Height * $sc)
        $bmp = New-Object System.Drawing.Bitmap($w, $h)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.DrawImage($img, 0, 0, $w, $h)
        $img.Dispose()
        $out = Join-Path $srcDir ($base + '.jpg')
        $tmpOut = Join-Path $srcDir ($base + '.vp_tmp.jpg')
        $q = $startQ
        do {
            $params = New-Object System.Drawing.Imaging.EncoderParameters(1)
            $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$q)
            $bmp.Save($tmpOut, $codec, $params)
            $size = (Get-Item $tmpOut).Length
            $usedQ = $q
            $q -= 5
        } while ($size -gt $maxBytes -and $q -ge 50)
        Move-Item $tmpOut $out -Force
        if ($src -ne $out) { Remove-Item $src -Force }
        $g.Dispose(); $bmp.Dispose()
        $ok++
        Add-Content $logFile ("IMAGE OK " + $src + " -> " + $out + " " + $w + "x" + $h + " q" + $usedQ + " " + $size + "B")
        Write-Host ("[ ok ] " + $base + ".jpg - " + $w + "x" + $h + ", quality " + $usedQ + ", " + [int]($size / 1KB) + " KB")
    } catch {
        $fail++
        Add-Content $logFile ("IMAGE FAIL " + $src + " - " + $_.Exception.Message)
        Write-Host ("[FAIL] " + $base + " - " + $_.Exception.Message)
    }
}
"DONE=$ok" | Set-Content $countsFile
"SKIPPED=$skip" | Add-Content $countsFile
"FAILED=$fail" | Add-Content $countsFile
