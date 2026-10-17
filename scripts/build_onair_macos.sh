#!/bin/bash
# Builds OnAir on macOS with AVS+ video: OnAir at the commit the patch was made for, the OnAir patch,
# and the AVS+-patched static FFmpeg from build_ffmpeg_macos.sh. Needs Homebrew with
# cmake pkg-config hackrf soapysdr libusb glfw. Result: ~/avsplus/OnAir/build/dect2 (the app).
set -e
eval "$(/opt/homebrew/bin/brew shellenv)"
ROOT=$HOME/avsplus
COMMIT=5003cf20c3eae03e52fef6b88a034cf9afff0bf0
cd "$ROOT"
[ -d OnAir ] || git clone https://github.com/adswill/OnAir
cd OnAir
git checkout -q -- .
git checkout -q "$COMMIT"
git apply "$ROOT/onair-avsplus.patch"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DDECT2_BUILD_APP=ON -DDECT2_BUILD_TESTS=ON \
  -DDECT2_FFMPEG_PREFIX="$ROOT/ffmpeg-prefix"
cmake --build build -j"$(sysctl -n hw.ncpu)" --target dect2 test_ts
./build/test_ts | tail -3
otool -L build/dect2 | grep -i -E 'avcodec|avformat' || echo "FFmpeg is linked statically (no libav*.dylib dependency)"
