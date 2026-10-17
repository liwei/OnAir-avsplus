#!/bin/bash
# Cross-compiles the Windows x64 programs of OnAir with AVS+ video (OnAir.exe as dect2.exe, onair-cli as dect2cli.exe, test_ts.exe)
# in a Docker container with mingw-w64, and runs the test programs under Wine. A build check, not a full Windows package: the
# optional radio libraries of the official download are left out. Needs Docker and git. Result: ~/avsplus/wincross/work/onair-build/.
set -e
ROOT=$HOME/avsplus
COMMIT=5003cf20c3eae03e52fef6b88a034cf9afff0bf0
cd "$ROOT"
[ -d OnAir ] || git clone https://github.com/adswill/OnAir
cd OnAir
git checkout -q -- .
git checkout -q "$COMMIT"
git apply "$ROOT/onair-avsplus.patch"
cp "$ROOT/avsplus-ffmpeg-7.1.2.patch" tools/package/patches/
# the dependency sources, at the versions cross_deps_windows.sh names (it downloads nothing itself)
S=build-windows-deps/src
mkdir -p $S
[ -f $S/libusb-1.0.27.tar.bz2 ] || curl -fsSL -o $S/libusb-1.0.27.tar.bz2 https://github.com/libusb/libusb/releases/download/v1.0.27/libusb-1.0.27.tar.bz2
[ -f $S/glfw-3.4.zip ] || curl -fsSL -o $S/glfw-3.4.zip https://github.com/glfw/glfw/releases/download/3.4/glfw-3.4.zip
[ -f $S/hackrf-2024.02.1.tar.xz ] || curl -fsSL -o $S/hackrf-2024.02.1.tar.xz https://github.com/greatscottgadgets/hackrf/releases/download/v2024.02.1/hackrf-2024.02.1.tar.xz
[ -f $S/ffmpeg-7.1.2.tar.xz ] || curl -fsSL -o $S/ffmpeg-7.1.2.tar.xz https://ffmpeg.org/releases/ffmpeg-7.1.2.tar.xz
sha256sum -c - <<EOF
ffaa41d741a8a3bee244ac8e54a72ea05bf2879663c098c82fc5757853441575  $S/libusb-1.0.27.tar.bz2
b5ec004b2712fd08e8861dc271428f048775200a2df719ccf575143ba749a3e9  $S/glfw-3.4.zip
d9ced67e6b801cd02c18d0c4654ed18a4bcb36c24a64330c347dfccbd859ad16  $S/hackrf-2024.02.1.tar.xz
089bc60fb59d6aecc5d994ff530fd0dcb3ee39aa55867849a2bbc4e555f9c304  $S/ffmpeg-7.1.2.tar.xz
EOF
cd "$ROOT"
docker build -t onair-wincross "$ROOT/wincross"
mkdir -p wincross/prefix wincross/work
docker run --rm -v "$ROOT/OnAir":/src:ro -v "$ROOT":/avs:ro -v "$ROOT/wincross/prefix":/prefix -v "$ROOT/wincross/work":/work onair-wincross bash /avs/wincross/run.sh
