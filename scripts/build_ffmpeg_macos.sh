#!/bin/bash
# Builds FFmpeg 7.1.2 with the AVS+ (Guangdian profile) cavs decoder on macOS, as static libraries
# for OnAir (-DDECT2_FFMPEG_PREFIX) plus an ffmpeg program for testing. Needs the Xcode command
# line tools only. Expects ffmpeg-7.1.2.tar.xz and avsplus-ffmpeg-7.1.2.patch in ~/avsplus.
set -e
ROOT=$HOME/avsplus
SRC=$ROOT/ffmpeg-7.1.2
PREFIX=$ROOT/ffmpeg-prefix
BUILD=$ROOT/build-ffmpeg
cd "$ROOT"
echo "089bc60fb59d6aecc5d994ff530fd0dcb3ee39aa55867849a2bbc4e555f9c304  ffmpeg-7.1.2.tar.xz" | shasum -a 256 -c -
rm -rf "$SRC" "$BUILD" "$PREFIX"
tar -xf ffmpeg-7.1.2.tar.xz
(cd "$SRC" && patch -p1 < "$ROOT/avsplus-ffmpeg-7.1.2.patch")
mkdir -p "$BUILD" && cd "$BUILD"
"$SRC"/configure --prefix="$PREFIX" --enable-static --disable-shared --enable-pic \
  --disable-doc --disable-debug --disable-network --disable-autodetect \
  --disable-avdevice --disable-ffplay --disable-ffprobe \
  --enable-videotoolbox \
  > "$ROOT/configure.log" 2>&1 || { tail -30 "$ROOT/configure.log"; exit 1; }
make -j"$(sysctl -n hw.ncpu)"
make install
"$PREFIX"/bin/ffmpeg -hide_banner -h decoder=cavs | head -3
