@echo off
setlocal
title Real-CUGAN Studio - photos + videos, every model, one bat
cd /d "%~dp0"

:: ==================== SETTINGS ====================
:: Photo output: JPG width, JPEG quality, max bytes (YouTube limit 2 MB)
set "JPG_W=2560"
set "JPG_Q=95"
set "JPG_MAX=2000000"
:: Video output quality (lower = better): NVENC CQ / x264-x265 CRF
set "CQ=18"
:: Upscaler tile size (bigger = faster on a strong GPU; 0 = auto, 256 = safe fallback)
set "TILE=512"
:: Upscaler threads (load:process:save)
set "THREADS=4:2:4"
:: Videos with more frames than this ask before starting
set "MAXFRAMES=6000"
:: ==================================================

echo ============================================================
echo   REAL-CUGAN STUDIO
echo   One bat for photos and videos - all models, all settings
echo ============================================================
echo.
set "LOGF=%~dp0REALCUGAN.log"
:: ---------- self-check: this file must be complete ----------
findstr /l /c:"Invoke-Expression" "%~f0" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] This .bat file looks damaged or incomplete.
    echo Download a fresh copy of this file and try again.
    echo.
    pause
    exit /b 1
)
if not exist "realcugan-ncnn-vulkan.exe" (
    echo [ERROR] realcugan-ncnn-vulkan.exe not found.
    echo Put this .bat file in the Real-CUGAN folder, next to the exe.
    echo.
    pause
    exit /b 1
)

:: ---------- find ffmpeg + ffprobe ----------
set "FF="
set "FP="
for %%D in ("%~dp0" "%LOCALAPPDATA%\VideoPipeline\MakeVideo" "%LOCALAPPDATA%\Microsoft\WinGet\Links") do (
    if not defined FF if exist "%%~D\ffmpeg.exe" (
        set "FF=%%~D\ffmpeg.exe"
        set "FP=%%~D\ffprobe.exe"
    )
)
if not defined FF (
    ffmpeg -version >nul 2>&1
    if not errorlevel 1 (
        set "FF=ffmpeg"
        set "FP=ffprobe"
    )
)
if not defined FF (
    echo [ERROR] ffmpeg not found - not next to this bat, not in the
    echo MakeVideo cache folder, not on PATH. Install ffmpeg, then retry.
    echo.
    pause
    exit /b 1
)
if not exist "%FP%" if not "%FP%"=="ffprobe" set "FP="
"%FF%" -version > "%TEMP%\vp_ffver.txt" 2>&1
set "FFVTOK="
for /f "usebackq tokens=3" %%V in ("%TEMP%\vp_ffver.txt") do if not defined FFVTOK set "FFVTOK=%%V"
if not defined FFVTOK set "FFVTOK=ready"

:: ---------- encoder probes (done once) ----------
set "GPUHEVC=OFF"
"%FF%" -v error -f lavfi -i testsrc=duration=0.1:size=256x256:rate=1 -c:v hevc_nvenc -f null - >nul 2>&1
if not errorlevel 1 set "GPUHEVC=OK"
set "GPUH264=OFF"
"%FF%" -v error -f lavfi -i testsrc=duration=0.1:size=256x256:rate=1 -c:v h264_nvenc -f null - >nul 2>&1
if not errorlevel 1 set "GPUH264=OK"
set "GPULINE=CPU only"
if "%GPUHEVC%"=="OK" if "%GPUH264%"=="OK" set "GPULINE=HEVC ready  -  H.264 ready"
if "%GPUHEVC%"=="OK" if not "%GPUH264%"=="OK" set "GPULINE=HEVC ready  -  H.264 on CPU"
if not "%GPUHEVC%"=="OK" if "%GPUH264%"=="OK" set "GPULINE=HEVC on CPU  -  H.264 ready"

:: ---------- which model sets are installed ----------
set "HASPRO=NO"
if exist "models\models-pro\" set "HASPRO=YES"
set "HASSE=NO"
if exist "models\models-se\" set "HASSE=YES"
set "HASNOSE=NO"
if exist "models\models-nose\" set "HASNOSE=YES"
set "MSP=no"
if "%HASPRO%"=="YES" set "MSP=yes"
set "MSS=no"
if "%HASSE%"=="YES" set "MSS=yes"
set "MSN=no"
if "%HASNOSE%"=="YES" set "MSN=yes"
if not exist "import" mkdir "import"
if not exist "export" mkdir "export"

echo   SYSTEM CHECK
echo   ----------------------------------------------------------
echo   ffmpeg ....... %FFVTOK%
echo   GPU encode ... %GPULINE%
echo   Model sets ... pro %MSP%  -  se %MSS%  -  nose %MSN%

:: ---------- progress monitor preflight ----------
set "MV_TASK="
set "MV_SELFTEST=1"
call :psrun
set "MV_SELFTEST="
if errorlevel 1 (
    echo [ERROR] The progress monitor ^(PowerShell^) could not start.
    echo See the Troubleshooting section of the README.
    echo.
    pause
    exit /b 1
)
echo.

