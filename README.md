# AVS+ video for OnAir (DTMB television in China)

Patches and build scripts that make [OnAir](https://github.com/adswill/OnAir) show the picture of
DTMB channels whose video is AVS+. OnAir out of the box plays the sound of such a channel and says
"AVS+ video: FFmpeg decodes only the AVS JiZhun profile, not AVS+ (broadcast profile 0x48), so there
is no picture".

Tested on 2026-10-17 with a HackRF One on an Apple M4 Mac mini (macOS 27.0.1), on the Jiangsu
(JSBC) multiplex: the JSCS channel plays with picture and sound. The Linux packages are built and
checked on x86-64 (decoder and test suite, no DTMB signal at hand); the Windows programs are
cross-compiled and checked under Wine only.

## Why there is no picture

AVS+ is not a separate codec. It is the *Guangdian* (broadcast) profile, id 0x48, of the Chinese
AVS1 video standard (GB/T 20090.16, "AVS1-P16"). It adds weighted quantization, arithmetic entropy
coding (AEC) and interlace tools to the *JiZhun* (baseline) profile, id 0x20, of AVS1-P2.

FFmpeg's `cavs` decoder (`libavcodec/cavsdec.c`) implements JiZhun only. Its sequence-header parser
returns "only support JiZhun profile" for every other profile, and because the caller ignores that
return value, the decoder then mis-decodes the pictures rather than stopping. This is true of every
FFmpeg release, so no distribution's FFmpeg plays AVS+.

OnAir knows this: `core/src/player.cpp` reads the profile byte of the first sequence header on the
video PID and, for 0x48, closes the decoder and shows the note above instead of garbage.

## What the patches do

### `avsplus-ffmpeg-7.1.2.patch` (against the FFmpeg 7.1.2 release tarball)

Replaces FFmpeg's `cavs` decoder with the AVS1-P2 + AVS1-P16 decoder published in
<https://github.com/maliwen2015/ffmpeg_cavs_dra> (`libavcodec/libcavs.c`, `libcavs.h`,
`libcavsdec.c`). The codec keeps the name `cavs` and the id `AV_CODEC_ID_CAVS`, so demuxing and
stream selection in applications need no change. Compared with the upstream patch:

- Only the AVS+ part is taken. The DRA audio decoder and its codec-id, MPEG-TS and `allcodecs.c`
  hunks are left out, as is an unrelated edit to the H.264 SEI object list.
- The upstream patch file is malformed (its 18,000-line hunk declares two lines more than it has)
  and its files use CRLF line endings; the new files are added whole, with LF endings.
- `cavs_cpu_num_processors()` used `sched_getaffinity` / `cpu_set_t`, which macOS lacks. It now
  does so on Linux only and uses `sysconf(_SC_NPROCESSORS_ONLN)` elsewhere; `<unistd.h>` is
  included for it and for `nice()`.
- `init_crop_table()` is made `static`: FFmpeg builds with `-Werror=missing-prototypes` under clang.
- The decoder gets an `AVCodec::profiles` table (`0x20 JiZhun`, `0x48 Guangdian`). FFmpeg's own
  `cavs` decoder lists no profiles, so an application can tell the two apart through the public API.
- The Makefile lists `mpeg12data.o` with the decoder (it uses `ff_mpeg12_frame_rate_tab`) so the
  decoder links when it is the only one enabled; `cavs_decoder_select` in `configure` is dropped
  since the old DSP helpers are no longer used.

### `onair-avsplus.patch` (against OnAir commit `5003cf20`, 2026-10-17)

- `core/src/player.cpp`, `core/include/dect2/player.h`: instead of refusing profile 0x48 outright,
  the player asks the `cavs` decoder whether it lists the profile found in the stream, and only shows
  the "no picture" note when it does not. With a stock FFmpeg nothing changes.
- `tests/test_ts.cpp`: a check that a decoder listing the profile gets no note.
- `app/codec_help.cpp`, `docs/CODECS.md`: the help text and codec documentation say how AVS+ can be
  played.
- `CMakeLists.txt`: when OnAir is built against a static FFmpeg (`-DDECT2_FFMPEG_PREFIX`), the
  pkg-config flags on macOS contain `-framework X` pairs, which `pkg_check_modules` splits into two
  list items and CMake then links as `-lX` ("library 'CoreFoundation' not found"). They are joined
  again.
- `tools/package/make_dmg.sh`: passes a `DECT2_FFMPEG_PREFIX` environment variable on to CMake, so
  the packaged OnAir.app uses the patched FFmpeg instead of Homebrew's.
- `tools/package/build_ffmpeg_static.sh` (the static FFmpeg of the Linux packages): FFmpeg 7.1.2
  instead of 8.0, the patch applied from `tools/package/patches/`, and the `cavs` decoder and
  `cavsvideo` parser added to its component list (it had no AVS decoder at all, so the Linux
  packages showed no picture even for plain AVS channels). `make_deb.sh` looks for the 7.1.2 tarball.
- `tools/package/cross_deps_windows.sh` (the FFmpeg of the Windows cross-build): the same version
  change and patch step.

The OnAir patch expects `avsplus-ffmpeg-7.1.2.patch` at `tools/package/patches/` in the OnAir
tree; the scripts below copy it there.

## How to build

All scripts work in `~/avsplus`:

```sh
mkdir -p ~/avsplus && cp -r patches/* scripts/* ~/avsplus/
cd ~/avsplus
```

