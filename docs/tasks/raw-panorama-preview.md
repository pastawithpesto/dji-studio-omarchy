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

## Implementation choices

Use `dji-reframe --raw-panorama INPUT OUTPUT` to write an MP4 preview. FFprobe supplies the stream indexes, codecs, dimensions, and average frame rates. The mode ignores MJPEG video, attached pictures, and timed thumbnails. Exactly two other video streams must remain. Both streams must have the same codec, square dimensions, and positive average frame rate. Compare frame rates as rational numbers. Refuse an unclear pair before FFmpeg starts.

FFmpeg joins the selected streams in their source order. It uses `hstack=inputs=2:shortest=1` and `v360=input=dfisheye:output=equirect:w=2048:h=1024`. Video ends when the shorter camera stream ends. The output uses H.264, CRF 20, and `yuv420p`. The mode keeps source video timestamps with `-fps_mode passthrough`. It encodes the first audio stream as AAC when audio is present. Audio keeps its own duration. The mode refuses an existing output path. FFmpeg also uses `-n`. The program passes process arguments directly.

These settings are design choices. Stream shape does not prove the camera model or lens layout. No DJI lens calibration or seam correction is applied.

## Author validation

The author checked remote main at `2026-10-12T05:16:51.8429867Z`. Its SHA was `366dd125c928ea3bf1c813d6f6b42abc1242e13d`. It was an ancestor of task HEAD `6ef9ab34cf6d1ecbb15153039c78c1a7d03a3010` before the implementation commit. The branch was `work/raw-panorama-preview-20261012`. The worktree was `C:\Users\svg-9\Desktop\dji-studio-linux-raw-panorama-20261012`. All 20 open PR claims had separate file scopes.

Local command checks used Windows FFmpeg and FFprobe `9.0.1-full_build-www.gyan.dev`. The integration tests were written but did not run locally. Rust and Cargo were unavailable. The PR CI must compile the exact candidate and run `cargo test --locked`.

`tests/cli_raw_panorama.rs` creates small media files in a test-owned temporary directory. It runs the CLI with an MJPEG stream before the camera streams. The source also has two audio streams. The test checks H.264 output, 2048 x 1024 dimensions, 12 decoded video frames, 12 fps, and one AAC stream. It checks that the audio has the first stream's 440 Hz tone. It decodes the complete output with `-xerror`. Other cases test absent audio, one or three camera streams, non-square streams, different dimensions, different frame rates, invalid media, incorrect argument count, and an existing output.

The author ran the following source and export commands directly. These commands test FFmpeg behavior. They do not test the compiled Rust CLI.

```powershell
ffmpeg -v error -nostdin -n -f lavfi -i 'color=c=green:s=32x32:r=12' -f lavfi -i 'testsrc2=s=64x64:r=12' -f lavfi -i 'testsrc2=s=64x64:r=12' -f lavfi -i 'sine=frequency=440:sample_rate=48000' -f lavfi -i 'sine=frequency=880:sample_rate=48000' -map 0:v:0 -map 3:a:0 -map 1:v:0 -map 2:v:0 -map 4:a:0 -c:v libx264 -c:v:0 mjpeg -threads:v 1 -pix_fmt yuv420p -c:a aac -t 1 -f matroska test-input.osv
ffmpeg -v error -nostdin -n -i test-input.osv -filter_complex '[0:2][0:3]hstack=inputs=2:shortest=1,v360=input=dfisheye:output=equirect:w=2048:h=1024[panorama]' -map '[panorama]' -map '0:a:0?' -c:v libx264 -crf 20 -pix_fmt yuv420p -fps_mode passthrough -c:a aac -movflags +faststart -f mp4 test-preview.mp4
ffprobe -v error -count_frames -show_entries 'stream=index,codec_type,codec_name,width,height,nb_read_frames,avg_frame_rate' -of json test-preview.mp4
ffmpeg -v error -xerror -nostdin -i test-preview.mp4 -map 0:v:0 -map '0:a?' -f null -
```

The generated source SHA-256 was `bd956aeaf8f2bd448ab3965b6d10de3d559ac3ec698c920bfba622decc34c804`. The output SHA-256 was `0cc564f9f62a3dcf1ead89a7789fd20fc1da8e527878c7cbc4b37b172afeecd1`. The output had 12 H.264 frames at 2048 x 1024 and 12 fps. It had one AAC stream. Complete video and audio decoding passed. Generated container hashes can change between runs.

The author also used the same export command on the pinned local OSV file. The filter used camera indexes `0` and `1`. The output SHA-256 was `e9e56911eebb1a97f7cdf4080e4c2233edf10542e1932e0401ad8d908af810f9`. The output had 47 H.264 frames at 2048 x 1024 and 50 fps. It had one AAC stream. Complete video and audio decoding passed. Private media and local outputs are not included in the repository.

Independent Sol High review and Astra High verification are pending. A reproducible Windows panorama comparison is pending. Do not mark the feature complete.