:: ---------- close a leftover upscaler from a cancelled run ----------
:: (if a run was cancelled by closing the window, the engine can keep
::  running invisibly and eat the CPU/GPU - the next run crawls)
tasklist /FI "IMAGENAME eq realcugan-ncnn-vulkan.exe" 2>nul | find /I "realcugan-ncnn-vulkan.exe" >nul
if not errorlevel 1 (
    echo   Found a leftover upscaler from an earlier run - closing it so it
    echo   does not slow this run down.
    taskkill /IM "realcugan-ncnn-vulkan.exe" /F >nul 2>&1
    echo.
)

:: ---------- dropped files? classify and go ----------
if "%~1"=="" goto :mainmenu
set "EXT=%~x1"
set "ARGMODE="
if /i "%EXT%"==".mp4" set "ARGMODE=video"
if /i "%EXT%"==".mkv" set "ARGMODE=video"
if /i "%EXT%"==".webm" set "ARGMODE=video"
if /i "%EXT%"==".mov" set "ARGMODE=video"
if /i "%EXT%"==".avi" set "ARGMODE=video"
if /i "%EXT%"==".m4v" set "ARGMODE=video"
if /i "%EXT%"==".ts" set "ARGMODE=video"
if /i "%EXT%"==".jpg" set "ARGMODE=photo"
if /i "%EXT%"==".jpeg" set "ARGMODE=photo"
if /i "%EXT%"==".png" set "ARGMODE=photo"
if /i "%EXT%"==".webp" set "ARGMODE=photo"
if /i "%EXT%"==".bmp" set "ARGMODE=photo"
if not defined ARGMODE (
    echo I cannot tell what "%~nx1" is - starting the menu instead.
    echo.
    goto :mainmenu
)
if "%ARGMODE%"=="video" goto :args_video
goto :args_photo

:args_photo
set "KIND=PHOTOS"
set "SRCMODE=args"
goto :menu_set
:args_video
set "KIND=VIDEOS"
set "SRCMODE=args"
goto :menu_set

:: ================= MAIN MENU =================
:mainmenu
if not defined MENUSEEN (
    cls
    set "MENUSEEN=1"
)
echo ============================================================
echo   REAL-CUGAN STUDIO
echo ============================================================
echo.
if defined LASTJOB echo   %LASTJOB%
if defined LASTJOB echo.
echo   What do you want to upscale?
echo.
echo   [1]  PHOTOS    Screenshots and images   -^>  JPG in export
echo   [2]  VIDEOS    Clips and videos         -^>  MP4 in export
echo.
echo   [0]  Quit
echo.
set "C="
set /p "C=  Enter number: "
if "%C%"=="1" goto :mm_photo
if "%C%"=="2" goto :mm_video
if "%C%"=="0" exit /b 0
echo Please type 1, 2 or 0.
goto :mainmenu

:mm_photo
set "KIND=PHOTOS"
set "SRCMODE=import"
goto :menu_set
:mm_video
set "KIND=VIDEOS"
set "SRCMODE=import"
goto :menu_set

:: ================= MODEL SET =================
:menu_set
cls
echo ============================================================
echo   REAL-CUGAN STUDIO
echo   %KIND%  ^>  Model set
echo ============================================================
echo.
set "CNT=0"
set "NUM_PRO="
set "NUM_SE="
set "NUM_NOSE="
if "%HASPRO%"=="NO" goto :ms_pro_done
set /a CNT+=1
set "NUM_PRO=%CNT%"
echo   [%CNT%]  models-pro     Best quality for illustrations and anime
:ms_pro_done
if "%HASSE%"=="NO" goto :ms_se_done
set /a CNT+=1
set "NUM_SE=%CNT%"
echo   [%CNT%]  models-se      All-rounder - only set with denoise 1 and 2, and 4x
:ms_se_done
if "%HASNOSE%"=="NO" goto :ms_nose_done
set /a CNT+=1
set "NUM_NOSE=%CNT%"
echo   [%CNT%]  models-nose    No-denoise only, 2x - for pristine sources
:ms_nose_done
echo.
echo   (pro and se run at the SAME speed - pick by quality, not speed)
echo.
echo   [0]  Back to main menu
echo.
set "C="
set /p "C=  Enter number: "
if "%C%"=="0" goto :mainmenu
if defined NUM_PRO if "%C%"=="%NUM_PRO%" goto :set_pro
if defined NUM_SE if "%C%"=="%NUM_SE%" goto :set_se
if defined NUM_NOSE if "%C%"=="%NUM_NOSE%" goto :set_nose
echo Please pick one of the listed numbers.
goto :menu_set

:set_pro
if "%HASPRO%"=="NO" (
    echo models-pro is not installed in the models folder.
    goto :menu_set
)
set "MSET=models-pro"
set "SETTAG=PRO"
goto :menu_scale
:set_se
if "%HASSE%"=="NO" (
    echo models-se is not installed in the models folder.
    goto :menu_set
)
set "MSET=models-se"
set "SETTAG=SE"
goto :menu_scale
:set_nose
if "%HASNOSE%"=="NO" (
    echo models-nose is not installed in the models folder.
    goto :menu_set
)
set "MSET=models-nose"
set "SETTAG=NOSE"
goto :menu_scale

