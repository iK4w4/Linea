@echo off
setlocal EnableDelayedExpansion
title MAKE_VIDEO - one folder, one line, finished video(s)
rem =====================================================================
rem  MAKE_VIDEO.bat  by iK4w4
rem  Drop this ONE file inside a single line folder (e.g. a RANK folder,
rem  AFTER ALL_IN_ONE cleaned the audio and upscaled the screenshots)
rem  and double-click it. It renders the finished YouTube video(s) for
rem  THAT folder only, in the exact format of the channel:
rem    3840x2160 24fps - intro card 0-5s - photo fades in, dead still -
rem    voice starts at 6.0s (1s after the intro) at the channel loudness
rem    (-14 LUFS / -1.0 dBTP, the YouTube target) - video ends 1s after the voice, fading out.
rem  Photos: the bat lists the screenshots and ASKS which one to use
rem  for the Japanese video and which for the English video.
rem  Videos are written to a VIDEOS subfolder: players like mpv/VLC
rem  auto-play a same-named WAV sitting beside an MP4 from 0:00 - the
rem  subfolder makes that impossible.
rem  Assets are NOT embedded: place your intro card as intro.jpg (or
rem  intro.png) next to this bat, and optionally a subscribe.png graphic
rem  (transparent or black-backed), which pops up on smart timing, 5s at
rem  a time, with the photo dimmed under it. Placeholders ship in assets/.
rem  ffmpeg is downloaded once (first run) if it is not found.
rem =====================================================================

set "HERE=%~dp0"
rem  DIM = how dark the photo goes while Subscribe is on screen: the photo is
rem  multiplied by 1-DIM. 0.9375 gives x0.0625 brightness = exposure -4.
set "DIM=0.9375"
cd /d "%HERE%"
set "CACHE=%LOCALAPPDATA%\VideoPipeline\MakeVideo"
if not exist "%CACHE%" mkdir "%CACHE%"
set "LOG=%HERE%make_video_log.txt"
echo ============================================================
echo  MAKE_VIDEO - one folder in, finished YouTube video^(s^) out
echo  Folder: %HERE%
echo ============================================================

rem ---------------- find ffmpeg ----------------
set "FF="
set "FP="
if exist "%HERE%ffmpeg.exe" set "FF=%HERE%ffmpeg.exe"
if exist "%HERE%ffprobe.exe" set "FP=%HERE%ffprobe.exe"
if not defined FF if exist "%CACHE%\ffmpeg.exe" set "FF=%CACHE%\ffmpeg.exe"
if not defined FP if exist "%CACHE%\ffprobe.exe" set "FP=%CACHE%\ffprobe.exe"
if not defined FF (
  for %%P in (ffmpeg.exe) do if not "%%~$PATH:P"=="" set "FF=%%~$PATH:P"
)
if not defined FP (
  for %%P in (ffprobe.exe) do if not "%%~$PATH:P"=="" set "FP=%%~$PATH:P"
)
if not defined FF (
  echo ffmpeg not found - downloading it once, please wait...
  echo [%date% %time%] downloading ffmpeg >> "%LOG%"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile '%CACHE%\ffmpeg.zip' } catch { exit 1 }"
  if errorlevel 1 goto :noffmpeg
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Force -Path '%CACHE%\ffmpeg.zip' -DestinationPath '%CACHE%\ffmpeg_x'"
  if errorlevel 1 goto :noffmpeg
  for /r "%CACHE%\ffmpeg_x" %%E in (ffmpeg.exe) do copy /y "%%E" "%CACHE%\ffmpeg.exe" >nul
  for /r "%CACHE%\ffmpeg_x" %%E in (ffprobe.exe) do copy /y "%%E" "%CACHE%\ffprobe.exe" >nul
  del /q "%CACHE%\ffmpeg.zip" 2>nul
  rd /s /q "%CACHE%\ffmpeg_x" 2>nul
  if exist "%CACHE%\ffmpeg.exe" set "FF=%CACHE%\ffmpeg.exe"
  if exist "%CACHE%\ffprobe.exe" set "FP=%CACHE%\ffprobe.exe"
)
if not defined FF goto :noffmpeg
if not defined FP goto :noffmpeg
echo  ffmpeg       : %FF%
rem ---------------- encoder: GPU (NVENC) if the card answers, else CPU ----------------
set "VENC=-c:v libx264 -preset medium -tune stillimage -crf 16"
set "ENCNAME=CPU (libx264)"
set "USEGPU="
"%FF%" -v error -f lavfi -i color=black:s=256x256:d=0.1 -c:v h264_nvenc -preset p5 -tune hq -rc vbr -cq 22 -b:v 0 -maxrate 40M -bufsize 80M -spatial-aq 1 -profile:v high -bf 2 -pix_fmt yuv420p -f null - 2>nul
if not errorlevel 1 set "USEGPU=1"
if defined USEGPU set "VENC=-c:v h264_nvenc -preset p5 -tune hq -rc vbr -cq 22 -b:v 0 -maxrate 40M -bufsize 80M -spatial-aq 1"
if defined USEGPU set "ENCNAME=GPU (NVENC - your RTX card)"
echo  Encoder      : %ENCNAME%

