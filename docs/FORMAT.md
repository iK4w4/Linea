# Output format spec

What every MAKE_VIDEO render has to match. If a render misses this,
the bat treats it as failed. All times are in seconds.

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

- Loudnorm is a single pass, `I=-14 : TP=-1.0 : LRA=11`. That is the
  YouTube target.
- The silence is glued on before loudnorm, never delayed in after it.
  A delay filter after loudnorm loses the offset. Measured, not theory:
  a 3.0 s test burst with a 5.5 s delay placed after loudnorm came out
  at 3.04 s.

## Subscribe pops (only when `subscribe.png` is present)

- Each window is 5.0 s. The first starts at `max(6.5, 0.55 * total)`,
  the rest follow every 30.0 s. A window is only used if it ends by
  `total - 1.2`.
- The graphic fades in and out over 0.15 s. The dim envelope fades over
  0.25 s.
- While a window is open the photo is multiplied by 0.0625, which is
  exposure -4 EV. In the graph this is a black overlay at alpha
  `DIM=0.9375`.
- The graphic is a full-frame 3840x2160 canvas and the artwork sits
  inside the PNG itself, so its size and position on screen are
  whatever the PNG carries.
- A transparent PNG (alpha pixel format) goes through the overlay path.
  A black-backed PNG goes through the screen-blend path. The bat picks
  by probing the file's pixel format with ffprobe.

## Encoders

- NVENC, if a real test encode passes:
  `h264_nvenc, preset p5, tune hq, VBR CQ 22, maxrate 40M, bufsize 80M,
  spatial-aq 1`.
- CPU fallback: `libx264, preset medium, tune stillimage, crf 16`.
- Every graph ends with `scale=out_range=tv:out_color_matrix=bt709,
  format=yuv420p` and the stream is tagged `-color_range tv`. That tag
  is what stops range-assuming players from stretching the picture on
  playback.

## Render verification

A render only reports `[ ok ]` when all three of these hold:

1. The old output file was deleted before the render started, so a
   stale file can never pass as a new render.
2. ffmpeg exited with code 0.
3. The finished file's probed duration is within 2.0 s of the computed
   timeline.

Failed renders delete their partial output. After a good render the
bat measures where the sound actually starts, with silencedetect, and
prints it. The built-in part is always 6.0 s. Anything past that is
the clip's own lead-in.

## Preparation specs (stage 1)

Voice (UVR, MDX-Net):

| Setting | Value |
| --- | --- |
| Model | any MDX-Net vocal model (.ckpt) from UVR's model downloads; the bat uses the one in UVR's models folder, or the file MODEL_PATH points at |
| Segment size | SEGMENT_SIZE in the bat; use your model's recommended value |
| Overlap | OVERLAP_MDXC in the bat |
| GPU conversion | on |
| Vocals only | on (no instrumental file kept) |
| Output | WAV PCM 16-bit, same folder and name as the source |
| Source | deleted after a verified conversion (toggle) |

Images (Real-ESRGAN):

| Setting | Value |
| --- | --- |
| Model | I_MODEL in ALL_IN_ONE (scale is I_SCALE); the ncnn release ships several models |
| Finish | downscale only, to 2560 px wide JPG |
| Quality | 95, stepping down by 5 until the file fits 2,000,000 bytes |
| Skip rule | sources already 2560 px wide or wider are left untouched |
| Replacement | in place; PNG masters exist only during the run |

---

Part of [Linea](https://github.com/iK4w4/Linea) · © 2026 Kawa (@iK4w4) · MIT License