:: ================= SCALE =================
:menu_scale
cls
echo ============================================================
echo   REAL-CUGAN STUDIO
echo   %KIND%  ^>  %MSET%  ^>  Scale
echo ============================================================
echo.
set "CNT=0"
set "NUM_S2="
set "NUM_S3="
set "NUM_S4="
call :hasscale 2
if not defined SC_OK goto :msc_2_done
set /a CNT+=1
set "NUM_S2=%CNT%"
echo   [%CNT%]  2x    Double size - the sweet spot, fastest
:msc_2_done
call :hasscale 3
if not defined SC_OK goto :msc_3_done
set /a CNT+=1
set "NUM_S3=%CNT%"
echo   [%CNT%]  3x    Triple size - slower, for when you want it BIG
:msc_3_done
call :hasscale 4
if not defined SC_OK goto :msc_4_done
set /a CNT+=1
set "NUM_S4=%CNT%"
echo   [%CNT%]  4x    Quadruple size - slowest (models-se only)
:msc_4_done
echo.
echo   [0]  Back
echo.
set "C="
set /p "C=  Enter number: "
if "%C%"=="0" goto :menu_set
if defined NUM_S2 if "%C%"=="%NUM_S2%" goto :scale_2
if defined NUM_S3 if "%C%"=="%NUM_S3%" goto :scale_3
if defined NUM_S4 if "%C%"=="%NUM_S4%" goto :scale_4
echo Please pick one of the listed numbers.
goto :menu_scale

:scale_2
call :hasscale 2
if not defined SC_OK (
    echo 2x is not available for %MSET% - no 2x model files installed.
    goto :menu_scale
)
set "SCALE=2"
goto :menu_denoise
:scale_3
call :hasscale 3
if not defined SC_OK (
    echo 3x is not available for %MSET% - no 3x model files installed.
    goto :menu_scale
)
set "SCALE=3"
goto :menu_denoise
:scale_4
call :hasscale 4
if not defined SC_OK (
    echo 4x is not available for %MSET% - no 4x model files installed.
    goto :menu_scale
)
set "SCALE=4"
goto :menu_denoise

:hasscale
set "SC_OK="
if exist "models\%MSET%\up%~1x-conservative.param" set "SC_OK=1"
if exist "models\%MSET%\up%~1x-no-denoise.param" set "SC_OK=1"
if exist "models\%MSET%\up%~1x-denoise1x.param" set "SC_OK=1"
if exist "models\%MSET%\up%~1x-denoise2x.param" set "SC_OK=1"
if exist "models\%MSET%\up%~1x-denoise3x.param" set "SC_OK=1"
goto :eof

:: ================= DENOISE =================
:menu_denoise
cls
echo ============================================================
echo   REAL-CUGAN STUDIO
echo   %KIND%  ^>  %MSET%  ^>  %SCALE%x  ^>  Denoise
echo ============================================================
echo.
echo   Same speed at every level - pick by how dirty the SOURCE is:
echo.
set "CNT=0"
set "NUM_Dm1="
set "NUM_D0="
set "NUM_D1="
set "NUM_D2="
set "NUM_D3="
if not exist "models\%MSET%\up%SCALE%x-conservative.param" goto :md_m1_done
set /a CNT+=1
set "NUM_Dm1=%CNT%"
echo   [%CNT%]  -1   Conservative  - gentle cleaning, keeps the most detail
:md_m1_done
if not exist "models\%MSET%\up%SCALE%x-no-denoise.param" goto :md_0_done
set /a CNT+=1
set "NUM_D0=%CNT%"
echo   [%CNT%]  0    None          - untouched, for pristine sources
:md_0_done
if not exist "models\%MSET%\up%SCALE%x-denoise1x.param" goto :md_1_done
set /a CNT+=1
set "NUM_D1=%CNT%"
echo   [%CNT%]  1    Light         - a little compression cleanup
:md_1_done
if not exist "models\%MSET%\up%SCALE%x-denoise2x.param" goto :md_2_done
set /a CNT+=1
set "NUM_D2=%CNT%"
echo   [%CNT%]  2    Medium        - solid cleaning for normal episode frames
:md_2_done
if not exist "models\%MSET%\up%SCALE%x-denoise3x.param" goto :md_3_done
set /a CNT+=1
set "NUM_D3=%CNT%"
echo   [%CNT%]  3    Strongest     - for noisy, blocky, low-quality sources
:md_3_done
echo.
echo   [0]  Back
echo.
set "C="
set /p "C=  Enter number: "
if "%C%"=="0" goto :menu_scale
if defined NUM_Dm1 if "%C%"=="%NUM_Dm1%" goto :dn_m1
if defined NUM_D0 if "%C%"=="%NUM_D0%" goto :dn_0
if defined NUM_D1 if "%C%"=="%NUM_D1%" goto :dn_1
if defined NUM_D2 if "%C%"=="%NUM_D2%" goto :dn_2
if defined NUM_D3 if "%C%"=="%NUM_D3%" goto :dn_3
echo Please pick one of the listed numbers.
goto :menu_denoise