rem ---------------- find / unpack intro card ----------------
set "INTRO="
if exist "%HERE%intro.jpg" set "INTRO=%HERE%intro.jpg"
if not defined INTRO if exist "%HERE%intro.png" set "INTRO=%HERE%intro.png"
if not defined INTRO (
  echo ERROR: no intro card found next to this bat.
  echo Place your intro card beside MAKE_VIDEO.bat as intro.jpg or
  echo intro.png - 3840x2160 recommended - then run again.
  pause
  exit /b 1
)
echo  Intro card   : %INTRO%

rem ---------------- subscribe overlay (optional: subscribe.png beside the bat) ----------------
set "SUB="
if exist "%HERE%subscribe.png" set "SUB=%HERE%subscribe.png"
if defined SUB echo  Subscribe    : subscribe.png - smart timing, 5s pops, photo dims under it

rem ---------------- choose the photos (JP and EN separately) ----------------
set "NPH=0"
for %%I in ("%HERE%*.jpg" "%HERE%*.png") do (
  set /a NPH+=1
  set "PH!NPH!=%%I"
  set "PN!NPH!=%%~nxI"
)
if !NPH! equ 0 (
  echo No screenshot found in this folder. Nothing to do.
  pause
  exit /b 1
)
set "JP_SEL=1"
set "PHOTO_JP=%PH1%"
set "PHOTO_EN=%PH1%"
if !NPH! equ 1 goto :photos_done
echo.
echo ------------------------------------------------------------
echo  PHOTOS - pick one for JP and one for EN
echo ------------------------------------------------------------
for /l %%N in (1,1,!NPH!) do call echo   %%N - %%PN%%N%%
echo.
set "JP_NUM="
set /p "JP_NUM=Which photo for the JAPANESE video? [1 to !NPH!, Enter = 1]: "
set "SEL=1"
if defined JP_NUM for /l %%N in (1,1,!NPH!) do if "!JP_NUM!"=="%%N" set "SEL=%%N"
set "JP_SEL=%SEL%"
call set "PHOTO_JP=%%PH%SEL%%%"
set "EN_NUM="
set /p "EN_NUM=Which photo for the ENGLISH video? [1 to !NPH!, Enter = same as JP, %JP_SEL%]: "
set "SEL=%JP_SEL%"
if defined EN_NUM for /l %%N in (1,1,!NPH!) do if "!EN_NUM!"=="%%N" set "SEL=%%N"
call set "PHOTO_EN=%%PH%SEL%%%"
:photos_done
for %%Q in ("%PHOTO_JP%") do set "PHOTO_JP_NAME=%%~nxQ"
for %%Q in ("%PHOTO_EN%") do set "PHOTO_EN_NAME=%%~nxQ"
echo  Photo for JP : %PHOTO_JP_NAME%
echo  Photo for EN : %PHOTO_EN_NAME%

rem ---------------- collect audio (WAV first, else MP3) ----------------
call :now_cs
set "T0_CS=%NOW_CS%"
set "HASWAV="
for %%A in ("%HERE%*.wav") do set "HASWAV=1"
set "MADE=0"
set "SKIPPED=0"
set "FAILED=0"
if not exist "%HERE%VIDEOS" mkdir "%HERE%VIDEOS"
if defined HASWAV (
  for %%A in ("%HERE%*.wav") do call :render "%%A"
) else (
  for %%A in ("%HERE%*.mp3") do call :render "%%A"
)
if !MADE! equ 0 if !SKIPPED! equ 0 if !FAILED! equ 0 (
  echo No .wav or .mp3 audio found in this folder.
  echo Run ALL_IN_ONE first so the cleaned WAV is here.
)
call :now_cs
set /a ELAPSED_CS=NOW_CS-T0_CS
if %ELAPSED_CS% LSS 0 set /a ELAPSED_CS+=8640000
set "V=%ELAPSED_CS%"
call :fmt_cs
set "TOTAL_TIME_STR=%FMT%"
echo.
echo ============================================================
echo  ALL DONE - your videos are in the VIDEOS folder
echo  Videos : made !MADE!, failed !FAILED!
echo  Time taken: %TOTAL_TIME_STR%
echo  Log: %LOG%
echo ============================================================
echo [%date% %time%] done made=!MADE! failed=!FAILED! >> "%LOG%"
pause
exit /b 0