### macOS (Apple Silicon or Intel)

Needs the Xcode command line tools and Homebrew with
`cmake pkg-config hackrf soapysdr libusb glfw` (`nasm` too on Intel).

```sh
curl -fsSLO https://ffmpeg.org/releases/ffmpeg-7.1.2.tar.xz   # the script checks its SHA-256
bash build_ffmpeg_macos.sh     # FFmpeg 7.1.2 + AVS+, static, into ~/avsplus/ffmpeg-prefix
bash build_onair_macos.sh      # OnAir at commit 5003cf20 + patch, built against it; runs test_ts
bash make_app_macos.sh         # OnAir.app and a .dmg in ~/avsplus/OnAir/build-release/
```

`~/avsplus/OnAir/build/dect2` runs directly after the second step. The .app from the third step is
signed ad hoc, so macOS asks once on first launch. It has the same bundle identifier as the official
OnAir.app; keep them in different folders or replace the official one knowingly.

### Linux (.deb, .tar.gz and portable packages)

Needs Docker and git; everything else happens in OnAir's own build container (Ubuntu 22.04, so the
packages run on anything newer).

```sh
bash build_linux_packages.sh   # ~/avsplus/OnAir/build-packages/onair_<v>_<arch>.deb and the tarballs
```

This is OnAir's `make_deb.sh` on the patched tree. `PLATFORM=linux/arm64` (or `linux/amd64`) builds
the other architecture under emulation, as the script documents. The static FFmpeg it builds is
cached in a Docker volume; the script removes a stale one first.

### Windows (cross-compile check)

Needs Docker and git. Builds OnAir's Windows programs with mingw-w64 in a container and runs the
test suite and the decoder check under Wine. It is a build check with the HackRF driver only, not the
official package with every radio library; packaging those is OnAir's `make_windows_cross.sh`, which
needs all of its dependency archives.

```sh
bash crossbuild_windows.sh     # ~/avsplus/wincross/work/onair-build/{dect2,dect2cli,test_ts}.exe
```

Checking the decoder alone: record the channel from OnAir (TV tab, **Record**) and run
`~/avsplus/ffmpeg-prefix/bin/ffmpeg -i recording.ts -an -c:v rawvideo -f rawvideo -y /dev/null`.
A working decoder reports the frame count with no decoder errors; a stock ffmpeg shows nothing but
"only support JiZhun profile" messages.

## What was verified

- The patched FFmpeg builds on Linux (GCC 13), macOS (Apple clang 21) and for Windows x64
  (mingw-w64 GCC 13) and, configured with nothing but the `cavs` decoder, links on its own.
- A 19-second recording of JSCS (profile byte 0x48) decodes with no decoder errors on all three:
  the same 295 pictures from the static FFmpeg of the Linux package and from the Windows build under
  Wine, clean pictures when viewed.
- The decoder's profile table is visible through `avcodec_find_decoder(AV_CODEC_ID_CAVS)->profiles`.
- OnAir builds against it on macOS with FFmpeg linked statically; its `test_ts` suite passes; the
  live DTMB channel shows a picture in the player.
- The Linux `.deb` and portable packages build in OnAir's container with the patched static FFmpeg
  inside (no FFmpeg shared-library dependency); `test_ts` passes there.
- The Windows `dect2.exe`, `dect2cli.exe` and `test_ts.exe` cross-compile; `test_ts.exe` passes under
  Wine. No Windows machine or radio was involved.

## Caveats

- **Licensing and patents.** The decoder repository is MIT-licensed as a whole and its libavcodec
  wrapper carries FFmpeg's LGPL header, but `libcavs.c` itself has no licence header and its origin
  is not stated. AVS+ is a patented codec. OnAir upstream deliberately ships no patented codec, which
  is why this is a personal build and not a pull request. Check the rules where you live.
- Software decoding only: VideoToolbox has no AVS support. 720x576 decodes at well over real time
  on an M4.
- The OnAir patch is against one commit; later OnAir versions may need it rebased.
- The FFmpeg patch is against 7.1.2. OnAir's official downloads use FFmpeg 8; the patch has not been
  tried on 8.x.

## License

The build scripts and this document are under the Apache License 2.0 (`LICENSE`). The patches
modify FFmpeg (LGPL-2.1-or-later) and OnAir (GPL-3.0-or-later) and are offered under those
projects' licences; the decoder the FFmpeg patch adds has the provenance described under Caveats.

## Files

| File | What |
|---|---|
| `patches/avsplus-ffmpeg-7.1.2.patch` | the FFmpeg change, `patch -p1` inside `ffmpeg-7.1.2/` |
| `patches/onair-avsplus.patch` | the OnAir change, `git apply` at commit `5003cf20` |
| `scripts/build_ffmpeg_macos.sh` | FFmpeg 7.1.2 + patch, static, for OnAir |
| `scripts/build_onair_macos.sh` | OnAir + patch against that FFmpeg, runs `test_ts` |
| `scripts/make_app_macos.sh` | OnAir.app and .dmg via OnAir's `make_dmg.sh` |
| `scripts/build_linux_packages.sh` | the Linux packages via OnAir's `make_deb.sh` (Docker) |
| `scripts/crossbuild_windows.sh` | Windows cross-compile check (Docker, mingw-w64, Wine) |
| `scripts/wincross/` | the container, its build steps and the decoder check program for the above |