:dn_m1
set "NOISE=-1"
set "VARIANT=conservative"
if not exist "models\%MSET%\up%SCALE%x-conservative.param" (
    echo Denoise -1 is not available for %MSET% %SCALE%x - file not installed.
    goto :menu_denoise
)
goto :after_denoise
:dn_0
set "NOISE=0"
set "VARIANT=no-denoise"
if not exist "models\%MSET%\up%SCALE%x-no-denoise.param" (
    echo Denoise 0 is not available for %MSET% %SCALE%x - file not installed.
    goto :menu_denoise
)
goto :after_denoise
:dn_1
set "NOISE=1"
set "VARIANT=denoise1x"
if not exist "models\%MSET%\up%SCALE%x-denoise1x.param" (
    echo Denoise 1 is not available for %MSET% %SCALE%x - file not installed.
    goto :menu_denoise
)
goto :after_denoise
:dn_2
set "NOISE=2"
set "VARIANT=denoise2x"
if not exist "models\%MSET%\up%SCALE%x-denoise2x.param" (
    echo Denoise 2 is not available for %MSET% %SCALE%x - file not installed.
    goto :menu_denoise
)
goto :after_denoise
:dn_3
set "NOISE=3"
set "VARIANT=denoise3x"
if not exist "models\%MSET%\up%SCALE%x-denoise3x.param" (
    echo Denoise 3 is not available for %MSET% %SCALE%x - file not installed.
    goto :menu_denoise
)
goto :after_denoise

:after_denoise
set "TAG=_CUGAN_%SETTAG%_%SCALE%x_DN%NOISE%"
if "%KIND%"=="VIDEOS" goto :menu_codec
goto :confirm

:: ================= VIDEO ENCODER =================
:menu_codec
cls
echo ============================================================
echo   REAL-CUGAN STUDIO
echo   VIDEOS  ^>  %MSET%  ^>  %SCALE%x  ^>  Denoise %NOISE%  ^>  Encoder
echo ============================================================
echo.
echo   [1]  HEVC (H.265)    Best quality per MB, smaller files (recommended)
echo   [2]  H.264           The classic - plays on everything, bigger files
echo.
echo   [0]  Back
echo.
set "C="
set /p "C=  Enter number: "
if "%C%"=="1" goto :codec_hevc
if "%C%"=="2" goto :codec_h264
if "%C%"=="0" goto :menu_denoise
echo Please pick 1 or 2.
goto :menu_codec

:codec_hevc
set "CODEC=hevc"
set "CODECTAG=HEVC"
goto :confirm
:codec_h264
set "CODEC=h264"
set "CODECTAG=H.264"
goto :confirm

:: ================= CONFIRM =================
:confirm
cls
echo ============================================================
echo   REAL-CUGAN STUDIO
echo   %KIND%  ^>  %MSET%  ^>  %SCALE%x  ^>  Denoise %NOISE%  ^>  Check
echo ============================================================
echo.
echo   Type ....... %KIND%  (source: %SRCMODE%)
echo   Model ...... %MSET%
echo   Scale ...... %SCALE%x
echo   Denoise .... %NOISE%  (%VARIANT%)
echo   Engine ..... tile %TILE%  -  threads %THREADS%
if "%KIND%"=="VIDEOS" echo   Encoder .... %CODECTAG%  -  quality %CQ%, GPU when possible
if "%KIND%"=="VIDEOS" echo   Output ..... MP4 in export - original frame rate, ALL audio tracks
if "%KIND%"=="PHOTOS" echo   Output ..... JPG in export - %JPG_W%px wide, quality %JPG_Q%, under 2 MB
echo   File tag ... %TAG%
if "%KIND%"=="PHOTOS" echo   Example .... myphoto%TAG%.jpg
if "%KIND%"=="VIDEOS" echo   Example .... myclip%TAG%.mp4
echo.
set "C="
set /p "C=  Press Enter to START, or type 0 to go back: "
if "%C%"=="0" goto :confirm_back
if not "%C%"=="" goto :confirm
if "%KIND%"=="VIDEOS" goto :run_video
goto :run_photo

:confirm_back
if "%KIND%"=="VIDEOS" goto :menu_codec
goto :menu_denoise