rem =====================================================================
:render
set "AUD=%~1"
set "PHOTO=%PHOTO_JP%"
if not "%AUD:[EN]=%"=="%AUD%" set "PHOTO=%PHOTO_EN%"
for %%Q in ("%PHOTO%") do set "PHOTONAME=%%~nxQ"
set "OUT=%HERE%VIDEOS\%~n1.mp4"
rem --- audio duration via ffprobe (direct redirect - no fragile quoting), ---
rem --- then ONE PowerShell call does all the timeline math into a file  ---
set "DUR="
"%FP%" -v error -show_entries format=duration -of csv=p=0 "%AUD%" > "%TEMP%\mv_dur.txt" 2>>"%LOG%"
set /p DUR=<"%TEMP%\mv_dur.txt"
if not defined DUR (
  echo [fail] cannot read audio: %~nx1
  set /a FAILED+=1
  exit /b 0
)
del "%TEMP%\mv_math.txt" 2>nul
powershell -NoProfile -Command "[System.Threading.Thread]::CurrentThread.CurrentCulture=[System.Globalization.CultureInfo]::InvariantCulture; $d=[double]'%DUR%'; $pd=$d+2.0; $tot=$d+7.0; $fo=$pd-1.0; $fades=''; $when=''; $dimf=''; $s=[Math]::Max(6.5, 0.55*$tot); while(($s+5) -le ($tot-1.2)){ if($fades -ne ''){ $fades+=','; $when+='+'; $dimf+=',' }; $e=$s+5; $fades+=('fade=t=in:st={0:F2}:d=0.15,fade=t=out:st={1:F2}:d=0.15' -f $s, ($e-0.15)); $when+=('between(t,{0:F2},{1:F2})' -f $s, $e); $dimf+=('fade=t=in:st={0:F2}:d=0.25:alpha=1,fade=t=out:st={1:F2}:d=0.25:alpha=1' -f $s, ($e-0.25)); $s+=30 }; [IO.File]::WriteAllLines('%TEMP%\mv_math.txt', [string[]]@(('{0:F2},{1:F2},{2:F2}' -f $pd,$tot,$fo), $fades, $when, $dimf))" >>"%LOG%" 2>&1
if exist "%TEMP%\mv_math.txt" goto math_have
powershell -NoProfile -Command "[System.Threading.Thread]::CurrentThread.CurrentCulture=[System.Globalization.CultureInfo]::InvariantCulture; $d=[double]'%DUR%'; [IO.File]::WriteAllText('%TEMP%\mv_math.txt', ('{0:F2},{1:F2},{2:F2}' -f ($d+2.0),($d+7.0),($d+1.0)))" >>"%LOG%" 2>&1
:math_have
set "SUBFADE="
set "SUBWHEN="
set "DIMFADE="
set "LC=0"
for /f "usebackq delims=" %%L in ("%TEMP%\mv_math.txt") do (
  set /a LC+=1
  if !LC! equ 1 for /f "tokens=1-3 delims=," %%a in ("%%L") do (
    set "PD=%%a"
    set "TOTAL=%%b"
    set "FOUT=%%c"
  )
  if !LC! equ 2 set "SUBFADE=%%L"
  if !LC! equ 3 set "SUBWHEN=%%L"
  if !LC! equ 4 set "DIMFADE=%%L"
)
if not defined TOTAL (
  echo [fail] timeline math failed for: %~nx1
  set /a FAILED+=1
  exit /b 0
)
set "SUBEFFECT="
if defined SUB if defined SUBWHEN set "SUBEFFECT=1"
set "SUBALPHA="
if defined SUBEFFECT (
  "%FP%" -v error -show_entries stream=pix_fmt -of "csv=p=0" "%SUB%" > "%TEMP%\mv_fmt.txt" 2>nul
  set "SUBFMT="
  set /p SUBFMT=<"%TEMP%\mv_fmt.txt"
  if defined SUBFMT echo !SUBFMT! | findstr /i /c:"rgba" /c:"bgra" /c:"argb" /c:"abgr" /c:"pal8" >nul && set "SUBALPHA=1"
)
echo ------------------------------------------------------------
echo  MAKING - %~n1.mp4
echo ------------------------------------------------------------
echo  photo %PHOTONAME% - audio %DUR%s - total %TOTAL%s
if defined SUBALPHA echo   subscribe : transparent PNG - full-strength overlay
echo [%date% %time%] render %OUT% dur=%DUR% >> "%LOG%"
if exist "%OUT%" del /f /q "%OUT%"
set "RFAIL="
if not defined SUBEFFECT goto render_plain
if defined SUBALPHA goto render_alpha
  "%FF%" -y -loop 1 -framerate 24 -i "%INTRO%" -loop 1 -framerate 24 -i "%PHOTO%" -i "%AUD%" -loop 1 -framerate 24 -i "%SUB%" -filter_complex "[0:v]scale=3840:2160:flags=lanczos,setsar=1,fps=24,trim=duration=5.0,setpts=PTS-STARTPTS,fade=t=in:st=0:d=0.5,fade=t=out:st=4.5:d=0.5[intro];[1:v]scale=3840:2160:flags=lanczos,setsar=1,fps=24,trim=duration=%PD%,setpts=PTS-STARTPTS,fade=t=in:st=0:d=1.0,fade=t=out:st=%FOUT%:d=1.0[photo];[intro][photo]concat=n=2:v=1:a=0[base];color=c=black:s=3840x2160:r=24:d=%TOTAL%,format=rgba,%DIMFADE%,colorchannelmixer=aa=%DIM%[dim];[base][dim]overlay=0:0[dimmed];[dimmed]format=gbrp[baseg];[3:v]scale=3840:2160:flags=lanczos,setsar=1,fps=24,trim=duration=%TOTAL%,setpts=PTS-STARTPTS,%SUBFADE%,format=gbrp[subf];[baseg][subf]blend=all_mode=screen:enable='%SUBWHEN%'[blendv];[blendv]format=yuv420p[vid];[vid]scale=out_range=tv:out_color_matrix=bt709,format=yuv420p[vout];[2:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[voice];aevalsrc=0:d=6.0:s=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[sil];[sil][voice]concat=n=2:v=0:a=1,loudnorm=I=-14:TP=-1.0:LRA=11,aresample=48000,apad,atrim=duration=%TOTAL%[aud]" -map "[vout]" -map "[aud]" %VENC% -profile:v high -bf 2 -pix_fmt yuv420p -color_range tv -r 24 -color_primaries bt709 -color_trc bt709 -colorspace bt709 -c:a aac -b:a 320k -ar 48000 -movflags +faststart -t %TOTAL% "%OUT%" >> "%LOG%" 2>&1
