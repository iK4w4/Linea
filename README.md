# Linea

[![YouTube](https://img.shields.io/badge/YouTube-@iK4w4-FF0000?logo=youtube&logoColor=white)](https://www.youtube.com/@iK4w4)
[![Telegram](https://img.shields.io/badge/Telegram-@iK4w4-26A5E4?logo=telegram&logoColor=white)](https://t.me/iK4w4)
[![Telegram Bot](https://img.shields.io/badge/Telegram_Bot-@AskKawaBot-26A5E4?logo=telegram&logoColor=white)](https://t.me/AskKawaBot)

I make short dialogue videos for YouTube. One spoken line per video, the
voice cleaned, one screenshot, the same intro every time. Linea is the
set of tools I built to make them, and it is what renders the videos on
[my channel](https://www.youtube.com/@iK4w4).

There is no compiled code here. Five Windows bat files drive ffmpeg, a
UVR model, Real-ESRGAN and Real-CUGAN. No binaries, models or media are
included. You bring the engines (see Prerequisites) and your own assets
(see `assets/`).

## Pipeline

```
raw clip (mp3) + screenshots (jpg/png)
        |
        v
[1] ALL_IN_ONE.bat ............ per folder: voice separation, then upscale
        |                         -> clip.wav (vocals only, in place)
        |                         -> screenshots at 2560 px JPG, in place
        v
[2] REALCUGAN.bat ............. optional, standalone: photo/video upscaling
        |                         (Real-CUGAN ncnn, models-pro / se / nose)
        v
[3] MAKE_VIDEO.bat ............ renders one folder into finished video(s)
                                  -> VIDEOS\<clip name>.mp4
```

Stage 1 goes folder by folder and finishes each folder before starting
the next, so the first folder is ready to render while the rest are
still processing. Only one GPU program runs at a time. Each engine
exits before the next step, which frees the VRAM, and there is a short
cooldown between folders. Run a stage again and it skips whatever is
already done.

## Repository layout

```
tools/make-video/MAKE_VIDEO.bat        stage 3 renderer (one folder -> MP4)
tools/all-in-one/ALL_IN_ONE.bat        stage 1 (audio + images, per folder)
tools/clean-voice/SETUP_CLEAN_VOICE.bat  one-time headless UVR runner install
tools/clean-voice/CLEAN_VOICE_ALL.bat    stage 1, audio only (standalone)
tools/realcugan/REALCUGAN.bat          stage 2 upscaler studio (photos/videos)
assets/intro.jpg                       placeholder intro card (replace it)
assets/subscribe.png                   placeholder overlay graphic (replace it)
docs/FORMAT.md                         the exact output specification
```

## Prerequisites

- Windows 10 or 11. PowerShell 5.1 ships with Windows, nothing to install.
- ffmpeg and ffprobe. MAKE_VIDEO looks next to itself first, then in its
  cache folder, then on PATH. If it finds nothing it downloads the
  gyan.dev essentials build once. REALCUGAN does the same lookup but
  never downloads.
- For voice separation, Python 3.10 (3.9 works too) and the
  MB-Roformer-Kim model inside an Ultimate Vocal Remover v5.6.1 install.
  UVR itself is GUI-only, so SETUP_CLEAN_VOICE.bat installs the
  `uvr-headless-runner` package into a private venv at
  `%LOCALAPPDATA%\VideoPipeline\CleanVoice\venv` and the bats drive that.
  UVR is not modified.
- For image upscaling in stage 1, a portable Real-ESRGAN ncnn build with
  the `realesrgan-x4plus-anime` model. The bat checks the common folders
  first, then searches the disks, and caches the path it finds.
- For stage 2, a portable Real-CUGAN ncnn build (`realcugan-ncnn-vulkan`)
  sitting next to REALCUGAN.bat, with any of the `models-pro`,
  `models-se` or `models-nose` sets. The menus only offer combinations
  whose `.param` files actually exist on disk.
- An NVIDIA GPU with NVENC helps but is optional. MAKE_VIDEO tests
  NVENC with a real encode and falls back to libx264 if the test fails.
  The separation and upscale engines use Vulkan or CUDA.

## Tool contracts

### MAKE_VIDEO.bat
Drop it into one line folder, meaning one audio clip plus its
screenshots, and run it. It asks which screenshot goes with the
Japanese-named audio and which with the English-named one (files with
`[EN]` in the name get the EN photo). It renders one MP4 per audio file
into a `VIDEOS\` subfolder and checks each render against
docs/FORMAT.md. It reads two assets from beside itself: `intro.jpg` or
`intro.png` (required) and `subscribe.png` (optional).

The videos go into a subfolder for a reason. mpv and VLC auto-load an
audio file that sits next to a video with the same name, and play it
from 0:00 over the video's own audio. The rendered file then looks
broken when it is not. The subfolder makes that impossible.

State: `%LOCALAPPDATA%\VideoPipeline\MakeVideo` (the ffmpeg cache) and
`make_video_log.txt` beside the bat.

### ALL_IN_ONE.bat
Drop it at the root of a folder tree, for example an episode pack with
one subfolder per line, and run it. For each folder it turns every clip
into a vocals-only WAV in place (the source is deleted on success, the
`A_DELETE_SOURCE` toggle at the top turns that off), then upscales
every image in the folder, then moves on. If one engine is missing,
that half is skipped for the folder with a message and the other half
still runs.

State: `%LOCALAPPDATA%\VideoPipeline\CleanVoice` (model path cache),
`%LOCALAPPDATA%\VideoPipeline\Upscale` (engine path cache), and
`all_in_one_log.txt` at the root.

### CLEAN_VOICE_ALL.bat / SETUP_CLEAN_VOICE.bat
The audio half of stage 1 as a standalone tool. Setup runs once per PC.
After that the bat converts every clip under its own folder tree with
the same model and settings as ALL_IN_ONE.

### REALCUGAN.bat
An interactive upscaler for photos and videos. Drop files or folders on
it, or run it and use the menus: model set, scale, denoise level, and
for video the codec. Photos come out as 2560 px JPG q95 under a 2 MB
cap, with the model settings written into the filename. Videos are
split into frames, upscaled, and re-encoded (HEVC or H.264, GPU when
the test encode passes) with every audio track carried over. Work
folders are removed on every exit path, cancels included. Tile size,
threads, CQ and the frame guard sit in the settings block at the top.

## Output format

The short version: 3840x2160 at 24 fps, H.264 High, limited-range
bt709, AAC 320 kbps 48 kHz, faststart. Intro card from 0 to 5 s, photo
from 5 s, voice starting at exactly 6.0 s, one loudnorm pass to
-14 LUFS and -1.0 dBTP, total runtime is the audio plus 7 s. The full
spec, including how the subscribe pops are timed and the dim level, is
in [docs/FORMAT.md](docs/FORMAT.md).

Two decisions in there are easy to break by accident, so they are
written down here too:

- Limited range. Every render path ends with an explicit conversion to
  limited-range bt709 and a `color_range=tv` tag. Without it the frames
  go into the file tagged full range, and players that assume limited
  range stretch the picture on playback. You get roughly 16% more
  contrast, crushed blacks and clipped whites. I shipped that bug
  before I caught it.
- Silence before loudnorm. The 6 second offset is plain silence glued
  to the front of the clip before normalization. A delay filter placed
  after loudnorm loses the delay. I measured it with a test tone: a
  burst at 3.0 s with a 5.5 s delay after loudnorm landed at 3.04 s.
  With the delay before loudnorm it landed at 8.50 s. So the silence
  goes first, always.

## Configuration

Every setting lives in a block at the top of its bat file. The dim
level and encoder presets in MAKE_VIDEO, model names, segment size and
target widths in ALL_IN_ONE and CLEAN_VOICE_ALL, tile size, threads and
CQ in REALCUGAN. You never edit the middle of a script to configure
these. Engine paths are found on first run and cached. Any cache can be
skipped by setting the path variable at the top of the file instead
(MODEL_PATH, ESRGAN_PATH).

## Troubleshooting

- ffmpeg not found (MAKE_VIDEO). The download failed or was blocked.
  Get the gyan.dev essentials build yourself and put ffmpeg.exe and
  ffprobe.exe next to MAKE_VIDEO.bat.
- MB-Roformer-Kim model not found. The bats check the standard UVR
  folders first, then search the whole PC, once. If the model lives
  somewhere odd, set MODEL_PATH at the top of the bat to the full path
  of the .ckpt file.
- The progress monitor could not start (REALCUGAN). The monitor is a
  PowerShell script the bat pulls out of itself. Antivirus or a strict
  execution policy can block it, and the bat cannot run without it.
- No intro card found (MAKE_VIDEO). Put intro.jpg or intro.png next to
  the bat. A placeholder is in `assets/`.

## Author

Linea is a project by Kawa ([@iK4w4](https://github.com/iK4w4)).
The videos are on [YouTube](https://www.youtube.com/@iK4w4). I am also
on [Telegram](https://t.me/iK4w4), and questions and requests go to the
contact bot: [@AskKawaBot](https://t.me/AskKawaBot).

The batch files and documentation in this repository are released
under the MIT License (see [LICENSE](LICENSE)).