:: ================= RUN: PHOTOS =================
:run_photo
set "MV_TASK="
cls
echo ============================================================
echo   WORKING - PHOTOS
echo   %MSET%  -  %SCALE%x  -  denoise %NOISE%
echo ============================================================
echo.
set "WORKP=%~dp0photo_work"
if exist "%WORKP%" rd /s /q "%WORKP%"
mkdir "%WORKP%\in" "%WORKP%\masters"
set PC=0
if "%SRCMODE%"=="args" goto :stage_args
for %%F in ("import\*.jpg" "import\*.jpeg" "import\*.png" "import\*.webp" "import\*.bmp") do (
    copy /y "%%F" "%WORKP%\in\" >nul
    set /a PC+=1
)
goto :staged
:stage_args
if "%~1"=="" goto :staged
if exist "%~1\" (
    for %%F in ("%~1\*.jpg" "%~1\*.jpeg" "%~1\*.png" "%~1\*.webp" "%~1\*.bmp") do (
        copy /y "%%F" "%WORKP%\in\" >nul
        set /a PC+=1
    )
) else (
    copy /y "%~1" "%WORKP%\in\" >nul
    set /a PC+=1
)
shift
goto :stage_args
:staged
if %PC%==0 (
    echo No photos found to upscale.
    rd /s /q "%WORKP%"
    pause
    goto :mainmenu
)
echo.
echo Upscaling %PC% photo(s): %MSET% %SCALE%x, denoise %NOISE% ...
set "MV_MODE=count"
set "MV_DIR=%WORKP%\masters"
set "MV_TOTAL=%PC%"
set "MV_FILE="
set "MV_CMD=realcugan-ncnn-vulkan.exe"
set "MV_ARGS=-i "%WORKP%\in" -o "%WORKP%\masters" -m "models\%MSET%" -s %SCALE% -n %NOISE% -t %TILE% -j %THREADS% -f png"
set "MV_ERR=%WORKP%\photo_error.txt"
call :psrun
if errorlevel 99 goto :photo_cancelled
set "MONFAIL="
if errorlevel 1 set "MONFAIL=1"
set MC=0
for %%F in ("%WORKP%\masters\*.png") do set /a MC+=1
if %MC%==0 goto :photo_efail
if defined MONFAIL if %MC% LSS %PC% goto :photo_efail
if defined MONFAIL echo       note: monitor flagged a problem, but the upscaled frames are all here.
echo Converting to JPG (%JPG_W%px, quality %JPG_Q%, under 2 MB, tagged %TAG%) ...
set "MV_TASK=resize"
set "MV_R_SRC=%WORKP%\masters"
set "MV_R_DST=%~dp0export"
set "MV_R_W=%JPG_W%"
set "MV_R_Q=%JPG_Q%"
set "MV_R_MAX=%JPG_MAX%"
set "MV_R_SUFFIX=%TAG%"
call :psrun
set "MV_TASK="
if errorlevel 1 (
    echo [WARNING] The JPG conversion failed - the big upscaled PNGs are
    echo KEPT in photo_work\masters so the upscale work is not lost.
    >>"%LOGF%" echo %DATE% %TIME%  PHOTO-RESIZE-FAILED  %MSET% %SCALE%x DN%NOISE% x%PC%
    set "LASTJOB=Last job: PHOTOS - JPG conversion failed; upscaled PNGs kept in photo_work\masters"
    pause
    goto :mainmenu
)
rd /s /q "%WORKP%"
>>"%LOGF%" echo %DATE% %TIME%  PHOTOS OK  %MSET% %SCALE%x DN%NOISE%  %PC% file(s) -^> export
set "LASTJOB=Last job: PHOTOS done - %PC% JPG(s) in export (%MSET%, %SCALE%x, denoise %NOISE%)"
echo.
echo [ ok ] Done - %PC% JPG(s) in the export folder, tagged %TAG%.
echo.
goto :mainmenu

:photo_cancelled
echo [CANCELLED] Deleting the photo work folder ...
rd /s /q "%WORKP%"
>>"%LOGF%" echo %DATE% %TIME%  PHOTOS CANCELLED  %MSET% %SCALE%x DN%NOISE%
set "LASTJOB=Last job: PHOTOS cancelled - everything cleaned up"
goto :mainmenu
:photo_efail
echo [ERROR] The photo upscale failed.
if exist "%WORKP%\photo_error.txt" (
    echo --- the tool reported: ---
    type "%WORKP%\photo_error.txt"
    echo --------------------------
)
echo Deleting the photo work folder ...
rd /s /q "%WORKP%"
>>"%LOGF%" echo %DATE% %TIME%  PHOTOS FAILED  %MSET% %SCALE%x DN%NOISE%
set "LASTJOB=Last job: PHOTOS failed - details in REALCUGAN.log"
pause
goto :mainmenu

:: ================= RUN: VIDEOS =================
:run_video
set "MV_TASK="
set "STOPALL="
cls
echo ============================================================
echo   WORKING - VIDEOS
echo   %MSET%  -  %SCALE%x  -  denoise %NOISE%  -  %CODECTAG%
echo ============================================================
echo.
if "%SRCMODE%"=="args" goto :video_args
set VCOUNT=0
for %%V in ("import\*.mp4" "import\*.mkv" "import\*.webm" "import\*.mov" "import\*.avi" "import\*.m4v" "import\*.ts") do set /a VCOUNT+=1
if %VCOUNT%==0 (
    echo The import folder has no videos in it.
    echo.
    pause
    goto :mainmenu
)
echo Found %VCOUNT% video(s) in import.
echo.
for %%V in ("import\*.mp4" "import\*.mkv" "import\*.webm" "import\*.mov" "import\*.avi" "import\*.m4v" "import\*.ts") do call :process_video "%%~fV"
goto :video_done
:video_args
if "%~1"=="" goto :video_done
call :process_video "%~1"
shift
goto :video_args
:video_done
set "LASTJOB=Last job: VIDEOS finished - results in export (details in REALCUGAN.log)"
echo.
echo ============================================================
echo   VIDEO JOB DONE - results are in the export folder.
echo ============================================================
echo.
goto :mainmenu

