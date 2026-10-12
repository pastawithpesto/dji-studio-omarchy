# Raw panorama preview

Owner: `revmnds`.

## Goal

Add an explicit CLI mode that reads two camera video streams and writes a 2:1 panorama preview. Use FFmpeg to join the streams and map dual fisheye video to equirectangular video. This is a native workflow design choice. It is not a recovered DJI Studio contract.

## Scope

- `src/main.rs`
- `tests/cli_raw_panorama.rs`
- `docs/tasks/raw-panorama-preview.md`

## Input evidence

The local camera file `CAM_20260926140513_0225_D.OSV` has SHA-256 `b4e86b8404e56c7bd68baea7d308cf5f0b22b52e0570047813ac4b036ee96c53`. It has two HEVC video streams. Each stream has 47 frames at 3840 x 3840 and 50 fps. Both streams decode with FFmpeg. The file has AAC audio, four data streams, and one MJPEG preview stream.

A local FFmpeg trial used `hstack=inputs=2` and `v360=input=dfisheye:output=equirect:w=2048:h=1024`. The output has 47 H.264 frames at 50 fps and AAC audio. The image shows the full scene. It also shows visible seam and lens errors. Do not use this trial as proof of DJI Studio parity.

## Work

1. Check the input stream list. Select two matching square camera video streams. Reject an input with no clear pair.
2. Add `--raw-panorama INPUT OUTPUT`. Keep the existing reframe mode separate. Refuse an existing output path.
3. Write a 2048 x 1024 H.264 panorama preview. Include the first audio stream when present.
4. Test stream selection and output with a small generated dual-stream file. Test the local camera file without adding private media to the repository.
5. Obtain independent Sol High review and Astra High milestone verification for the exact commit.

## Limit

The preview does not use DJI lens calibration, seam masks, or GPU processing. A matching Windows equirectangular export is not confirmed. Keep this feature experimental until a reproducible Windows comparison passes.
