#!/bin/bash
# Builds the OnAir Linux packages (.deb, .tar.gz, portable .tar.gz) with AVS+ video, using OnAir's own Docker-based packaging
# script. Needs Docker and git. Result: ~/avsplus/OnAir/build-packages/. As with make_deb.sh, PLATFORM=linux/amd64 or
# PLATFORM=linux/arm64 builds the other architecture under emulation.
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
mkdir -p tools/package/cache
[ -f tools/package/cache/ffmpeg-7.1.2.tar.xz ] || curl -fsSL -o tools/package/cache/ffmpeg-7.1.2.tar.xz https://ffmpeg.org/releases/ffmpeg-7.1.2.tar.xz
echo "089bc60fb59d6aecc5d994ff530fd0dcb3ee39aa55867849a2bbc4e555f9c304  tools/package/cache/ffmpeg-7.1.2.tar.xz" | sha256sum -c -
# make_deb.sh keeps its static FFmpeg in a Docker volume and reuses it: an FFmpeg of another version built earlier would be taken as it is
docker volume rm -f onair-pkg-ffmpeg onair-pkg-ffmpeg-x86 >/dev/null 2>&1 || true
tools/package/make_deb.sh
ls -la build-packages/