:: ================= process one video =================
:process_video
if defined STOPALL goto :eof
set "IN=%~1"
set "WORK=%~dp0video_work\%~n1"
set "OUT=%~dp0export\%~n1%TAG%.mp4"
echo ----------------------------------------
echo Video: %~nx1
if exist "%OUT%" (
    echo [skip] Already in export: %~n1%TAG%.mp4
    echo        Delete it from export if you want a redo.
    goto :eof
)
if exist "%WORK%" rd /s /q "%WORK%"
mkdir "%WORK%\frames" "%WORK%\up"
set "MV_ERR=%WORK%\mv_error.txt"

:: probe frame rate (fraction like 24000/1001 goes straight to ffmpeg)
"%FP%" -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0 "%IN%" > "%WORK%\fps.txt" 2>nul
set /p FPS=<"%WORK%\fps.txt"
if not defined FPS set "FPS=24"
if "%FPS%"=="0/0" set "FPS=24"
:: probe EVERY audio track - dual-audio files (JP+EN) keep ALL tracks
"%FP%" -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 "%IN%" > "%WORK%\acodec.txt" 2>nul
set ATRACKS=0
set "ABAD="
for /f "usebackq" %%C in ("%WORK%\acodec.txt") do (
    set /a ATRACKS+=1
    if /i not "%%C"=="aac" if /i not "%%C"=="mp3" if /i not "%%C"=="alac" if /i not "%%C"=="ac3" set "ABAD=1"
)
:: total frame count for the progress bar (some files do not carry it)
"%FP%" -v error -select_streams v:0 -show_entries stream=nb_frames -of csv=p=0 "%IN%" > "%WORK%\total.txt" 2>nul
set "TOTAL=0"
set /p TOTAL=<"%WORK%\total.txt"
echo %TOTAL%| findstr /r "^[0-9][0-9]*$" >nul || set "TOTAL=0"
echo Frame rate: %FPS%    Audio tracks found: %ATRACKS%
if %ATRACKS% GTR 0 type "%WORK%\acodec.txt"

echo [1/3] Extracting frames ...
set "MV_MODE=count"
set "MV_DIR=%WORK%\frames"
set "MV_TOTAL=%TOTAL%"
set "MV_FILE="
set "MV_CMD=%FF%"
set "MV_ARGS=-v error -i "%IN%" -fps_mode passthrough "%WORK%\frames\%%06d.png""
call :psrun
if errorlevel 99 goto :vcancelled
set "MONFAIL="
if errorlevel 1 set "MONFAIL=1"
set N=0
for %%F in ("%WORK%\frames\*.png") do set /a N+=1
if %N%==0 goto :vfail
if defined MONFAIL if %TOTAL%==0 goto :vfail
set /a NEED=%TOTAL%-2
if defined MONFAIL if %N% LSS %NEED% goto :vfail
if defined MONFAIL echo       note: extractor stopped at %N% of %TOTAL% frames (file tail) - continuing with %N%.
if %N% GTR %MAXFRAMES% (
    echo.
    echo [WARNING] %N% frames at %SCALE%x is a LOT - hours of GPU time and
    echo           a mountain of PNG frames while it works.
    set "GO="
    set /p "GO=Type Y to continue with this one, anything else skips it: "
    if /i not "%GO%"=="Y" (
        echo Skipped - deleting the extracted frames ...
        rd /s /q "%WORK%"
        goto :eof
    )
)

echo [2/3] Upscaling frames with Real-CUGAN (GPU, the slow part) ...
set "MV_MODE=count"
set "MV_DIR=%WORK%\up"
set "MV_TOTAL=%N%"
set "MV_FILE="
set "MV_CMD=realcugan-ncnn-vulkan.exe"
set "MV_ARGS=-i "%WORK%\frames" -o "%WORK%\up" -m "models\%MSET%" -s %SCALE% -n %NOISE% -t %TILE% -j %THREADS% -f png"
call :psrun
if errorlevel 99 goto :vcancelled
set "MONFAIL="
if errorlevel 1 set "MONFAIL=1"
set M=0
for %%F in ("%WORK%\up\*.png") do set /a M+=1
if %M% LSS %N% goto :vfail
if defined MONFAIL echo       note: monitor flagged a problem, but all %M% frames are upscaled - continuing.

