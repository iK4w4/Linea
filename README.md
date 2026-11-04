# Linea

[![YouTube](https://img.shields.io/badge/YouTube-@iK4w4-FF0000?logo=youtube&logoColor=white)](https://www.youtube.com/@iK4w4)
[![Telegram](https://img.shields.io/badge/Telegram-@iK4w4-26A5E4?logo=telegram&logoColor=white)](https://t.me/iK4w4)

A Windows batch pipeline that turns short anime dialogue clips and screenshots
into finished 4K YouTube videos. It is the tooling behind a dialogue-line
channel format: one spoken line per video, cleaned voice, one still frame,
fixed intro, loudness-normalized to the YouTube target.

Linea is the production pipeline behind the dialogue-line videos on the author's [YouTube channel](https://www.youtube.com/@iK4w4) - the videos there are rendered with these tools.

Everything here is orchestration. The pipeline is five `.bat` files driving
ffmpeg, an Ultimate Vocal Remover model, Real-ESRGAN and Real-CUGAN. No
binaries, models or media are bundled; you bring the engines (see
Prerequisites) and your own assets (see `assets/`).

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

Stage 1 runs folder by folder and finishes each folder completely before
starting the next, so the first folder is upload-ready while the rest are
still processing. Only one GPU engine runs at a time; each engine exits
(VRAM freed) before the next step, with a cooldown between folders.
Re-running any stage skips work that is already done.

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

- Windows 10/11, PowerShell 5.1 (built in).
- ffmpeg + ffprobe. MAKE_VIDEO looks next to itself, then in its cache
  folder, then on PATH, and downloads the gyan.dev essentials build once
  if none is found. REALCUGAN uses the same lookup, minus the download.
- For voice separation: Python 3.10 (3.9 also accepted) and the
  MB-Roformer-Kim model in an Ultimate Vocal Remover v5.6.1 install.
  UVR's executable is GUI-only, so `SETUP_CLEAN_VOICE.bat` installs the
  `uvr-headless-runner` package into a private venv
  (`%LOCALAPPDATA%\VideoPipeline\CleanVoice\venv`) and the bats drive
  that. UVR itself is not modified.
- For image upscaling in stage 1: a portable Real-ESRGAN ncnn build with
  the `realesrgan-x4plus-anime` model. The bat auto-detects it (common
  folders first, then a disk search) and caches the path.
- For stage 2: a portable Real-CUGAN ncnn build (`realcugan-ncnn-vulkan`)
  placed next to `REALCUGAN.bat`, with any of the `models-pro`,
  `models-se`, `models-nose` sets. Menus only offer combinations whose
  `.param` files exist on disk.
- Optional: an NVIDIA GPU with NVENC. MAKE_VIDEO probes NVENC with a real
  test encode and falls back to libx264 if the probe fails. The separation
  and upscale engines use Vulkan/CUDA as configured.

## Tool contracts

### MAKE_VIDEO.bat
Drop it into one line folder (one audio clip + its screenshots) and run it.
It asks which screenshot to use for the Japanese-named audio and which for
the English-named one (files with `[EN]` in the name get the EN photo),
renders one MP4 per audio file into a `VIDEOS\` subfolder, and verifies
each render (see docs/FORMAT.md). Assets are read from beside the bat:
`intro.jpg` / `intro.png` (required) and `subscribe.png` (optional).

Rendered videos land in a subfolder on purpose: players such as mpv and
VLC auto-load an external audio file that shares the video's basename and
play it from 0:00, masking the embedded track. The subfolder makes that
impossible.

State: `%LOCALAPPDATA%\VideoPipeline\MakeVideo` (ffmpeg cache),
`make_video_log.txt` beside the bat.

### ALL_IN_ONE.bat
Drop it at the root of a folder tree (e.g. an episode pack: one subfolder
per line) and run it. For each folder it converts every clip to a
vocals-only WAV in place (source deleted on success; `A_DELETE_SOURCE`
toggle at the top), then upscales every image in that folder, then moves
on. If one engine is missing, that half is skipped per folder with a
message and the other half still runs.

State: `%LOCALAPPDATA%\VideoPipeline\CleanVoice` (model path cache),
`%LOCALAPPDATA%\VideoPipeline\Upscale` (engine path cache),
`all_in_one_log.txt` at the root.

### CLEAN_VOICE_ALL.bat / SETUP_CLEAN_VOICE.bat
The audio half of stage 1 as a standalone tool. Setup runs once per PC;
the batch file then converts every clip under its own folder tree with
the same model and settings as ALL_IN_ONE.

### REALCUGAN.bat
Interactive upscaler for photos and videos. Drop files or folders on it,
or run it and use the menus: model set, scale, denoise level, and (for
video) codec. Photos land as 2560 px JPG q95 under a 2 MB cap, tagged
with the model settings in the filename. Videos are extracted to frames,
upscaled, and re-encoded (HEVC or H.264, GPU when the probe passes) with
all audio tracks carried over. Work folders are removed on every exit
path, including cancels. Settings (tile size, threads, CQ, frame guard)
sit at the top of the file.

## Output format

Summary: 3840x2160 at 24 fps, H.264 High, limited-range bt709, AAC
320 kbps 48 kHz, faststart. Intro card 0-5 s, photo from 5 s, voice welded
at exactly 6.0 s, single-pass loudnorm to -14 LUFS / -1.0 dBTP, runtime
audio duration + 7 s. The full specification, including the subscribe-pop
timing algorithm and the dim level, is in [docs/FORMAT.md](docs/FORMAT.md).

Two format decisions are deliberate and worth knowing before changing them:

- Limited range. If the graph's frames are allowed to carry full-range
  metadata into the file, players that assume limited range re-expand the
  picture on playback: roughly +16% contrast, crushed blacks, clipped
  whites. Every render path therefore ends with an explicit conversion
  to limited-range bt709 and a matching `color_range=tv` tag.
- Silence before loudnorm. The 6.0 s voice offset is built by
  concatenating generated silence before normalization. Putting a delay
  filter after loudnorm silently loses the delay; the order in the graph
  is load-bearing.

## Configuration

Every tunable lives in a settings block at the top of its bat file: the
dim level and encoder presets in MAKE_VIDEO, model names, segment size
and target widths in ALL_IN_ONE and CLEAN_VOICE_ALL, tile size, threads
and CQ in REALCUGAN. Nothing is configured by editing the middle of a
script. Paths to engines are auto-detected on first run and cached;
every cache can be bypassed by setting the matching path variable at
the top of the file (MODEL_PATH, ESRGAN_PATH).

## Troubleshooting

- **ffmpeg not found (MAKE_VIDEO).** The automatic download failed or
  was blocked. Get the gyan.dev essentials build manually, and put
  ffmpeg.exe and ffprobe.exe next to MAKE_VIDEO.bat.
- **MB-Roformer-Kim model not found.** The bats search the standard UVR
  folders, then the whole PC, once. If the model lives somewhere
  unusual, set MODEL_PATH at the top of the bat to the full path of the
  .ckpt file.
- **The progress monitor could not start (REALCUGAN).** The monitor is
  a PowerShell script the bat extracts from itself. Antivirus or a
  locked-down execution policy can block it; the bat cannot run
  without it.
- **No intro card found (MAKE_VIDEO).** Place intro.jpg or intro.png
  next to the bat. A placeholder ships in `assets/`.

## Author

Linea is a project by Kawa ([@iK4w4](https://github.com/iK4w4)).
The videos are on [YouTube](https://www.youtube.com/@iK4w4); the author is
also on [Telegram](https://t.me/iK4w4).

The batch files and documentation in this repository are released
under the MIT License (see [LICENSE](LICENSE)).
