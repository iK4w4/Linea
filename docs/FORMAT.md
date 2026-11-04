# Output format specification

The contract every MAKE_VIDEO render is built and verified against.
All times in seconds.

## Container and streams

| Property | Value |
| --- | --- |
| Container | MP4, `+faststart` |
| Video | 3840x2160, 24 fps, H.264 High profile, bf 2 |
| Color | bt709 primaries/transfer/matrix, **limited range** (`tv`) |
| Audio | AAC, 320 kbps, 48 kHz, stereo |
| Duration | audio duration + 7.0 |

## Timeline

| Segment | Window | Treatment |
| --- | --- | --- |
| Intro card | 0.0 - 5.0 | lanczos to 3840x2160, fade in 0.5, fade out at 4.5 over 0.5 |
| Photo | 5.0 - end | fade in 1.0 at its start, dead still (no pan/zoom), fade out over the final 1.0 |
| Voice | starts exactly 6.0 | 6.0 of generated silence concatenated **before** the clip |
| End | audio end + 1.0 of photo tail | total = audio + 7.0 (photo segment = audio + 2.0) |

## Audio chain

`aresample 48 kHz -> [silence 6.0 + clip] concat -> loudnorm -> apad -> atrim to total`

- Loudnorm: single pass, `I=-14 : TP=-1.0 : LRA=11` (YouTube target).
- The silence is concatenated before loudnorm, never delayed after it:
  a delay filter placed downstream of loudnorm loses the offset.

## Subscribe pops (only when `subscribe.png` is present)

- Windows: 5.0 each. First window starts at `max(6.5, 0.55 * total)`;
  further windows every 30.0. A window is only emitted if it ends by
  `total - 1.2`.
- Graphic fade: 0.15 in/out. Dim envelope fade: 0.25 in/out.
- While a window is open the photo is multiplied by 0.0625: exposure
  -4 EV (`DIM=0.9375` black overlay alpha in the graph).
- The graphic is full-frame (3840x2160 canvas, artwork placed by the
  asset itself), so its size and position on screen are whatever the
  PNG carries.
- Transparent PNG (alpha pix_fmt) renders on the overlay path;
  black-backed PNG renders on the screen-blend path. The path is chosen
  by probing the file's pixel format with ffprobe.

## Encoders

- NVENC (preferred, probed with a real test encode):
  `h264_nvenc, preset p5, tune hq, VBR CQ 22, maxrate 40M, bufsize 80M,
  spatial-aq 1`.
- CPU fallback: `libx264, preset medium, tune stillimage, crf 16`.
- Every graph ends with `scale=out_range=tv:out_color_matrix=bt709,
  format=yuv420p` and the stream is tagged `-color_range tv`. This is
  what keeps range-assuming players from re-expanding the picture.

## Render verification

A render only reports `[ ok ]` when all three hold:

1. The previous output file was deleted before the render started
   (a stale file can never pass as a new render).
2. ffmpeg exited with code 0.
3. The finished file's probed duration is within 2.0 s of the computed
   timeline.

Failed renders delete their partial output. After a successful render
the bat also measures the first-sound onset with silencedetect and
prints it; the built-in portion is always 6.0 s, anything beyond that
is the clip's own lead-in.

## Preparation specs (stage 1)

Voice (UVR, MDX-Net):

| Setting | Value |
| --- | --- |
| Model | MB-Roformer-Kim (`MelBandRoformer.ckpt`) |
| Segment size | 3680 |
| Overlap | 4 |
| GPU conversion | on |
| Vocals only | on (no instrumental file kept) |
| Output | WAV PCM 16-bit, same folder and name as the source |
| Source | deleted after a verified conversion (toggle) |

Images (Real-ESRGAN):

| Setting | Value |
| --- | --- |
| Model | realesrgan-x4plus-anime, scale 4 |
| Finish | downscale only, to 2560 px wide JPG |
| Quality | 95, stepping down by 5 until the file fits 2,000,000 bytes |
| Skip rule | sources already 2560 px wide or wider are left untouched |
| Replacement | in place; PNG masters exist only during the run |

---

Part of [Linea](https://github.com/iK4w4/Linea) · © 2026 Kawa (@iK4w4) · MIT License