echo [3/3] Stitching the MP4 (%CODECTAG%) ...
if "%CODEC%"=="hevc" goto :venc_hevc
if "%GPUH264%"=="OK" goto :venc_h264_gpu
set "VENC=-c:v libx264 -preset slow -crf %CQ%"
echo       encoder: CPU (libx264)
goto :venc_done
:venc_h264_gpu
set "VENC=-c:v h264_nvenc -preset p7 -cq %CQ% -b:v 0"
echo       encoder: GPU (h264_nvenc)
goto :venc_done
:venc_hevc
if "%GPUHEVC%"=="OK" goto :venc_hevc_gpu
set "VENC=-c:v libx265 -preset medium -crf %CQ% -tag:v hvc1"
echo       encoder: CPU (libx265)
goto :venc_done
:venc_hevc_gpu
set "VENC=-c:v hevc_nvenc -preset p7 -cq %CQ% -b:v 0 -tag:v hvc1"
echo       encoder: GPU (hevc_nvenc)
:venc_done
set "MV_MODE=elapsed"
set "MV_DIR="
set "MV_TOTAL=0"
set "MV_FILE=%OUT%"
set "MV_CMD=%FF%"
if %ATRACKS%==0 goto :stitch_noaudio
if defined ABAD goto :stitch_aac
set "MV_ARGS=-y -v error -framerate %FPS% -i "%WORK%\up\%%06d.png" -i "%IN%" -map 0:v:0 -map 1:a %VENC% -c:a copy -pix_fmt yuv420p -movflags +faststart "%OUT%""
call :psrun
if errorlevel 99 goto :vcancelled
if not errorlevel 1 goto :vpok
call :outcheck
if errorlevel 1 goto :vfail
goto :vpok
:stitch_aac
set "MV_ARGS=-y -v error -framerate %FPS% -i "%WORK%\up\%%06d.png" -i "%IN%" -map 0:v:0 -map 1:a %VENC% -c:a aac -b:a 192k -pix_fmt yuv420p -movflags +faststart "%OUT%""
call :psrun
if errorlevel 99 goto :vcancelled
if not errorlevel 1 goto :vpok
call :outcheck
if errorlevel 1 goto :vfail
goto :vpok
:stitch_noaudio
set "MV_ARGS=-y -v error -framerate %FPS% -i "%WORK%\up\%%06d.png" %VENC% -pix_fmt yuv420p -movflags +faststart "%OUT%""
call :psrun
if errorlevel 99 goto :vcancelled
if not errorlevel 1 goto :vpok
call :outcheck
if errorlevel 1 goto :vfail
goto :vpok

:vpok
>>"%LOGF%" echo %DATE% %TIME%  VIDEO OK  %OUT%
echo [ ok ] export\%~n1%TAG%.mp4
rd /s /q "%WORK%"
goto :eof

:vfail
echo [ERROR] Something failed on: %~nx1
if exist "%WORK%\mv_error.txt" (
    echo --- the tool reported: ---
    type "%WORK%\mv_error.txt"
    echo --------------------------
)
echo Deleting everything this run created ...
if exist "%OUT%" del /f /q "%OUT%"
if exist "%WORK%" rd /s /q "%WORK%"
echo Cleaned - no frames or partial files left behind.
>>"%LOGF%" echo %DATE% %TIME%  VIDEO FAILED  %~nx1
echo.
pause
goto :eof

:vcancelled
set "STOPALL=1"
echo.
echo [CANCELLED] Deleting everything this run created for: %~nx1
if exist "%OUT%" del /f /q "%OUT%"
if exist "%WORK%" rd /s /q "%WORK%"
echo Cleaned - frames, upscaled frames and any partial MP4 are gone.
echo Any remaining videos will be skipped.
>>"%LOGF%" echo %DATE% %TIME%  VIDEO CANCELLED  %~nx1
pause
goto :eof

:outcheck
"%FP%" -v error -show_entries format=duration -of csv=p=0 "%OUT%" > "%WORK%\dur.txt" 2>nul
set "DUR="
set /p DUR=<"%WORK%\dur.txt"
if not defined DUR exit /b 1
if "%DUR%"=="N/A" exit /b 1
exit /b 0

:psrun
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText('%~f0'); $i=$s.LastIndexOf('::POWERSHELL_BELOW'); Invoke-Expression $s.Substring($s.IndexOf([char]10, $i))"
exit /b %errorlevel%

