#!/bin/bash
# Packages the AVS+ build of OnAir as OnAir.app and a .dmg with the project's own packaging script,
# pointed at the patched static FFmpeg. Run after build_onair_macos.sh.
# Result: ~/avsplus/OnAir/build-release/OnAir.app and OnAir-<version>-macos-<arch>.dmg next to it.
set -e
eval "$(/opt/homebrew/bin/brew shellenv)"
ROOT=$HOME/avsplus
cd "$ROOT/OnAir"
export DECT2_FFMPEG_PREFIX=$ROOT/ffmpeg-prefix
# the radio libraries OnAir can bundle (RTL-SDR, Airspy, LimeSuite, Hamlib, ...) are optional here: only the HackRF is needed
export ONAIR_ALLOW_MISSING_RADIO_LIBS=1
# Homebrew libraries on this Mac are built for its own macOS, not the 15.0 floor of the official downloads
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-$(sw_vers -productVersion | cut -d. -f1).0}
bash tools/package/make_dmg.sh
ls -la build-release/*.dmg
otool -L build-release/OnAir.app/Contents/MacOS/OnAir | grep -i avcodec || echo "FFmpeg is linked statically into OnAir.app"
