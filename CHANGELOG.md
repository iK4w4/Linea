# Changelog

## 1.0 - 2026-11-04

First tagged release. The five tools, as used for the channel:

- ALL_IN_ONE.bat - one run per episode pack: voice clean, then image
  upscale, folder by folder.
- CLEAN_VOICE_ALL.bat / SETUP_CLEAN_VOICE.bat - vocals-only WAVs with a
  UVR MDX-Net model, plus the one-time setup.
- MAKE_VIDEO.bat - the 4K render: intro card, voice at exactly 6.0s,
  loudnorm -14 LUFS, limited-range bt709 output in a VIDEOS subfolder.
- REALCUGAN.bat - photo and video upscaling with a progress monitor.

Changes on release day:

- Safety: ALL_IN_ONE no longer deletes source clips by default.
  `A_DELETE_SOURCE` now defaults to 0 (kept); set it to 1 if you want
  sources deleted after a successful clean. The README says this near
  the top, together with a note that you need the rights to the media
  you process.
- The voice model is a setting, not a name: the bats take any vocal
  .ckpt in UVR's MDX_Net_Models folder, or a MODEL_PATH you pin.
- README and docs/FORMAT.md rewritten in plain first person, with the
  measured notes (the loudnorm/adelay tone test, the full-range bug)
  kept as they happened.