if errorlevel 1 set "RFAIL=1"
goto render_check
:render_alpha
  "%FF%" -y -loop 1 -framerate 24 -i "%INTRO%" -loop 1 -framerate 24 -i "%PHOTO%" -i "%AUD%" -loop 1 -framerate 24 -i "%SUB%" -filter_complex "[0:v]scale=3840:2160:flags=lanczos,setsar=1,fps=24,trim=duration=5.0,setpts=PTS-STARTPTS,fade=t=in:st=0:d=0.5,fade=t=out:st=4.5:d=0.5[intro];[1:v]scale=3840:2160:flags=lanczos,setsar=1,fps=24,trim=duration=%PD%,setpts=PTS-STARTPTS,fade=t=in:st=0:d=1.0,fade=t=out:st=%FOUT%:d=1.0[photo];[intro][photo]concat=n=2:v=1:a=0[base];color=c=black:s=3840x2160:r=24:d=%TOTAL%,format=rgba,%DIMFADE%,colorchannelmixer=aa=%DIM%[dim];[base][dim]overlay=0:0[dimmed];[3:v]scale=3840:2160:flags=lanczos,setsar=1,fps=24,trim=duration=%TOTAL%,setpts=PTS-STARTPTS,%DIMFADE%,format=rgba[subf];[dimmed][subf]overlay=0:0[vid];[vid]scale=out_range=tv:out_color_matrix=bt709,format=yuv420p[vout];[2:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[voice];aevalsrc=0:d=6.0:s=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[sil];[sil][voice]concat=n=2:v=0:a=1,loudnorm=I=-14:TP=-1.0:LRA=11,aresample=48000,apad,atrim=duration=%TOTAL%[aud]" -map "[vout]" -map "[aud]" %VENC% -profile:v high -bf 2 -pix_fmt yuv420p -color_range tv -r 24 -color_primaries bt709 -color_trc bt709 -colorspace bt709 -c:a aac -b:a 320k -ar 48000 -movflags +faststart -t %TOTAL% "%OUT%" >> "%LOG%" 2>&1
