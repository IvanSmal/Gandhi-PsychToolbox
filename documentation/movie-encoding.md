# Preparing movie files for the rigs

How to encode a movie before using it as a stimulus (HandBrake, ffmpeg or
similar). Background: [timing.md](timing.md) for how movie frames are logged.

## What encoding fixes and what it doesn't

The 2026-10-27 stress test on rig2 (NASA 1080p60 H.264 clip at 120 Hz) found
that decoding is not the bottleneck: software decoding runs at about 440 fps,
over 7 times what a 60 fps movie needs. The uneven cadence it showed (most
frames held 2 flips, some 1 or 3) comes from frames being released on
GStreamer's clock instead of the display's vsync. Re-encoding does not change
that; only vsync-locked playback in GraphicsHandler does.

Encoding still matters for the problems in the table: a frame rate that cannot
be shown evenly, approximate frame numbers, slow or imprecise seeks, scaling.

## Settings

| Setting | Why | HandBrake |
|---|---|---|
| **Frame rate that divides the display rate** (60 or 30 for 120 Hz; 60 or 30 for 60 Hz) | 24, 25 or 29.97 fps on 120 Hz can't be shown evenly however playback works: frames must alternate between 4 and 5 flips. | Framerate 60 or 30, **Constant Framerate** |
| **Constant frame rate** | Phone and screen recordings are often variable-rate, which makes `movie_frame` approximate (see timing.md). | Constant Framerate |
| **Short keyframe interval** (every frame to every ~0.5 s) | A seek has to decode forward from the previous keyframe. With long gaps between keyframes, seeks are slower and land less predictably. | x264 extra options: `keyint=30:min-keyint=1`; `keyint=1` is all-intra (larger files) |
| **No B-frames, `tune fastdecode`** | Cheaper, simpler decoding, with no frame reordering. | x264 `bframes=0`, Tune: fastdecode |
| **Display resolution, 8-bit 4:2:0** | No scaling at draw time, and no slow 10-bit paths. | 1920×1080, H.264 8-bit |
| **No audio track** | Nothing to decode or keep in sync. | Remove audio |

## Going further

- **Intra-only files** (Motion JPEG, like the timing test movie from
  `makeMovieTimingTest`, or H.264 with `keyint=1`). Every frame is independent,
  so seeks are exact and instant, and stepping frame by frame is cheap. Files
  are 3–10× bigger, which is fine on local disk.
- **Pre-decoding into textures**: load every frame into GPU memory before the
  trial and draw them yourself, with no decoder at run time. Full control, but a
  1080p frame is about 8 MB, so 8 s at 60 fps is about 4 GB: too much for the
  RX 6600's 8 GB in general. Only practical for short clips or smaller sizes.

## Status

These are guidelines; no re-encoded file has been tested on a rig yet. A
planned check: re-encode the NASA stress clip all-intra with no B-frames and
rerun the stress task on rig2. The expected result is the same 1/2/3-flip
cadence, confirming that encoding is not its cause.