::POWERSHELL_BELOW
if ($env:MV_SELFTEST) { Write-Host '  progress monitor: OK'; exit 0 }
if ($env:MV_TASK -eq 'resize') {
    try {
        $srcDir = $env:MV_R_SRC
        $dstDir = $env:MV_R_DST
        $targetW = [int]$env:MV_R_W
        $startQ = [int]$env:MV_R_Q
        $maxBytes = [int]$env:MV_R_MAX
        $suffix = $env:MV_R_SUFFIX
        New-Item -ItemType Directory -Force $dstDir | Out-Null
        Add-Type -AssemblyName System.Drawing
        $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
        Get-ChildItem $srcDir -Recurse -File | Where-Object { $_.Extension -in '.png','.jpg','.jpeg','.webp','.bmp' } | ForEach-Object {
            $img = [System.Drawing.Image]::FromFile($_.FullName)
            $scale = $targetW / $img.Width
            if ($scale -gt 1) { $scale = 1 }
            $w = [int]($img.Width * $scale)
            $h = [int]($img.Height * $scale)
            $bmp = New-Object System.Drawing.Bitmap($w, $h)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.DrawImage($img, 0, 0, $w, $h)
            $out = Join-Path $dstDir ($_.BaseName + '.jpg')
            $q = $startQ
            do {
                $params = New-Object System.Drawing.Imaging.EncoderParameters(1)
                $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$q)
                $bmp.Save($out, $codec, $params)
                $size = (Get-Item $out).Length
                $usedQ = $q
                $q -= 5
            } while ($size -gt $maxBytes -and $q -ge 50)
            foreach ($ext in '.png','.jpeg','.webp','.bmp') {
                $old = Join-Path $dstDir ($_.BaseName + $ext)
                if (Test-Path $old) { Remove-Item $old -Force }
            }
            Write-Host ("{0} -> {1}x{2}, quality {3}, {4:N0} KB" -f $_.Name, $w, $h, $usedQ, ($size / 1KB))
            $g.Dispose(); $bmp.Dispose(); $img.Dispose()
        }
        
        exit 0
    } catch {
        Write-Host ('  conversion failed: ' + $_.Exception.Message)
        exit 1
    }
}
$mode = $env:MV_MODE
$dir = $env:MV_DIR
$total = 0
[void][int]::TryParse($env:MV_TOTAL, [ref]$total)
$watchFile = $env:MV_FILE
$errPath = $env:MV_ERR
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $env:MV_CMD
$psi.Arguments = $env:MV_ARGS
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.RedirectStandardError = $true
$p = New-Object System.Diagnostics.Process
$p.StartInfo = $psi
[void]$p.Start()
$errTask = $p.StandardError.ReadToEndAsync()
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$full = [string][char]0x2588
$lite = [string][char]0x2591
function FmtT([double]$s) {
    if ([double]::IsNaN($s) -or [double]::IsInfinity($s) -or $s -lt 0) { return '--:--' }
    $ts = [TimeSpan]::FromSeconds($s)
    if ($ts.TotalHours -ge 1) { return ('{0}:{1:00}:{2:00}' -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds) }
    return ('{0}:{1:00}' -f [int]$ts.TotalMinutes, $ts.Seconds)
}
$lastC = 0
$lastT = 0.0
$fps = 0.0
$keysOk = $true
try { $null = [Console]::KeyAvailable } catch { $keysOk = $false }
while (-not $p.HasExited) {
    if ($keysOk) {
        try {
            if ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                if ($k.Key -eq 'Q' -or $k.Key -eq 'Escape') {
                    try { $p.Kill() } catch {}
                    Write-Host ''
                    Write-Host '  Cancelled by you - cleaning up...'
                    exit 99
                }
            }
        } catch { $keysOk = $false }
    }
    $el = $sw.Elapsed.TotalSeconds
    if ($mode -eq 'count') {
        $c = 0
        if ($dir) { $c = @(Get-ChildItem $dir -Filter '*.png' -File -ErrorAction SilentlyContinue).Count }
        if ($el -gt $lastT + 0.4) {
            $inst = ($c - $lastC) / ($el - $lastT)
            if ($inst -ge 0) { if ($fps -le 0) { $fps = $inst } else { $fps = 0.6 * $fps + 0.4 * $inst } }
            $lastC = $c; $lastT = $el
        }
        if ($total -gt 0) {
            $frac = $c / $total; if ($frac -gt 1) { $frac = 1 }
            $fill = [int][math]::Floor(26 * $frac)
            $bar = $full * $fill + $lite * (26 - $fill)
            $pct = [int][math]::Floor(100 * $frac)
            $eta = -1; if ($fps -gt 0.05) { $eta = ($total - $c) / $fps }
            $line = '{0} {1,3}%  {2}/{3}  {4} fps  {5} elapsed  ETA {6}' -f $bar, $pct, $c, $total, $fps.ToString('0.0'), (FmtT $el), (FmtT $eta)
        } else {
            $line = '{0} frames  {1} fps  {2} elapsed' -f $c, $fps.ToString('0.0'), (FmtT $el)
        }
        [Console]::Write("`r  " + $line + '   ')
    } else {
        $sz = ''
        if ($watchFile -and (Test-Path $watchFile)) { $sz = '  -  {0} MB written so far' -f [math]::Round((Get-Item $watchFile).Length / 1MB, 1) }
        [Console]::Write("`r  encoding...  " + (FmtT $el) + ' elapsed' + $sz + '   ')
    }
    Start-Sleep -Milliseconds 700
}
$p.WaitForExit()
$errText = ''
try { if ($errTask.Wait(3000)) { $errText = $errTask.Result } } catch {}
Write-Host ''
if ($p.ExitCode -ne 0) {
    $t = ''
    if ($errText) { $t = $errText.Trim() }
    if ($t) {
        Write-Host '  --- the tool reported: ---'
        Write-Host $t
        Write-Host '  --------------------------'
        if ($errPath) { try { [IO.File]::WriteAllText($errPath, $t) } catch {} }
    }
    exit 3
}
if ($mode -eq 'count' -and $total -gt 0) {
    [Console]::Write("`r  " + ($full * 26) + ' 100%  done in ' + (FmtT $sw.Elapsed.TotalSeconds) + '   ')
    Write-Host ''
} else {
    Write-Host ('  done in ' + (FmtT $sw.Elapsed.TotalSeconds))
}
exit 0