if errorlevel 1 set "RFAIL=1"
goto render_check
:render_plain
  "%FF%" -y -loop 1 -framerate 24 -i "%INTRO%" -loop 1 -framerate 24 -i "%PHOTO%" -i "%AUD%" -filter_complex "[0:v]scale=3840:2160:flags=lanczos,setsar=1,fps=24,trim=duration=5.0,setpts=PTS-STARTPTS,fade=t=in:st=0:d=0.5,fade=t=out:st=4.5:d=0.5[intro];[1:v]scale=3840:2160:flags=lanczos,setsar=1,fps=24,trim=duration=%PD%,setpts=PTS-STARTPTS,fade=t=in:st=0:d=1.0,fade=t=out:st=%FOUT%:d=1.0[photo];[intro][photo]concat=n=2:v=1:a=0,format=yuv420p[vid];[vid]scale=out_range=tv:out_color_matrix=bt709,format=yuv420p[vout];[2:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[voice];aevalsrc=0:d=6.0:s=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[sil];[sil][voice]concat=n=2:v=0:a=1,loudnorm=I=-14:TP=-1.0:LRA=11,aresample=48000,apad,atrim=duration=%TOTAL%[aud]" -map "[vout]" -map "[aud]" %VENC% -profile:v high -bf 2 -pix_fmt yuv420p -color_range tv -r 24 -color_primaries bt709 -color_trc bt709 -colorspace bt709 -c:a aac -b:a 320k -ar 48000 -movflags +faststart -t %TOTAL% "%OUT%" >> "%LOG%" 2>&1
if errorlevel 1 set "RFAIL=1"
:render_check
if not exist "%OUT%" goto :render_bad
"%FP%" -v error -show_entries format=duration -of csv=p=0 "%OUT%" > "%TEMP%\mv_odur.txt" 2>nul
set "ODUR="
set /p ODUR=<"%TEMP%\mv_odur.txt"
if not defined ODUR goto :render_bad
powershell -NoProfile -Command "[System.Threading.Thread]::CurrentThread.CurrentCulture=[System.Globalization.CultureInfo]::InvariantCulture; $o=[double]'%ODUR%'; $t=[double]'%TOTAL%'; if([Math]::Abs($o-$t) -lt 2.0){ exit 0 }; exit 1" >>"%LOG%" 2>&1
if errorlevel 1 goto :render_bad
if defined RFAIL goto :render_bad
goto :render_ok
:render_bad
if exist "%OUT%" del /f /q "%OUT%"
echo [fail] render failed for %~nx1 - see make_video_log.txt
set /a FAILED+=1
exit /b 0
:render_ok
for %%Q in ("%OUT%") do set "OUTBYTES=%%~zQ"
set /a OUTMB=(OUTBYTES+524288)/1048576
echo [ ok ] %~n1.mp4  (~!OUTMB! MB)
"%FF%" -i "%OUT%" -af silencedetect=noise=-45dB:d=0.2 -f null - 2> "%TEMP%\mv_sd.txt"
findstr /c:"silence_end" "%TEMP%\mv_sd.txt" > "%TEMP%\mv_se.txt" 2>nul
set "ONLINE="
set /p ONLINE=<"%TEMP%\mv_se.txt"
if defined ONLINE (
  set "ONSET=%ONLINE:*silence_end: =%"
  for /f "tokens=1 delims=| " %%z in ("%ONSET%") do set "ONSET=%%z"
  echo        first sound at !ONSET!s - built-in silence is 6.0s, the rest is your clip's own lead-in
)
set /a MADE+=1
exit /b 0

rem =====================================================================
:noffmpeg
echo.
echo ERROR: ffmpeg could not be downloaded automatically.
echo Get it manually from https://www.gyan.dev/ffmpeg/builds/
echo (ffmpeg-release-essentials.zip), unzip it, and put ffmpeg.exe
echo and ffprobe.exe next to this bat file. Then run again.
echo [%date% %time%] ffmpeg download failed >> "%LOG%"
pause
exit /b 1

rem ====================== subroutines: now_cs / fmt_cs ======================
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

